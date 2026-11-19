"""Bounded sessions over Java stdin and the Agent Test Toolkit file protocol."""
import datetime
import json
import os
from pathlib import Path
import re
import shutil
import socket
import subprocess
import threading
import time
import uuid

from common import (bounded, check_tree, plain_path, read_json, relative, require,
                    separate, sha256, verify_file, write_json)
from windows_job import Job


def read_java_args(path):
    """Arguments from a file written by prepare.java_args: one double-quoted argument per line."""
    result = []
    for line in path.read_text(encoding='utf-8').rstrip('\n').split('\n'):
        require(len(line) >= 2 and line[0] == '"' and line[-1] == '"', 'Unexpected launch argument file format')
        result.append(line[1:-1].replace('\\"', '"'))
    return result


def maybe_json(path):
    try:
        return read_json(path)
    except (FileNotFoundError, PermissionError, json.JSONDecodeError):
        return None


def wait_until(test, timeout, processes=(), deadline=None):
    end = min(time.monotonic() + timeout, deadline or float('inf'))
    while True:
        for child in processes:
            require(child.poll() is None, f'Owned process {child.pid} exited unexpectedly: {child.returncode}')
        value = test()
        if value:
            return value
        if time.monotonic() >= end:
            raise TimeoutError('Runtime condition deadline expired')
        time.sleep(.1)


class Ownership:
    def __init__(self, root, evidence):
        self.path = root / 'active.lock'
        self.token = uuid.uuid4().hex
        fd = os.open(self.path, os.O_WRONLY | os.O_CREAT | os.O_EXCL)
        with os.fdopen(fd, 'w', encoding='utf-8') as stream:
            json.dump({'pid': os.getpid(), 'token': self.token, 'evidence': str(evidence)}, stream)

    def close(self):
        require(read_json(self.path).get('token') == self.token, 'Ownership changed; retaining lock')
        self.path.unlink()


def validate_plan(plan):
    require(plan.get('schema') == 1, 'Expected session schema 1')
    bounded(plan.get('timeoutSeconds', 600), 1, 7200, 'timeoutSeconds')
    bounded(plan.get('stopSeconds', 30), 1, 60, 'stopSeconds')
    steps = plan.get('steps')
    require(isinstance(steps, list) and 0 < len(steps) <= 500, 'Use 1..500 session steps')
    actions = {'start', 'stop', 'console', 'bundle', 'request', 'screenshot', 'pair', 'interrupt', 'waitLog', 'ownerWait', 'expectExit'}
    for step in steps:
        require(step.get('action') in actions, 'Unknown session action')
        if step['action'] != 'pair':
            require(step.get('side') in ('server', 'client'), 'Each action needs a runtime side')
        if step['action'] == 'ownerWait':
            # Only the agent's fresh marker or the session deadline ends it; a timer cannot release an owner pause.
            require('timeout' not in step, 'ownerWait has no timeout; the session deadline bounds it')
            marker = step.get('contains', '')
            require(isinstance(marker, str) and bool(re.fullmatch('[A-Za-z0-9_.-]{4,128}', marker)), 'ownerWait needs a Toolkit mark label of 4..128 letters, digits, _ . or -')
            continue
        bounded(step.get('timeout', 120), .1, 600, 'step timeout')
        if step['action'] in ('console', 'request'):
            value = step.get('text', '')
            require(isinstance(value, str) and 0 < len(value) <= 512 and all(32 <= ord(c) <= 126 for c in value), 'Commands must be one printable ASCII line of 1..512 characters')
        if step['action'] == 'console':
            require(step['side'] == 'server' and bool(step.get('contains')), 'Console steps need an expected fresh log marker')
        if step['action'] == 'request':
            require(step.get('channel', 'inbox') in ('inbox', 'client-inbox'), 'Invalid Toolkit channel')
            require(step.get('expect', 'done') in ('done', 'failed', 'refused'), 'Invalid expected Toolkit result')
            if step.get('expect', 'done') != 'done':
                require(bool(step.get('reason')), 'Negative requests need the expected reason')
        if step['action'] == 'bundle':
            require(step['side'] == 'server' and bool(re.fullmatch('[A-Za-z0-9_-]+', step.get('name', ''))), 'Console bundles need a server and safe bundle name')
        if step['action'] == 'waitLog':
            require(bool(step.get('contains')), 'waitLog needs a marker')


