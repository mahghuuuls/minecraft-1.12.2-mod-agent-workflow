"""Shared validation for the local, cache-only Cleanroom runtime tool."""
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import time


class RuntimeErrorDetail(Exception):
    pass


def require(condition, message):
    if not condition:
        raise RuntimeErrorDetail(message)


def read_json(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def write_json(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(path.name + '.tmp')
    temp.write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')
    for attempt in range(21):
        try:
            os.replace(temp, path)
            break
        except PermissionError:
            # Windows readers/virus scanners may briefly deny FILE_SHARE_DELETE.
            if attempt == 20:
                raise
            time.sleep(.1)


def sha256(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def plain_path(value):
    path = Path(value)
    require(path.is_absolute(), f'Use an absolute local path: {path}')
    require(not str(path).startswith('\\\\'), 'Network paths are not supported')
    require('..' not in path.parts, f'Parent traversal is not allowed: {path}')
    for part in [*reversed(path.parents), path]:
        if part.exists() or part.is_symlink():
            info = part.lstat()
            require(not stat.S_ISLNK(info.st_mode) and not (getattr(info, 'st_file_attributes', 0) & 0x400),
                    f'Links and reparse points are not supported: {part}')
    return path.resolve()


def relative(value):
    require(isinstance(value, str) and '\\' not in value, 'Use forward slashes in relative paths')
    path = PurePosixPath(value)
    require(value and not path.is_absolute() and all(p not in ('.', '..') for p in value.split('/')),
            f'Invalid relative path: {value}')
    require(not re.search(r'[:*?"<>|\x00-\x1f]', value), f'Invalid relative path: {value}')
    for part in path.parts:
        require(not part.endswith((' ', '.')) and not re.match(r'(?i)^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)', part),
                f'Reserved path: {value}')
    return Path(*path.parts)


def inside(path, parent):
    return path == parent or parent in path.parents


def separate(root, other):
    require(not inside(root, other) and not inside(other, root), f'Runtime overlaps a source/protected path: {other}')


def verify_file(path, expected):
    path = plain_path(path)
    require(path.is_file(), f'Missing input: {path}')
    require(bool(re.fullmatch('[a-fA-F0-9]{64}', expected or '')), f'Missing SHA-256 pin: {path}')
    require(sha256(path) == expected.lower(), f'Input SHA-256 changed: {path}')
    return path


def check_tree(root):
    plain_path(root)
    for base, dirs, files in os.walk(root, followlinks=False):
        for name in dirs + files:
            path = plain_path(Path(base) / name)
            require(not path.is_file() or path.stat().st_nlink == 1, f'Hard-linked runtime file: {path}')


def bounded(value, low, high, label):
    require(type(value) in (int, float) and low <= value <= high, f'{label} must be {low}..{high}')
    return value
