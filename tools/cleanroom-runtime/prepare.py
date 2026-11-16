"""Resolve pinned cached inputs, then copy them into a new isolated runtime."""
from pathlib import Path
import hashlib
import json
import platform
import re
import shutil
import urllib.parse
import uuid
import zipfile

from common import (bounded, inside, plain_path, read_json, relative, require,
                    separate, sha256, verify_file, write_json)

MC = '1.12.2'
MAIN = 'top.outlands.foundation.boot.Foundation'
SERVER_TWEAKER = 'net.minecraftforge.fml.common.launcher.FMLServerTweaker'
CLIENT_TWEAKER = 'net.minecraftforge.fml.common.launcher.FMLTweaker'


def contained_dependencies(path):
    """Pin only dependencies explicitly declared by a selected mod's JAR manifest."""
    with zipfile.ZipFile(path) as jar:
        if 'META-INF/MANIFEST.MF' not in jar.namelist():
            return {}
        manifest = jar.read('META-INF/MANIFEST.MF').decode('utf-8').replace('\r', '').replace('\n ', '')
        main = manifest.split('\n\n', 1)[0]
        fields = dict(line.split(': ', 1) for line in main.splitlines() if ': ' in line)
        result = {}
        for name in fields.get('ContainedDeps', '').split():
            item = relative(name)
            require(len(item.parts) == 1 and name.endswith('.jar'), 'Unsupported nested dependency path')
            result['mods/1.12.2/' + name] = hashlib.sha256(jar.read(name)).hexdigest()
        return result


def allowed(lib):
    rules = lib.get('rules', [])
    result = not rules
    for rule in rules:
        osrule = rule.get('os', {})
        if osrule.get('name', 'windows') != 'windows':
            continue
        if 'arch' in osrule and not re.fullmatch(osrule['arch'], 'amd64'):
            continue
        require(not rule.get('features'), 'Feature-dependent libraries need a supported profile')
        result = rule['action'] == 'allow'
    return result


def java_args(path, args):
    require(all('\n' not in str(a) and '\r' not in str(a) for a in args), 'Newline in launch argument')
    path.write_text('\n'.join('"' + str(a).replace('\\', '/').replace('"', '\\"') + '"' for a in args) + '\n', encoding='utf-8')