class Game:
    def __init__(self, session, side, label):
        self.session, self.side, self.label = session, side, label
        self.dir = session.root / side
        self.evidence = session.evidence / label
        self.evidence.mkdir()
        # Retain prior channel state, then remove it from the active game before launch.
        for channel in ('inbox', 'client-inbox'):
            source = self.dir / 'config/devtool' / channel
            if source.exists():
                shutil.move(str(source), str(self.evidence / ('previous-' + channel)))
        self.snapshot('before')
        self.log_path = self.evidence / 'console.log'
        self.log_handle = self.log_path.open('w', encoding='utf-8')
        self.started = int(time.time() * 1000)
        self.p = None
        self.expected_exit = False

    def start(self):
        self.p = self.session.job.start(self.command(), cwd=self.dir, stdin=subprocess.PIPE,
                                        stdout=self.log_handle, stderr=subprocess.STDOUT, text=True, encoding='utf-8')
        self.session.record('launched', side=self.side, label=self.label, pid=self.p.pid)

    def command(self):
        java, args = self.session.manifest['java']['path'], self.session.root / (self.side + '.args')
        if self.session.manifest.get('argFile', True):
            return [java, '@' + str(args)]
        # Java 8 has no @argument files: pass the same verified arguments directly.
        command = [java, *read_java_args(args)]
        require(len(subprocess.list2cmdline(command)) < 32000, 'Launch command exceeds the Windows command-line limit')
        return command

    def log(self):
        return self.log_path.read_text(encoding='utf-8', errors='replace')

    def wait(self, test, timeout):
        return wait_until(test, timeout, [g.p for g in self.session.games.values() if g.p and not g.expected_exit], self.session.deadline)

    def fresh_mark(self, label):
        """A test for a Toolkit mark line with exactly this label, written to this console log after now.

        Reads only the new bytes on each poll and checks complete lines, so an ordinary log or chat line cannot release it."""
        pattern = re.compile(rb'\[DevToolkit\]\[MARK\].* label=' + re.escape(label.encode('ascii')) + rb'(?:\s|$)')
        with self.log_path.open('rb') as stream:
            state = {'position': stream.seek(0, 2), 'partial': b''}

        def test():
            with self.log_path.open('rb') as stream:
                stream.seek(state['position'])
                chunk = stream.read()
            state['position'] += len(chunk)
            lines = (state['partial'] + chunk).split(b'\n')
            state['partial'] = lines.pop()
            return any(pattern.search(line.rstrip(b'\r')) for line in lines)
        return test

    def ready(self, timeout):
        if self.side == 'server':
            self.wait(lambda: 'Done (' in self.log(), timeout)
        else:
            self.wait(lambda: (maybe_json(self.dir / 'config/devtool/client-inbox/status.json') or {}).get('startedAtMillis', 0) >= self.started, timeout)
        self.session.record('ready', side=self.side, label=self.label)

    def send_console(self, text):
        require(self.p.poll() is None, 'Cannot send to an exited server')
        self.p.stdin.write(text + '\n')
        self.p.stdin.flush()

    def request(self, text, channel='inbox', timeout=120, expect='done', reason=None, cleanup=False):
        inbox = self.dir / 'config/devtool' / channel
        waiter = (lambda test, seconds: wait_until(test, seconds, [self.p])) if cleanup else self.wait
        waiter(lambda: (inbox / 'status.json').exists(), timeout)
        request_id = 'run-' + uuid.uuid4().hex
        temp = inbox / (request_id + '.tmp')
        temp.write_text(text + '\n', encoding='ascii')
        temp.rename(inbox / (request_id + '.req'))
        answer = waiter(lambda: maybe_json(inbox / (request_id + '.result.json')), timeout)
        require(answer.get('id') == request_id and answer.get('request') == text, 'Toolkit answer identity mismatch')
        self.session.record('request', side=self.side, text=text, answer=answer)
        require(answer.get('outcome') == expect, f'Unexpected Toolkit result: {answer}')
        if reason:
            require(answer.get('reason') == reason, 'Unexpected failure reason')
        if text.startswith('run ') and 'resultFile' in answer:
            result = read_json(self.dir / 'config/devtool/results' / relative(answer['resultFile']))
            require(result.get('requestId') == request_id, 'Stale or unrelated bundle result')
            self.session.record('bundle-result', side=self.side, result=result)
        return answer

    def snapshot(self, phase):
        check_tree(self.dir)
        for name in ('config', 'scripts', 'logs', 'crash-reports', 'screenshots'):
            source = self.dir / name
            if source.exists():
                shutil.copytree(source, self.evidence / phase / name, ignore=shutil.ignore_patterns('local-join.secret'), dirs_exist_ok=True)
        for name in ('options.txt', 'server.properties', 'eula.txt', 'ops.json'):
            if (self.dir / name).exists():
                dest = self.evidence / phase / name
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(self.dir / name, dest)

    def stop(self):
        failed = None
        timeout = self.session.plan.get('stopSeconds', 30)
        try:
            if self.p and self.p.poll() is None:
                try:
                    if self.side == 'server':
                        self.send_console('stop')
                    else:
                        server = self.session.games.get('server')
                        if server and server.p.poll() is None and (server.dir / 'config/devtool/inbox/status.json').exists():
                            server.request('client quit', timeout=timeout, cleanup=True)
                        elif (self.dir / 'config/devtool/inbox/status.json').exists():
                            self.request('client quit', timeout=timeout, cleanup=True)
                        else:
                            self.request('quit', 'client-inbox', timeout=timeout, cleanup=True)
                    self.p.wait(timeout)
                    require(self.p.returncode == 0, f'Nonzero shutdown: {self.p.returncode}')
                    self.session.record('stopped', side=self.side, label=self.label, exitCode=self.p.returncode)
                except Exception as exc:
                    failed = exc
                    self.session.record('forced-cleanup', side=self.side, label=self.label, reason=str(exc))
                    if self.p.poll() is None:
                        self.p.kill()
                        self.p.wait(10)
            elif self.p:
                require(self.expected_exit, f'Unexpected early exit: {self.p.returncode}')
        finally:
            if self.p and self.p.poll() is None:
                self.p.kill()
                self.p.wait(10)
            if self.p and self.p.stdin:
                self.p.stdin.close()
            self.log_handle.close()
            self.snapshot('after')
        if failed:
            raise failed


