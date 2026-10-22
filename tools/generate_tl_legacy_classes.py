#!/usr/bin/env python3
import argparse
import hashlib
import os
import re
import sys

import generate_tl_meta_class_table as class_table

TL_COMBINATOR = re.compile(r'^([A-Za-z_][A-Za-z0-9_.]*)#([0-9a-fA-F]{1,8})((?:\s+[^=]+?)?)\s*=\s*([^;]+?)\s*;$')
RESERVED_NAMES = {'id', 'hash', 'type', 'long', 'description', 'class', 'self', 'default', 'bool', 'int'}
PRIMITIVES = {
    'int': ('int32_t', 'TLConstructedValueTypePrimitiveInt32', 'getInt32', 'primitive.int32Value'),
    'long': ('int64_t', 'TLConstructedValueTypePrimitiveInt64', 'getInt64', 'primitive.int64Value'),
    'double': ('double', 'TLConstructedValueTypePrimitiveDouble', 'getDouble', 'primitive.doubleValue'),
    'Bool': ('bool', 'TLConstructedValueTypePrimitiveBool', 'getBool', 'primitive.boolValue'),
    '#': ('int32_t', 'TLConstructedValueTypePrimitiveInt32', 'getInt32', 'primitive.int32Value'),
}
NATIVE = {
    'string': ('NSString', 'TLConstructedValueTypeString', 'getString'),
    'bytes': ('NSData', 'TLConstructedValueTypeBytes', 'getBytes'),
}
REGISTER_LINE = '    TLMetaClassStore::registerObjectClass([%s new]);\n'


class GeneratorError(Exception):
    pass


def murmur3(data, seed=-137723950):
    h = seed & 0xffffffff
    length = len(data)
    blocks = length // 4
    for index in range(blocks):
        k = int.from_bytes(data[index * 4:index * 4 + 4], 'little')
        k = (k * 0xcc9e2d51) & 0xffffffff
        k = ((k << 15) | (k >> 17)) & 0xffffffff
        k = (k * 0x1b873593) & 0xffffffff
        h ^= k
        h = ((h << 13) | (h >> 19)) & 0xffffffff
        h = (h * 5 + 0xe6546b64) & 0xffffffff
    tail = data[blocks * 4:]
    k = 0
    if len(tail) >= 3:
        k ^= tail[2] << 16
    if len(tail) >= 2:
        k ^= tail[1] << 8
    if len(tail) >= 1:
        k ^= tail[0]
        k = (k * 0xcc9e2d51) & 0xffffffff
        k = ((k << 15) | (k >> 17)) & 0xffffffff
        k = (k * 0x1b873593) & 0xffffffff
        h ^= k
    h ^= length
    h ^= h >> 16
    h = (h * 0x85ebca6b) & 0xffffffff
    h ^= h >> 13
    h = (h * 0xc2b2ae35) & 0xffffffff
    h ^= h >> 16
    return h


def name_hash(text):
    return '(int32_t)0x%x' % murmur3(text.encode('utf-8'))


def parse_schema(path):
    constructors, methods = {}, {}
    section = constructors
    with open(path, 'r', encoding='utf-8') as handle:
        for raw in handle:
            line = raw.strip()
            if line == '---functions---':
                section = methods
                continue
            if line == '---types---':
                section = constructors
                continue
            match = TL_COMBINATOR.match(line)
            if match is None:
                continue
            name, signature, arguments, result = match.groups()
            fields = []
            for argument in arguments.split():
                if argument.startswith('{') or ':' not in argument:
                    continue
                field_name, field_type = argument.split(':', 1)
                condition = None
                if '?' in field_type:
                    flag, field_type = field_type.split('?', 1)
                    flag_name, flag_bit = flag.split('.')
                    condition = (flag_name, int(flag_bit))
                fields.append({'name': field_name, 'type': field_type, 'condition': condition})
            section[name] = {'name': name, 'signature': int(signature, 16), 'fields': fields, 'result': result}
    types = {}
    for constructor in constructors.values():
        types.setdefault(constructor['result'], []).append(constructor)
    return constructors, methods, types


