#!/usr/bin/env python3
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[2]
errors = []

def scan(directory, rules):
    for path in sorted(directory.rglob('*')):
        if path.suffix not in {'.h', '.m', '.mm'}:
            continue
        source = path.read_text(errors='ignore')
        for pattern, name in rules:
            match = pattern.search(source)
            if match is not None:
                line = source.count('\n', 0, match.start()) + 1
                errors.append(f"{path.relative_to(root)}:{line}: {name}")

scan(root / 'OnegramPlatform', [
    (re.compile(r'OnegramUI|OnegramUIBridge|Telegraph|LegacyComponents'), 'higher-layer dependency'),
    (re.compile(r'\bTG[A-Z][A-Za-z0-9_]*\b'), 'Telegram dependency'),
])

scan(root / 'OnegramUI', [
    (re.compile(r'OnegramUIBridge|Telegraph|LegacyComponents|SSignalKit|MtProtoKit'), 'application dependency'),
    (re.compile(r'\bTG[A-Z][A-Za-z0-9_]*\b'), 'Telegram dependency'),
    (re.compile(r'\bAVPlayer\b|\bAVCapture[A-Za-z0-9_]*\b'), 'AVFoundation backend'),
    (re.compile(r'\bCI(?:Image|Context|Color|Filter)\b'), 'Core Image backend'),
    (re.compile(r'\bNSLayoutConstraint\b'), 'Auto Layout'),
    (re.compile(r'\bUICollectionView\b'), 'UICollectionView'),
    (re.compile(r'\bUITextPosition\b|\bUITextRange\b'), 'modern text input API'),
])

scan(root / 'OnegramUIBridge', [
    (re.compile(r'#import\s+[<"][^\n">]*(?:Base|Chat|Chrome|Common|Info|Lists|Profile|Screens)/'), 'visual UI dependency'),
    (re.compile(r'<UIKit/UIKit.h>'), 'UIKit dependency'),
])

if errors:
    print('Onegram architecture audit failed', file=sys.stderr)
    for error in errors:
        print(error, file=sys.stderr)
    raise SystemExit(1)