class Session:
    def __init__(self, root, plan, job_factory=Job):
        self.root = plain_path(root)
        self.plan = plan
        validate_plan(plan)
        require(not (self.root / 'preparing.json').exists(), 'Runtime preparation is incomplete')
        self.manifest = read_json(self.root / 'runtime.json')
        require(self.manifest.get('schema') == 1 and self.manifest.get('minecraft') == '1.12.2' and self.manifest['root'] == str(self.root), 'Runtime identity mismatch or moved directory')
        for path in self.manifest['protectedRoots']:
            separate(self.root, plain_path(path))
        require(self.manifest['authorization'].get('toolkitActions') is True and self.manifest['authorization'].get('eulaAccepted') is True, 'Recorded runtime authorization missing')
        if any(s['action'] == 'start' and s['side'] == 'client' for s in plan['steps']):
            require(self.manifest['authorization'].get('clientLaunch') is True, 'Graphical client launch has not been authorized')
        if any(s['action'] == 'start' and s['side'] == 'server' for s in plan['steps']):
            require(self.manifest['authorization'].get('serverLaunch') is True, 'Local server launch has not been authorized')
        self.evidence = self.root / 'evidence' / (datetime.datetime.now().strftime('%Y%m%d-%H%M%S') + '-' + uuid.uuid4().hex[:8])
        self.games, self.events, self.port = {}, [], None
        self.job_factory = job_factory
        self.record_lock = threading.Lock()
        self.deadline = time.monotonic() + plan.get('timeoutSeconds', 600)

    def record(self, event, **values):
        # One writer at a time: events.json is replaced through a fixed temporary name.
        with self.record_lock:
            row = {'time': datetime.datetime.now().isoformat(), 'event': event, **values}
            self.events.append(row)
            print(json.dumps(row), flush=True)
            write_json(self.evidence / 'events.json', self.events)

    def verify(self):
        check_tree(self.root)
        verify_file(self.manifest['java']['path'], self.manifest['java']['sha256'])
        for path, digest in self.manifest['immutable'].items():
            verify_file(self.root / relative(path), digest)
        # No unlisted JARs may enter the runtime unnoticed.
        for side in ('client', 'server'):
            actual = {p.relative_to(self.root).as_posix() for p in (self.root / side / 'mods').rglob('*.jar')}
            expected = {p for p in self.manifest['immutable'] if p.startswith(side + '/mods/')}
            generated = self.manifest.get('allowedGenerated', {})
            require(expected <= actual and actual <= expected | set(generated), f'Mod inventory changed for {side}')
            for path in actual - expected:
                verify_file(self.root / relative(path), generated[path])

    def configure_server(self):
        with socket.socket() as sock:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_EXCLUSIVEADDRUSE, 1)
            chosen = self.plan.get('port', 0)
            require(type(chosen) is int and 0 <= chosen <= 65535, 'Invalid port')
            sock.bind(('127.0.0.1', chosen))
            self.port = sock.getsockname()[1]
        # Java binds next. A race is reported by readiness/early-exit, never by killing the listener.
        text = f'server-ip=127.0.0.1\nserver-port={self.port}\nonline-mode=false\nlevel-name=runtime-test\nlevel-type=FLAT\ngenerator-settings=3;minecraft:bedrock,2*minecraft:dirt,minecraft:grass;1;\nspawn-protection=0\nmax-players=2\nview-distance=4\ngamemode=1\nmax-tick-time=60000\nenable-rcon=false\nenable-query=false\n'
        (self.root / 'server/server.properties').write_text(text, encoding='utf-8')
        write_json(self.root / 'server/ops.json', [{'uuid': self.manifest['playerUuid'], 'name': self.manifest['player'], 'level': 4, 'bypassesPlayerLimit': False}])
        require('eula=true' in (self.root / 'server/eula.txt').read_text(), 'Runtime EULA file no longer records acceptance')
        self.record('server-configured', port=self.port, bind='127.0.0.1')

    def expand(self, text):
        if '{port}' in text:
            require(self.port is not None, 'No server port is active')
            text = text.replace('{port}', str(self.port))
        return text.replace('{player}', self.manifest['player']).replace('{run}', self.evidence.name)

    def step(self, step, number):
        action, side, timeout = step['action'], step.get('side'), step.get('timeout', 120)
        require(time.monotonic() < self.deadline, 'Session deadline expired')
        if action == 'start':
            require(side not in self.games, f'{side} already started')
            self.verify()
            if side == 'server':
                self.configure_server()
            game = Game(self, side, f'{number:03d}-{side}')
            self.games[side] = game
            game.start()
            game.ready(timeout)
            return
        if action == 'pair':
            require('server' in self.games and 'client' not in self.games, 'Pair after server startup and before client startup')
            server = self.games['server']
            secret = server.dir / 'config/devtool/local-join.secret'
            server.wait(secret.exists, timeout)
            shutil.copyfile(secret, self.root / 'client/config/devtool/local-join.secret')
            self.record('local-pairing', note='ephemeral proof copied only between the two isolated directories')
            return
        require(side in self.games, f'{side} is not running')
        game = self.games[side]
        if action == 'stop':
            try:
                game.stop()
            finally:
                del self.games[side]
        elif action == 'console':
            offset = len(game.log())
            game.send_console(self.expand(step['text']))
            game.wait(lambda: step['contains'] in game.log()[offset:], timeout)
        elif action == 'bundle':
            started = int(time.time() * 1000)
            name = step['name']
            game.send_console('devtool run ' + name)
            def result():
                for path in (game.dir / 'config/devtool/results').glob(name + '-*.json'):
                    data = maybe_json(path) or {}
                    if data.get('startedAtMillis', 0) >= started:
                        return data
            data = game.wait(result, timeout)
            self.record('console-bundle', result=data)
            require(int(data.get('failed', -1)) == 0 and data.get('bundle') == name and data.get('channel') == 'console', 'Console bundle failed or identity mismatched')
        elif action == 'request':
            game.request(self.expand(step['text']), step.get('channel', 'inbox'), timeout, step.get('expect', 'done'), step.get('reason'))
        elif action == 'screenshot':
            require('client' in self.games, 'Screenshot requires a live client')
            client = self.games['client']
            label = 'shot-' + uuid.uuid4().hex[:12]
            game.request('screenshot ' + label + ' 20 hide=hud', timeout=timeout)
            image = client.wait(lambda: next((client.dir / 'screenshots').glob(label + '-*.png'), None), timeout)
            client.wait(lambda: any('side=CLIENT' in line and 'action=saved' in line and image.name in line for line in client.log().splitlines()), timeout)
            self.record('screenshot', file=str(image), sha256=sha256(image))
        elif action == 'interrupt':
            require(self.plan.get('allowInterruptionTest') is True, 'Intentional interruption test is not enabled')
            game.p.kill()
            game.p.wait(10)
            game.expected_exit = True
            self.record('intentional-interruption', side=side, exitCode=game.p.returncode)
        elif action == 'expectExit':
            game.p.wait(min(timeout, max(.1, self.deadline - time.monotonic())))
            require(game.p.returncode == step.get('code', 0), 'Unexpected exit code')
            game.expected_exit = True
            self.record('expected-exit', side=side, exitCode=game.p.returncode)
        elif action == 'waitLog':
            game.wait(lambda: step['contains'] in game.log(), timeout)
        elif action == 'ownerWait':
            require(game.p is not None and game.p.poll() is None, f'{side} process is not running; nothing can release ownerWait')
            test = game.fresh_mark(step['contains'])
            self.record('owner-wait', side=side, contains=step['contains'])
            game.wait(test, max(.1, self.deadline - time.monotonic()))
            self.record('owner-wait-released', side=side, contains=step['contains'])

    def run(self):
        check_tree(self.root)
        ownership = Ownership(self.root, self.evidence)
        errors = []
        self.job = None
        try:
            self.evidence.mkdir(parents=True)
            write_json(self.evidence / 'plan.json', self.plan)
            shutil.copyfile(self.root / 'runtime.json', self.evidence / 'runtime.json')
            # The launch arguments, including any profile jvmArgs, belong to this run's evidence.
            for name in ('profile.json', 'client.args', 'server.args'):
                if (self.root / name).exists():
                    shutil.copyfile(self.root / name, self.evidence / name)
            for source in Path(__file__).parent.glob('*.py'):
                shutil.copyfile(source, self.evidence / source.name)
            self.verify()
            self.job = self.job_factory()
            self.record('session-start')
            for i, step in enumerate(self.plan['steps']):
                self.record('step', index=i, specification=step)
                self.step(step, i)
        except Exception as exc:
            errors.append(str(exc))
            self.record('failure', error=str(exc))
        finally:
            # Preserve the server while the client's quit request is processed.
            for side in ('client', 'server'):
                if side in self.games:
                    try:
                        self.games[side].stop()
                    except Exception as exc:
                        errors.append(f'{side} cleanup: {exc}')
            if self.job:
                self.job.close()
            for side in ('client', 'server'):
                proof = self.root / side / 'config/devtool/local-join.secret'
                if proof.exists():
                    try:
                        plain_path(proof).unlink()
                    except Exception as exc:
                        errors.append(f'Proof cleanup: {exc}')
            try:
                ownership.close()
            except Exception as exc:
                errors.append(f'Ownership cleanup: {exc}')
        result = {'status': 'failed' if errors else 'passed', 'errors': errors, 'evidence': str(self.evidence)}
        write_json(self.evidence / 'result.json', result)
        self.record('session-end', **result)
        return result
