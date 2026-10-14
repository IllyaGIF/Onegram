#!/usr/bin/env python3
import argparse
import re
import sys

TYPE_START = re.compile(r'^\s*TLSchemeType\$schemeType \*constructor = \[\[TLSchemeType\$schemeType alloc\] init\];\s*$')
METHOD_START = re.compile(r'^\s*TLSchemeMethod\$schemeMethod \*constructor = \[\[TLSchemeMethod\$schemeMethod alloc\] init\];\s*$')
SIGNATURE = re.compile(r'^\s*constructor\.n_id = \(int32_t\)0x([0-9a-fA-F]{1,8});\s*$')
PREDICATE = re.compile(r'^\s*constructor\.predicate = @"([^"\\]*)";\s*$')
METHOD = re.compile(r'^\s*constructor\.method = @"([^"\\]*)";\s*$')
RESULT_TYPE = re.compile(r'^\s*constructor\.type = @"([^"\\]*)";\s*$')
PARAM_START = re.compile(r'^\s*TLSchemeParam\$schemeParam \*arg = \[\[TLSchemeParam\$schemeParam alloc\] init\];\s*$')
PARAM_NAME = re.compile(r'^\s*arg\.name = @"([^"\\]*)";\s*$')
PARAM_TYPE = re.compile(r'^\s*arg\.type = @"([^"\\]*)";\s*$')
PARAM_END = re.compile(r'^\s*\[fields addObject:arg\];\s*$')
TYPE_END = re.compile(r'^\s*\[TLmetaSchemeTypes addObject:constructor\];\s*$')
METHOD_END = re.compile(r'^\s*\[TLmetaSchemeMethods addObject:constructor\];\s*$')


TL_COMBINATOR = re.compile(r'^([A-Za-z_][A-Za-z0-9_.]*)#([0-9a-fA-F]{1,8})((?:\s+[^=]+?)?)\s*=\s*([^;]+?)\s*;$')
TL_SECTION_TYPES = '---types---'
TL_SECTION_FUNCTIONS = '---functions---'


class SchemeError(Exception):
    pass


def parse_generated_scheme(text):
    types = []
    methods = []
    entry = None
    param = None
    for line_number, line in enumerate(text.splitlines(), 1):
        if TYPE_START.match(line) or METHOD_START.match(line):
            if entry is not None:
                raise SchemeError('line %d: nested constructor' % line_number)
            entry = {'kind': 'type' if TYPE_START.match(line) else 'method', 'signature': None, 'name': None, 'type': None, 'params': []}
            continue
        if entry is None:
            if PARAM_START.match(line) or SIGNATURE.match(line):
                raise SchemeError('line %d: field outside constructor' % line_number)
            continue
        match = SIGNATURE.match(line)
        if match:
            entry['signature'] = int(match.group(1), 16)
            continue
        match = PREDICATE.match(line)
        if match:
            if entry['kind'] != 'type':
                raise SchemeError('line %d: predicate in method' % line_number)
            entry['name'] = match.group(1)
            continue
        match = METHOD.match(line)
        if match:
            if entry['kind'] != 'method':
                raise SchemeError('line %d: method in type' % line_number)
            entry['name'] = match.group(1)
            continue
        match = RESULT_TYPE.match(line)
        if match:
            entry['type'] = match.group(1)
            continue
        if PARAM_START.match(line):
            if param is not None:
                raise SchemeError('line %d: nested param' % line_number)
            param = {'name': None, 'type': None}
            continue
        match = PARAM_NAME.match(line)
        if match:
            if param is None:
                raise SchemeError('line %d: param name outside param' % line_number)
            param['name'] = match.group(1)
            continue
        match = PARAM_TYPE.match(line)
        if match:
            if param is None:
                raise SchemeError('line %d: param type outside param' % line_number)
            param['type'] = match.group(1)
            continue
        if PARAM_END.match(line):
            if param is None or param['name'] is None or param['type'] is None:
                raise SchemeError('line %d: incomplete param' % line_number)
            entry['params'].append((param['name'], param['type']))
            param = None
            continue
        end_type = TYPE_END.match(line)
        end_method = METHOD_END.match(line)
        if end_type or end_method:
            if param is not None:
                raise SchemeError('line %d: unterminated param' % line_number)
            if entry['signature'] is None or entry['name'] is None or entry['type'] is None:
                raise SchemeError('line %d: incomplete constructor' % line_number)
            if (entry['kind'] == 'type') != bool(end_type):
                raise SchemeError('line %d: constructor added to the wrong list' % line_number)
            (types if end_type else methods).append(entry)
            entry = None
    if entry is not None or param is not None:
        raise SchemeError('unterminated constructor at end of input')
    expected_constructors = len(re.findall(r'\[\[TLScheme(?:Type\$schemeType|Method\$schemeMethod) alloc\] init\]', text))
    expected_params = len(re.findall(r'\[\[TLSchemeParam\$schemeParam alloc\] init\]', text))
    if expected_constructors != len(types) + len(methods):
        raise SchemeError('parsed %d constructors, expected %d' % (len(types) + len(methods), expected_constructors))
    parsed_params = sum(len(item['params']) for item in types + methods)
    if expected_params != parsed_params:
        raise SchemeError('parsed %d params, expected %d' % (parsed_params, expected_params))
    return types, methods


