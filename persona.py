#!/usr/bin/env python3
import argparse
import json
from pathlib import Path
import subprocess
import sys
import unicodedata

PRESETS = Path(__file__).with_name('presets.json')
FIELDS = ('style', 'body')


def load(path):
    return json.loads(path.read_text(encoding='utf-8'))


def batch(persona):
    if not isinstance(persona, dict) or set(persona) != set(FIELDS):
        raise ValueError('Expected a JSON object with exactly style and body')
    for key in FIELDS:
        text = persona[key]
        if not isinstance(text, str) or not text.strip():
            raise ValueError(f'{key} must be a nonempty string')
        if any(unicodedata.category(c) in ('Cc', 'Cs') and c not in '\n\t\r' for c in text):
            raise ValueError(f'{key} contains an unsupported control character or surrogate')
    if len(persona['style']) > 200:
        raise ValueError('style exceeds 200 characters')
    return [{'path': f'soul.{key}', 'value_json': json.dumps(persona[key], ensure_ascii=False)}
            for key in FIELDS]


def main(argv=None):
    parser = argparse.ArgumentParser(description='Preview or apply Minis Soul tone and personality.')
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('list', help='List bundled preset IDs')
    for name in ('preview', 'apply'):
        command = commands.add_parser(name)
        source = command.add_mutually_exclusive_group(required=True)
        source.add_argument('--preset', help='Bundled preset ID')
        source.add_argument('--file', type=Path, help='Custom UTF-8 JSON file')
    args = parser.parse_args(argv)
    try:
        if args.command == 'list':
            print('\n'.join(sorted(load(PRESETS))))
            return 0
        if args.file is not None:
            persona = load(args.file)
        else:
            presets = load(PRESETS)
            if args.preset not in presets:
                raise ValueError('Unknown preset; run list for available IDs')
            persona = presets[args.preset]
        payload = batch(persona)
        if args.command == 'preview':
            print(json.dumps({item['path']: persona[key] for key, item in zip(FIELDS, payload)},
                             ensure_ascii=False, indent=2))
            return 0
        # Keep native stdout/stderr (including audit information) and exit status.
        result = subprocess.run(['minis-config', 'set-batch'],
                                input=json.dumps(payload).encode('ascii') + b'\n',
                                check=False)
        if result.returncode == 126:
            print('Permission denied; check Minis Settings → Permissions. No retry.', file=sys.stderr)
        return result.returncode if result.returncode >= 0 else 128 - result.returncode
    except (OSError, ValueError) as error:
        print(f'MinisPersona: {error}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
