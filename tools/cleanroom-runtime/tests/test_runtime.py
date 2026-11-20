import contextlib
import ctypes
from ctypes import wintypes
import io
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time
import threading
import unittest
from unittest.mock import patch

TOOL = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL))
from common import RuntimeErrorDetail, check_tree, plain_path, relative, separate, sha256, verify_file, write_json
from prepare import allowed, java_args
from session import Game, Ownership, Session, maybe_json, read_java_args, validate_plan, wait_until
from windows_job import Job

FAKE = Path(__file__).with_name('fake_game.py')


class RuntimeTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='cleanroom-runtime-test-')
        self.root = Path(self.tmp.name) / 'runtime'
        self.root.mkdir()
        self.root = self.root.resolve()
        for side in ('client', 'server'):
            (self.root / side / 'config/devtool').mkdir(parents=True)
            (self.root / side / 'mods').mkdir()
        (self.root / 'server/eula.txt').write_text('eula=true\n')
        (self.root / 'libraries').mkdir()
        (self.root / 'libraries/input.jar').write_bytes(b'pinned input')
        self.manifest = {'schema': 1, 'root': str(self.root), 'minecraft': '1.12.2',
                         'java': {'path': sys.executable, 'sha256': sha256(sys.executable)},
                         'player': 'RuntimeTester', 'playerUuid': '00000000-0000-0000-0000-000000000000',
                         'protectedRoots': [], 'authorization': {'eulaAccepted': True, 'toolkitActions': True, 'clientLaunch': True, 'serverLaunch': True},
                         'immutable': {'libraries/input.jar': sha256(self.root / 'libraries/input.jar')}}
        write_json(self.root / 'runtime.json', self.manifest)
        self.sink = io.StringIO()

    def tearDown(self):
        self.tmp.cleanup()

    def session(self, steps, mode='server', **extra):
        plan = {'schema': 1, 'timeoutSeconds': 15, 'stopSeconds': 1, 'steps': steps, **extra}
        with contextlib.redirect_stdout(self.sink), patch.object(Game, 'command', lambda _: [sys.executable, str(FAKE), mode]):
            return Session(self.root, plan).run()

    def test_console_transport_and_graceful_shutdown(self):
        result = self.session([{'action': 'start', 'side': 'server', 'timeout': 3},
                               {'action': 'console', 'side': 'server', 'text': 'save-all', 'contains': 'ANSWER save-all', 'timeout': 3}])
        self.assertEqual('passed', result['status'])
        self.assertFalse((self.root / 'active.lock').exists())
        self.assertIn('stopped', (Path(result['evidence']) / 'events.json').read_text())

    def test_client_request_and_exit(self):
        result = self.session([{'action': 'start', 'side': 'client', 'timeout': 3},
                               {'action': 'request', 'side': 'client', 'channel': 'client-inbox', 'text': 'quit'},
                               {'action': 'expectExit', 'side': 'client', 'timeout': 3}], mode='client')
        self.assertEqual('passed', result['status'])

    def test_dead_process_is_failure(self):
        result = self.session([{'action': 'start', 'side': 'server', 'timeout': 3}], mode='crash')
        self.assertEqual('failed', result['status'])
        self.assertIn('17', str(result['errors']))

    def test_stale_readiness_cannot_pass(self):
        inbox = self.root / 'client/config/devtool/client-inbox'
        inbox.mkdir()
        write_json(inbox / 'status.json', {'startedAtMillis': 1})
        result = self.session([{'action': 'start', 'side': 'client', 'timeout': .4}], mode='stale')
        self.assertEqual('failed', result['status'])
        self.assertTrue((Path(result['evidence']) / '000-client/previous-client-inbox/status.json').exists())

    def test_unresponsive_process_is_killed_and_result_failed(self):
        result = self.session([{'action': 'start', 'side': 'server', 'timeout': .3}], mode='hang')
        self.assertEqual('failed', result['status'])
        self.assertIn('forced-cleanup', (Path(result['evidence']) / 'events.json').read_text())
        self.assertFalse((self.root / 'active.lock').exists())

    def test_wrong_toolkit_identity_is_failure(self):
        result = self.session([{'action': 'start', 'side': 'client', 'timeout': 3},
                               {'action': 'request', 'side': 'client', 'channel': 'client-inbox', 'text': 'open example', 'timeout': 3}], mode='wrong-id')
        self.assertEqual('failed', result['status'])
        self.assertIn('identity mismatch', str(result['errors']))

    def test_changed_input_prevents_launch(self):
        (self.root / 'libraries/input.jar').write_bytes(b'changed')
        result = self.session([{'action': 'start', 'side': 'server'}])
        self.assertEqual('failed', result['status'])
        self.assertFalse((self.root / 'server/child-pid.txt').exists())

    def test_extra_mod_prevents_launch(self):
        (self.root / 'server/mods/unlisted.jar').write_bytes(b'extra')
        result = self.session([{'action': 'start', 'side': 'server'}])
        self.assertEqual('failed', result['status'])
        self.assertIn('inventory changed', str(result['errors']))

    def test_llibrary_memory_repo_requires_exact_location_and_embedded_pin(self):
        core = 'llibrary-core-1.0.11-1.12.2.jar'
        path = self.root / 'server/mods/memory_repo/net/ilexiconn/llibrary-core/1.0.11-1.12.2' / core
        path.parent.mkdir(parents=True)
        path.write_bytes(b'embedded core')
        plan = {'schema': 1, 'steps': [{'action': 'start', 'side': 'server'}]}
        with self.assertRaisesRegex(RuntimeErrorDetail, 'inventory changed'):
            Session(self.root, plan).verify()
        self.manifest['allowedGenerated'] = {f'server/mods/1.12.2/{core}': sha256(path)}
        write_json(self.root / 'runtime.json', self.manifest)
        with self.assertRaisesRegex(RuntimeErrorDetail, 'inventory changed'):
            Session(self.root, plan).verify()
        self.manifest['cleanroom'] = '0.7.14-alpha'
        write_json(self.root / 'runtime.json', self.manifest)
        session = Session(self.root, plan)
        session.verify()
        path.write_bytes(b'changed core')
        with self.assertRaisesRegex(RuntimeErrorDetail, 'SHA-256 changed'):
            session.verify()
        path.write_bytes(b'embedded core')
        path.rename(path.parent.parent / core)
        with self.assertRaisesRegex(RuntimeErrorDetail, 'inventory changed'):
            session.verify()

    def test_expanded_save_name_boundary(self):
        for verb in ('create', 'open'):
            for prefix, valid in [('runtime-', True), ('overlong-', False)]:
                with self.subTest(verb=verb, prefix=prefix):
                    steps = [{'action': 'start', 'side': 'client', 'timeout': 3},
                             {'action': 'request', 'side': 'client', 'channel': 'client-inbox',
                              'text': f'{verb} {prefix}{{run}}'}]
                    result = self.session(steps, mode='client')
                    if valid:
                        self.assertEqual('passed', result['status'], result['errors'])
                    else:
                        self.assertIn('exceeds 32 characters', str(result['errors']))
                        self.assertFalse((Path(result['evidence']) / '000-client').exists())

    def test_declared_extracted_jar_is_allowed_but_changed_bytes_fail(self):
        path = self.root / 'server/mods/1.12.2/child.jar'
        path.parent.mkdir()
        path.write_bytes(b'expected child')
        self.manifest['allowedGenerated'] = {'server/mods/1.12.2/child.jar': sha256(path)}
        write_json(self.root / 'runtime.json', self.manifest)
        result = self.session([{'action': 'start', 'side': 'server', 'timeout': 3}])
        self.assertEqual('passed', result['status'])
        path.write_bytes(b'changed child')
        result = self.session([{'action': 'start', 'side': 'server', 'timeout': 3}])
        self.assertEqual('failed', result['status'])
        self.assertIn('SHA-256 changed', str(result['errors']))

    def test_occupied_port_leaves_listener_alone(self):
        with socket.socket() as listener:
            listener.setsockopt(socket.SOL_SOCKET, socket.SO_EXCLUSIVEADDRUSE, 1)
            listener.bind(('127.0.0.1', 0))
            listener.listen()
            result = self.session([{'action': 'start', 'side': 'server'}], port=listener.getsockname()[1])
            self.assertEqual('failed', result['status'])
            with socket.create_connection(listener.getsockname(), timeout=1):
                pass
        self.assertFalse((self.root / 'server/child-pid.txt').exists())

    def test_second_owner_refused_and_first_lock_preserved(self):
        lock = Ownership(self.root, self.root / 'evidence')
        before = (self.root / 'active.lock').read_bytes()
        try:
            with self.assertRaises(FileExistsError):
                self.session([{'action': 'start', 'side': 'server'}])
            self.assertEqual(before, (self.root / 'active.lock').read_bytes())
        finally:
            lock.close()

    def test_authorization_refused_before_launch(self):
        self.manifest['authorization']['clientLaunch'] = False
        write_json(self.root / 'runtime.json', self.manifest)
        with self.assertRaisesRegex(RuntimeErrorDetail, 'authorized'):
            self.session([{'action': 'start', 'side': 'client'}])
        self.assertFalse((self.root / 'active.lock').exists())

    def test_protected_root_overlap_refused(self):
        self.manifest['protectedRoots'] = [str(self.root.parent)]
        write_json(self.root / 'runtime.json', self.manifest)
        with self.assertRaisesRegex(RuntimeErrorDetail, 'overlaps'):
            self.session([{'action': 'start', 'side': 'server'}])

    def test_eula_alone_does_not_authorize_server_launch(self):
        self.manifest['authorization']['serverLaunch'] = False
        write_json(self.root / 'runtime.json', self.manifest)
        with self.assertRaisesRegex(RuntimeErrorDetail, 'server launch has not been authorized'):
            self.session([{'action': 'start', 'side': 'server'}])

    def test_interruption_requires_explicit_test_flag(self):
        result = self.session([{'action': 'start', 'side': 'server', 'timeout': 3}, {'action': 'interrupt', 'side': 'server'}])
        self.assertEqual('failed', result['status'])
        self.assertIn('not enabled', str(result['errors']))

    def test_real_process_restart_after_intentional_interruption(self):
        result = self.session([{'action': 'start', 'side': 'server', 'timeout': 3},
                               {'action': 'interrupt', 'side': 'server'}, {'action': 'stop', 'side': 'server'},
                               {'action': 'start', 'side': 'server', 'timeout': 3}], allowInterruptionTest=True)
        self.assertEqual('passed', result['status'])

    def test_deadline_is_not_success(self):
        result = self.session([{'action': 'start', 'side': 'server', 'timeout': 3},
                               {'action': 'waitLog', 'side': 'server', 'contains': 'NEVER', 'timeout': .3}])
        self.assertEqual('failed', result['status'])
        self.assertIn('deadline', str(result['errors']))

    MARK = '[DevToolkit][MARK] side=SERVER worldTick=1 label='

    def owner_wait_session(self, steps, release, timeout_seconds=15):
        """Run a session; when it records owner-wait, send the server console lines from another thread."""
        plan = {'schema': 1, 'timeoutSeconds': timeout_seconds, 'stopSeconds': 1, 'steps': steps}
        with contextlib.redirect_stdout(self.sink), patch.object(Game, 'command', lambda _: [sys.executable, str(FAKE), 'server']):
            session = Session(self.root, plan)

            def releaser():
                end = time.monotonic() + 10
                while time.monotonic() < end:
                    if any(e['event'] == 'owner-wait' for e in session.events) and 'server' in session.games:
                        time.sleep(.5)
                        for line in release:
                            session.record('test-sent', line=line)
                            session.games['server'].send_console(line)
                            time.sleep(.3)
                        return
                    time.sleep(.05)
            thread = threading.Thread(target=releaser)
            thread.start()
            result = session.run()
            thread.join()
        names = [e['event'] for e in session.events]
        return result, session, names

    def test_owner_wait_ends_only_on_a_fresh_toolkit_mark(self):
        result, session, names = self.owner_wait_session(
            [{'action': 'start', 'side': 'server', 'timeout': 3},
             {'action': 'ownerWait', 'side': 'server', 'contains': 'OWNER_DONE'}],
            ['OWNER_DONE said in chat', self.MARK + 'OWNER_DONE_LATER', self.MARK + 'OWNER_DONE'])
        self.assertEqual('passed', result['status'], result)
        self.assertEqual(1, names.count('owner-wait-released'))
        sent = [e['line'] for e in session.events if e['event'] == 'test-sent']
        self.assertEqual(3, len(sent))
        last_sent = max(i for i, n in enumerate(names) if n == 'test-sent')
        self.assertGreater(names.index('owner-wait-released'), last_sent)

    def test_owner_wait_ignores_a_mark_written_before_it(self):
        result, session, names = self.owner_wait_session(
            [{'action': 'start', 'side': 'server', 'timeout': 3},
             {'action': 'console', 'side': 'server', 'text': self.MARK + 'OWNER_DONE', 'contains': 'label=OWNER_DONE', 'timeout': 3},
             {'action': 'ownerWait', 'side': 'server', 'contains': 'OWNER_DONE'}], [], timeout_seconds=5)
        self.assertEqual('failed', result['status'])
        self.assertIn('owner-wait', names)
        self.assertIn('deadline', str(result['errors']))
        self.assertGreater(names.index('failure'), names.index('owner-wait'))
        self.assertNotIn('owner-wait-released', names)

    def test_owner_wait_needs_a_running_process(self):
        result = self.session([{'action': 'start', 'side': 'server', 'timeout': 3},
                               {'action': 'interrupt', 'side': 'server'},
                               {'action': 'ownerWait', 'side': 'server', 'contains': 'OWNER_DONE'}], allowInterruptionTest=True)
        self.assertEqual('failed', result['status'])
        self.assertIn('not running', str(result['errors']))

    def test_owner_wait_has_no_timer_of_its_own(self):
        for step in ({'action': 'ownerWait', 'side': 'server', 'contains': 'OWNER_DONE', 'timeout': 600},
                     {'action': 'ownerWait', 'side': 'server', 'contains': 'X'},
                     {'action': 'ownerWait', 'side': 'server', 'contains': 'two words'},
                     {'action': 'ownerWait', 'side': 'server', 'contains': '{run}_DONE'},
                     {'action': 'ownerWait', 'contains': 'OWNER_DONE'}):
            with self.subTest(step=step), self.assertRaises(RuntimeErrorDetail):
                validate_plan({'schema': 1, 'steps': [step]})
        validate_plan({'schema': 1, 'steps': [{'action': 'ownerWait', 'side': 'client', 'contains': 'OWNER_DONE'}]})

    def test_evidence_keeps_the_launch_arguments(self):
        (self.root / 'server.args').write_text('"-Dexample.flag=true"\n')
        result = self.session([{'action': 'start', 'side': 'server', 'timeout': 3}])
        self.assertEqual('passed', result['status'])
        self.assertIn('example.flag', (Path(result['evidence']) / 'server.args').read_text())

    def test_java_8_command_passes_the_verified_arguments_directly(self):
        args = ['-Dfile.encoding=UTF-8', '-cp', 'C:/runtime/a b.jar;C:/runtime/c.jar', 'main.Class', 'say "hi"']
        java_args(self.root / 'server.args', args)
        self.assertEqual(args, read_java_args(self.root / 'server.args'))
        self.manifest['argFile'] = False
        write_json(self.root / 'runtime.json', self.manifest)
        session_command = None
        with contextlib.redirect_stdout(self.sink):
            session = Session(self.root, {'schema': 1, 'steps': [{'action': 'start', 'side': 'server'}]})
            session.evidence.mkdir(parents=True)
            probe = Game(session, 'server', 'probe')
            session_command = probe.command()
            probe.log_handle.close()
        self.assertEqual([sys.executable, *args], session_command)
        (self.root / 'server.args').write_text('not quoted\n')
        with contextlib.redirect_stdout(self.sink):
            probe = Game(session, 'server', 'probe2')
        with self.assertRaisesRegex(RuntimeErrorDetail, 'argument file format'):
            probe.command()
        probe.log_handle.close()

    def test_java_8_command_refuses_an_overlong_command_line(self):
        java_args(self.root / 'server.args', ['-cp', ';'.join('C:/runtime/library-' + str(n) + '.jar' for n in range(1500)), 'main.Class'])
        self.manifest['argFile'] = False
        write_json(self.root / 'runtime.json', self.manifest)
        with contextlib.redirect_stdout(self.sink):
            session = Session(self.root, {'schema': 1, 'steps': [{'action': 'start', 'side': 'server'}]})
            session.evidence.mkdir(parents=True)
            probe = Game(session, 'server', 'probe')
        with self.assertRaisesRegex(RuntimeErrorDetail, 'command-line limit'):
            probe.command()
        probe.log_handle.close()

    def test_older_manifest_without_arg_file_uses_the_argument_file(self):
        self.assertNotIn('argFile', self.manifest)
        with contextlib.redirect_stdout(self.sink):
            session = Session(self.root, {'schema': 1, 'steps': [{'action': 'start', 'side': 'server'}]})
            session.evidence.mkdir(parents=True)
            probe = Game(session, 'server', 'probe')
        self.assertEqual([sys.executable, '@' + str(self.root / 'server.args')], probe.command())
        probe.log_handle.close()

    def test_unsafe_relative_paths(self):
        for value in ('../x', '/absolute', 'a/../b', 'a\\b', 'C:/x', 'x:stream', 'NUL.txt', 'a./b'):
            with self.subTest(value=value), self.assertRaises(RuntimeErrorDetail):
                relative(value)

    def test_hardlinked_runtime_file_refused(self):
        source = self.root / 'libraries/input.jar'
        os.link(source, self.root / 'libraries/link.jar')
        with self.assertRaisesRegex(RuntimeErrorDetail, 'Hard-linked'):
            check_tree(self.root)

    def test_junction_to_reference_is_refused(self):
        reference = self.root.parent / 'reference'
        reference.mkdir()
        junction = self.root / 'junction'
        subprocess.run(['cmd', '/d', '/c', 'mklink', '/J', str(junction), str(reference)], check=True, capture_output=True)
        try:
            with self.assertRaisesRegex(RuntimeErrorDetail, 'reparse'):
                check_tree(self.root)
        finally:
            os.rmdir(junction)

    def test_bad_plan_rejected_before_process(self):
        for step in ({'action': 'unknown'}, {'action': 'console', 'side': 'server', 'text': 'a\nb', 'contains': 'x'},
                     {'action': 'request', 'side': 'client', 'text': 'quit', 'expect': 'failed'}):
            with self.subTest(step=step), self.assertRaises(RuntimeErrorDetail):
                validate_plan({'schema': 1, 'steps': [step]})

    def test_missing_and_changed_cached_inputs(self):
        with self.assertRaises(RuntimeErrorDetail):
            verify_file(self.root / 'absent.jar', '0' * 64)
        with self.assertRaises(RuntimeErrorDetail):
            verify_file(self.root / 'libraries/input.jar', '0' * 64)

    def test_metadata_platform_rules(self):
        self.assertFalse(allowed({'rules': [{'action': 'allow', 'os': {'name': 'linux'}}]}))
        self.assertTrue(allowed({'rules': [{'action': 'allow', 'os': {'name': 'windows'}}]}))

    def test_windows_job_kills_child_on_close(self):
        job = Job()
        child = job.start([sys.executable, '-c', 'import time; time.sleep(60)'], stdout=subprocess.DEVNULL)
        job.close()
        child.wait(timeout=5)
        self.assertIsNotNone(child.returncode)

    def test_evidence_update_survives_temporary_windows_reader(self):
        path = self.root / 'evidence.json'
        write_json(path, {'value': 'old'})
        api = ctypes.WinDLL('kernel32', use_last_error=True)
        api.CreateFileW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD, ctypes.c_void_p, wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE]
        api.CreateFileW.restype = wintypes.HANDLE
        api.CloseHandle.argtypes = [wintypes.HANDLE]
        handle = api.CreateFileW(str(path), 0x80000000, 1, None, 3, 0, None)
        self.assertNotEqual(ctypes.c_void_p(-1).value, handle)
        release = threading.Timer(.25, lambda: api.CloseHandle(handle))
        release.start()
        try:
            write_json(path, {'value': 'new'})
        finally:
            release.join()
        self.assertEqual('new', json.loads(path.read_text())['value'])

    def test_live_toolkit_result_waits_for_windows_writer_to_release(self):
        path = self.root / 'answer.json'
        write_json(path, {'outcome': 'done'})
        api = ctypes.WinDLL('kernel32', use_last_error=True)
        api.CreateFileW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD, ctypes.c_void_p, wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE]
        api.CreateFileW.restype = wintypes.HANDLE
        api.CloseHandle.argtypes = [wintypes.HANDLE]
        handle = api.CreateFileW(str(path), 0x40000000, 0, None, 3, 0, None)
        self.assertNotEqual(ctypes.c_void_p(-1).value, handle)
        release = threading.Timer(.25, lambda: api.CloseHandle(handle))
        release.start()
        try:
            self.assertIsNone(maybe_json(path))
            self.assertEqual('done', wait_until(lambda: maybe_json(path), 2)['outcome'])
        finally:
            release.join()

    def test_abrupt_supervisor_exit_kills_only_owned_child(self):
        parent = subprocess.Popen([sys.executable, str(FAKE), 'job-parent'], cwd=self.root,
                                  creationflags=subprocess.CREATE_NO_WINDOW)
        sibling = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(60)'], creationflags=subprocess.CREATE_NO_WINDOW)
        api = ctypes.WinDLL('kernel32', use_last_error=True)
        api.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
        api.OpenProcess.restype = wintypes.HANDLE
        api.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
        api.CloseHandle.argtypes = [wintypes.HANDLE]
        handle = None
        try:
            path = self.root / 'job-child-pid.txt'
            wait_until(lambda: path.exists() and path.stat().st_size > 0, 5, [parent])
            handle = api.OpenProcess(0x100000, False, int(path.read_text()))
            self.assertTrue(handle)
            parent.kill()
            parent.wait(5)
            self.assertEqual(0, api.WaitForSingleObject(handle, 5000))
            self.assertIsNone(sibling.poll())
        finally:
            if parent.poll() is None:
                parent.kill()
                parent.wait(5)
            sibling.kill()
            sibling.wait(5)
            if handle:
                api.CloseHandle(handle)


if __name__ == '__main__':
    unittest.main()
