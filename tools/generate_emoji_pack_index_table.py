#!/usr/bin/env python3
import argparse
import os
import plistlib
import struct
import sys


class TableError(Exception):
    pass


def load_entries(index_path, pack_size):
    with open(index_path, 'rb') as handle:
        index = plistlib.load(handle)
    entries = []
    for key, value in index.items():
        parts = key.split('-')
        codepoints = []
        for part in parts:
            if not part or any(c not in '0123456789abcdef' for c in part):
                raise TableError('invalid key %r' % key)
            codepoint = int(part, 16)
            if '%x' % codepoint != part:
                raise TableError('non canonical key %r' % key)
            codepoints.append(codepoint)
        if not isinstance(value, bytes) or len(value) != 8:
            raise TableError('invalid entry for key %r' % key)
        offset, length = struct.unpack('>II', value)
        if offset + length > pack_size:
            raise TableError('entry %r exceeds pack size' % key)
        entries.append((tuple(codepoints), offset, length))
    entries.sort(key=lambda entry: entry[0])
    for previous, current in zip(entries, entries[1:]):
        if previous[0] == current[0]:
            raise TableError('duplicate key %r' % (current[0],))
    return entries


def render(entries, pack_size, max_codepoints):
    lines = []
    lines.append('#ifndef TGEmojiPackIndexTable_h')
    lines.append('#define TGEmojiPackIndexTable_h')
    lines.append('')
    lines.append('#include <stdint.h>')
    lines.append('')
    lines.append('typedef struct')
    lines.append('{')
    lines.append('    uint32_t codepointsOffset;')
    lines.append('    uint32_t codepointsCount;')
    lines.append('    uint32_t packOffset;')
    lines.append('    uint32_t packLength;')
    lines.append('} TGEmojiPackIndexTableEntry;')
    lines.append('')
    lines.append('static const uint64_t TGEmojiPackIndexTablePackSize = %dULL;' % pack_size)
    lines.append('static const uint32_t TGEmojiPackIndexTableMaxCodepoints = %d;' % max_codepoints)
    lines.append('static const uint32_t TGEmojiPackIndexTableCount = %d;' % len(entries))
    lines.append('')
    lines.append('static const uint32_t TGEmojiPackIndexTableCodepoints[] =')
    lines.append('{')
    flat = []
    for codepoints, _, _ in entries:
        flat.extend(codepoints)
    for start in range(0, len(flat), 8):
        lines.append('    ' + ', '.join('0x%x' % value for value in flat[start:start + 8]) + ',')
    lines.append('};')
    lines.append('')
    lines.append('static const TGEmojiPackIndexTableEntry TGEmojiPackIndexTableEntries[] =')
    lines.append('{')
    cursor = 0
    for codepoints, offset, length in entries:
        lines.append('    {%d, %d, %d, %d},' % (cursor, len(codepoints), offset, length))
        cursor += len(codepoints)
    lines.append('};')
    lines.append('')
    lines.append('#endif')
    lines.append('')
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('index')
    parser.add_argument('pack')
    parser.add_argument('output')
    args = parser.parse_args()
    pack_size = os.path.getsize(args.pack)
    try:
        entries = load_entries(args.index, pack_size)
    except TableError as error:
        sys.stderr.write('%s\n' % error)
        return 1
    max_codepoints = max(len(entry[0]) for entry in entries)
    with open(args.output, 'w') as handle:
        handle.write(render(entries, pack_size, max_codepoints))
    return 0


if __name__ == '__main__':
    sys.exit(main())
