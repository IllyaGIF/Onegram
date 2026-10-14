#!/usr/bin/env python3
import argparse
import glob
import os
import re
import sys

REGISTRATION = re.compile(r'TLMetaClassStore::(registerObjectClass|registerVectorClass)\(\[([A-Za-z0-9_$]+) new\]\);')
IMPLEMENTATION = re.compile(r'@implementation\s+([A-Za-z0-9_$]+)(?:\s*:\s*[A-Za-z0-9_$]+)?(.*?)@end', re.S)
REGISTER_FUNCTION = 'void TLRegisterClasses()\n{\n'


class TableError(Exception):
    pass


def literal_method_value(body, selector):
    match = re.search(r'-\s*\(int32_t\)\s*' + selector + r'\s*\{\s*return\s+(?:\(int32_t\)\s*)?(0x[0-9a-fA-F]{1,8}|-?\d+)\s*;\s*\}', body)
    if match is None:
        return None
    value = int(match.group(1), 0) & 0xffffffff
    return value - (1 << 32) if value & 0x80000000 else value


def load_implementations(source_dir):
    implementations = {}
    for path in sorted(glob.glob(os.path.join(source_dir, '*.mm'))):
        with open(path, 'r', encoding='utf-8', errors='replace') as handle:
            text = handle.read()
        for match in IMPLEMENTATION.finditer(text):
            name = match.group(1)
            if name in implementations:
                raise TableError('class %s is implemented in %s and %s' % (name, implementations[name]['path'], path))
            implementations[name] = {
                'path': path,
                'TLconstructorName': literal_method_value(match.group(2), 'TLconstructorName'),
                'TLconstructorSignature': literal_method_value(match.group(2), 'TLconstructorSignature'),
            }
    return implementations


def split_registration_source(text):
    start = text.find(REGISTER_FUNCTION)
    if start < 0:
        raise TableError('TLRegisterClasses() not found')
    end = text.find('\n}\n', start)
    if end < 0:
        raise TableError('TLRegisterClasses() is not terminated')
    return text[:end + 3], text[start:end]


def build_entries(registrations, implementations, kind, selector):
    entries = {}
    for registration_kind, class_name in registrations:
        if registration_kind != kind:
            continue
        implementation = implementations.get(class_name)
        if implementation is None:
            raise TableError('class %s has no implementation' % class_name)
        key = implementation[selector]
        if key is None:
            raise TableError('class %s has no literal %s' % (class_name, selector))
        if key not in entries:
            entries[key] = class_name
    return sorted(entries.items())


def render(prefix, object_entries, vector_entries):
    names = []
    offsets = {}
    size = 0
    for _, class_name in object_entries + vector_entries:
        if class_name not in offsets:
            offsets[class_name] = size
            names.append(class_name)
            size += len(class_name) + 1
    output = [prefix.rstrip('\n'), '']
    output.append('static const char TLMetaClassNames[] =')
    for class_name in names:
        output.append('    "%s\\0"' % class_name)
    output.append('    ;')
    output.append('')
    for symbol, entries in (('TLMetaObjectClassEntries', object_entries), ('TLMetaVectorClassEntries', vector_entries)):
        output.append('static const TLMetaClassEntry %s[] =' % symbol)
        output.append('{')
        for key, class_name in entries:
            output.append('    {(int32_t)0x%08x, %d},' % (key & 0xffffffff, offsets[class_name]))
        output.append('};')
        output.append('')
    output.append('static const TLMetaClassTable TLMetaClassTableInstance =')
    output.append('{')
    output.append('    TLMetaClassNames,')
    output.append('    TLMetaObjectClassEntries,')
    output.append('    (uint32_t)(sizeof(TLMetaObjectClassEntries) / sizeof(TLMetaObjectClassEntries[0])),')
    output.append('    TLMetaVectorClassEntries,')
    output.append('    (uint32_t)(sizeof(TLMetaVectorClassEntries) / sizeof(TLMetaVectorClassEntries[0]))')
    output.append('};')
    output.append('')
    output.append('const TLMetaClassTable *TLgetMetaClassTable()')
    output.append('{')
    output.append('    return &TLMetaClassTableInstance;')
    output.append('}')
    output.append('')
    return '\n'.join(output)


def main():
    parser = argparse.ArgumentParser(description='Append the lazily resolved TL class table to the generated TLRegisterClasses() source.')
    parser.add_argument('registration', help='TLMetaScheme.mm containing TLRegisterClasses()')
    parser.add_argument('sources', help='directory with the generated TL class implementations')
    parser.add_argument('output', nargs='+', help='destination TLMetaScheme.mm files')
    arguments = parser.parse_args()
    with open(arguments.registration, 'r', encoding='utf-8') as handle:
        text = handle.read()
    prefix, body = split_registration_source(text)
    registrations = REGISTRATION.findall(body)
    if not registrations:
        raise TableError('TLRegisterClasses() has no registrations')
    implementations = load_implementations(arguments.sources)
    object_entries = build_entries(registrations, implementations, 'registerObjectClass', 'TLconstructorName')
    vector_entries = build_entries(registrations, implementations, 'registerVectorClass', 'TLconstructorSignature')
    rendered = render(prefix, object_entries, vector_entries)
    for path in arguments.output:
        with open(path, 'w', encoding='utf-8') as handle:
            handle.write(rendered)
    sys.stderr.write('registrations=%d objectClasses=%d vectorClasses=%d\n' % (len(registrations), len(object_entries), len(vector_entries)))


if __name__ == '__main__':
    try:
        main()
    except TableError as error:
        sys.stderr.write('error: %s\n' % error)
        sys.exit(1)
