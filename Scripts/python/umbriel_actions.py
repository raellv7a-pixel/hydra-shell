#!/usr/bin/env python3
"""Read the running installation's canonical action vocabulary (no compositor mutation)."""
import json
import re
import subprocess

ACTION_RE = re.compile(r"[a-z][a-z0-9-]*(?: [^\s\x00-\x1f\x7f]+(?: +[^\s\x00-\x1f\x7f]+)*)?")

GROUPS = {
    'Apps': 'Aplicativos', 'Focus': 'Foco', 'Move & size': 'Mover e redimensionar',
    'Windows': 'Janelas', 'Scratchpad': 'Scratchpads', 'Workspaces': 'Workspaces',
    'Overview': 'Visão Geral', 'System': 'Sistema', 'Screencasting': 'Screencast',
}


def catalog(help_text):
    group = ''
    in_actions = False
    entries = []
    for line in help_text.splitlines():
        if line.startswith('Available actions'):
            in_actions = True
        elif in_actions and line and not line.startswith(' '):
            group = GROUPS.get(line, line)
        match = re.match(r'^  (.+?)\s{2,}(\S.*)$', line)
        if not match or not group:
            continue
        signature, description = match.groups()
        parts = signature.split(maxsplit=1)
        name = parts[0]
        if not re.fullmatch(r'[a-z][a-z0-9-]*', name):
            continue
        argument = parts[1] if len(parts) > 1 else ''
        entries.append({'key': name, 'name': description, 'category': group,
                        'argument': argument, 'required': bool(argument and argument.startswith('<')),
                        'signature': signature})
    return entries


if __name__ == '__main__':
    result = subprocess.run(['umbriel', 'msg', '--help'], capture_output=True, text=True, check=True)
    print(json.dumps(catalog(result.stdout), ensure_ascii=False))
