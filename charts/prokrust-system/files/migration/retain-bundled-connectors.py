#!/usr/bin/env python3
"""Helm 3 post-renderer for the last upgrade of a System with bundled connectors."""
import re
import sys

import yaml


DOCUMENT = re.compile(r"(?m)(?=^---[ \t]*\r?$)")
PROVIDER = re.compile(r"\A(?:---[ \t]*\r?\n)?# Source: prokrust-system/charts/connectors/charts/[^/\s]+/templates/[^\r\n]+\r?\n")


def retain(manifest):
    documents = DOCUMENT.split(manifest)
    count = 0
    for i, document in enumerate(documents):
        source = PROVIDER.match(document)
        if source:
            obj = yaml.safe_load(document)
            if not isinstance(obj, dict) or not obj.get('metadata', {}).get('name'):
                raise ValueError('Bundled provider manifest lacks a resource name')
            obj['metadata'].setdefault('annotations', {})['helm.sh/resource-policy'] = 'keep'
            documents[i] = document[:source.end()] + yaml.safe_dump(obj, sort_keys=False)
            count += 1
    if not count:
        raise ValueError('No bundled connector resources found in this Helm render')
    return ''.join(documents), count


if __name__ == '__main__':
    try:
        output, count = retain(sys.stdin.read())
    except (ValueError, yaml.YAMLError) as error:
        sys.exit(str(error))
    print(f'Retaining {count} bundled connector resources', file=sys.stderr)
    sys.stdout.write(output)
