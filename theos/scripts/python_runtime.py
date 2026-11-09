#!/usr/bin/env python3
import argparse
import marshal
from pathlib import Path, PurePosixPath
import py_compile
import sys
import tempfile
import zipfile

EXCLUDED_DIRECTORIES = {'__pycache__', '.ruff_cache', 'site-packages', 'test', 'tests', 'idle_test', 'idlelib', 'tkinter', 'turtledemo'}
EXCLUDED_FILES = {'turtle.py', '__phello__.foo.py'}
EXCLUDED_SUFFIXES = {'.pyc', '.pyo', '.exe', '.dll'}
TIMESTAMP = (1980, 1, 1, 0, 0, 0)


def selected_files(root):
    for path in sorted(root.rglob('*')):
        relative = path.relative_to(root)
        if any(part in EXCLUDED_DIRECTORIES for part in relative.parts[:-1]):
            continue
        if path.is_dir() or path.name in EXCLUDED_FILES or path.suffix in EXCLUDED_SUFFIXES:
            continue
        if relative.parts[0] in EXCLUDED_DIRECTORIES:
            continue
        yield path, PurePosixPath(*relative.parts)


def compiled(path, display):
    with tempfile.TemporaryDirectory() as directory:
        output = Path(directory) / 'module.pyc'
        py_compile.compile(str(path), cfile=str(output), dfile=display, doraise=True,
                           invalidation_mode=py_compile.PycInvalidationMode.UNCHECKED_HASH)
        return output.read_bytes()


def entry(name):
    info = zipfile.ZipInfo(str(name), TIMESTAMP)
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = 0o100644 << 16
    return info


def write_archive(roots, output):
    names = set()
    temporary = output.with_name(output.name + '.tmp')
    with zipfile.ZipFile(temporary, 'w') as archive:
        for root in roots:
            for path, relative in selected_files(root):
                if relative.suffix == '.py':
                    name = relative.with_suffix('.pyc')
                    data = compiled(path, output.name + '/' + str(relative))
                else:
                    name = relative
                    data = path.read_bytes()
                if name in names:
                    raise SystemExit('Duplicate runtime entry: ' + str(name))
                names.add(name)
                archive.writestr(entry(name), data)
    temporary.replace(output)


def c_bytes(data):
    rows = []
    for offset in range(0, len(data), 16):
        rows.append('    ' + ', '.join('0x%02x' % byte for byte in data[offset:offset + 16]) + ',')
    return '\n'.join(rows)


def write_frozen(modules, output):
    parts = ['#pragma once', '', '#include <Python.h>', '']
    table = []
    for index, (name, path) in enumerate(modules):
        code = compile(path.read_bytes(), '<frozen ' + name + '>', 'exec', dont_inherit=True)
        data = marshal.dumps(code)
        symbol = 'OnegramFrozenModule' + str(index)
        parts += ['static const unsigned char ' + symbol + '[] = {', c_bytes(data), '};', '']
        table.append('    {"' + name + '", ' + symbol + ', (int)sizeof(' + symbol + '), 0, NULL},')
    parts += ['static const struct _frozen OnegramFrozenModules[] = {'] + table + ['    {NULL, NULL, 0, 0, NULL},', '};', '']
    temporary = output.with_name(output.name + '.tmp')
    temporary.write_text('\n'.join(parts))
    temporary.replace(output)


def main():
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest='command', required=True)
    archive = commands.add_parser('archive')
    archive.add_argument('--output', required=True, type=Path)
    archive.add_argument('roots', nargs='+', type=Path)
    frozen = commands.add_parser('frozen')
    frozen.add_argument('--output', required=True, type=Path)
    frozen.add_argument('--module', action='append', nargs=2, metavar=('NAME', 'PATH'), required=True)
    args = parser.parse_args()
    if sys.version_info[:2] != (3, 11):
        raise SystemExit('The runtime must be compiled by the bundled Python 3.11 host interpreter')
    if args.command == 'archive':
        write_archive(args.roots, args.output)
    else:
        write_frozen([(name, Path(path)) for name, path in args.module], args.output)


if __name__ == '__main__':
    main()
