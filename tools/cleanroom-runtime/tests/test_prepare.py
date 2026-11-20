import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import read_json, sha256, write_json, RuntimeErrorDetail
from prepare import prepare, MAIN, CLIENT_TWEAKER, SERVER_TWEAKER
from refresh import refresh
from session import Ownership, Session, read_manifest


class PrepareTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='cleanroom-import-test-')
        self.base = Path(self.tmp.name).resolve()
        self.workspace = self.base / 'workspace'
        self.workspace.mkdir()
        self.source = self.base / 'reference'
        self.source.mkdir()
        self.lib = 'libraries/com/cleanroommc/cleanroom/0.7.14-alpha/cleanroom-0.7.14-alpha-universal.jar'
        self.serverlib = 'libraries/net/minecraft/server/1.12.2/server-1.12.2.jar'
        for name in (self.lib, self.serverlib, 'java.exe', 'client.jar'):
            path = self.source / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(('fixture ' + name).encode())
        self.args = self.source / 'libraries/com/cleanroommc/cleanroom/0.7.14-alpha/win_args.txt'
        self.args.write_text('-cp\n' + self.lib + ';' + self.serverlib + '\n' + MAIN + '\n--tweakClass\n' + SERVER_TWEAKER + '\n')
        assets = self.source / 'assets'
        write_json(assets / 'indexes/1.12.json', {'objects': {}})
        def sha1(path):
            return hashlib.sha1(path.read_bytes()).hexdigest()
        self.pin = lambda path: {'path': str(path), 'sha256': sha256(path)}
        forge = {'version': '0.7.14-alpha', 'mainClass': MAIN, '+tweakers': [CLIENT_TWEAKER], 'requires': [{'uid': 'net.minecraft', 'equals': '1.12.2'}], 'libraries': [{'downloads': {'artifact': {'url': 'https://example.invalid/' + Path(self.lib).name, 'sha1': sha1(self.source / self.lib)}}}]}
        mc = {'libraries': [], 'mainJar': {'downloads': {'artifact': {'sha1': sha1(self.source / 'client.jar')}}}, 'assetIndex': {'id': '1.12', 'sha1': sha1(assets / 'indexes/1.12.json')}}
        metas = {'net.minecraftforge.json': forge, 'net.minecraft.json': mc, 'org.lwjgl3.json': {'libraries': []}}
        for name, value in metas.items():
            write_json(self.source / name, value)
        self.cfg = {'schema': 1, 'minecraft': '1.12.2', 'cleanroom': '0.7.14-alpha',
                    'java': self.pin(self.source / 'java.exe'),
                    'authorization': {'source': 'test fixture', 'eulaAccepted': True, 'eulaSource': 'test fixture', 'toolkitActions': True},
                    'metadata': {name: self.pin(self.source / name) for name in metas},
                    'clientJar': self.pin(self.source / 'client.jar'), 'libraryRoots': [str(self.source / 'libraries')],
                    'serverInstall': str(self.source), 'serverArgsSha256': sha256(self.args),
                    'assets': str(assets), 'protectedRoots': [str(self.source)], 'mods': [], 'files': []}
        self.profile = self.base / 'profile.json'
        (self.base / 'release').write_text('JAVA_VERSION="25.0.3"\n')

    def tearDown(self):
        self.tmp.cleanup()

    def invoke(self):
        write_json(self.profile, self.cfg)
        return prepare(self.profile, self.workspace, 'sample')

    def test_import_copies_without_modifying_sources(self):
        before = {str(p): sha256(p) for p in self.source.rglob('*') if p.is_file()}
        result = self.invoke()
        root = Path(result['root'])
        self.assertEqual('prepared', result['status'])
        self.assertTrue((root / self.lib).is_file())
        self.assertEqual(1, (root / self.lib).stat().st_nlink)
        self.assertFalse((root / 'preparing.json').exists())
        self.assertEqual(before, {str(p): sha256(p) for p in self.source.rglob('*') if p.is_file()})
        self.assertIn('eula=true', (root / 'server/eula.txt').read_text())
        self.assertIn(str(root).replace('\\', '/'), (root / 'client.args').read_text())
        self.assertNotIn('example.invalid', (root / 'client.args').read_text())

    def test_second_prepare_refuses_existing_runtime(self):
        result = self.invoke()
        original = (Path(result['root']) / 'runtime.json').read_bytes()
        with self.assertRaisesRegex(RuntimeErrorDetail, 'already exists'):
            self.invoke()
        self.assertEqual(original, (Path(result['root']) / 'runtime.json').read_bytes())

    def prepare_builds(self, sides=('client', 'server')):
        old = self.source / 'example.jar'
        candidate = self.base / old.name
        for path, data in ((old, 'previous'), (candidate, 'candidate')):
            with zipfile.ZipFile(path, 'w') as jar:
                jar.writestr('version.txt', data)
        self.cfg['mods'] = [{**self.pin(old), 'sides': list(sides)}]
        self.cfg['authorization']['serverLaunch'] = True
        return Path(self.invoke()['root']), candidate, sha256(old), sha256(candidate)

    def test_refresh_cli_updates_both_sides_and_preserves_history(self):
        root, candidate, previous, current = self.prepare_builds()
        args = (root / 'server.args').read_bytes()
        plan = {'schema': 1, 'steps': [{'action': 'start', 'side': 'server'}]}
        waiting = Session(root, plan)
        cmd = [sys.executable, str(Path(__file__).resolve().parents[1] / 'runtime.py'), 'refresh',
               '--root', str(root), '--jar', str(candidate), '--from-sha256', previous, '--sha256', current]
        run = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        self.assertEqual(run.returncode, 0, run.stderr)
        evidence = Path(json.loads(run.stdout)['evidence'])
        self.assertEqual(previous, sha256(evidence / 'previous.jar'))
        self.assertEqual(previous, read_json(evidence / 'previous-profile.json')['mods'][0]['sha256'])
        self.assertEqual(current, read_json(root / 'profile.json')['mods'][0]['sha256'])
        self.assertEqual(args, (root / 'server.args').read_bytes())
        for path in read_json(evidence / 'change.json')['targets']:
            self.assertEqual(current, sha256(root / path))
            self.assertEqual(previous, read_json(evidence / 'previous-runtime.json')['immutable'][path])
        self.assertIn('changed before session', str(waiting.run()['errors']))
        fake = Path(__file__).with_name('fake_game.py')
        with patch('session.Game.command', return_value=[sys.executable, str(fake), 'server']):
            result = Session(root, plan).run()
        self.assertEqual('passed', result['status'], result)
        self.assertEqual(current, read_json(Path(result['evidence']) / 'runtime.json')['immutable']['server/mods/example.jar'])

    def test_refresh_checks_previous_inventory_and_active_owner(self):
        root, candidate, previous, current = self.prepare_builds()
        lock = Ownership(root, root / 'other-evidence')
        try:
            with self.assertRaises(FileExistsError):
                refresh(root, candidate, previous, current)
        finally:
            lock.close()
        (root / self.lib).write_bytes(b'drift')
        with self.assertRaisesRegex(RuntimeErrorDetail, 'SHA-256 changed'):
            refresh(root, candidate, previous, current)
        self.assertEqual(previous, sha256(root / 'server/mods/example.jar'))

    def test_refresh_refuses_live_java_and_incorrect_pins_before_staging(self):
        root, candidate, previous, current = self.prepare_builds()
        java = subprocess.CompletedProcess([], 0, stdout=f'java.exe "@{root}/server.args"')
        with patch('refresh.subprocess.run', return_value=java), self.assertRaisesRegex(RuntimeErrorDetail, 'running Java'):
            refresh(root, candidate, previous, current)
        with patch('refresh.require_stopped'):
            with self.assertRaisesRegex(RuntimeErrorDetail, 'SHA-256 changed'):
                refresh(root, candidate, previous, '0' * 64)
            with self.assertRaisesRegex(RuntimeErrorDetail, 'Previous project JAR'):
                refresh(root, candidate, '0' * 64, current)
        self.assertFalse((root / 'evidence').exists())
        self.assertEqual(previous, sha256(root / 'client/mods/example.jar'))

    @patch('refresh.require_stopped')
    def test_refresh_honors_single_side_and_rejects_new_embedded_dependency(self, stopped):
        root, candidate, previous, current = self.prepare_builds(('client',))
        refresh(root, candidate, previous, current)
        self.assertFalse((root / 'server/mods/example.jar').exists())
        with zipfile.ZipFile(candidate, 'a') as jar:
            jar.writestr('META-INF/MANIFEST.MF', 'ContainedDeps: child.jar\n')
            jar.writestr('child.jar', b'child')
        with self.assertRaisesRegex(RuntimeErrorDetail, 'Embedded dependency'):
            refresh(root, candidate, current, sha256(candidate))
        self.assertEqual(current, sha256(root / 'client/mods/example.jar'))
        self.assertFalse((root / 'preparing.json').exists())

    @patch('refresh.require_stopped')
    def test_partial_refresh_blocks_launch_and_keeps_prior_inputs(self, stopped):
        root, candidate, previous, current = self.prepare_builds()
        copy = shutil.copyfile

        def interrupt(source, dest):
            if dest == root / 'server/mods/example.jar':
                raise OSError('simulated copy failure')
            return copy(source, dest)

        with patch('refresh.shutil.copyfile', side_effect=interrupt), self.assertRaisesRegex(OSError, 'copy failure'):
            refresh(root, candidate, previous, current)
        evidence = Path(read_json(root / 'preparing.json')['evidence'])
        self.assertEqual(previous, sha256(evidence / 'previous.jar'))
        with self.assertRaisesRegex(RuntimeErrorDetail, 'incomplete'):
            read_manifest(root)
        with self.assertRaisesRegex(RuntimeErrorDetail, 'incomplete'):
            refresh(root, candidate, previous, current)

    def test_missing_library_fails_before_destination_writes(self):
        (self.source / self.lib).unlink()
        with self.assertRaisesRegex(FileNotFoundError, 'no download'):
            self.invoke()
        self.assertFalse((self.workspace / 'runtime').exists())

    def test_changed_metadata_fails_before_destination_writes(self):
        (self.source / 'net.minecraftforge.json').write_text('{}')
        with self.assertRaisesRegex(RuntimeErrorDetail, 'SHA-256 changed'):
            self.invoke()
        self.assertFalse((self.workspace / 'runtime').exists())

    def test_eula_acceptance_is_not_inferred(self):
        self.cfg['authorization']['eulaAccepted'] = False
        with self.assertRaisesRegex(RuntimeErrorDetail, 'EULA acceptance'):
            self.invoke()
        self.assertFalse((self.workspace / 'runtime').exists())

    def test_import_cannot_write_into_reference(self):
        self.workspace = self.source
        with self.assertRaisesRegex(RuntimeErrorDetail, 'overlaps'):
            self.invoke()
        self.assertFalse((self.source / 'runtime').exists())

    def test_conflicting_mod_names_are_not_silently_replaced(self):
        for directory in ('a', 'b'):
            path = self.source / directory / 'same.jar'
            path.parent.mkdir()
            with zipfile.ZipFile(path, 'w') as jar:
                jar.writestr('data.txt', directory)
            self.cfg['mods'].append({**self.pin(path), 'sides': ['server']})
        with self.assertRaisesRegex(RuntimeErrorDetail, 'Conflicting'):
            self.invoke()
        self.assertFalse((self.workspace / 'runtime').exists())

    def test_declared_bundled_dependency_is_pinned(self):
        mod = self.source / 'container.jar'
        with zipfile.ZipFile(mod, 'w') as jar:
            jar.writestr('META-INF/MANIFEST.MF', 'Manifest-Version: 1.0\r\nContainedDeps: child-\r\n lib.jar\r\n\r\n')
            jar.writestr('child-lib.jar', b'embedded jar')
        self.cfg['mods'] = [{**self.pin(mod), 'sides': ['server']}]
        result = self.invoke()
        manifest = read_json(Path(result['root']) / 'runtime.json')
        self.assertEqual(hashlib.sha256(b'embedded jar').hexdigest(), manifest['allowedGenerated']['server/mods/1.12.2/child-lib.jar'])

    def test_client_query_result_defaults_to_cancel_on_both_sides(self):
        root = Path(self.invoke()['root'])
        self.assertIn('"-Dfml.queryResult=cancel"', (root / 'client.args').read_text())
        self.assertIn('"-Dfml.queryResult=cancel"', (root / 'server.args').read_text())

    def test_client_query_result_is_a_client_profile_choice(self):
        for choice, expected in (('confirm', '"-Dfml.queryResult=confirm"'), ('none', None)):
            with self.subTest(choice=choice):
                self.cfg['clientQueryResult'] = choice
                write_json(self.profile, self.cfg)
                root = Path(prepare(self.profile, self.workspace, 'query-' + choice)['root'])
                client = (root / 'client.args').read_text()
                if expected is None:
                    self.assertNotIn('fml.queryResult', client)
                else:
                    self.assertIn(expected, client)
                self.assertIn('"-Dfml.queryResult=cancel"', (root / 'server.args').read_text())

    def test_unknown_client_query_result_fails_before_destination_writes(self):
        self.cfg['clientQueryResult'] = 'yes'
        with self.assertRaisesRegex(RuntimeErrorDetail, 'clientQueryResult'):
            self.invoke()
        self.assertFalse((self.workspace / 'runtime').exists())

    def test_cleanroom_java_must_be_one_its_metadata_supports(self):
        forge = read_json(self.source / 'net.minecraftforge.json')
        forge['compatibleJavaMajors'] = [25]
        write_json(self.source / 'net.minecraftforge.json', forge)
        self.cfg['metadata']['net.minecraftforge.json'] = self.pin(self.source / 'net.minecraftforge.json')
        (self.base / 'release').write_text('JAVA_VERSION="21.0.5"\n')
        with self.assertRaisesRegex(RuntimeErrorDetail, 'supports Java'):
            self.invoke()
        self.assertFalse((self.workspace / 'runtime').exists())
        (self.base / 'release').write_text('JAVA_VERSION="25.0.3"\n')
        self.assertEqual('prepared', self.invoke()['status'])

    def test_cleanroom_refuses_java_8(self):
        (self.base / 'release').write_text('JAVA_VERSION="1.8.0_462"\n')
        with self.assertRaisesRegex(RuntimeErrorDetail, 'modern Java'):
            self.invoke()
        self.assertFalse((self.workspace / 'runtime').exists())

    def test_jvm_system_properties_reach_both_sides(self):
        self.cfg['jvmArgs'] = ['-Dmixin.debug.export=true', '-Dexample.path=C:/work/out']
        root = Path(self.invoke()['root'])
        for side in ('client', 'server'):
            text = (root / (side + '.args')).read_text()
            self.assertIn('"-Dmixin.debug.export=true"', text)
            self.assertIn('"-Dexample.path=C:/work/out"', text)
            self.assertLess(text.index('mixin.debug.export'), text.index('"-cp"'))

    def test_jvm_args_accept_only_new_system_properties(self):
        for value, message in ((['-Xmx8G'], 'system properties'), (['-Dname=two words'], 'system properties'),
                               (['-Dname="quoted"'], 'system properties'), (['-Dfml.queryResult=confirm'], 'tool-owned'),
                               (['-Djava.library.path=C:/x'], 'tool-owned'), (['-Da=1', '-Da=2'], 'twice'),
                               (['-Dcom.sun.management.jmxremote.port=9010'], 'namespace'), (['-Dorg.lwjgl.librarypath=C:/x'], 'namespace'),
                               (['-Duser.dir=C:/x'], 'namespace'), (['-Dlog4j.configurationFile=C:/x.xml'], 'namespace'),
                               (['-Dfml.coreMods.load=a.B'], 'tool-owned'), (['-Dhttps.proxyHost=x'], 'namespace'), (['-Djnidispatch.path=C:/x.dll'], 'namespace'),
                               ('-Da=1', 'list'), (['-Da=1'] * 17, 'list')):
            with self.subTest(value=value):
                self.cfg['jvmArgs'] = value
                with self.assertRaisesRegex(RuntimeErrorDetail, message):
                    self.invoke()
                self.assertFalse((self.workspace / 'runtime').exists())

    def test_generated_toolkit_settings_dismiss_the_tutorial(self):
        root = Path(self.invoke()['root'])
        for side in ('client', 'server'):
            text = (root / side / 'config/devtool/devtool.cfg').read_text()
            client_section = text[text.index('client {'):text.index('}', text.index('client {'))]
            self.assertIn('B:dismissTutorial=true', client_section)

    def test_toolkit_channel_input_cannot_be_imported(self):
        self.cfg['files'] = [{**self.pin(self.source / 'client.jar'), 'target': 'client/config/devtool/client-inbox/status.json'}]
        with self.assertRaisesRegex(RuntimeErrorDetail, 'Tool-managed'):
            self.invoke()
        self.assertFalse((self.workspace / 'runtime').exists())


