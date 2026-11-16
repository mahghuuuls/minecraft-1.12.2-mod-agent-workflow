import hashlib
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import read_json, sha256, write_json, RuntimeErrorDetail
from prepare import prepare, MAIN, CLIENT_TWEAKER, SERVER_TWEAKER


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

    def test_toolkit_channel_input_cannot_be_imported(self):
        self.cfg['files'] = [{**self.pin(self.source / 'client.jar'), 'target': 'client/config/devtool/client-inbox/status.json'}]
        with self.assertRaisesRegex(RuntimeErrorDetail, 'Tool-managed'):
            self.invoke()
        self.assertFalse((self.workspace / 'runtime').exists())


if __name__ == '__main__':
    unittest.main()