def normalize_tl_param_type(param_type):
    return 'int' if param_type == '#' else param_type


def parse_tl_scheme(text, source):
    types = []
    methods = []
    section = 'type'
    for line_number, raw_line in enumerate(text.splitlines(), 1):
        line = raw_line.split('//', 1)[0].strip()
        if not line:
            continue
        if line == TL_SECTION_TYPES:
            section = 'type'
            continue
        if line == TL_SECTION_FUNCTIONS:
            section = 'method'
            continue
        match = TL_COMBINATOR.match(line)
        if match is None:
            raise SchemeError('%s:%d: unsupported combinator %r' % (source, line_number, line))
        name, signature, arguments, result_type = match.groups()
        params = []
        for argument in arguments.split():
            if argument.startswith('{') or ':' not in argument:
                continue
            param_name, param_type = argument.split(':', 1)
            if param_type.startswith('!'):
                continue
            params.append((param_name, normalize_tl_param_type(param_type)))
        entry = {'kind': section, 'signature': int(signature, 16), 'name': name, 'type': result_type, 'params': params}
        (types if section == 'type' else methods).append(entry)
    return types, methods


def merge_tl_schemes(schemes):
    types = []
    methods = []
    seen = set()
    for scheme_types, scheme_methods in schemes:
        for entry in scheme_types + scheme_methods:
            key = (entry['kind'], entry['name'])
            if key in seen:
                raise SchemeError('duplicate %s %s' % (entry['kind'], entry['name']))
            seen.add(key)
        types.extend(scheme_types)
        methods.extend(scheme_methods)
    return types, methods


class StringPool:
    def __init__(self):
        self.offsets = {}
        self.strings = []
        self.size = 0

    def offset(self, value):
        if '\0' in value or '"' in value or '\\' in value or not value.isascii():
            raise SchemeError('unsupported string %r' % value)
        existing = self.offsets.get(value)
        if existing is not None:
            return existing
        offset = self.size
        self.offsets[value] = offset
        self.strings.append(value)
        self.size += len(value) + 1
        return offset


def signature_literal(signature):
    return '(int32_t)0x%08x' % signature


