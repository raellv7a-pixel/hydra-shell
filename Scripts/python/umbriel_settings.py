#!/usr/bin/env python3
"""Validated native settings in Hydra's owned Umbriel include."""
import json
import re
import sys
import tomllib

import umbriel_config

CORNERS = ('top_left', 'top_right', 'bottom_left', 'bottom_right')
OVERVIEW = {
    'zoom': 0.5, 'scroll_factor_horizontal': 1.0,
    'scroll_factor_vertical': 1.0, 'background_blur': True,
    'workspace_wallpaper': True, 'shortcuts': True,
    'shortcut_keys': '1234567890',
}
CORNER = {'enabled': False, 'delay_ms': 500, 'action': ''}


def defaults():
    return {'overview': dict(OVERVIEW),
            'screencast': {'disable_dynamic_confirmation': False},
            'hot_corners': {corner: dict(CORNER) for corner in CORNERS}}


def validate(state):
    if not isinstance(state, dict) or set(state) != {'overview', 'hot_corners', 'screencast'}:
        raise ValueError('Estado Umbriel inválido')
    screencast = state['screencast']
    if (not isinstance(screencast, dict) or set(screencast) != {'disable_dynamic_confirmation'}
            or type(screencast['disable_dynamic_confirmation']) is not bool):
        raise ValueError('Confirmação de compartilhamento inválida')
    overview = state['overview']
    corners = state['hot_corners']
    if not isinstance(overview, dict) or set(overview) != set(OVERVIEW):
        raise ValueError('Campos da Visão Geral inválidos')
    if not isinstance(corners, dict) or set(corners) != set(CORNERS):
        raise ValueError('Cantos Ativos inválidos')
    for field, lo, hi in (('zoom', 0.1, 0.75),
                          ('scroll_factor_horizontal', 0.1, 10.0),
                          ('scroll_factor_vertical', 0.1, 10.0)):
        number = overview[field]
        if type(number) not in (float, int) or not lo <= number <= hi:
            raise ValueError(field + ' fora do intervalo')
    for field in ('background_blur', 'workspace_wallpaper', 'shortcuts'):
        if type(overview[field]) is not bool:
            raise ValueError(field + ' deve ser booleano')
    keys = overview['shortcut_keys']
    if (not isinstance(keys, str) or len(keys) < 2 or
        any(ord(k) < 0x21 or ord(k) > 0x7e for k in keys) or
        len(set(keys.lower())) != len(keys)):
        raise ValueError('shortcut_keys requer dois ou mais caracteres ASCII únicos')
    for name in CORNERS:
        corner = corners[name]
        if not isinstance(corner, dict) or set(corner) != set(CORNER):
            raise ValueError('Campos de ' + name + ' inválidos')
        if type(corner['enabled']) is not bool or type(corner['delay_ms']) is not int or not 0 <= corner['delay_ms'] <= 10000:
            raise ValueError('Ativação ou atraso inválido em ' + name)
        action = corner['action']
        if (not isinstance(action, str) or (action and
            (not re.fullmatch(r'[a-z][a-z0-9-]*(?::[^\r\n]+)?', action) or action.endswith((':', '/'))))
            or (corner['enabled'] and not action)):
            raise ValueError('Ação inválida em ' + name)
    return state


def generate(state):
    validate(state)
    lines = ['# Configuração nativa Umbriel gerenciada pela Hydra.', '', '[overview]']
    for field in OVERVIEW:
        lines.append(field + ' = ' + json.dumps(state['overview'][field], ensure_ascii=False))
    lines += ['', '[screencast]', 'disable_dynamic_confirmation = ' +
              json.dumps(state['screencast']['disable_dynamic_confirmation'])]
    for name in CORNERS:
        corner = state['hot_corners'][name]
        lines += ['', '[hot_corners.' + name + ']',
                  'enabled = ' + json.dumps(corner['enabled']),
                  'delay_ms = ' + str(corner['delay_ms'])]
        if corner['action']:
            lines.append('action = ' + json.dumps(corner['action'], ensure_ascii=False))
    return '\n'.join(lines) + '\n'


def current():
    directory = umbriel_config.config_dir()
    master = directory / 'config.toml'
    owned = directory / 'hydra' / 'settings.toml'
    master_text = master.read_text() if master.exists() else ''
    owned_text = owned.read_text() if owned.exists() else None
    owners, sources = umbriel_config.settings_sources(master_text, directory)
    state = defaults()
    if owned_text is not None:
        stored = tomllib.loads(owned_text)
        state['overview'].update(stored.get('overview', {}))
        state['screencast'].update(stored.get('screencast', {}))
        for name in CORNERS:
            state['hot_corners'][name].update(stored.get('hot_corners', {}).get(name, {}))
        validate(state)
    return {'state': state, 'owners': owners,
            'revision': umbriel_config.settings_revision(master_text, owned_text, sources)}


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else 'state'
    if command == 'state':
        print(json.dumps(current(), ensure_ascii=False))
    elif command == 'save':
        state = validate(json.loads(sys.argv[2]))
        umbriel_config.commit('settings', generate(state),
                              expected_revision=sys.argv[3] if len(sys.argv) > 3 else None)
        print(json.dumps(current(), ensure_ascii=False))
    else:
        raise ValueError('Comando desconhecido: ' + command)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, tomllib.TOMLDecodeError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
