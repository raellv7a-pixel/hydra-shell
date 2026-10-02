#!/usr/bin/env python3
"""Post-render app actions; profiles are guarded and user preferences preserved."""
import argparse
import sys

from lib.app_config import apply_antigravity, apply_obsidian, ensure_css_import
from lib.renderer import resolve_template_path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app', choices=('antigravity', 'obsidian', 'inkscape', 'gimp'))
    args = parser.parse_args()
    resolve = resolve_template_path
    try:
        if args.app == 'antigravity':
            apply_antigravity(resolve('~/.gemini/antigravity-cli/settings.json'),
                              resolve('$XDG_CACHE_HOME/hydra/antigravity.json'))
        elif args.app == 'obsidian':
            apply_obsidian(resolve('$XDG_CACHE_HOME/hydra/obsidian.css'), [
                resolve('$XDG_CONFIG_HOME/obsidian/obsidian.json'),
                resolve('~/.var/app/md.obsidian.Obsidian/config/obsidian/obsidian.json'),
            ])
        else:
            if args.app == 'inkscape':
                roots = [resolve('$XDG_CONFIG_HOME/inkscape/ui'),
                         resolve('~/.var/app/org.inkscape.Inkscape/config/inkscape/ui')]
                filename = 'user.css'
            else:
                roots = [resolve(base + '/GIMP/' + version)
                         for base in ('$XDG_CONFIG_HOME', '~/.var/app/org.gimp.GIMP/config')
                         for version in ('3.0', '3.2')]
                filename = 'gimp.css'
            failed = False
            for root in roots:
                try:
                    ensure_css_import(root / filename, root / 'hydra-colors.css')
                except (OSError, ValueError) as error:
                    print(f'{args.app} theme import skipped: {error}', file=sys.stderr)
                    failed = True
            return int(failed)
    except (OSError, ValueError) as error:
        print(f'{args.app} theme apply: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
