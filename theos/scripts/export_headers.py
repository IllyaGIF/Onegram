#!/usr/bin/env python3
import json
import sys
from generate import OUT, source_link
from xcode_graph import ROOT, actual_path

target=next(t for t in json.loads((OUT/'manifest.json').read_text())['targets'] if t['instance']==sys.argv[1])
for phase in target['phases']:
    if phase['type']!='PBXCopyFilesBuildPhase':continue
    if phase.get('dstSubfolderSpec')!='16' or not phase.get('dstPath','').startswith('include/'):
        raise SystemExit('Unsupported copy phase: '+phase['id'])
    for entry in phase['entries']:
        if not entry['path']:continue
        source=actual_path(ROOT/entry['path'])
        if not source.exists():raise FileNotFoundError(source)
        dest=OUT/'products'/phase['dstPath']/source.name
        source_link(dest, source, replace_generated=True)
