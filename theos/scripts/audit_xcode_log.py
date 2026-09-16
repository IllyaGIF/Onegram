#!/usr/bin/env python3
"""Compare observed Xcode commands with the extracted graph, without pruning it."""
import argparse
import collections
import json
import re
import shlex
from pathlib import Path
from generate import OUT


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('log', type=Path)
    args = parser.parse_args()
    text = args.log.read_text()
    commands = []
    link = None
    for line in text.splitlines():
        if not line.lstrip().startswith('/Applications/'):
            continue
        if ' -c ' not in line and ' -filelist ' not in line:
            continue
        words = shlex.split(line)
        if '-c' in words and '-o' in words:
            source = words[words.index('-c') + 1]
            output = words[words.index('-o') + 1]
            target = re.search(r'/([^/]+)\.build/Objects-normal/', output)
            if target:
                commands.append(dict(target=target[1], source=source.replace('/Users/user/Desktop/Onegram/', ''),
                                     output=output, arch=words[words.index('-arch') + 1], command=words))
        if '-o' in words and words[words.index('-o') + 1].endswith('/Telegram.app/Telegram'):
            link = words
    if link is None:
        raise SystemExit('No final Telegram linker command found')
    manifest = json.loads((OUT / 'manifest.json').read_text())
    comparisons = []
    for target in manifest['targets']:
        expected = {entry['path'] for entry in target['sources']}
        observed = {entry['source'] for entry in commands if entry['target'] == target['name'] and entry['arch'] == 'armv7'}
        comparisons.append(dict(target=target['name'], expected=len(expected), observed=len(observed),
                                not_observed=sorted(expected - observed), additional=sorted(observed - expected)))
    ordered_inputs = []
    for i, word in enumerate(link):
        if word in ('-framework', '-weak_framework', '-force_load'):
            ordered_inputs.append([word, link[i + 1]])
        elif word in ('-ObjC', '-all_load', '-dead_strip') or word.startswith(('-l', '-weak-l')):
            ordered_inputs.append([word])
        elif word.endswith('.a') and link[i - 1] != '-force_load':
            ordered_inputs.append([word])
    important = {'TGCommon.m', 'TGGenericPeerMediaGalleryModel.m', 'LegacyComponentsInternal.m'}
    report = dict(log=str(args.log), build_succeeded='** BUILD SUCCEEDED **' in text,
                  source_comparison=comparisons, ordered_link_inputs=ordered_inputs,
                  linker_command=link, file_list=link[link.index('-filelist') + 1],
                  important_compiles=[c for c in commands if Path(c['source']).name in important],
                  compile_counts=dict(collections.Counter(c['target'] + ':' + c['arch'] for c in commands)),
                  limitation='Compile commands establish observed source ownership. The referenced LinkFileList contents and reused archive members are not present in this log. Absence of a compile command is not evidence to exclude a source.')
    (OUT / 'xcode-log-comparison.json').write_text(json.dumps(report, indent=2) + '\n')
    for item in comparisons:
        print(f"{item['target']}: {item['observed']} observed armv7 compiles; {item['expected']} graph sources; {len(item['not_observed'])} not observed")
    for name in sorted(important):
        print(name + ': ' + ', '.join(c['target'] + '/' + c['arch'] for c in report['important_compiles'] if Path(c['source']).name == name))
    print(report['limitation'])


if __name__ == '__main__':
    main()
