"""Replace one explicitly selected packaged mod in a stopped, project-owned runtime."""
from pathlib import Path
import shutil
import subprocess
import uuid

from common import plain_path, read_json, relative, require, separate, verify_file, write_json
from prepare import contained_dependencies
from session import Ownership, read_manifest, verify_inventory, verify_mod_inventory


def require_stopped(root):
    # Managed sessions hold active.lock. Also detect a Java launched directly with this root's arguments.
    query = ("$ErrorActionPreference='Stop'; "
             "[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false); "
             "Get-CimInstance Win32_Process -Filter \"Name='java.exe' OR Name='javaw.exe'\" | "
             "ForEach-Object { if (-not $_.CommandLine) { throw 'Cannot identify a running Java process' }; "
             "$_.CommandLine }")
    processes = subprocess.run(['powershell.exe', '-NoProfile', '-NonInteractive', '-Command', query],
                               check=True, capture_output=True, encoding='utf-8', timeout=30)
    runtime_prefix = root.as_posix().casefold() + '/'
    require(runtime_prefix not in processes.stdout.replace('\\', '/').casefold(),
            'A running Java process references this runtime')


def refresh(root, jar, previous_sha256, new_sha256):
    root = plain_path(root)
    read_manifest(root)  # Validate the location before writing the lock.
    evidence = root / 'evidence' / ('refresh-' + uuid.uuid4().hex)
    lock = Ownership(root, evidence)
    try:
        manifest = read_manifest(root)
        verify_inventory(root, manifest)
        require_stopped(root)
        candidate = verify_file(jar, new_sha256)
        separate(root, candidate)
        name = relative(candidate.name).as_posix()
        require(candidate.suffix.lower() == '.jar', 'Select a packaged project JAR')
        old_pin, new_pin = previous_sha256.lower(), new_sha256.lower()
        require(old_pin != new_pin, 'Identical build; reuse the prepared runtime')

        profile = read_json(root / 'profile.json')
        matches = [mod for mod in profile['mods'] if Path(mod['path']).name.casefold() == name.casefold()]
        require(len(matches) == 1, 'Expected exactly one prepared mod with this filename')
        mod = matches[0]
        require(mod['sha256'].lower() == old_pin, 'Previous project JAR pin differs from profile')
        require(mod['sides'] and set(mod['sides']) <= {'client', 'server'}, 'Invalid project JAR sides')
        targets = {f'{side}/mods/{name}' for side in mod['sides']}
        possible_targets = {f'{side}/mods/{name}'.casefold() for side in ('client', 'server')}
        installed = {path for path in manifest['immutable'] if path.casefold() in possible_targets}
        require(installed == targets, 'Project JAR placement differs from prepared profile')
        entries = [entry for entry in manifest['inputs'] if entry['path'] in targets]
        require({e['path'] for e in entries} == targets and len(entries) == len(targets),
                'Missing or ambiguous prepared project input')
        for entry in entries:
            target = entry['path']
            require(entry['sha256'] == manifest['immutable'][target] == old_pin and
                    plain_path(entry['source']) == plain_path(mod['path']), 'Prepared project JAR identity mismatch')

        old_jar = root / entries[0]['path']
        evidence.mkdir(parents=True)
        shutil.copyfile(root / 'profile.json', evidence / 'previous-profile.json')
        shutil.copyfile(root / 'runtime.json', evidence / 'previous-runtime.json')
        shutil.copyfile(old_jar, evidence / 'previous.jar')
        verify_file(evidence / 'previous.jar', old_pin)
        staged = evidence / 'candidate.jar'
        shutil.copyfile(candidate, staged)
        verify_file(staged, new_pin)
        require(contained_dependencies(staged) == contained_dependencies(old_jar),
                'Embedded dependency set changed; prepare a new runtime')

        change = {'previousSha256': old_pin, 'sha256': new_pin, 'source': str(candidate), 'targets': sorted(targets)}
        write_json(evidence / 'change.json', change)
        # From the first installed write until both manifests and all copies verify, run and refresh refuse entry.
        marker = root / 'preparing.json'
        write_json(marker, {'operation': 'refresh', 'evidence': str(evidence)})
        for entry in entries:
            target = entry['path']
            shutil.copyfile(staged, root / target)
            verify_file(root / target, new_pin)
            manifest['immutable'][target] = new_pin
            entry.update(source=str(candidate), sha256=new_pin)
        mod.update(path=str(candidate), sha256=new_pin)
        verify_mod_inventory(root, manifest)
        write_json(root / 'profile.json', profile)
        write_json(root / 'runtime.json', manifest)
        require(read_json(root / 'profile.json') == profile and read_json(root / 'runtime.json') == manifest,
                'Refreshed metadata failed read-back')
        staged.unlink()
        marker.unlink()
        return {'status': 'refreshed', 'evidence': str(evidence), **change}
    finally:
        lock.close()
