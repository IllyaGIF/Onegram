#!/usr/bin/env python3
"""Compare current Xcode inputs, persisted manifest, and actual Theos FILES."""
import json
import hashlib
import shlex
import sys
from pathlib import Path
from generate import OUT, entries, effective_sources, selected_targets
from xcode_graph import ROOT, actual_path, graph

def audit():
    manifest = json.loads((OUT/'manifest.json').read_text())
    targets = selected_targets(graph(manifest['configuration']))
    errors = []
    counts = dict(sources=0, resources=0, frameworks=0, flags=0)
    for path,digest in manifest.get('header_maps',{}).items():
        file=OUT/path
        if not file.is_file() or hashlib.sha256(file.read_bytes()).hexdigest()!=digest:
            errors.append('Modified/missing header map: '+path)
    for target in targets:
        saved = next(t for t in manifest['targets'] if t['id']==target['id'])
        expected = {'sources':effective_sources(target), 'resources':entries(target,'PBXResourcesBuildPhase'),
                    'frameworks':entries(target,'PBXFrameworksBuildPhase')}
        for category, values in expected.items():
            for e in values:
                if e not in saved[category]:
                    counts[category] += 1
                    errors.append(f'{target["name"]}: missing/changed {category}: {e["path"]}')
            if any(e not in values for e in saved[category]):errors.append('Unexpected '+category+' in '+target['name'])
        if saved['settings']!=target['settings'] or saved['phases']!=target['phases']:
            errors.append('Stale settings/phases: '+target['name'])
        text=(OUT/(saved['instance']+'.mk')).read_text()
        if hashlib.sha256(text.encode()).hexdigest()!=saved['make_sha256']:
            errors.append('Generated Makefile was modified: '+saved['instance'])
        files=text.replace('\\\n','').splitlines()
        source_line=next(line for line in files if line.startswith(saved['instance']+'_FILES ='))
        actual = [(ROOT/'theos'/p).resolve() for p in shlex.split(source_line.split('=',1)[1])]
        wanted = [actual_path(ROOT/e['path']).resolve() for e in expected['sources']]
        if actual != wanted:
            errors.append('Theos FILES differs: '+target['name'])
            counts['sources']+=len(set(wanted)-set(actual))
        original_names=shlex.split(source_line.split('=',1)[1])
        for entry,path,original in zip(expected['sources'],actual,original_names):
            if not path.is_file():errors.append('Missing source on disk: '+str(path.relative_to(ROOT)))
            flag=entry['settings'].get('COMPILER_FLAGS')
            local_line=next((line for line in files if line.startswith(original+'_CFLAGS =')), '')
            actual_flags=shlex.split(local_line.split('=',1)[1]) if local_line else []
            wanted_flags=shlex.split(flag or '')
            if wanted_flags and actual_flags[-len(wanted_flags):]!=wanted_flags:
                counts['flags']+=1
                errors.append('Missing per-file flags: '+entry['path'])
            if path.suffix in ('.m','.mm'):
                arc=[f for f in actual_flags if f in ('-fobjc-arc','-fno-objc-arc')]
                wanted_arc=[f for f in wanted_flags if f in ('-fobjc-arc','-fno-objc-arc')]
                default='-fobjc-arc' if target['settings'].get('CLANG_ENABLE_OBJC_ARC')=='YES' else '-fno-objc-arc'
                if not arc or arc[-1]!=(wanted_arc[-1] if wanted_arc else default):
                    errors.append('Incorrect ARC mode: '+entry['path'])
        for e in expected['resources']:
            if e['path'] and not actual_path(ROOT/e['path']).exists():
                errors.append('Missing resource on disk: '+e['path'])
        print(f'{target["name"]}: {len(wanted)} sources, {len(expected["resources"])} resource records')
    for key,val in counts.items():print(f'Missing {key}: {val}')
    for error in errors:print('ERROR: '+error)
    print('Coverage audit does not certify compilation, resource processing, or binary parity.')
    return 1 if errors else 0

if __name__=='__main__':sys.exit(audit())
