#!/usr/bin/env python3
"""Own only screencast.chooser_cmd; retain other TOML text and reversible ownership."""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import sys
import tomllib

from umbriel_config import statements
from umbriel_keybinds import atomic
from hydra_share_picker import official_picker


def paths():
    config = Path(os.environ.get('XDG_CONFIG_HOME') or Path.home() / '.config')
    state = Path(os.environ.get('XDG_STATE_HOME') or Path.home() / '.local/state')
    return config / 'xdg-desktop-portal-umbriel/config.toml', state / 'hydra/portal-picker.json'


def command():
    return 'exec python3 ' + shlex.quote(str(Path(__file__).resolve().with_name('hydra_share_picker.py')))


def chooser(text):
    return tomllib.loads(text).get('screencast', {}).get('chooser_cmd')


def assignment(text):
    section = ''
    for start, end, statement in statements(text):
        stripped = statement.strip()
        header = re.match(r'^\[([^\[\]]+)\]', stripped)
        if header:
            section = header.group(1).strip()
            continue
        key = r'chooser_cmd' if section == 'screencast' else r'screencast\s*\.\s*chooser_cmd' if not section else None
        if key and re.match(r'^\s*' + key + r'\s*=', statement):
            return start, end, statement
    if chooser(text) is not None:
        raise ValueError('chooser_cmd usa sintaxe externa não editável com segurança')
    return None


def replace(text, value, original=None):
    found = assignment(text)
    if found:
        start, end, statement = found
        if original is not None:
            replacement = original
        elif value is None:
            replacement = ''
        else:
            # Keep the existing key spelling and trailing inline comment.
            prefix = statement[:statement.index('=') + 1]
            tail = ''
            quote = None
            escaped = False
            for index, char in enumerate(statement[len(prefix):], len(prefix)):
                if escaped:
                    escaped = False
                elif quote and char == '\\' and quote == '"':
                    escaped = True
                elif quote and char == quote:
                    quote = None
                elif not quote and char in "\"'":
                    quote = char
                elif not quote and char == '#':
                    tail = ' ' + statement[index:].rstrip('\r\n')
                    break
            replacement = prefix + ' ' + json.dumps(value) + tail + '\n'
        result = text[:start] + replacement + text[end:]
    elif value is not None:
        # A dotted root assignment avoids touching/reformatting an existing table.
        data = tomllib.loads(text)
        if 'screencast' in data:
            match = re.search(r'^\s*\[screencast\]\s*(?:#[^\n]*)?\n', text, re.M)
            if not match:
                raise ValueError('Tabela screencast externa não editável com segurança')
            result = text[:match.end()] + 'chooser_cmd = ' + json.dumps(value) + '\n' + text[match.end():]
        else:
            result = text + ('\n' if text and not text.endswith('\n') else '') + '\n[screencast]\nchooser_cmd = ' + json.dumps(value) + '\n'
    else:
        result = text
    before = tomllib.loads(text)
    after = tomllib.loads(result)
    for data in (before, after):
        section = data.get('screencast', {})
        section.pop('chooser_cmd', None)
        if not section:
            data.pop('screencast', None)
    if before != after:
        raise ValueError('A escrita alteraria outras configurações do portal')
    return result


def snapshot():
    path, record_path = paths()
    text = path.read_text() if path.exists() else ''
    record = json.loads(record_path.read_text()) if record_path.exists() else None
    value = chooser(text)
    installed = record.get('installed') if record else command()
    enabled = value == installed
    conflict = bool(record and value != installed and value != record.get('previous'))
    revision = hashlib.sha256((text + '\0' + json.dumps(record, sort_keys=True)).encode()).hexdigest()
    return {'enabled': enabled, 'externallyChanged': conflict, 'chooser': value or '', 'revision': revision}, text, record


def set_enabled(enabled, revision):
    path, record_path = paths()
    record_path.parent.mkdir(parents=True, exist_ok=True)
    with record_path.with_suffix('.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        state, text, record = snapshot()
        if revision != state['revision']:
            raise ValueError('Configuração do portal mudou; recarregue antes de alterar')
        if path.is_symlink() or record_path.is_symlink():
            raise ValueError('Configuração por symlink é controlada externamente')
        if state['externallyChanged']:
            raise ValueError('chooser_cmd alterado externamente; a Hydra não o sobrescreverá')
        if enabled:
            if state['enabled']:
                return state
            official_picker()  # Do not install a chooser with no official fallback.
            found = assignment(text)
            record = {'installed': command(), 'previous': chooser(text),
                      'statement': found[2] if found else None}
            candidate = replace(text, record['installed'])
            # Record the prior value before cutover, so interruption never loses it.
            atomic(record_path, json.dumps(record))
        else:
            if not state['enabled']:
                return state
            if not record:
                raise ValueError('Valor anterior desconhecido; remova chooser_cmd manualmente')
            candidate = replace(text, record['previous'], record['statement'])
        if (path.read_text() if path.exists() else '') != text:
            raise ValueError('Configuração do portal mudou durante a escrita')
        atomic(path, candidate)
        if not enabled:
            record_path.unlink(missing_ok=True)
        return snapshot()[0]


def main():
    if len(sys.argv) == 1 or sys.argv[1] == 'state':
        result = snapshot()[0]
    else:
        result = set_enabled(sys.argv[1] == 'enable', sys.argv[2])
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
