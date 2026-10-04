#!/usr/bin/env python3
"""Hydra-owned Umbriel fragments; validate the complete candidate before replacement."""
import argparse
import copy
import fcntl
import hashlib
import json
import os
from pathlib import Path
import subprocess
import re
import tempfile
import tomllib

from umbriel_keybinds import atomic


def statements(text):
    """Yield TOML statement spans, respecting strings, arrays and comments."""
    start = 0
    i = 0
    depth = 0
    quote = None
    while i < len(text):
        char = text[i]
        if quote:
            if char == '\\' and quote[0] == '"':
                i += 2
                continue
            if text.startswith(quote, i):
                i += len(quote)
                quote = None
                continue
        elif char in "\"'":
            quote = char * 3 if text.startswith(char * 3, i) else char
            i += len(quote)
            continue
        elif char == '#':
            end = text.find('\n', i)
            i = len(text) if end < 0 else end
            continue
        elif char in '[{':
            depth += 1
        elif char in ']}':
            depth -= 1
        elif char == '\n' and depth == 0:
            yield start, i + 1, text[start:i + 1]
            start = i + 1
        i += 1
    if start < len(text):
        yield start, len(text), text[start:]


def with_includes(text, replacements):
    """Update include arrays only. Prove every other parsed value is unchanged."""
    data = tomllib.loads(text)
    expected = copy.deepcopy(data)
    include = expected.setdefault('include', {})
    optional = include.setdefault('optional', {})
    for table in (include, optional):
        files = table.get('files', [])
        if not isinstance(files, list) or any(not isinstance(f, str) for f in files):
            raise ValueError('Umbriel include.files must be a string array')
        updated = []
        for name in files:
            name = replacements.get(name, name)
            if name not in updated:
                updated.append(name)
        table['files'] = updated
    # Add owned includes as optional; retain the user's required includes in place.
    for old, new in replacements.items():
        if new not in include['files'] and new not in optional['files']:
            optional['files'].append(new)
    sections = {}
    assignments = {}
    section = ()
    for start, end, statement in statements(text):
        stripped = statement.strip()
        if not stripped or stripped.startswith('#'):
            continue
        if stripped.startswith('['):
            probe = tomllib.loads(statement + '\n__hydra_probe = 0\n')
            path = []
            while isinstance(probe, dict) and '__hydra_probe' not in probe:
                key = next(iter(probe))
                path.append(key)
                probe = probe[key]
            section = tuple(path)
            sections[section] = end
            continue
        parsed = tomllib.loads(statement)
        path = list(section)
        while isinstance(parsed, dict) and len(parsed) == 1:
            key = next(iter(parsed))
            path.append(key)
            parsed = parsed[key]
        if tuple(path) in (('include', 'files'), ('include', 'optional', 'files')):
            assignments[tuple(path)] = (start, end, section)
    edits = []
    for path, table in [(('include', 'files'), include), (('include', 'optional', 'files'), optional)]:
        old_table = data.get('include', {}) if len(path) == 2 else data.get('include', {}).get('optional', {})
        if table['files'] == old_table.get('files', []) and 'files' in old_table:
            continue
        if not table['files'] and 'files' not in old_table:
            table.pop('files')
            continue
        if path in assignments:
            start, end, section = assignments[path]
            key = '.'.join(path[len(section):])
            edits.append((start, end, key + ' = ' + json.dumps(table['files']) + '\n'))
        elif path[:-1] in sections:
            at = sections[path[:-1]]
            edits.append((at, at, 'files = ' + json.dumps(table['files']) + '\n'))
        elif path[:-1] not in (('include',), ('include', 'optional')):
            raise ValueError('Unsupported include shape')
        else:
            edits.append((len(text), len(text), '\n[' + '.'.join(path[:-1]) + ']\nfiles = ' + json.dumps(table['files']) + '\n'))
    if not optional:
        include.pop('optional')
    for start, end, replacement in sorted(edits, reverse=True):
        text = text[:start] + replacement + text[end:]
    if tomllib.loads(text) != expected:
        raise ValueError('Cannot preserve this Umbriel include structure safely')
    return text


