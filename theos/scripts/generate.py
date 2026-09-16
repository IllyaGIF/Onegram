#!/usr/bin/env python3
import argparse
import fnmatch
import json
import hashlib
import os
import re
import shlex
import subprocess
from pathlib import Path
from xcode_graph import ROOT, Project, actual_path, graph
import sys

OUT = ROOT / 'theos' / os.environ.get('ONEGRAM_GENERATED_DIR','generated')
VARIABLE = re.compile(r'\$\(([^)]+)\)|\$\{([^}]+)\}')

def write(path, contents):
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists() or path.read_text() != contents:
        path.write_text(contents)

def expand(value, settings):
    for _ in range(30):
        updated = VARIABLE.sub(lambda m: settings.get(m[1] or m[2], m[0]), value)
        if updated == value:
            return value
        value = updated
    raise ValueError('Cyclic Xcode setting: ' + value)

def entries(target, phase):
    return [e for p in target['phases'] if p['type'] == phase for e in p['entries']]

def selected_targets(data):
    by_product = {t['product']:t for t in data['targets']}
    by_id = {t['id']:t for t in data['targets']}
    result = []
    def visit(t):
        if any(x['id'] == t['id'] for x in result):
            return
        project = Project(ROOT / t['project'])
        for dep in t['dependencies']:
            proxy = project.objects.get(dep.get('targetProxy'), {})
            visit(by_id[dep.get('target', proxy.get('remoteGlobalIDString'))])
        for entry in entries(t, 'PBXFrameworksBuildPhase'):
            if entry['path'] in by_product:
                visit(by_product[entry['path']])
        result.append(t)
    visit(next(t for t in data['targets'] if t['name'] == 'Telegraph'))
    return result

def effective_sources(target):
    patterns = shlex.split(target['settings'].get('EXCLUDED_SOURCE_FILE_NAMES', ''))
    sources = [e for e in entries(target, 'PBXSourcesBuildPhase') if e['path'] and
               not any(fnmatch.fnmatch(Path(e['path']).name, p) for p in patterns)]
    if os.environ.get('ONEGRAM_ARCH') == 'arm64' and target['name'] == 'libtgvoip':
        replacements = {'spl_sqrt_floor_arm.S':'spl_sqrt_floor.c',
                        'complex_bit_reverse_arm.S':'complex_bit_reverse.c',
                        'filter_ar_fast_q12_armv7.S':'filter_ar_fast_q12.c'}
        for entry in sources:
            if Path(entry['path']).name in replacements:
                replacement=str(Path(entry['path']).with_name(replacements[Path(entry['path']).name]))
                assert any(e['path']==replacement for e in sources), replacement
        sources=[e for e in sources if Path(e['path']).name not in replacements]
    return sources

def shell_flags(flags):
    return ' '.join(shlex.quote(x).replace('$', '$$').replace('#', r'\#') for x in flags)