class ForgePrepareTests(unittest.TestCase):
    """A standard Forge profile from a launcher-format installation (Forge version file inheriting vanilla 1.12.2)."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='forge-import-test-')
        self.base = Path(self.tmp.name).resolve()
        self.workspace = self.base / 'workspace'
        self.workspace.mkdir()
        self.source = self.base / 'install'
        libs = self.source / 'libraries'
        self.forge_lib = 'net/minecraftforge/forge/1.12.2-14.23.5.2864/forge-1.12.2-14.23.5.2864.jar'
        self.wrapper = 'net/minecraft/launchwrapper/1.12/launchwrapper-1.12.jar'
        self.natives = 'org/lwjgl/lwjgl/lwjgl-platform/2.9.4/lwjgl-platform-2.9.4-natives-windows.jar'
        for name in (self.forge_lib, self.wrapper):
            (libs / name).parent.mkdir(parents=True, exist_ok=True)
            (libs / name).write_bytes(('fixture ' + name).encode())
        (libs / self.natives).parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(libs / self.natives, 'w') as jar:
            jar.writestr('lwjgl64.dll', b'native fixture')
        for name in ('java.exe', 'client.jar', 'server.jar'):
            (self.source / name).write_bytes(('fixture ' + name).encode())
        assets = self.source / 'assets'
        write_json(assets / 'indexes/1.12.json', {'objects': {}})
        sha1 = lambda path: hashlib.sha1(path.read_bytes()).hexdigest()
        art = lambda rel: {'path': rel, 'url': 'https://example.invalid/' + rel, 'sha1': sha1(libs / rel)}
        self.forge_meta = {'id': 'forge-14.23.5.2864', 'inheritsFrom': '1.12.2', 'mainClass': 'net.minecraft.launchwrapper.Launch',
                           'minecraftArguments': '--username ${auth_player_name} --tweakClass net.minecraftforge.fml.common.launcher.FMLTweaker --versionType Forge',
                           'libraries': [{'name': 'net.minecraftforge:forge:1.12.2-14.23.5.2864', 'downloads': {'artifact': art(self.forge_lib)}},
                                         {'name': 'net.minecraft:launchwrapper:1.12', 'downloads': {'artifact': art(self.wrapper)}}]}
        vanilla = {'id': '1.12.2', 'assetIndex': {'id': '1.12', 'sha1': sha1(assets / 'indexes/1.12.json')},
                   'downloads': {'client': {'sha1': sha1(self.source / 'client.jar')}, 'server': {'sha1': sha1(self.source / 'server.jar')}},
                   # The launcher lists an empty placeholder artifact beside the natives; it is never fetched.
                   'libraries': [{'name': 'org.lwjgl.lwjgl:lwjgl-platform:2.9.4', 'natives': {'windows': 'natives-windows'},
                                  'downloads': {'artifact': {'path': 'org/lwjgl/lwjgl/lwjgl-platform/2.9.4/lwjgl-platform-2.9.4.jar', 'url': 'https://example.invalid/x.jar', 'sha1': '0' * 40},
                                                'classifiers': {'natives-windows': art(self.natives)}}},
                                 {'name': 'net.minecraft:launchwrapper:1.0', 'downloads': {'artifact': {'path': 'x/launchwrapper-1.0.jar', 'url': 'https://example.invalid/y.jar', 'sha1': '1' * 40}}}]}
        write_json(self.source / 'forge.json', self.forge_meta)
        write_json(self.source / 'vanilla.json', vanilla)
        self.pin = lambda path: {'path': str(path), 'sha256': sha256(path)}
        self.cfg = {'schema': 1, 'minecraft': '1.12.2', 'loader': 'forge', 'forge': '14.23.5.2864',
                    'java': self.pin(self.source / 'java.exe'),
                    'authorization': {'source': 'test fixture', 'eulaAccepted': True, 'eulaSource': 'test fixture', 'toolkitActions': True},
                    'metadata': {'net.minecraft.json': self.pin(self.source / 'vanilla.json'), 'net.minecraftforge.json': self.pin(self.source / 'forge.json')},
                    'clientJar': self.pin(self.source / 'client.jar'), 'serverJar': self.pin(self.source / 'server.jar'),
                    'libraryRoots': [str(libs)], 'assets': str(assets), 'protectedRoots': [str(self.source)], 'mods': [], 'files': []}
        self.profile = self.base / 'profile.json'
        (self.base / 'release').write_text('JAVA_VERSION="1.8.0_462"\n')

    def tearDown(self):
        self.tmp.cleanup()

    def invoke(self, name='forge'):
        write_json(self.profile, self.cfg)
        return prepare(self.profile, self.workspace, name)

    def test_forge_profile_launches_launchwrapper_and_the_forge_server(self):
        root = Path(self.invoke()['root'])
        client = (root / 'client.args').read_text()
        server = (root / 'server.args').read_text()
        for text in (client, server):
            self.assertIn(self.forge_lib, text)
            self.assertIn('"-Dfml.queryResult=cancel"', text)
        self.assertIn('"net.minecraft.launchwrapper.Launch"\n"--tweakClass"\n"net.minecraftforge.fml.common.launcher.FMLTweaker"\n"--versionType"\n"Forge"', client)
        self.assertIn('"forge-14.23.5.2864"', client)
        self.assertIn('minecraft/client-1.12.2.jar', client)
        self.assertNotIn('launchwrapper-1.0', client)
        self.assertNotIn('lwjgl-platform-2.9.4.jar', client)
        self.assertIn('"net.minecraftforge.fml.relauncher.ServerLaunchWrapper"\n"nogui"', server)
        self.assertIn('minecraft/server-1.12.2.jar', server)
        self.assertNotIn('client-1.12.2.jar', server)
        self.assertTrue((root / 'natives/lwjgl64.dll').is_file())
        manifest = read_json(root / 'runtime.json')
        self.assertEqual(('forge', '14.23.5.2864', None), (manifest['loader'], manifest['forge'], manifest['cleanroom']))

    def test_changed_server_jar_fails_before_destination_writes(self):
        (self.source / 'server.jar').write_bytes(b'another server')
        self.cfg['serverJar'] = self.pin(self.source / 'server.jar')
        with self.assertRaisesRegex(RuntimeErrorDetail, 'server identity'):
            self.invoke()
        self.assertFalse((self.workspace / 'runtime').exists())

    def test_forge_profile_refuses_cleanroom_fields_and_unpinned_metadata(self):
        for change, message in ((lambda c: c.update(cleanroom='0.7.14-alpha'), 'serverJar'),
                                (lambda c: c.update(forge='14.23.4.2768'), 'Forge 14.23.5'),
                                (lambda c: c['metadata'].update({'org.lwjgl3.json': c['metadata']['net.minecraft.json']}), 'metadata must pin'),
                                (lambda c: c.update(loader='fabric'), 'loader')):
            with self.subTest(message=message):
                saved = json.loads(json.dumps(self.cfg))
                change(self.cfg)
                with self.assertRaisesRegex(RuntimeErrorDetail, message):
                    self.invoke()
                self.assertFalse((self.workspace / 'runtime').exists())
                self.cfg = saved

    def test_java_8_launches_without_an_argument_file(self):
        manifest = read_json(Path(self.invoke('java8')['root']) / 'runtime.json')
        self.assertEqual((8, False), (manifest['javaMajor'], manifest['argFile']))

    def test_forge_needs_a_readable_java_8(self):
        for release, message in (('JAVA_VERSION="25.0.3"', 'runs on Java 8'), (None, 'Cannot read the Java version')):
            with self.subTest(release=release):
                if release is None:
                    (self.base / 'release').unlink()
                else:
                    (self.base / 'release').write_text(release + '\n')
                with self.assertRaisesRegex(RuntimeErrorDetail, message):
                    self.invoke()
                self.assertFalse((self.workspace / 'runtime').exists())

    def test_java_8_release_file_above_jre_is_read(self):
        jre = self.source / 'jre/bin/java.exe'
        jre.parent.mkdir(parents=True)
        jre.write_bytes(b'fixture jre java')
        (self.base / 'release').unlink()
        (self.source / 'release').write_text('JAVA_VERSION="1.8.0_462"' + '\n')
        self.cfg['java'] = self.pin(jre)
        manifest = read_json(Path(self.invoke('jre')['root']) / 'runtime.json')
        self.assertEqual((8, False), (manifest['javaMajor'], manifest['argFile']))

    def test_release_file_above_a_modern_bin_folder_is_not_read(self):
        (self.base / 'release').unlink()
        jdk = self.source / 'jdk/bin/java.exe'
        jdk.parent.mkdir(parents=True)
        jdk.write_bytes(b'fixture jdk java')
        (self.base / 'install' / 'release').write_text('JAVA_VERSION="1.8.0_462"\n')
        self.cfg['java'] = self.pin(jdk)
        with self.assertRaisesRegex(RuntimeErrorDetail, 'Cannot read the Java version'):
            self.invoke()

    def test_shared_classes_jar_of_a_natives_entry_is_used_once(self):
        shared = 'com/mojang/text2speech/1.10.3/text2speech-1.10.3.jar'
        speech_natives = 'com/mojang/text2speech/1.10.3/text2speech-1.10.3-natives-windows.jar'
        libs = self.source / 'libraries'
        (libs / shared).parent.mkdir(parents=True)
        (libs / shared).write_bytes(b'speech classes')
        with zipfile.ZipFile(libs / speech_natives, 'w') as jar:
            jar.writestr('SAPIWrapper_x64.dll', b'speech native')
        sha1 = lambda rel: hashlib.sha1((libs / rel).read_bytes()).hexdigest()
        art = lambda rel: {'path': rel, 'url': 'https://example.invalid/' + rel, 'sha1': sha1(rel)}
        vanilla = read_json(self.source / 'vanilla.json')
        vanilla['libraries'] += [{'name': 'com.mojang:text2speech:1.10.3', 'downloads': {'artifact': art(shared)}},
                                 {'name': 'com.mojang:text2speech:1.10.3', 'natives': {'windows': 'natives-windows'},
                                  'downloads': {'artifact': art(shared), 'classifiers': {'natives-windows': art(speech_natives)}}}]
        write_json(self.source / 'vanilla.json', vanilla)
        self.cfg['metadata']['net.minecraft.json'] = self.pin(self.source / 'vanilla.json')
        root = Path(self.invoke('speech')['root'])
        client = (root / 'client.args').read_text()
        self.assertEqual(1, client.count('text2speech-1.10.3.jar'))
        self.assertEqual(1, client.count('text2speech-1.10.3-natives-windows.jar'))
        self.assertTrue((root / 'natives/SAPIWrapper_x64.dll').is_file())

    def test_changed_client_jar_fails_before_destination_writes(self):
        (self.source / 'client.jar').write_bytes(b'another client')
        self.cfg['clientJar'] = self.pin(self.source / 'client.jar')
        with self.assertRaisesRegex(RuntimeErrorDetail, 'client identity'):
            self.invoke()
        self.assertFalse((self.workspace / 'runtime').exists())

    def test_library_without_a_pinned_jar_is_refused(self):
        self.forge_meta['libraries'].append({'name': 'org.example:old-format:1.0', 'url': 'https://example.invalid/maven/'})
        write_json(self.source / 'forge.json', self.forge_meta)
        self.cfg['metadata']['net.minecraftforge.json'] = self.pin(self.source / 'forge.json')
        with self.assertRaisesRegex(RuntimeErrorDetail, 'old-format:1.0 resolves to no pinned JAR'):
            self.invoke()
        self.assertFalse((self.workspace / 'runtime').exists())

    def test_forge_version_file_must_name_the_pinned_forge(self):
        self.forge_meta['libraries'] = self.forge_meta['libraries'][1:]
        write_json(self.source / 'forge.json', self.forge_meta)
        self.cfg['metadata']['net.minecraftforge.json'] = self.pin(self.source / 'forge.json')
        with self.assertRaisesRegex(RuntimeErrorDetail, 'does not name'):
            self.invoke()


if __name__ == '__main__':
    unittest.main()
