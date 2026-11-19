"""Resolve pinned cached inputs, then copy them into a new isolated runtime (Cleanroom or standard Forge)."""
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
# Standard Forge: the vanilla launcher's entry point, as the Forge version file names it, and Forge's server entry point.
LAUNCH = 'net.minecraft.launchwrapper.Launch'
FORGE_SERVER_MAIN = 'net.minecraftforge.fml.relauncher.ServerLaunchWrapper'


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


def java_major(java):
    """The Java feature version from the installation's release file (JDK root, or above jre/ in a JDK 8), or None."""
    candidates = [java.parent.parent / 'release']
    if java.parent.parent.name.lower() == 'jre':
        candidates.append(java.parent.parent.parent / 'release')
    for release in candidates:
        if release.is_file():
            match = re.search(r'^JAVA_VERSION="(\d+)(?:\.(\d+))?', release.read_text(encoding='utf-8', errors='replace'), re.M)
            if match:
                first = int(match.group(1))
                return int(match.group(2) or 0) if first == 1 else first
    return None


def java_args(path, args):
    require(all('\n' not in str(a) and '\r' not in str(a) for a in args), 'Newline in launch argument')
    path.write_text('\n'.join('"' + str(a).replace('\\', '/').replace('"', '\\"') + '"' for a in args) + '\n', encoding='utf-8')


# Properties the tool sets itself, and namespaces that could move files, load unpinned native code, open listeners,
# change the console encoding the session reads, or route network traffic. jvmArgs is for diagnostic switches only.
TOOL_PROPERTIES = {'file.encoding', 'java.library.path', 'fml.queryResult', 'fml.coreMods.load', 'line.separator', 'path.separator'}
REFUSED_PREFIXES = ('java.', 'javax.', 'jdk.', 'sun.', 'com.sun.', 'user.', 'file.', 'native.', 'os.', 'stdout.', 'stderr.',
                    'org.lwjgl.', 'jna.', 'jnidispatch.', 'net.java.games.', 'log4j', 'minecraft.', 'http.', 'https.', 'ftp.', 'socksProxy',
                    'socksNonProxy', 'networkaddress.')