def generate(configuration):
    data = graph(configuration)
    targets = selected_targets(data)
    write(OUT/'xcode-graph.json', json.dumps(data, indent=2, sort_keys=True)+'\n')
    manifest = {'configuration':configuration, 'targets':[], 'case_aliases':[]}
    namespace_map = {}
    sdk=Path(os.environ.get('THEOS',str(Path.home()/'theos')))/('sdks/iPhoneOS'+os.environ.get('ONEGRAM_SDK_VERSION','6.1')+'.sdk')
    sdk_frameworks={p.stem.casefold():p for p in (sdk/'System/Library/Frameworks').glob('*.framework')}
    for t in targets:
        name = 'Telegram' if t['name'] == 'Telegraph' else Path(t['product']).stem
        project_dir = str((ROOT/t['project']).parent.parent)
        settings = dict(t['settings'], SRCROOT=project_dir, PROJECT_DIR=project_dir,
                        BUILT_PRODUCTS_DIR=str(OUT/'products'), CONFIGURATION_BUILD_DIR=str(OUT/'products'),
                        TARGET_BUILD_DIR=str(OUT/'products'), BUILD_ROOT=str(OUT/'build'),
                        CONFIGURATION=configuration, EXECUTABLE_NAME='Telegram', PRODUCT_NAME=t['settings']['PRODUCT_NAME'])
        settings.update(SDKROOT='@SDKROOT@', DT_TOOLCHAIN_DIR='@TOOLCHAIN@',
                        DEVELOPER_FRAMEWORKS_DIR='@DEVELOPER_FRAMEWORKS@', USER_LIBRARY_DIR='@USER_LIBRARY@')
        def tokens(key):
            value=expand(t['settings'].get(key, ''), settings)
            value=value.replace('/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain', '@TOOLCHAIN@')
            if VARIABLE.search(value):raise ValueError('Unresolved '+key+': '+value)
            return shlex.split(value)
        def paths(key):
            result = []
            for p in tokens(key):
                if not p.startswith(('/', '@')):
                    p = str(Path(project_dir)/p)
                if p.endswith('/**'):
                    base = actual_path(p[:-3])
                    result.append(str(base))
                    if base.is_dir():
                        result.extend(str(x) for x in sorted(base.rglob('*')) if x.is_dir())
                else:
                    result.append(str(actual_path(p)))
            return result
        sources = effective_sources(t)
        lines = [name+'_FILES = \\']
        resolved = []
        source_includes = {}
        for i,e in enumerate(sources):
            path = actual_path(ROOT/e['path'])
            rel = os.path.relpath(path, ROOT/'theos')
            if any(c in rel for c in '$#;()&'):
                alias=OUT/'source-files'/(hashlib.sha256(e['path'].encode()).hexdigest()[:16]+path.suffix)
                alias.parent.mkdir(parents=True,exist_ok=True)
                if not alias.exists():alias.symlink_to(os.path.relpath(path,alias.parent))
                rel=str(alias.relative_to(ROOT/'theos'))
                source_includes[rel]=str(path.parent)
            elif any(c.isspace() for c in rel):
                alias = OUT/'source-dirs'/hashlib.sha256(str(path.parent.relative_to(ROOT)).encode()).hexdigest()[:12]
                alias.parent.mkdir(parents=True,exist_ok=True)
                if not alias.exists(): alias.symlink_to(os.path.relpath(path.parent,alias.parent),target_is_directory=True)
                rel = str((alias/path.name).relative_to(ROOT/'theos'))
            if path != ROOT/e['path']:
                manifest['case_aliases'].append({'xcode':e['path'],'actual':str(path.relative_to(ROOT))})
            resolved.append((e,rel))
            lines.append('  '+rel+(' \\' if i+1<len(sources) else ''))
        flags = tokens('OTHER_CFLAGS') + tokens('WARNING_CFLAGS')
        if os.environ.get('ONEGRAM_ARCH') == 'arm64':
            flags += ['-DOS_OBJECT_USE_OBJC=0','-I'+str(OUT/'dependency-sources/openssl-OpenSSL_1_0_2h/include')]
        flags += ['-D'+d for d in tokens('GCC_PREPROCESSOR_DEFINITIONS')]
        flags += ['-I'+p for p in paths('HEADER_SEARCH_PATHS')]
        flags += ['-iquote'+p for p in paths('USER_HEADER_SEARCH_PATHS')]
        flags += ['-F'+p for p in paths('FRAMEWORK_SEARCH_PATHS')]
        flags += ['-I'+str(OUT/'headers'/(name+'.hmap')), '-I'+str(OUT/'headers/namespaces.hmap')]
        if t['settings'].get('GCC_NO_COMMON_BLOCKS') == 'YES': flags += ['-fno-common']
        if t['settings'].get('GCC_SYMBOLS_PRIVATE_EXTERN') == 'YES': flags += ['-fvisibility=hidden']
        if t['settings'].get('GCC_THUMB_SUPPORT') == 'NO' and os.environ.get('ONEGRAM_ARCH','armv7') == 'armv7': flags += ['-marm']
        if t['settings'].get('GCC_GENERATE_DEBUGGING_SYMBOLS') == 'NO': flags += ['-g0']
        if t['settings'].get('GCC_PREFIX_HEADER'):
            prefix = expand(t['settings']['GCC_PREFIX_HEADER'], settings)
            if not prefix.startswith('/'): prefix = str(Path(project_dir)/prefix)
            flags += ['-include',prefix]
        for e,rel in resolved:
            ext = Path(rel).suffix
            local = []
            if rel in source_includes:local += ['-iquote'+source_includes[rel]]
            if ext in ('.m','.mm'):
                local += ['-fobjc-arc' if t['settings'].get('CLANG_ENABLE_OBJC_ARC') == 'YES' else '-fno-objc-arc']
            if ext in ('.c','.m'):
                local += ['-std='+t['settings'].get('GCC_C_LANGUAGE_STANDARD','gnu99')]
            if ext in ('.cc','.cpp','.cxx','.mm'):
                local += ['-std='+t['settings'].get('CLANG_CXX_LANGUAGE_STANDARD','gnu++98'),
                          '-stdlib='+t['settings'].get('CLANG_CXX_LIBRARY','libstdc++')]
                if 'OTHER_CPLUSPLUSFLAGS' in t['settings']: local += tokens('OTHER_CPLUSPLUSFLAGS')
            local += shlex.split(e['settings'].get('COMPILER_FLAGS',''))
            lines.append(rel+'_CFLAGS = '+shell_flags(local))
        lines.append(name+'_CFLAGS = '+shell_flags(flags))
        lines.append(name+'_CCFLAGS = -stdlib='+t['settings'].get('CLANG_CXX_LIBRARY','libstdc++'))
        lines.append(name+'_OPTFLAG = -O'+t['settings'].get('GCC_OPTIMIZATION_LEVEL','s'))
        links = tokens('OTHER_LDFLAGS')
        links += ['-stdlib='+t['settings'].get('CLANG_CXX_LIBRARY','libstdc++')]
        if os.environ.get('ONEGRAM_ARCH') == 'arm64':
            archive='@TOOLCHAIN@/usr/lib/arc/libarclite_iphoneos.a'
            if archive in links:
                index=links.index(archive)
                assert links[index-1]=='-force_load'
                del links[index-1:index+1]
        if t['settings'].get('DEAD_CODE_STRIPPING') == 'YES' or (name == 'Telegram' and configuration == 'Release Hockeyapp' and 'DEAD_CODE_STRIPPING' not in t['settings']):
            links.insert(0, '-Wl,-dead_strip')
        if os.environ.get('ONEGRAM_ARCH') == 'arm64':
            links=[p.replace(str(ROOT/'thirdparty/TgVoipWebrtcIOS6/openssl-ios5/lib'),str(OUT/'products')).replace(str(ROOT/'thirdparty/PSTCollectionView/lib/libPSTCollectionView.a'),str(OUT/'products/libPSTCollectionView.a')) for p in links]
        if os.environ.get('ONEGRAM_ARCH') == 'arm64' and name == 'Telegram':
            links += ['-weak_framework', 'WebKit', '-weak_framework', 'PushKit']
        links += ['-L'+p for p in paths('LIBRARY_SEARCH_PATHS')]
        links += ['-F'+p for p in paths('FRAMEWORK_SEARCH_PATHS')]
        for p in tokens('LD_RUNPATH_SEARCH_PATHS'): links += ['-Wl,-rpath,'+p]
        frameworks, weak = [], []
        for e in entries(t,'PBXFrameworksBuildPhase'):
            if not e['path']: continue
            path = expand(e['path'],settings)
            is_weak = 'Weak' in e['settings'].get('ATTRIBUTES',[])
            if path.endswith('.framework'):
                (weak if is_weak else frameworks).append(Path(path).stem)
                links += ['-weak_framework' if is_weak else '-framework', Path(path).stem]
                if not path.startswith('@SDKROOT@'):
                    parent = str(Path(path).parent)
                    if not parent.startswith('/'): parent = str(ROOT/parent)
                    links += ['-F'+parent]
            elif path.startswith('@SDKROOT@/usr/lib/lib'):
                library = Path(path).name[3:].removesuffix('.dylib')
                links += ['-weak-l'+library if is_weak else '-l'+library]
            else:
                links += [path if path.startswith(('/', '@')) else str(ROOT/path)]
        lines += [name+'_FRAMEWORKS =',name+'_WEAK_FRAMEWORKS =',
                  name+'_LDFLAGS = '+shell_flags(links)]
        link_inputs=[p for p in links if p.endswith('.a')]
        for e in entries(t,'PBXFrameworksBuildPhase'):
            path=e['path'] or ''
            if path.endswith('.framework') and not path.startswith('$'):
                link_inputs.append(str(ROOT/path/Path(path).stem))
        lines.append(name+'_LINK_INPUTS = '+' '.join(link_inputs))
        content = '\n'.join(lines)+'\n'
        content = content.replace('@TOOLCHAIN@/usr/lib/arc/libarclite_iphoneos.a','$(XCODE_ARCLITE)')
        content = content.replace(str(ROOT), '$(ONEGRAM_ROOT)').replace('@SDKROOT@','$(ISYSROOT)').replace('@TOOLCHAIN@','$(XCODE_TOOLCHAIN_DIR)').replace('@DEVELOPER_FRAMEWORKS@','$(XCODE_DEVELOPER_FRAMEWORKS_DIR)').replace('@USER_LIBRARY@','$(XCODE_USER_LIBRARY_DIR)')
        write(OUT/(name+'.mk'),content)
        manifest['targets'].append({'name':t['name'], 'instance':name, 'id':t['id'],
                                   'make_sha256':hashlib.sha256(content.encode()).hexdigest(),
                                   'sources':sources, 'resources':entries(t,'PBXResourcesBuildPhase'),
                                   'frameworks':entries(t,'PBXFrameworksBuildPhase'),
                                   'headers':entries(t,'PBXHeadersBuildPhase'),
                                   'phases':t['phases'], 'settings':t['settings']})
        project = Project(ROOT/t['project'])
        header_map = {}
        refs = [project.ref(k) for k,o in project.objects.items()
                if o.get('path','').endswith(('.h','.hpp'))]
        refs += [str(ROOT/e['path']) for e in entries(t,'PBXHeadersBuildPhase') if e['path']]
        for ref in refs:
            path = actual_path(ref)
            if path.is_file():
                header_map[Path(ref).name] = str(path)
        for ref in refs + [str(ROOT/e['path']) for e in sources]:
            path=actual_path(ref)
            if not path.is_file():continue
            for spelling in re.findall(r'^\s*#\s*(?:import|include)\s*["<]([^">]+)[">]',path.read_text(errors='replace'),re.M):
                if '/' not in spelling:continue
                framework,header=spelling.split('/',1)
                framework_dir=sdk_frameworks.get(framework.casefold())
                if framework_dir:
                    requested=framework_dir.parent/(framework+'.framework')/'Headers'/header
                    real=actual_path(requested)
                    if not requested.exists() and real.is_file():header_map[spelling]=str(real)
                    continue
                candidate=path.parent/spelling
                resolved_header=actual_path(candidate)
                if not candidate.exists() and resolved_header.is_file():
                    header_map[spelling]=str(resolved_header.resolve())
        header_map['endian.h']=str(ROOT/'theos/compat/endian.h')
        namespace_aliases = {Path(ref).parent.name for ref in refs
                             if Path(ref).parent.name.casefold() == t['name'].casefold()}
        for e in entries(t,'PBXHeadersBuildPhase'):
            if not e['path']: continue
            path = actual_path(ROOT/e['path'])
            if not path.is_file(): continue
            namespaces = {t['name'], path.parent.name}
            namespaces.update(namespace_aliases)
            for namespace in namespaces:
                namespace_map[namespace+'/'+Path(e['path']).name] = str(path)
        for phase in t['phases']:
            if phase['type']!='PBXCopyFilesBuildPhase':continue
            if phase.get('dstSubfolderSpec')!='16' or not phase.get('dstPath','').startswith('include/'):
                raise ValueError('Unimplemented copy phase: '+str(phase))
            for e in phase['entries']:
                if not e['path']:continue
                source=actual_path(ROOT/e['path'])
                dest=OUT/'products'/phase['dstPath']/source.name
                dest.parent.mkdir(parents=True,exist_ok=True)
                if not dest.exists():dest.symlink_to(os.path.relpath(source,dest.parent))
        write(OUT/'headers'/(name+'.json'),json.dumps({'mappings':header_map},indent=2,sort_keys=True)+'\n')
    write(OUT/'headers/namespaces.json',json.dumps({'mappings':namespace_map},indent=2,sort_keys=True)+'\n')
    if sys.platform == 'darwin':
        hmaptool=Path('/usr/local/opt/llvm/bin/hmaptool')
    else:
        hmaptool=Path(os.environ.get('THEOS',str(Path.home()/'theos')))/'toolchain/linux/iphone/bin/hmaptool'
    for path in sorted((OUT/'headers').glob('*.json')):
        output=path.with_suffix('.hmap')
        temporary=path.with_suffix('.hmap.tmp')
        subprocess.run(['python3',str(hmaptool),'write',str(path),str(temporary)],check=True)
        if output.exists() and output.read_bytes()==temporary.read_bytes():temporary.unlink()
        else:temporary.replace(output)
    manifest['header_maps']={str(p.relative_to(OUT)):hashlib.sha256(p.read_bytes()).hexdigest()
                             for p in sorted((OUT/'headers').iterdir()) if p.is_file()}
    write(OUT/'manifest.json',json.dumps(manifest,indent=2,sort_keys=True)+'\n')
    libraries = [t['instance'] for t in manifest['targets'] if t['instance']!='Telegram']
    write(OUT/'dependencies.mk','XCODE_LIBRARIES = '+' '.join(libraries)+'\n')
    return manifest

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--configuration',default='Release Hockeyapp')
    args = parser.parse_args()
    result = generate(args.configuration)
    print('Generated '+str(len(result['targets']))+' complete targets')