def config_dir():
    value = os.environ.get('XDG_CONFIG_HOME', '')
    return (Path(value) if value.startswith('/') else Path.home() / '.config') / 'umbriel'


def settings_sources(master_text, directory, managed=('overview', 'hot_corners'), owned='settings.toml'):
    """Identify competing native settings and snapshot every personal include."""
    owners = []
    sources = {}

    def scan(text, path):
        key = path.resolve()
        if key in sources:
            return
        sources[key] = text
        data = tomllib.loads(text)
        for name in managed:
            if name in data:
                owners.append(str(path) + ': [' + name + ']')
        includes = data.get('include', {})
        if not isinstance(includes, dict):
            raise ValueError('Invalid Umbriel include table')
        required = includes.get('files', [])
        optional = includes.get('optional', {})
        if not isinstance(required, list) or not isinstance(optional, dict):
            raise ValueError('Invalid Umbriel include declaration')
        extra = optional.get('files', [])
        if not isinstance(extra, list):
            raise ValueError('Invalid Umbriel optional includes')
        for entry in required + extra:
            if not isinstance(entry, str):
                raise ValueError('Invalid Umbriel include path')
            target = Path(os.path.expandvars(os.path.expanduser(entry)))
            if not target.is_absolute():
                target = path.parent / target
            if target.resolve() == (directory / 'hydra' / owned).resolve():
                continue
            if target.exists():
                scan(target.read_text(), target)
            elif entry in required:
                raise ValueError('Arquivo include obrigatório ausente: ' + str(target))
    scan(master_text, directory / 'config.toml')
    return owners, sources


def settings_owners(master_text, directory):
    return settings_sources(master_text, directory)[0]


def settings_revision(master_text, owned_text, sources):
    payload = json.dumps({
        'master': master_text, 'owned': owned_text,
        'includes': [(str(path), text) for path, text in sorted(sources.items())]
    }, ensure_ascii=False, sort_keys=True)
    return hashlib.sha256(payload.encode('utf-8')).hexdigest()