def jvm_properties(values):
    """Extra JVM options from the profile: diagnostic Java system properties only, never ones the tool or the isolation depends on."""
    require(isinstance(values, list) and len(values) <= 16, 'jvmArgs must be a list of at most 16 entries')
    seen = set()
    for value in values:
        match = re.fullmatch(r'-D([A-Za-z0-9_.-]{1,128})=([!#-~]{0,512})', value) if isinstance(value, str) else None
        require(match is not None, 'jvmArgs entries must be -Dname=value system properties without spaces or quotes')
        require(match.group(1) not in TOOL_PROPERTIES, f'jvmArgs cannot set the tool-owned property {match.group(1)}')
        require(not match.group(1).startswith(REFUSED_PREFIXES), f'jvmArgs cannot set {match.group(1)}: its namespace can affect isolation, native code, logging or networking')
        require(match.group(1) not in seen, f'jvmArgs sets {match.group(1)} twice')
        seen.add(match.group(1))
    return list(values)


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
    loader = cfg.get('loader', 'cleanroom')
    require(loader in ('cleanroom', 'forge'), 'loader must be cleanroom or forge')
    if loader == 'cleanroom':
        require(bool(re.fullmatch(r'0\.7\.[0-9]+-alpha', cfg.get('cleanroom', ''))), 'Expected a pinned Cleanroom 0.7.x-alpha version')
    else:
        require(bool(re.fullmatch(r'14\.23\.5\.[0-9]+', cfg.get('forge', ''))), 'Expected a pinned Forge 14.23.5.x version for Minecraft 1.12.2')
        require('cleanroom' not in cfg and 'serverInstall' not in cfg, 'A Forge profile takes serverJar, not Cleanroom fields')
    auth = cfg['authorization']
    require(bool(auth.get('source')), 'Record the owner authorization source')
    require(auth.get('eulaAccepted') is True and bool(auth.get('eulaSource')), 'Saved owner EULA acceptance and source are required')
    require(auth.get('toolkitActions') is True, 'Toolkit actions require recorded authorization')
    player = cfg.get('player', 'RuntimeTester')
    require(bool(re.fullmatch('[A-Za-z0-9_]{1,16}', player)), 'Invalid local player name')
    heap = bounded(cfg.get('heapMiB', 2048), 512, 8192, 'heapMiB')
    require(type(heap) is int, 'heapMiB must be an integer')
    # The server always cancels Forge's startup questions. The client may instead confirm them, or leave them to the screen.
    client_query = cfg.get('clientQueryResult', 'cancel')
    require(client_query in ('cancel', 'confirm', 'none'), 'clientQueryResult must be cancel, confirm or none')
    extra_jvm = jvm_properties(cfg.get('jvmArgs', []))
    java = verify_file(cfg['java']['path'], cfg['java']['sha256'])
    require(java.name.lower() == 'java.exe', 'Select java.exe, not a launcher or shell')
    # Java 8 cannot read an @argument file, so its launch arguments go on the command line itself.
    major = java_major(java)
    require(major is not None, 'Cannot read the Java version from the installation release file next to the selected java.exe')
    if loader == 'forge':
        require(major == 8, f'Forge 1.12.2 runs on Java 8; the selected Java is {major}')
    else:
        require(major >= 9, f'Cleanroom needs a modern Java; the selected Java is {major}')
    arg_file = major >= 9
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

    caches = [plain_path(p) for p in cfg['libraryRoots']]
    for cache in caches:
        require(cache.is_dir(), f'Missing library cache: {cache}')
        separate(root, cache)
    index = {}
    for cache in caches:
        for source in cache.rglob('*.jar'):
            index.setdefault(source.name, []).append((cache, source))

    def sha1_of(path):
        with path.open('rb') as stream:
            return hashlib.file_digest(stream, 'sha1').hexdigest()

    def artifact(item):
        filename = Path(item['path']).name if item.get('path') else Path(urllib.parse.urlparse(item['url']).path).name
        expected = item['sha1']
        require(bool(re.fullmatch('[a-f0-9]{40}', expected)), 'Invalid artifact SHA-1 in pinned metadata')
        for cache, source in index.get(filename, []):
            plain_path(source)
            if sha1_of(source) == expected:
                return add(source, 'libraries/' + source.relative_to(cache).as_posix())
        raise FileNotFoundError(f'Missing cached artifact {filename}, SHA-1 {expected}; no download was attempted')

    def libraries(libs, skip=(), strict=False):
        """Classpath entries and native JARs of one metadata file's allowed libraries.

        With strict (launcher-format files of standard Forge), every allowed library must resolve to a pinned JAR. In the
        vanilla 1.12.2 file some natives entries also list a plain artifact that launchers may not fetch (an empty
        lwjgl-platform JAR); such an artifact is used when the caches hold it and skipped when they do not, because the
        native classifier is what the game loads."""
        cp, natives = [], []
        for lib in libs:
            if not allowed(lib) or ':'.join(lib.get('name', '').split(':')[:2]) in skip:
                continue
            downloads = lib.get('downloads', {})
            before = len(cp)
            if 'artifact' in downloads:
                try:
                    item = artifact(downloads['artifact'])
                    if item not in cp:
                        cp.append(item)
                except FileNotFoundError:
                    if not (strict and 'natives' in lib):
                        raise
            native = lib.get('natives', {}).get('windows', 'natives-windows').replace('${arch}', '64')
            if native in downloads.get('classifiers', {}):
                item = artifact(downloads['classifiers'][native])
                natives.append(item)
                cp.append(item)
            listed = downloads.get('artifact', {}).get('path', '')
            already = bool(listed) and any(entry.endswith('/' + listed) for entry in cp)
            require(not strict or len(cp) > before or already, f'Library {lib.get("name")} resolves to no pinned JAR; inspect the version file format')
        return cp, natives

    names = ('net.minecraft.json', 'net.minecraftforge.json', 'org.lwjgl3.json') if loader == 'cleanroom' else ('net.minecraft.json', 'net.minecraftforge.json')
    require(set(cfg['metadata']) == set(names), 'metadata must pin exactly: ' + ', '.join(names))
    metadata = {}
    for file in names:
        pin = cfg['metadata'][file]
        source = verify_file(pin['path'], pin['sha256'])
        add(source, 'inputs/' + file, pin['sha256'])
        metadata[file] = read_json(source)
    forge = metadata['net.minecraftforge.json']
    mc = metadata['net.minecraft.json']
    client = verify_file(cfg['clientJar']['path'], cfg['clientJar']['sha256'])
    if loader == 'cleanroom':
        require(forge['version'] == cfg['cleanroom'] and forge['mainClass'] == MAIN, 'Cleanroom metadata identity mismatch')
        supported = forge.get('compatibleJavaMajors')
        require(not supported or major in supported, f'Cleanroom {cfg["cleanroom"]} supports Java {supported}; the selected Java is {major}')
        require(CLIENT_TWEAKER in forge.get('+tweakers', []), 'Unknown client launch entry point')
        require(any(r.get('uid') == 'net.minecraft' and r.get('equals') == MC for r in forge['requires']), 'Minecraft metadata target mismatch')
        client_cp, native_jars = [], []
        for meta in metadata.values():
            cp, natives = libraries(meta['libraries'])
            client_cp += cp
            native_jars += natives
        require(sha1_of(client) == mc['mainJar']['downloads']['artifact']['sha1'], 'Minecraft client identity mismatch')
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
        launch = {'client': [MAIN, '--tweakClass', CLIENT_TWEAKER], 'server': [MAIN, '--tweakClass', SERVER_TWEAKER, 'nogui']}
        version_name = MC + '-Cleanroom-' + cfg['cleanroom']
    else:
        # Standard Forge from a launcher installation: the Forge version file inherits the vanilla 1.12.2 one.
        version = cfg['forge']
        loader_lib = 'net.minecraftforge:forge:' + MC + '-' + version
        require(forge.get('inheritsFrom') == MC and forge.get('mainClass') == LAUNCH and version in forge.get('id', ''), 'Forge version file identity mismatch')
        require('--tweakClass ' + CLIENT_TWEAKER in forge.get('minecraftArguments', ''), 'Unknown Forge client launch entry point')
        require(any(lib.get('name') == loader_lib for lib in forge['libraries']), 'The Forge version file does not name the pinned Forge library')
        require(mc.get('id') == MC, 'Minecraft metadata target mismatch')
        forge_cp, forge_natives = libraries(forge['libraries'], strict=True)
        overridden = {':'.join(lib['name'].split(':')[:2]) for lib in forge['libraries']}
        vanilla_cp, native_jars = libraries(mc['libraries'], overridden, strict=True)
        native_jars += forge_natives
        require(sha1_of(client) == mc['downloads']['client']['sha1'], 'Minecraft client identity mismatch')
        client_cp = forge_cp + vanilla_cp + [add(client, 'minecraft/client-1.12.2.jar')]
        server_jar = verify_file(cfg['serverJar']['path'], cfg['serverJar']['sha256'])
        separate(root, server_jar)
        require(sha1_of(server_jar) == mc['downloads']['server']['sha1'], 'Minecraft server identity mismatch')
        # The 1.12.2 server JAR carries its own libraries; Forge's list adds the loader and what it needs.
        server_cp = forge_cp + [add(server_jar, 'minecraft/server-1.12.2.jar')]
        launch = {'client': [LAUNCH, '--tweakClass', CLIENT_TWEAKER, '--versionType', 'Forge'], 'server': [FORGE_SERVER_MAIN, 'nogui']}
        version_name = forge['id']
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
        (game / 'config/devtool/devtool.cfg').write_text('client {\n B:allowActions=true\n B:requestChannel=true\n B:applyOnJoin=false\n B:dismissTutorial=true\n}\ninbox {\n B:enabled=true\n B:openOnLocalJoin=true\n B:localJoinOperator=false\n}\njoin {\n B:enabled=false\n}\n', encoding='utf-8')
    (root / 'client/options.txt').write_text('pauseOnLostFocus:false\nfullscreen:false\nrenderDistance:6\nmaxFps:60\nsoundCategory_master:0.0\nmipmapLevels:0\n', encoding='utf-8')
    (root / 'server/eula.txt').write_text('# Recorded owner acceptance: see runtime.json authorization.\neula=true\n', encoding='utf-8')
    player_uuid = str(uuid.UUID(bytes=hashlib.md5(('OfflinePlayer:' + player).encode()).digest(), version=3))
    common = ['-Xms256M', f'-Xmx{heap}M', '-Dfile.encoding=UTF-8', *extra_jvm]
    query = {'server': 'cancel', 'client': None if client_query == 'none' else client_query}
    for side in ('client', 'server'):
        cp = server_cp if side == 'server' else list(dict.fromkeys(client_cp))
        args = common + ([] if query[side] is None else ['-Dfml.queryResult=' + query[side]]) + ['-Djava.library.path=' + str(root / 'natives'), '-cp', ';'.join(str(root / p) for p in cp), *launch[side]]
        if side == 'client':
            args += ['--username', player, '--version', version_name, '--gameDir', str(root / 'client'), '--assetsDir', str(root / 'assets'), '--assetIndex', '1.12', '--uuid', player_uuid.replace('-', ''), '--accessToken', '0', '--userType', 'legacy', '--width', '960', '--height', '540']
        java_args(root / (side + '.args'), args)
    immutable = {e['path']: e['sha256'] for e in entries.values() if not e['path'].startswith(('client/config/', 'server/config/', 'client/scripts/', 'server/scripts/'))}
    for path in [*root.glob('*.args'), *(root / 'natives').glob('*.dll')]:
        immutable[path.relative_to(root).as_posix()] = sha256(path)
    manifest = {'schema': 1, 'root': str(root), 'minecraft': MC, 'loader': loader, 'cleanroom': cfg.get('cleanroom'), 'forge': cfg.get('forge'), 'javaMajor': major, 'argFile': arg_file, 'java': cfg['java'], 'player': player, 'playerUuid': player_uuid, 'authorization': auth, 'protectedRoots': list(map(str, protected)), 'inputs': list(entries.values()), 'immutable': immutable, 'allowedGenerated': generated}
    write_json(root / 'profile.json', cfg)
    write_json(root / 'runtime.json', manifest)
    (root / 'preparing.json').unlink()
    return {'status': 'prepared', 'root': str(root), 'inputs': len(entries), 'manifestSha256': sha256(root / 'runtime.json')}