def class_for_type(tl_type):
    return 'TL' + tl_type.replace('.', '_')


def property_name(field_name):
    if field_name in RESERVED_NAMES or field_name.startswith('new'):
        return 'n_' + field_name
    return field_name


def describe_field(field):
    tl_type = field['type']
    entry = {'name': field['name'], 'property': property_name(field['name']), 'condition': field['condition'], 'referenced': None}
    if tl_type in PRIMITIVES:
        objc, value_type, getter, member = PRIMITIVES[tl_type]
        entry.update(declaration='@property (nonatomic) %s %s;' % (objc, entry['property']), value_type=value_type, getter=getter, member=member)
    elif tl_type in NATIVE:
        objc, value_type, getter = NATIVE[tl_type]
        entry.update(declaration='@property (nonatomic, retain) %s *%s;' % (objc, entry['property']), value_type=value_type, getter=getter, member='nativeObject')
    elif tl_type.startswith(('Vector<', 'vector<')):
        entry.update(declaration='@property (nonatomic, retain) NSArray *%s;' % entry['property'], value_type='TLConstructedValueTypeVector', getter='getArray', member='nativeObject')
    else:
        objc = class_for_type(tl_type)
        entry.update(declaration='@property (nonatomic, retain) %s *%s;' % (objc, entry['property']), value_type='TLConstructedValueTypeObject', getter='getObject', member='nativeObject', referenced=objc)
    return entry


def stored_fields(combinator):
    return [describe_field(field) for field in combinator['fields'] if not (field['condition'] is not None and field['type'] == 'true')]


def render_build(class_name, fields):
    lines = ['- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)%smetaObject' % ('' if fields else '__unused '), '{']
    lines.append('    %s *object = [[%s alloc] init];' % (class_name, class_name))
    for field in fields:
        lines.append('    object.%s = metaObject->%s(%s);' % (field['property'], field['getter'], name_hash(field['name'])))
    lines.append('    return object;')
    lines.append('}')
    return lines


def render_fill(fields):
    lines = ['- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)%svalues' % ('' if fields else '__unused '), '{']
    for field in fields:
        if field['condition'] is not None:
            lines.append('    if (self.%s & (1 << %d))' % (property_name(field['condition'][0]), field['condition'][1]))
        lines.append('    {')
        lines.append('        TLConstructedValue value;')
        lines.append('        value.type = %s;' % field['value_type'])
        lines.append('        value.%s = self.%s;' % (field['member'], field['property']))
        lines.append('        values->insert(std::pair<int32_t, TLConstructedValue>(%s, value));' % name_hash(field['name']))
        lines.append('    }')
    lines.append('}')
    return lines


def render_concrete_implementation(class_name, base_name, combinator, fields):
    lines = ['@implementation %s : %s' % (class_name, base_name), '', '']
    lines += ['- (int32_t)TLconstructorSignature', '{', '    return (int32_t)0x%x;' % combinator['signature'], '}', '']
    lines += ['- (int32_t)TLconstructorName', '{', '    return %s;' % name_hash(combinator['name']), '}', '']
    lines += render_build(class_name, fields) + ['']
    lines += render_fill(fields) + ['', '', '@end', '']
    return lines


def render_abstract_methods():
    return [
        '- (int32_t)TLconstructorSignature', '{', '    return 0;', '}', '',
        '- (int32_t)TLconstructorName', '{', '    return 0;', '}', '',
        '- (id<TLObject>)TLbuildFromMetaObject:(std::tr1::shared_ptr<TLMetaObject>)__unused metaObject', '{', '    return nil;', '}', '',
        '- (void)TLfillFieldsWithValues:(std::map<int32_t, TLConstructedValue> *)__unused values', '{', '}', '', '',
    ]


def header_prologue(base_name):
    guard = 'TG_LEGACY_TL_%s_H' % base_name.upper()
    return ['#ifndef ' + guard, '#define ' + guard, '', '#import <Foundation/Foundation.h>', '', '#import "TLObject.h"', '#import "TLMetaRpc.h"', '']


