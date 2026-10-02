"""Bounded app integration: atomic writes and preservation of user-owned files."""
import json
import os
from pathlib import Path
import stat
import sys
import tempfile
from typing import Iterable


def atomic_write(path: Path, content: bytes) -> bool:
    """Replace changed files atomically, keep permissions, never replace symlinks."""
    if path.is_symlink():
        raise ValueError(f'refusing to replace symlink: {path}')
    if path.is_file() and path.read_bytes() == content:
        return False
    permissions = stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o600
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix='.hydra-theme-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as stream:
            os.fchmod(stream.fileno(), permissions)
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    return True


def apply_antigravity(profile: Path, recipe: Path) -> bool:
    """Opted-in official terminal scheme; retain every unrelated JSON value."""
    if not profile.is_file():
        return False
    wanted = json.loads(recipe.read_text())
    if wanted != {'colorScheme': 'terminal'}:
        raise ValueError('unsupported Antigravity theme recipe')
    settings = json.loads(profile.read_text())
    if not isinstance(settings, dict):
        raise ValueError('Antigravity settings must be a JSON object')
    if settings.get('colorScheme') == 'terminal':
        return False  # No unnecessary serialization, chmod or mtime changes.
    settings['colorScheme'] = 'terminal'
    return atomic_write(profile, (json.dumps(settings, indent=2, ensure_ascii=False) + '\n').encode())


def discover_obsidian_configs(manifests: Iterable[Path]) -> list[Path]:
    """Read only known app manifests; no recursive scanning or invented vaults."""
    found = set()
    for manifest in manifests:
        if not manifest.is_file():
            continue
        try:
            data = json.loads(manifest.read_text())
            vaults = data.get('vaults', {}) if isinstance(data, dict) else {}
            if not isinstance(vaults, dict):
                continue
            for entry in vaults.values():
                path = entry.get('path') if isinstance(entry, dict) else None
                if not isinstance(path, str) or not Path(path).is_absolute():
                    continue
                config = Path(path) / '.obsidian'
                if config.is_dir():
                    found.add(config.resolve())
        except (OSError, ValueError):
            # One unavailable/malformed install must not hide another's vaults.
            continue
    return sorted(found)


def apply_obsidian(source: Path, manifests: Iterable[Path]) -> int:
    payload = source.read_bytes()
    written = 0
    for config in discover_obsidian_configs(manifests):
        try:
            written += atomic_write(config / 'snippets/hydra.css', payload)
        except (OSError, ValueError) as error:
            print(f'Obsidian snippet skipped: {error}', file=sys.stderr)
    return written


def ensure_css_import(path: Path, colors: Path) -> bool:
    """Add only a Hydra import. Keep all user CSS bytes, including comments."""
    if not colors.is_file() or not path.parent.is_dir():
        return False
    content = path.read_bytes() if path.exists() else b''
    import_line = ('@import url("' + colors.name + '");').encode()
    if import_line in content:
        return False
    # Put imports before rules, where GTK can reliably load them.
    return atomic_write(path, import_line + b'\n' + content)
