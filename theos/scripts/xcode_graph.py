#!/usr/bin/env python3
"""Read OpenStep project files without third party dependencies."""
import fnmatch
import os
from functools import lru_cache
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOKEN = re.compile(r'\s+|/\*.*?\*/|//[^\n]*|"(?:\\.|[^"\\])*"|[{}()=;,]|[^\s{}()=;,]+', re.S)

def parse(path):
    return parse_text(path.read_text())

def parse_text(text, allow_duplicates=False):
    tokens = [m.group() for m in TOKEN.finditer(text)
              if not m.group().isspace() and not m.group().startswith(('/*', '//'))]
    pos = 0
    def take():
        nonlocal pos
        value = tokens[pos]
        pos += 1
        return value
    def value():
        token = take()
        if token == '{':
            result = {}
            while tokens[pos] != '}':
                key = value()
                assert take() == '='
                assert allow_duplicates or key not in result, key
                result[key] = value()
                assert take() == ';'
            take()
            return result
        if token == '(':
            result = []
            while tokens[pos] != ')':
                result.append(value())
                if tokens[pos] == ',':
                    take()
            take()
            return result
        if token.startswith('"'):
            def escape(m):
                s=m[1]
                if s.startswith('U') and len(s)==5:return chr(int(s[1:],16))
                if s[0] in '01234567':return chr(int(s,8))
                return {'n':'\n','r':'\r','t':'\t'}.get(s,s)
            result=re.sub(r'\\(U[0-9a-fA-F]{4}|[0-7]{1,3}|.)',escape,token[1:-1])
            return result.encode('utf-16','surrogatepass').decode('utf-16','surrogatepass')
        return token
    result = value()
    assert pos == len(tokens)
    return result

def xcconfig(path, inherited=None):
    result = dict(inherited or {})
    for line in path.read_text().splitlines():
        line = line.strip()
        if line.startswith('#include'):
            result.update(xcconfig(path.parent / re.search(r'"(.*?)"', line)[1], result))
        elif line and not line.startswith('//') and '=' in line:
            key, val = line.split('=', 1)
            key = key.strip()
            result[key] = val.strip().replace('$(inherited)', result.get(key, ''))
    return result

def string(value):
    return ' '.join(value) if isinstance(value, list) else value

@lru_cache(maxsize=None)
def actual_path(path):
    """Resolve a unique case-insensitive path as on a legacy Mac volume."""
    path = Path(path)
    if path.exists():
        return path
    current = Path(path.anchor) if path.is_absolute() else Path('.')
    for part in path.parts[1:] if path.is_absolute() else path.parts:
        candidate = current / part
        if not candidate.exists() and current.is_dir():
            matches = [p for p in current.iterdir() if p.name.casefold() == part.casefold()]
            if len(matches) == 1:
                candidate = matches[0]
        current = candidate
    return current

class Project:
    def __init__(self, path):
        self.path = path
        self.root = path.parent.parent
        self.data = parse(path)
        self.objects = self.data['objects']
        self.project = self.objects[self.data['rootObject']]
        self.parents = {}
        for key, obj in self.objects.items():
            for child in obj.get('children', []):
                self.parents[child] = key

    def ref(self, key):
        obj = self.objects[key]
        tree = obj.get('sourceTree', '<group>')
        path = obj.get('path', '')
        if tree == '<group>':
            parent = self.parents.get(key)
            prefix = self.ref(parent) if parent else str(self.root)
        elif tree == 'SOURCE_ROOT':
            prefix = str(self.root)
        elif tree == '<absolute>':
            prefix = ''
        else:
            prefix = '$(' + tree + ')'
        return str(Path(prefix) / path) if path else prefix

    def configuration(self, obj, name):
        configs = self.objects[obj['buildConfigurationList']]
        return next(self.objects[k] for k in configs['buildConfigurations'] if self.objects[k]['name'] == name)

    def settings(self, target, name):
        result = {}
        for obj in (self.project, target):
            cfg = self.configuration(obj, name)
            layers = []
            if cfg.get('baseConfigurationReference'):
                layers.append(xcconfig(Path(self.ref(cfg['baseConfigurationReference'])), result))
            layers.append(cfg['buildSettings'])
            for layer in layers:
                for key, val in layer.items():
                    result[key] = string(val).replace('$(inherited)', result.get(key, ''))
        for key in list(result):
            if '[' in key:
                base, conditions = key.split('[', 1)
                if all(fnmatch.fnmatch({'arch':os.environ.get('ONEGRAM_ARCH','armv7'),'sdk':'iphoneos'+os.environ.get('ONEGRAM_SDK_VERSION','6.1'),'config':name}.get(k,''),v)
                       for k,v in re.findall(r'(\w+)=([^\]]+)', '['+conditions)):
                    result[base] = result[key]
        if os.environ.get('ONEGRAM_ARCH') == 'arm64':
            result['IPHONEOS_DEPLOYMENT_TARGET'] = '7.0'
            result['ARCHS'] = 'arm64'
            result['VALID_ARCHS'] = 'arm64'
        return result

    def target(self, key, name):
        obj = self.objects[key]
        settings = self.settings(obj, name)
        phases = []
        for phase_id in obj['buildPhases']:
            phase = self.objects[phase_id]
            entries = []
            for build_id in phase.get('files', []):
                build = self.objects[build_id]
                ref = build.get('fileRef', build.get('productRef'))
                if ref is None:
                    entries.append({'id':build_id, 'path':None, 'settings':build.get('settings', {}), 'type':'dangling'})
                    continue
                file = self.objects[ref]
                paths = [self.ref(c) for c in file['children']] if file['isa'] == 'PBXVariantGroup' else [self.ref(ref)]
                for path in paths:
                    entries.append({'id': build_id, 'path':path.replace(str(ROOT) + '/', ''),
                                    'settings':build.get('settings', {}), 'type':file.get('lastKnownFileType', file.get('explicitFileType',''))})
            phases.append({'id':phase_id, 'type':phase['isa'], 'entries':entries,
                           **{k:v for k,v in phase.items() if k not in ('isa','files')}})
        return {'id':key, 'name':obj['name'], 'project':str(self.path.relative_to(ROOT)),
                'product': self.ref(obj['productReference']), 'settings':settings,
                'dependencies':[self.objects[d] for d in obj.get('dependencies',[])], 'phases':phases}

def graph(configuration='Release Hockeyapp'):
    projects = [Project(ROOT / 'Telegraph.xcodeproj/project.pbxproj')]
    main = projects[0]
    for obj in main.objects.values():
        if obj.get('lastKnownFileType') == 'wrapper.pb-project':
            path = Path(main.ref(next(k for k,v in main.objects.items() if v is obj))) / 'project.pbxproj'
            if path.exists():
                projects.append(Project(path))
    result = []
    for project in projects:
        for key in project.project['targets']:
            target = project.objects[key]
            configs = project.objects[target['buildConfigurationList']]
            names = [project.objects[c]['name'] for c in configs['buildConfigurations']]
            chosen = configuration if configuration in names else configs['defaultConfigurationName']
            result.append(project.target(key, chosen))
    return {'configuration':configuration, 'targets':result}

if __name__ == '__main__':
    print(json.dumps(graph(), indent=2, sort_keys=True))