def source_prologue(base_name):
    return ['#import "%s.h"' % base_name, '', '#import "../NSInputStream+TL.h"', '#import "../NSOutputStream+TL.h"', '']


class Generator:
    def __init__(self, schema, classes_dir):
        self.constructors, self.methods, self.types = parse_schema(schema)
        self.classes_dir = classes_dir
        self.created = []
        self.registered = []

    def header_exists(self, class_name):
        return os.path.exists(os.path.join(self.classes_dir, class_name + '.h'))

    def response_class(self, result):
        if result == 'Bool':
            return 'NSNumber', 0
        if result.startswith(('Vector<', 'vector<')):
            return 'NSArray', 0
        objc = class_for_type(result)
        if not self.header_exists(objc):
            raise GeneratorError('response type %s has no generated class' % result)
        constructors = self.types.get(result, [])
        return objc, constructors[0]['signature'] if len(constructors) == 1 else 0

    def write(self, path, lines):
        if not os.path.exists(path):
            self.created.append(os.path.basename(path))
        text = '\n'.join(lines)
        if path.endswith('.mm'):
            text += '\n'
        with open(path, 'w', encoding='utf-8') as handle:
            handle.write(text)

    def class_declarations(self, referenced):
        return ['@class %s;' % name for name in sorted(set(referenced))]

    def class_imports(self, referenced):
        return ['#import "%s.h"' % name for name in sorted(set(referenced)) if self.header_exists(name)]

    def generate_method(self, method):
        namespace, _, call = method['name'].rpartition('.')
        base_name = 'TLRPC%s_%s' % (namespace, call) if namespace else 'TLRPC' + call
        class_name = '%s$%s' % (base_name, method['name'].replace('.', '_'))
        fields = stored_fields(method)
        response, implied = self.response_class(method['result'])
        referenced = [field['referenced'] for field in fields if field['referenced']]
        if response not in ('NSNumber', 'NSArray'):
            referenced.append(response)
        header = header_prologue(base_name) + self.class_declarations(referenced)
        header += ['', '@interface %s : TLMetaRpc' % base_name, '']
        header += [field['declaration'] for field in fields]
        header += ['', '- (Class)responseClass;', '', '- (int)impliedResponseSignature;', '', '@end', '']
        header += ['@interface %s : %s' % (class_name, base_name), '', '', '@end', '', '#endif', '']
        source = source_prologue(base_name) + self.class_imports(referenced)
        source += ['', '@implementation %s' % base_name, '', '']
        source += ['- (Class)responseClass', '{', '    return [%s class];' % response, '}', '']
        source += ['- (int)impliedResponseSignature', '{', '    return %s;' % ('(int)0x%x' % implied if implied else '0'), '}', '']
        source += ['- (int)layerVersion', '{', '    return 228;', '}', '']
        source += render_abstract_methods() + ['@end', '']
        source += render_concrete_implementation(class_name, base_name, method, fields)
        self.write(os.path.join(self.classes_dir, base_name + '.h'), header)
        self.write(os.path.join(self.classes_dir, base_name + '.mm'), source)
        self.registered.append(class_name)
        return base_name

    def generate_constructor(self, constructor):
        base_name = class_for_type(constructor['result'])
        class_name = '%s$%s' % (base_name, constructor['name'].replace('.', '_'))
        fields = stored_fields(constructor)
        referenced = [field['referenced'] for field in fields if field['referenced']]
        header_path = os.path.join(self.classes_dir, base_name + '.h')
        source_path = os.path.join(self.classes_dir, base_name + '.mm')
        if os.path.exists(header_path):
            self.update_constructor(header_path, source_path, base_name, class_name, constructor, fields, referenced)
        else:
            self.create_type(header_path, source_path, base_name, class_name, constructor, fields, referenced)
        self.registered.append(class_name)
        return base_name

    def create_type(self, header_path, source_path, base_name, class_name, constructor, fields, referenced):
        single = len(self.types[constructor['result']]) == 1
        declarations = [field['declaration'] for field in fields]
        header = header_prologue(base_name) + self.class_declarations(referenced)
        header += ['', '@interface %s : NSObject <TLObject>' % base_name, '']
        header += declarations if single else []
        header += ['', '@end', '', '@interface %s : %s' % (class_name, base_name), '']
        header += [] if single else declarations
        header += ['', '@end', '', '#endif', '']
        source = source_prologue(base_name) + self.class_imports(referenced)
        source += ['', '@implementation %s' % base_name, '', '']
        source += render_abstract_methods() + ['@end', '']
        source += render_concrete_implementation(class_name, base_name, constructor, fields)
        self.write(header_path, header)
        self.write(source_path, source)

    def update_constructor(self, header_path, source_path, base_name, class_name, constructor, fields, referenced):
        with open(header_path, 'r', encoding='utf-8') as handle:
            header = handle.read()
        with open(source_path, 'r', encoding='utf-8') as handle:
            source = handle.read()
        base_block = re.search(r'@interface %s : NSObject <TLObject>\n(.*?)@end\n' % re.escape(base_name), header, re.S)
        if base_block is None:
            raise GeneratorError('%s has no base interface' % header_path)
        inherited = set(re.findall(r'@property \([^)]*\) [A-Za-z0-9_]+ \*?(\w+);', base_block.group(1)))
        own = [field['declaration'] for field in fields if field['property'] not in inherited]
        interface = '@interface %s : %s\n\n%s\n@end\n' % (class_name, base_name, '\n'.join(own) + '\n' if own else '')
        pattern = re.compile(r'@interface %s : %s\n.*?@end\n' % (re.escape(class_name), re.escape(base_name)), re.S)
        if pattern.search(header):
            header = pattern.sub(lambda _: interface, header, count=1)
        else:
            header = header.replace('\n#endif', '\n' + interface + '\n#endif', 1)
        missing_classes = [line for line in self.class_declarations(referenced) if line not in header]
        if missing_classes:
            anchor = header.index('\n@interface ')
            prefix = header[:anchor].rstrip('\n')
            separator = '\n' if prefix.rsplit('\n', 1)[-1].startswith('@class ') else '\n\n'
            header = prefix + separator + '\n'.join(missing_classes) + '\n\n' + header[anchor:].lstrip('\n')
        implementation = '\n'.join(render_concrete_implementation(class_name, base_name, constructor, fields))
        pattern = re.compile(r'@implementation %s : %s\n.*?@end\n' % (re.escape(class_name), re.escape(base_name)), re.S)
        if pattern.search(source):
            source = pattern.sub(lambda _: implementation, source, count=1)
        else:
            source = source.rstrip('\n') + '\n\n' + implementation
        missing_imports = [line for line in self.class_imports(referenced) if line not in source]
        if missing_imports:
            anchor = source.index('\n@implementation ')
            prefix = source[:anchor].rstrip('\n')
            separator = '\n\n' if prefix.rsplit('\n', 1)[-1].startswith('#import "../') else '\n'
            source = prefix + separator + '\n'.join(missing_imports) + '\n\n' + source[anchor:].lstrip('\n')
        with open(header_path, 'w', encoding='utf-8') as handle:
            handle.write(header)
        with open(source_path, 'w', encoding='utf-8') as handle:
            handle.write(source)

    def generate(self, name):
        if name in self.methods:
            return self.generate_method(self.methods[name])
        if name in self.constructors:
            return self.generate_constructor(self.constructors[name])
        raise GeneratorError('%s is not defined in the schema' % name)


