#!/usr/bin/env python3
"""CLI for isolated Minecraft 1.12.2 packaged Cleanroom test sessions."""
import argparse
import json
import platform
import sys

from common import read_json


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='action', required=True)
    prep = sub.add_parser('prepare')
    prep.add_argument('--profile', required=True)
    prep.add_argument('--workspace', required=True)
    prep.add_argument('--name', required=True)
    swap = sub.add_parser('refresh', help='replace the pinned project JAR on its prepared sides')
    swap.add_argument('--root', required=True)
    swap.add_argument('--jar', required=True)
    swap.add_argument('--from-sha256', required=True)
    swap.add_argument('--sha256', required=True)
    run = sub.add_parser('run')
    run.add_argument('--root', required=True)
    run.add_argument('--plan', required=True)
    args = parser.parse_args()
    try:
        if platform.system() != 'Windows':
            raise ValueError('Windows x64 and CPython 3.11+ are required')
        if args.action == 'prepare':
            from prepare import prepare
            result = prepare(args.profile, args.workspace, args.name)
        elif args.action == 'refresh':
            from refresh import refresh
            result = refresh(args.root, args.jar, args.from_sha256, args.sha256)
        else:
            from session import Session
            result = Session(args.root, read_json(args.plan)).run()
        print(json.dumps(result), flush=True)
        return 1 if result.get('status') == 'failed' else 0
    except Exception as exc:
        print(json.dumps({'status': 'failed', 'error': str(exc)}), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