def render_table(types, methods):
    pool = StringPool()
    params = []
    rendered_entries = {}
    for label, entries in (('types', types), ('methods', methods)):
        rows = []
        for entry in entries:
            params_offset = len(params)
            for name, param_type in entry['params']:
                params.append((pool.offset(name), pool.offset(param_type)))
            rows.append((entry['signature'], pool.offset(entry['name']), pool.offset(entry['type']), params_offset, len(entry['params'])))
        rendered_entries[label] = rows

    output = []
    output.append('#import "TLMetaSchemeData.h"')
    output.append('')
    output.append('static const char TLMetaSchemeStrings[] =')
    for value in pool.strings:
        output.append('    "%s\\0"' % value)
    output.append('    ;')
    output.append('')
    for label, symbol in (('types', 'TLMetaSchemeTypeEntries'), ('methods', 'TLMetaSchemeMethodEntries')):
        output.append('static const TLMetaSchemeEntry %s[] =' % symbol)
        output.append('{')
        for signature, name, result_type, params_offset, params_count in rendered_entries[label]:
            output.append('    {%s, %d, %d, %d, %d},' % (signature_literal(signature), name, result_type, params_offset, params_count))
        output.append('};')
        output.append('')
    output.append('static const TLMetaSchemeParamEntry TLMetaSchemeParamEntries[] =')
    output.append('{')
    for name, param_type in params:
        output.append('    {%d, %d},' % (name, param_type))
    output.append('};')
    output.append('')
    output.append('static const TLMetaSchemeTable TLMetaSchemeTableInstance =')
    output.append('{')
    output.append('    TLMetaSchemeStrings,')
    output.append('    TLMetaSchemeTypeEntries,')
    output.append('    (uint32_t)(sizeof(TLMetaSchemeTypeEntries) / sizeof(TLMetaSchemeTypeEntries[0])),')
    output.append('    TLMetaSchemeMethodEntries,')
    output.append('    (uint32_t)(sizeof(TLMetaSchemeMethodEntries) / sizeof(TLMetaSchemeMethodEntries[0])),')
    output.append('    TLMetaSchemeParamEntries,')
    output.append('    (uint32_t)(sizeof(TLMetaSchemeParamEntries) / sizeof(TLMetaSchemeParamEntries[0]))')
    output.append('};')
    output.append('')
    output.append('const TLMetaSchemeTable *TLgetMetaSchemeTable()')
    output.append('{')
    output.append('    return &TLMetaSchemeTableInstance;')
    output.append('}')
    output.append('')
    output.append('static NSString *TLMetaSchemeString(const TLMetaSchemeTable *table, uint32_t offset)')
    output.append('{')
    output.append('    return [[NSString alloc] initWithUTF8String:table->strings + offset];')
    output.append('}')
    output.append('')
    output.append('static NSMutableArray *TLMetaSchemeParams(const TLMetaSchemeTable *table, const TLMetaSchemeEntry *entry)')
    output.append('{')
    output.append('    NSMutableArray *fields = [[NSMutableArray alloc] initWithCapacity:entry->paramsCount];')
    output.append('    for (uint32_t i = 0; i < entry->paramsCount; i++)')
    output.append('    {')
    output.append('        const TLMetaSchemeParamEntry *paramEntry = &table->params[entry->paramsOffset + i];')
    output.append('        TLSchemeParam$schemeParam *arg = [[TLSchemeParam$schemeParam alloc] init];')
    output.append('        arg.name = TLMetaSchemeString(table, paramEntry->name);')
    output.append('        arg.type = TLMetaSchemeString(table, paramEntry->type);')
    output.append('        [fields addObject:arg];')
    output.append('    }')
    output.append('    return fields;')
    output.append('}')
    output.append('')
    output.append('TLScheme *TLgetMetaScheme()')
    output.append('{')
    output.append('    const TLMetaSchemeTable *table = TLgetMetaSchemeTable();')
    output.append('    NSMutableArray *TLmetaSchemeTypes = [[NSMutableArray alloc] initWithCapacity:table->typesCount];')
    output.append('    for (uint32_t i = 0; i < table->typesCount; i++)')
    output.append('    {')
    output.append('        const TLMetaSchemeEntry *entry = &table->types[i];')
    output.append('        TLSchemeType$schemeType *constructor = [[TLSchemeType$schemeType alloc] init];')
    output.append('        constructor.n_id = entry->signature;')
    output.append('        constructor.predicate = TLMetaSchemeString(table, entry->name);')
    output.append('        constructor.type = TLMetaSchemeString(table, entry->type);')
    output.append('        constructor.params = TLMetaSchemeParams(table, entry);')
    output.append('        [TLmetaSchemeTypes addObject:constructor];')
    output.append('    }')
    output.append('    NSMutableArray *TLmetaSchemeMethods = [[NSMutableArray alloc] initWithCapacity:table->methodsCount];')
    output.append('    for (uint32_t i = 0; i < table->methodsCount; i++)')
    output.append('    {')
    output.append('        const TLMetaSchemeEntry *entry = &table->methods[i];')
    output.append('        TLSchemeMethod$schemeMethod *constructor = [[TLSchemeMethod$schemeMethod alloc] init];')
    output.append('        constructor.n_id = entry->signature;')
    output.append('        constructor.method = TLMetaSchemeString(table, entry->name);')
    output.append('        constructor.type = TLMetaSchemeString(table, entry->type);')
    output.append('        constructor.params = TLMetaSchemeParams(table, entry);')
    output.append('        [TLmetaSchemeMethods addObject:constructor];')
    output.append('    }')
    output.append('    TLScheme$scheme *scheme = [[TLScheme$scheme alloc] init];')
    output.append('    scheme.types = TLmetaSchemeTypes;')
    output.append('    scheme.methods = TLmetaSchemeMethods;')
    output.append('    return scheme;')
    output.append('}')
    output.append('')
    return '\n'.join(output), pool, params


def main():
    parser = argparse.ArgumentParser(description='Convert TL schemes or a generated TLgetMetaScheme() source into the constant TLMetaSchemeTable form.')
    parser.add_argument('--tl', action='append', default=[], metavar='SCHEME', help='TL scheme file; may be repeated, entries are emitted in the given order')
    parser.add_argument('paths', nargs='+', help='without --tl: the generated TLMetaSchemeData.mm followed by destination files; with --tl: destination files')
    arguments = parser.parse_args()
    if arguments.tl:
        schemes = []
        for path in arguments.tl:
            with open(path, 'r', encoding='utf-8') as handle:
                schemes.append(parse_tl_scheme(handle.read(), path))
        types, methods = merge_tl_schemes(schemes)
        outputs = arguments.paths
    else:
        if len(arguments.paths) < 2:
            parser.error('an input file and at least one output file are required')
        with open(arguments.paths[0], 'r', encoding='utf-8') as handle:
            text = handle.read()
        types, methods = parse_generated_scheme(text)
        outputs = arguments.paths[1:]
    rendered, pool, params = render_table(types, methods)
    for path in outputs:
        with open(path, 'w', encoding='utf-8') as handle:
            handle.write(rendered)
    sys.stderr.write('types=%d methods=%d params=%d strings=%d bytes=%d\n' % (len(types), len(methods), len(params), len(pool.strings), pool.size))


if __name__ == '__main__':
    try:
        main()
    except SchemeError as error:
        sys.stderr.write('error: %s\n' % error)
        sys.exit(1)
