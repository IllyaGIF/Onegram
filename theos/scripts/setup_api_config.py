#!/usr/bin/env python3
import getpass
import os
from pathlib import Path
import re
import sys
import tempfile


def valid_api_id(value):
    return bool(re.fullmatch(r'[0-9]{1,10}', value)) and 0 < int(value) <= 2147483647


def valid_api_hash(value):
    return bool(re.fullmatch(r'[0-9a-fA-F]{32}', value))


def read_credentials(path):
    if not path.exists():
        return '', ''
    text = path.read_text(encoding='utf-8')
    api_id = re.search(
        r'^\s*#\s*define\s+SETUP_API_ID\((\w+)\)\s+\1\s*=\s*([0-9]+)\s*;',
        text, re.MULTILINE)
    api_hash = re.search(
        r'^\s*#\s*define\s+SETUP_API_HASH\((\w+)\)\s+\1\s*=\s*@"([^"\r\n]*)"\s*;',
        text, re.MULTILINE)
    return api_id.group(2) if api_id else '', api_hash.group(2) if api_hash else ''


def request_value(label, validator, hidden=False):
    while True:
        value = (getpass.getpass(label + ': ') if hidden else input(label + ': ')).strip()
        if validator(value):
            return value
        print('Invalid ' + label + '; try again.', file=sys.stderr)


def write_credentials(path, api_id, api_hash):
    descriptor, temporary = tempfile.mkstemp(prefix='.onegram-config-', dir=str(path.parent))
    try:
        with os.fdopen(descriptor, 'w', encoding='utf-8') as output:
            os.fchmod(output.fileno(), 0o600)
            output.write('#define SETUP_API_ID(apiId) apiId = ' + str(int(api_id)) + ';\n')
            output.write('#define SETUP_API_HASH(apiHash) apiHash = @"' + api_hash + '";\n')
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def setup(path):
    api_id, api_hash = read_credentials(path)
    if valid_api_id(api_id) and valid_api_hash(api_hash):
        return
    if not valid_api_id(api_id):
        api_id = os.environ.get('ONEGRAM_API_ID', '').strip()
    if not valid_api_hash(api_hash):
        api_hash = os.environ.get('ONEGRAM_API_HASH', '').strip()
    if not valid_api_id(api_id) or not valid_api_hash(api_hash):
        if not sys.stdin.isatty():
            raise ValueError('config.h needs Telegram API credentials. Run ./build.sh in a terminal '
                             'or set ONEGRAM_API_ID and ONEGRAM_API_HASH.')
        print('First build: configure your Telegram application credentials.\n'
              'Get API ID and API hash at https://my.telegram.org/apps', file=sys.stderr)
        if not valid_api_id(api_id):
            api_id = request_value('API ID (positive number)', valid_api_id)
        if not valid_api_hash(api_hash):
            api_hash = request_value('API hash (32 hexadecimal characters)', valid_api_hash, hidden=True)
    write_credentials(path, api_id, api_hash)
    print('Telegram API credentials saved to config.h.')


def main():
    if len(sys.argv) != 2:
        print('Usage: setup_api_config.py /path/to/config.h', file=sys.stderr)
        return 2
    try:
        setup(Path(sys.argv[1]))
    except (EOFError, KeyboardInterrupt):
        print('\nCredential setup cancelled; build not started.', file=sys.stderr)
        return 1
    except (OSError, ValueError) as error:
        print('ERROR: ' + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