def update_scheme_headers(paths, base_names):
    for path in paths:
        with open(path, 'r', encoding='utf-8') as handle:
            text = handle.read()
        missing = ['#import "%s.h"' % name for name in base_names if '#import "%s.h"' % name not in text]
        if not missing:
            continue
        anchor = text.index('\n', text.rindex('#import "')) + 1
        text = text[:anchor] + '\n'.join(missing) + '\n' + text[anchor:]
        with open(path, 'w', encoding='utf-8') as handle:
            handle.write(text)


def update_registrations(path, classes_dir, class_names):
    with open(path, 'r', encoding='utf-8') as handle:
        text = handle.read()
    prefix, _ = class_table.split_registration_source(text)
    missing = [REGISTER_LINE % name for name in class_names if REGISTER_LINE % name not in prefix]
    if missing:
        end = prefix.rindex('\n}\n')
        prefix = prefix[:end + 1] + ''.join(missing) + prefix[end + 1:]
    _, body = class_table.split_registration_source(prefix)
    registrations = class_table.REGISTRATION.findall(body)
    implementations = class_table.load_implementations(classes_dir)
    object_entries = class_table.build_entries(registrations, implementations, 'registerObjectClass', 'TLconstructorName')
    vector_entries = class_table.build_entries(registrations, implementations, 'registerVectorClass', 'TLconstructorSignature')
    with open(path, 'w', encoding='utf-8') as handle:
        handle.write(class_table.render(prefix, object_entries, vector_entries))


