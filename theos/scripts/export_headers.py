#!/usr/bin/env python3
"""Execute explicit Xcode copy phases for static-library header products."""
import json
import os
import sys
from generate import OUT
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
        dest.parent.mkdir(parents=True,exist_ok=True)
        if not dest.exists():dest.symlink_to(os.path.relpath(source,dest.parent))
