import argparse
import json
from pathlib import Path
import re
import subprocess


def escape_dollars(contents):
    return re.sub(rb'(?<!\$)\$(?!\$)', b'$$', contents)


def repair(compiler, objects):
    if not compiler.is_file() or not objects.is_dir():
        return
    version = subprocess.run([str(compiler), '--version'], check=True, capture_output=True, text=True).stdout
    if not re.search(r'clang version 3\.2(?:\D|$)', version):
        return
    stamp = objects / 'dependency-state.json'
    try:
        saved = json.loads(stamp.read_text())
    except (OSError, ValueError):
        saved = {}
    current = {}
    for path in objects.rglob('*.Td'):
        key = str(path.relative_to(objects))
        def identity():
            stat = path.stat()
            return [stat.st_size, stat.st_mtime_ns, stat.st_ctime_ns]
        record = identity()
        if saved.get(key) != record:
            contents = path.read_bytes()
            fixed = escape_dollars(contents)
            if fixed != contents:
                path.write_bytes(fixed)
                record = identity()
        current[key] = record
    if current != saved:
        temporary = stamp.with_suffix('.tmp')
        temporary.write_text(json.dumps(current, sort_keys=True) + '\n')
        temporary.replace(stamp)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--compiler', required=True, type=Path)
    parser.add_argument('--objects', required=True, type=Path)
    args = parser.parse_args()
    repair(args.compiler, args.objects)
