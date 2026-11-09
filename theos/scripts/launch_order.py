#!/usr/bin/env python3
import argparse
import bisect
import re
import struct
import sys
from collections import Counter
from pathlib import Path

N_STAB = 0xe0
N_TYPE = 0x0e
N_SECT = 0x0e
LC_SEGMENT = 0x1
LC_SYMTAB = 0x2
MH_MAGIC = 0xfeedface
FAT_MAGIC = 0xcafebabe
CPU_TYPE_ARM = 12
CPU_SUBTYPE_ARM_V6 = 6

def thin_slice(data):
    if struct.unpack_from('>I', data, 0)[0] != FAT_MAGIC:
        return data
    count = struct.unpack_from('>I', data, 4)[0]
    for index in range(count):
        cputype, subtype, offset, size, _ = struct.unpack_from('>5I', data, 8 + index * 20)
        if cputype == CPU_TYPE_ARM and subtype == CPU_SUBTYPE_ARM_V6:
            return data[offset:offset + size]
    raise SystemExit('armv6 slice not found')

def load_symbols(path):
    data = thin_slice(Path(path).read_bytes())
    if struct.unpack_from('<I', data, 0)[0] != MH_MAGIC:
        raise SystemExit('unsupported Mach-O: %s' % path)
    ncmds = struct.unpack_from('<I', data, 16)[0]
    offset = 28
    sections = {}
    section_index = 0
    symbols = []
    for _ in range(ncmds):
        cmd, size = struct.unpack_from('<2I', data, offset)
        if cmd == LC_SEGMENT:
            nsects = struct.unpack_from('<I', data, offset + 48)[0]
            for index in range(nsects):
                base = offset + 56 + index * 68
                section_index += 1
                sections[section_index] = (data[base + 16:base + 32].split(b'\0')[0].decode(), data[base:base + 16].split(b'\0')[0].decode())
        elif cmd == LC_SYMTAB:
            symoff, nsyms, stroff, _ = struct.unpack_from('<4I', data, offset + 8)
            for index in range(nsyms):
                strx, ntype, nsect, _, value = struct.unpack_from('<IBBhI', data, symoff + index * 12)
                if ntype & N_STAB or (ntype & N_TYPE) != N_SECT:
                    continue
                end = data.index(b'\0', stroff + strx)
                name = data[stroff + strx:end].decode(errors='replace')
                if name:
                    symbols.append((value, name, nsect))
        offset += size
    return symbols, sections

def read_addresses(paths):
    addresses = []
    marker = re.compile(r'LAUNCHORDER chunk=\d+((?: [0-9a-fA-F]+)+)')
    for path in paths:
        text = Path(path).read_text(errors='replace')
        found = False
        for match in marker.finditer(text):
            found = True
            addresses.extend(int(value, 16) for value in match.group(1).split())
        if not found:
            for line in text.splitlines():
                line = line.strip()
                if re.fullmatch(r'[0-9a-fA-F]+', line):
                    addresses.append(int(line, 16))
    return addresses

def class_name(symbol):
    match = re.match(r'^[-+]\[([^ (\]]+)', symbol)
    return match.group(1) if match else None

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--binary', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('inputs', nargs='+')
    arguments = parser.parse_args()

    symbols, sections = load_symbols(arguments.binary)
    names = Counter(name for _, name, _ in symbols)
    text = sorted((value & ~1, name) for value, name, section in symbols if sections.get(section) == ('__TEXT', '__text'))
    starts = [value for value, _ in text]
    exact = {}
    for value, name in text:
        exact.setdefault(value, name)
    data_symbols = {name for _, name, section in symbols if sections.get(section, ('', ''))[0] == '__DATA'}

    ordered = []
    seen = set()
    classes = []
    seen_classes = set()
    unresolved = 0
    for address in read_addresses(arguments.inputs):
        address &= ~1
        name = exact.get(address)
        if name is None:
            index = bisect.bisect_right(starts, address) - 1
            if index < 0:
                unresolved += 1
                continue
            name = text[index][1]
        if name in seen or names[name] != 1:
            continue
        seen.add(name)
        ordered.append(name)
        owner = class_name(name)
        if owner is not None and owner not in seen_classes:
            seen_classes.add(owner)
            for candidate in ('_OBJC_CLASS_$_' + owner, '_OBJC_METACLASS_$_' + owner):
                if candidate in data_symbols and names[candidate] == 1:
                    classes.append(candidate)

    output = Path(arguments.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text('\n'.join(ordered + classes) + '\n')
    print('functions=%d classes=%d unresolved=%d output=%s' % (len(ordered), len(classes), unresolved, output))
    return 0

if __name__ == '__main__':
    sys.exit(main())