def project_identifier(existing, seed):
    counter = 0
    while True:
        value = hashlib.md5(('onegram-tl:%s:%d' % (seed, counter)).encode('utf-8')).hexdigest()[:24].upper()
        if value not in existing:
            existing.add(value)
            return value
        counter += 1


def update_project(path, anchor, base_names):
    with open(path, 'r', encoding='utf-8') as handle:
        text = handle.read()
    existing = set(re.findall(r'\b([0-9A-F]{24})\b', text))
    for name in base_names:
        for extension in ('.h', '.mm'):
            file_name = name + extension
            if '/* %s */ = {isa = PBXFileReference' % file_name in text:
                continue
            anchor_name = anchor + extension
            reference = re.search(r'([0-9A-F]{24}) /\* %s \*/ = \{isa = PBXFileReference' % re.escape(anchor_name), text)
            if reference is None:
                raise GeneratorError('anchor %s is not in the project' % anchor_name)
            identifiers = {reference.group(1): project_identifier(existing, file_name)}
            for build in re.finditer(r'([0-9A-F]{24}) /\* %s in (\w+) \*/ = \{isa = PBXBuildFile' % re.escape(anchor_name), text):
                identifiers[build.group(1)] = project_identifier(existing, '%s:%s' % (file_name, build.group(2)))
            result = []
            for line in text.split('\n'):
                result.append(line)
                if any(identifier in line for identifier in identifiers):
                    duplicate = line
                    for old, new in identifiers.items():
                        duplicate = duplicate.replace(old, new)
                    result.append(duplicate.replace(anchor_name, file_name))
            text = '\n'.join(result)
    with open(path, 'w', encoding='utf-8') as handle:
        handle.write(text)


def main():
    parser = argparse.ArgumentParser(description='Generate legacy TL classes for constructors and methods of the current API schema.')
    parser.add_argument('--schema', required=True, help='api.tl of the target layer')
    parser.add_argument('--classes', required=True, help='directory with the generated TL classes')
    parser.add_argument('--scheme-source', required=True, help='TLMetaScheme.mm containing TLRegisterClasses()')
    parser.add_argument('--scheme-header', action='append', required=True, help='TLMetaScheme.h umbrella headers')
    parser.add_argument('--project', required=True, help='project.pbxproj that builds the TL classes')
    parser.add_argument('--anchor', required=True, help='existing TL class whose project entries new files mirror')
    parser.add_argument('names', nargs='+', help='schema constructor or method names')
    arguments = parser.parse_args()
    generator = Generator(arguments.schema, arguments.classes)
    base_names = []
    for name in arguments.names:
        base_name = generator.generate(name)
        if base_name not in base_names:
            base_names.append(base_name)
    update_scheme_headers(arguments.scheme_header, base_names)
    update_registrations(arguments.scheme_source, arguments.classes, generator.registered)
    update_project(arguments.project, arguments.anchor, base_names)
    sys.stderr.write('generated=%d created=%s\n' % (len(arguments.names), ','.join(generator.created) or '-'))


if __name__ == '__main__':
    try:
        main()
    except GeneratorError as error:
        sys.stderr.write('error: %s\n' % error)
        sys.exit(1)
