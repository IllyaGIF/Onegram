#!/usr/bin/env python3
import sys
import argparse
import os
import json
import re
import subprocess
import struct
import fnmatch
from pathlib import Path
from generate import OUT

def macho_exports(data):
    if data[:4] != b'\xce\xfa\xed\xfe':
        raise ValueError('Expected a thin 32-bit Mach-O executable')
    position = 28
    offset = size = 0
    for _ in range(struct.unpack_from('<I', data, 16)[0]):
        command, command_size = struct.unpack_from('<II', data, position)
        if command in (0x22, 0x80000022):
            offset, size = struct.unpack_from('<II', data, position + 40)
        elif command == 0x80000033:
            offset, size = struct.unpack_from('<II', data, position + 8)
        position += command_size
    if size == 0 or offset + size > len(data):
        raise ValueError('Missing Mach-O exports trie')
    trie = data[offset:offset + size]

    def uleb(position):
        value = shift = 0
        while position < len(trie) and shift < 64:
            byte = trie[position]
            position += 1
            value |= (byte & 0x7f) << shift
            if byte < 0x80:
                return value, position
            shift += 7
        raise ValueError('Invalid Mach-O exports trie integer')

    exports = set()

    def visit(position, prefix, ancestors):
        if position in ancestors or position >= len(trie):
            raise ValueError('Invalid Mach-O exports trie node')
        ancestors = ancestors | {position}
        terminal_size, position = uleb(position)
        if terminal_size:
            exports.add(prefix)
        position += terminal_size
        child_count = trie[position]
        position += 1
        for _ in range(child_count):
            end = trie.index(0, position)
            edge = trie[position:end].decode('utf-8')
            child, position = uleb(end + 1)
            visit(child, prefix + edge, ancestors)

    visit(0, '', set())
    return exports

def verify_armv6_runtime(data, definitions):
    private_list = Path(__file__).resolve().parents[1] / 'compat/ios3/OnegramRuntimePrivateSymbols.txt'
    patterns = private_list.read_text().splitlines()
    exports = macho_exports(data)
    leaked = sorted(name for name in exports if any(fnmatch.fnmatchcase(name, pattern) for pattern in patterns))
    if leaked:
        raise ValueError('ARMv6 compatibility runtime exports system symbols: ' + ', '.join(leaked))
    native_classes = {'__NSStackBlock__', '__NSMallocBlock__', '__NSAutoBlock__', '__NSFinalizingBlock__',
                      '__NSGlobalBlock__', '__NSBlockVariable__', 'NSBlockOperation', 'NSUUID',
                      'NSJSONSerialization', 'UIPopoverController', 'UIPopoverBackgroundView'}
    collisions = sorted(name for name in native_classes if '_OBJC_CLASS_$_' + name in definitions)
    if collisions:
        raise ValueError('ARMv6 application redefines native classes: ' + ', '.join(collisions))
    required = {'OnegramIOS3StackBlock', 'OnegramIOS3MallocBlock', 'OnegramIOS3GlobalBlock',
                'OnegramIOS3BlockOperation', 'OnegramIOS3PopoverController'}
    missing = sorted(name for name in required if '_OBJC_CLASS_$_' + name not in definitions)
    if missing:
        raise ValueError('Missing ARMv6 compatibility classes: ' + ', '.join(missing))
    return exports

def main():
    p=argparse.ArgumentParser()
    p.add_argument('binary',type=Path)
    p.add_argument('--reference',type=Path)
    host='macos' if sys.platform=='darwin' else 'linux'
    p.add_argument('--tools',type=Path,default=Path(os.environ.get('THEOS',str(Path.home()/'theos')))/('toolchain/'+host+'/iphone/bin'))
    args=p.parse_args()
    if not args.binary.is_file():raise SystemExit('Theos executable does not exist: '+str(args.binary))
    reports=OUT/'verification'
    reports.mkdir(parents=True,exist_ok=True)
    def inspect(path,label):
        result={}
        for tool,flags in [('file',[]),('lipo',['-info']),('otool',['-L']),('otool',['-l']),('nm',[]),('size',[])]:
            if tool == 'file':
                command='file'
            else:
                command=str(args.tools/tool)
            cmd=[command]+flags+[str(path)]
            output=subprocess.run(cmd,check=True,capture_output=True,text=True).stdout
            key=tool+''.join(flags)
            result[key]=output
            (reports/(label+'-'+key+'.txt')).write_text(output)
        return result
    actual=inspect(args.binary,'theos')
    print(actual['file']+actual['lipo-info'])
    arch=os.environ.get('ONEGRAM_ARCH','armv7')
    if 'Non-fat file:' not in actual['lipo-info'] or 'architecture: '+arch not in actual['lipo-info']:
        raise SystemExit('Expected a thin '+arch+' executable')
    minimum={'armv6':r'3\.1\.3','armv7':r'4\.3','arm64':r'7\.0'}[arch]
    sdk={'armv6':r'3\.1\.3','armv7':r'7\.0','arm64':r'11\.2'}[arch]
    if not re.search(r'LC_VERSION_MIN_IPHONEOS\s+cmdsize 16\s+version '+minimum+r'\s+sdk '+sdk,actual['otool-l']):
        raise SystemExit('Deployment or SDK marker differs from legacy Xcode output')
    if arch == 'armv6':
        definitions = {line.split()[-1] for line in actual['nm'].splitlines()
                       if len(line.split()) >= 3 and line.split()[-2] != 'U'}
        exports = verify_armv6_runtime(args.binary.read_bytes(), definitions)
        (reports / 'theos-exports.txt').write_text('\n'.join(sorted(exports)) + '\n')
        print('ARMv6 compatibility runtime isolation: OK')
    if arch == 'arm64':
        native_classes = {'NSURLSession', 'NSURLSessionConfiguration', 'NSURLSessionTask',
                          'NSURLSessionDataTask', 'WKWebView', 'WKWebViewConfiguration',
                          'PHAsset', 'PHImageManager', 'PHPhotoLibrary', 'CNContactFormatter',
                          'CNMutableContact', 'UIImpactFeedbackGenerator'}
        definitions = {line.split()[-1] for line in actual['nm'].splitlines()
                       if len(line.split()) >= 3 and line.split()[-2] != 'U'}
        collisions = sorted(name for name in native_classes if '_OBJC_CLASS_$_' + name in definitions)
        if collisions:
            raise SystemExit('Application redefines native classes: ' + ', '.join(collisions))
        if '/usr/lib/libstdc++.6.dylib' not in actual['otool-L'] or '/usr/lib/libc++.' in actual['otool-L']:
            raise SystemExit('Unexpected arm64 C++ runtime')
        print('Native class definitions and libstdc++: OK')
    if args.reference:
        reference=inspect(args.reference,'reference')
        def libraries(report):return {line.strip() for line in report['otool-L'].splitlines()[1:]}
        print('Additional link commands:',sorted(libraries(actual)-libraries(reference)))
        print('Missing link commands:',sorted(libraries(reference)-libraries(actual)))
    print('Reports: '+str(reports))

if __name__=='__main__':main()