def prepare(profile_path, workspace, name):
    require(platform.system() == 'Windows', 'This runtime importer currently supports Windows x64 only')
    require(platform.machine().lower() in ('amd64', 'x86_64'), 'Windows x64 is required')
    require(bool(re.fullmatch('[a-z0-9][a-z0-9-]{0,47}', name)), 'Invalid runtime name')
    workspace = plain_path(workspace)
    require(workspace.is_dir(), 'Workspace must already exist')
    root = plain_path(workspace / 'runtime' / name)
    require(not root.exists(), 'Runtime already exists; use a new name, never overwrite a running or retained instance')
    profile_path = plain_path(profile_path)
    cfg = read_json(profile_path)
    require(cfg.get('schema') == 1 and cfg.get('minecraft') == MC, 'Only profile schema 1 / Minecraft 1.12.2 is supported')
    require(bool(re.fullmatch(r'0\.7\.[0-9]+-alpha', cfg.get('cleanroom', ''))), 'Expected a pinned Cleanroom 0.7.x-alpha version')
    auth = cfg['authorization']
    require(bool(auth.get('source')), 'Record the owner authorization source')
    require(auth.get('eulaAccepted') is True and bool(auth.get('eulaSource')), 'Saved owner EULA acceptance and source are required')
    require(auth.get('toolkitActions') is True, 'Toolkit actions require recorded authorization')
    player = cfg.get('player', 'RuntimeTester')
    require(bool(re.fullmatch('[A-Za-z0-9_]{1,16}', player)), 'Invalid local player name')
    heap = bounded(cfg.get('heapMiB', 2048), 512, 8192, 'heapMiB')
    require(type(heap) is int, 'heapMiB must be an integer')
    java = verify_file(cfg['java']['path'], cfg['java']['sha256'])
    require(java.name.lower() == 'java.exe', 'Select java.exe, not a launcher or shell')
    protected = [plain_path(p) for p in cfg.get('protectedRoots', [])]
    for path in [profile_path, java, *protected]:
        separate(root, path)
    entries = {}

    def add(source, target, expected=None):
        source = plain_path(source)
        separate(root, source)
        require(source.is_file(), f'Missing cached input: {source}')
        target = relative(target).as_posix()
        digest = sha256(source)
        require(expected is None or digest == expected.lower(), f'Input SHA-256 changed: {source}')
        key = target.casefold()
        if key in entries:
            require(entries[key]['sha256'] == digest, f'Conflicting inputs for {target}')
        else:
            entries[key] = {'source': str(source), 'path': target, 'sha256': digest}
        return target

    metadata = {}
    for file in ('net.minecraft.json', 'net.minecraftforge.json', 'org.lwjgl3.json'):
        pin = cfg['metadata'][file]
        source = verify_file(pin['path'], pin['sha256'])
        add(source, 'inputs/' + file, pin['sha256'])
        metadata[file] = read_json(source)
    forge = metadata['net.minecraftforge.json']
    mc = metadata['net.minecraft.json']
    require(forge['version'] == cfg['cleanroom'] and forge['mainClass'] == MAIN, 'Cleanroom metadata identity mismatch')
    require(CLIENT_TWEAKER in forge.get('+tweakers', []), 'Unknown client launch entry point')
    require(any(r.get('uid') == 'net.minecraft' and r.get('equals') == MC for r in forge['requires']), 'Minecraft metadata target mismatch')
    caches = [plain_path(p) for p in cfg['libraryRoots']]
    for cache in caches:
        require(cache.is_dir(), f'Missing library cache: {cache}')
        separate(root, cache)
    index = {}
    for cache in caches:
        for source in cache.rglob('*.jar'):
            index.setdefault(source.name, []).append((cache, source))

    def artifact(item):
        filename = Path(urllib.parse.urlparse(item['url']).path).name
        expected = item['sha1']
        require(bool(re.fullmatch('[a-f0-9]{40}', expected)), 'Invalid artifact SHA-1 in pinned metadata')
        for cache, source in index.get(filename, []):
            plain_path(source)
            with source.open('rb') as stream:
                actual = hashlib.file_digest(stream, 'sha1').hexdigest()
            if actual == expected:
                return add(source, 'libraries/' + source.relative_to(cache).as_posix())
        raise FileNotFoundError(f'Missing cached artifact {filename}, SHA-1 {expected}; no download was attempted')

    client_cp, native_jars = [], []
    for meta in metadata.values():
        for lib in meta['libraries']:
            if not allowed(lib):
                continue
            downloads = lib.get('downloads', {})
            if 'artifact' in downloads:
                client_cp.append(artifact(downloads['artifact']))
            native = lib.get('natives', {}).get('windows', 'natives-windows').replace('${arch}', '64')
            if native in downloads.get('classifiers', {}):
                item = artifact(downloads['classifiers'][native])
                native_jars.append(item)
                client_cp.append(item)
    client = verify_file(cfg['clientJar']['path'], cfg['clientJar']['sha256'])
    with client.open('rb') as stream:
        require(hashlib.file_digest(stream, 'sha1').hexdigest() == mc['mainJar']['downloads']['artifact']['sha1'], 'Minecraft client identity mismatch')
    client_cp.append(add(client, 'minecraft/client-1.12.2.jar'))
    server = plain_path(cfg['serverInstall'])
    separate(root, server)
    server_args = verify_file(server / f'libraries/com/cleanroommc/cleanroom/{cfg["cleanroom"]}/win_args.txt', cfg['serverArgsSha256'])
    add(server_args, 'inputs/server-original.args')
    lines = server_args.read_text().splitlines()
    require(len(lines) == 5 and lines[0] == '-cp' and lines[2:] == [MAIN, '--tweakClass', SERVER_TWEAKER], 'Unsupported server argument file; inspect its format')
    server_cp = []
    for value in lines[1].split(';'):
        path = relative(value.replace('\\', '/'))
        require(path.parts[0] == 'libraries', 'Server library must be inside libraries/')
        server_cp.append(add(server / path, path.as_posix()))
    # The two sides must resolve the same universal loader binary.
    universal = f'libraries/com/cleanroommc/cleanroom/{cfg["cleanroom"]}/cleanroom-{cfg["cleanroom"]}-universal.jar'
    require(universal in server_cp and universal in client_cp, 'Missing pinned universal loader on one side')
    assets = plain_path(cfg['assets'])
    separate(root, assets)
    asset_id = mc['assetIndex']['id']
    require(asset_id == '1.12', 'Unexpected asset index')
    asset_index = assets / 'indexes/1.12.json'
    with asset_index.open('rb') as stream:
        require(hashlib.file_digest(stream, 'sha1').hexdigest() == mc['assetIndex']['sha1'], 'Asset index mismatch')
    add(asset_index, 'assets/indexes/1.12.json')
    for obj in read_json(asset_index)['objects'].values():
        h = obj['hash']
        require(bool(re.fullmatch('[a-f0-9]{40}', h)), 'Invalid asset hash')
        path = relative('objects/' + h[:2] + '/' + h)
        with (assets / path).open('rb') as stream:
            require(hashlib.file_digest(stream, 'sha1').hexdigest() == h, f'Asset content mismatch: {path}')
        add(assets / path, 'assets/' + path.as_posix())
    generated = {}
    for mod in cfg.get('mods', []):
        source = verify_file(mod['path'], mod['sha256'])
        require(source.suffix.lower() == '.jar', 'Mod input must be a JAR')
        for side in mod['sides']:
            require(side in ('client', 'server'), 'Invalid mod side')
            add(source, side + '/mods/' + source.name, mod['sha256'])
            for target, digest in contained_dependencies(source).items():
                target = side + '/' + target
                require(target not in generated or generated[target] == digest, f'Conflicting bundled dependency: {target}')
                generated[target] = digest
    for item in cfg.get('files', []):
        target = relative(item['target'])
        require(len(target.parts) > 2 and target.parts[0] in ('client', 'server') and target.parts[1] in ('config', 'scripts'), 'Extra files must target client/server config/ or scripts/')
        require(target.as_posix() not in ('client/config/devtool/devtool.cfg', 'server/config/devtool/devtool.cfg') and 'local-join.secret' not in target.parts and not any(p in ('inbox', 'client-inbox', 'results') for p in target.parts), 'Tool-managed paths cannot be imported')
        add(verify_file(item['path'], item['sha256']), target.as_posix(), item['sha256'])
    for path in protected:
        separate(root, path)
    # No destination writes happen until every source, identity and boundary passed.
    root.mkdir(parents=True)
    write_json(root / 'preparing.json', {'schema': 1, 'profile': str(profile_path)})
    for entry in entries.values():
        dest = root / entry['path']
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(entry['source'], dest)
        require(sha256(dest) == entry['sha256'], f'Input changed during copy: {entry["source"]}')
    for item in set(native_jars):
        with zipfile.ZipFile(root / item) as z:
            for member in z.infolist():
                if member.filename.lower().endswith('.dll'):
                    target = root / 'natives' / relative(Path(member.filename).name)
                    target.parent.mkdir(exist_ok=True)
                    data = z.read(member)
                    require(not target.exists() or target.read_bytes() == data, f'Native collision: {target.name}')
                    target.write_bytes(data)
    for side in ('client', 'server'):
        game = root / side
        (game / 'config/devtool').mkdir(parents=True, exist_ok=True)
        (game / 'config/devtool/devtool.cfg').write_text('client {\n B:allowActions=true\n B:requestChannel=true\n B:applyOnJoin=false\n}\ninbox {\n B:enabled=true\n B:openOnLocalJoin=true\n B:localJoinOperator=false\n}\njoin {\n B:enabled=false\n}\n', encoding='utf-8')
    (root / 'client/options.txt').write_text('pauseOnLostFocus:false\nfullscreen:false\nrenderDistance:6\nmaxFps:60\nsoundCategory_master:0.0\nmipmapLevels:0\n', encoding='utf-8')
    (root / 'server/eula.txt').write_text('# Recorded owner acceptance: see runtime.json authorization.\neula=true\n', encoding='utf-8')
    player_uuid = str(uuid.UUID(bytes=hashlib.md5(('OfflinePlayer:' + player).encode()).digest(), version=3))
    common = ['-Xms256M', f'-Xmx{heap}M', '-Dfml.queryResult=cancel', '-Dfile.encoding=UTF-8']
    for side in ('client', 'server'):
        cp = server_cp if side == 'server' else list(dict.fromkeys(client_cp))
        args = common + ['-Djava.library.path=' + str(root / 'natives'), '-cp', ';'.join(str(root / p) for p in cp), MAIN, '--tweakClass', SERVER_TWEAKER if side == 'server' else CLIENT_TWEAKER]
        if side == 'server':
            args += ['nogui']
        else:
            args += ['--username', player, '--version', MC + '-Cleanroom-' + cfg['cleanroom'], '--gameDir', str(root / 'client'), '--assetsDir', str(root / 'assets'), '--assetIndex', '1.12', '--uuid', player_uuid.replace('-', ''), '--accessToken', '0', '--userType', 'legacy', '--width', '960', '--height', '540']
        java_args(root / (side + '.args'), args)
    immutable = {e['path']: e['sha256'] for e in entries.values() if not e['path'].startswith(('client/config/', 'server/config/', 'client/scripts/', 'server/scripts/'))}
    for path in [*root.glob('*.args'), *(root / 'natives').glob('*.dll')]:
        immutable[path.relative_to(root).as_posix()] = sha256(path)
    manifest = {'schema': 1, 'root': str(root), 'minecraft': MC, 'cleanroom': cfg['cleanroom'], 'java': cfg['java'], 'player': player, 'playerUuid': player_uuid, 'authorization': auth, 'protectedRoots': list(map(str, protected)), 'inputs': list(entries.values()), 'immutable': immutable, 'allowedGenerated': generated}
    write_json(root / 'profile.json', cfg)
    write_json(root / 'runtime.json', manifest)
    (root / 'preparing.json').unlink()
    return {'status': 'prepared', 'root': str(root), 'inputs': len(entries), 'manifestSha256': sha256(root / 'runtime.json')}
