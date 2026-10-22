#!/usr/bin/env python3
import re
import sys
from collections import deque
from pathlib import Path


ANSI = re.compile(r'\x1b\[[0-?]*[ -/]*[@-~]')
ERROR = re.compile(r'(?:^|:\s)(?:fatal\s+)?error:(?:\s|$)|^[\w.]*Error:|^Undefined symbols for architecture|^(?:\S*/)?ld(?:64|\.lld)?: (?:library|framework|file) not found|No space left on device|Segmentation fault|(?:^|\s)Killed(?:\s|$)')


def summarize(path, output=sys.stdout):
    tail = deque(maxlen=15)
    diagnostics = []
    seen = set()
    following = 0
    no_space = False
    with Path(path).open(errors='replace') as source:
        for raw in source:
            line = ANSI.sub('', raw.rstrip('\n\r'))
            tail.append(line)
            no_space = no_space or 'No space left on device' in line
            if ERROR.search(line):
                following = 0
                if line not in seen:
                    seen.add(line)
                    if len(diagnostics) < 6:
                        diagnostics.append([line])
                        following = 4
            elif following:
                if not line.startswith(('make[', 'make:')) and '==> ' not in line:
                    diagnostics[-1].append(line)
                following -= 1
    if diagnostics:
        print('Build errors:', file=output)
        for block in diagnostics:
            print('\n'.join(block), file=output)
            print(file=output)
        if len(seen) > len(diagnostics):
            print(str(len(seen) - len(diagnostics)) + ' additional errors are recorded in the full build log.', file=output)
    else:
        print('Last build output:', file=output)
        print('\n'.join(tail), file=output)
    if no_space:
        print('The filesystem reported insufficient writable space. Existing build objects were kept; retry Build after resolving the storage error.', file=output)


if __name__ == '__main__':
    summarize(sys.argv[1])