def commit(kind, content, *, reload=True, expected_revision=None):
    if kind not in ('outputs', 'visual', 'theme', 'cursor', 'settings'):
        raise ValueError('Unknown Hydra fragment')
    tomllib.loads(content)
    directory = config_dir()
    master = directory / 'config.toml'
    owned = directory / 'hydra' / (kind + '.toml')
    owned.parent.mkdir(parents=True, exist_ok=True)
    if master.is_symlink() or owned.is_symlink():
        raise ValueError('Refusing to replace a symlinked Umbriel configuration')
    with (owned.parent / '.config.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        old_master = master.read_text() if master.exists() else ''
        old_owned = owned.read_text() if owned.exists() else None
        relative = 'hydra/' + owned.name
        if kind == 'settings':
            owners, sources = settings_sources(old_master, directory)
            if owners:
                raise ValueError('Configuração Umbriel controlada externamente: ' + ', '.join(owners))
            if (expected_revision is not None
                    and settings_revision(old_master, old_owned, sources) != expected_revision):
                raise ValueError('Configuração Umbriel mudou desde a leitura; recarregue a página')
        final_master = with_includes(old_master, {relative: relative})
        if content == old_owned and old_master == final_master:
            return
        stage = None
        root_stage = None
        installed = False
        try:
            with tempfile.NamedTemporaryFile(mode='w', encoding='utf8', dir=owned.parent, prefix='.candidate-', suffix='.toml', delete=False) as stream:
                stage = Path(stream.name)
                stream.write(content)
            staged_master = with_includes(old_master, {relative: 'hydra/' + stage.name})
            with tempfile.NamedTemporaryFile(mode='w', encoding='utf8', dir=directory, prefix='.candidate-', suffix='.toml', delete=False) as stream:
                root_stage = Path(stream.name)
                stream.write(staged_master)
            result = subprocess.run(['umbriel', 'config', 'validate', '-c', str(root_stage)], capture_output=True, text=True)
            if result.returncode:
                raise ValueError((result.stderr or result.stdout).strip())
            if (master.read_text() if master.exists() else '') != old_master or (owned.read_text() if owned.exists() else None) != old_owned:
                raise ValueError('Umbriel config changed during validation')
            if kind == 'settings' and settings_sources(old_master, directory) != (owners, sources):
                raise ValueError('Um include Umbriel foi alterado durante a validação')
            atomic(owned, content)
            installed = True
            if final_master != old_master:
                atomic(master, final_master)
            if reload:
                result = subprocess.run(['umbriel', 'msg', 'config-reload'], capture_output=True, text=True)
                if result.returncode:
                    raise ValueError((result.stderr or result.stdout).strip() or 'Umbriel reload failed')
        except Exception:
            if installed:
                if owned.exists() and owned.read_text() == content:
                    if old_owned is None:
                        owned.unlink()
                    else:
                        atomic(owned, old_owned)
                if master.exists() and master.read_text() == final_master and final_master != old_master:
                    if old_master:
                        atomic(master, old_master)
                    else:
                        master.unlink()
            raise
        finally:
            if stage:
                stage.unlink(missing_ok=True)
            if root_stage:
                root_stage.unlink(missing_ok=True)


TRANSFORMS = ['normal', '90', '180', '270', 'flipped', 'flipped-90', 'flipped-180', 'flipped-270']


def output_config(outputs):
    lines = ['# Hydra-owned monitor arrangement. Other output options remain user-owned.']
    for output in outputs:
        lines += ['', '[output.' + json.dumps(output['name']) + ']', 'enabled = ' + str(output.get('active', True) and not output.get('disabled', False)).lower()]
        if output.get('active', True) and not output.get('disabled', False):
            transform = output['transform']
            if str(transform).isdigit():
                transform = TRANSFORMS[int(transform)]
            lines += ['mode = ' + json.dumps(f"{int(output['width'])}x{int(output['height'])}@{output['refresh']}"),
                      'position = ' + json.dumps([int(output['x']), int(output['y'])]),
                      'scale = ' + str(output['scale']), 'transform = ' + json.dumps(transform)]
    return '\n'.join(lines) + '\n'


BLUR_NAMESPACES = [r'^hydra-(background|popupmenu|notifications|osd|toast|launcher-overlay)-.+$',
                   r'^hydra-show-keys$']

# Client shadows share the layer buffer. Keep their translucent fringe out of
# the blur mask and sample the live scene rather than only the wallpaper layer.
BLUR_IGNORE_ALPHA = 0.5


def visual_config(enabled, output_names):
    lines = ['# Hydra-owned shell surface effects.']
    namespaces = BLUR_NAMESPACES + [
        '^hydra-dock-' + re.escape(name) + '$' for name in output_names
    ]
    for namespace in namespaces:
        lines += ['', '[[layer_rule]]', 'match = { namespace = ' + json.dumps(namespace) + ' }',
                  'blur = ' + str(enabled).lower(), 'blur_optimized = false',
                  'blur_ignore_alpha = ' + str(BLUR_IGNORE_ALPHA)]
    lines += ['', '[[window_rule]]', 'match = { app_id = "^dev\\\\.noctalia\\\\.noctalia-qs$", title = "^Hydra$" }',
              'blur = ' + str(enabled).lower(), 'blur_optimized = false',
              'blur_ignore_alpha = ' + str(BLUR_IGNORE_ALPHA)]
    return '\n'.join(lines) + '\n'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('kind', choices=['outputs', 'visual', 'theme', 'cursor'])
    parser.add_argument('value')
    parser.add_argument('--no-reload', action='store_true')
    args = parser.parse_args()
    if args.kind == 'outputs':
        content = output_config(json.loads(args.value))
    elif args.kind == 'visual':
        value = json.loads(args.value)
        content = visual_config(value['enabled'], value['outputs'])
    elif args.kind == 'cursor':
        size = int(args.value)
        content = '[input.cursor]\ntheme = "Hydra-Adaptive"\nsize = ' + str(size) + '\n'
    else:
        content = Path(args.value).read_text()
    commit(args.kind, content, reload=not args.no_reload)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        print(str(error), file=__import__('sys').stderr)
        raise SystemExit(1)
