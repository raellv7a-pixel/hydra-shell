#!/usr/bin/env bash
# Hydra Shell — one-shot migration of the pre-rebrand Noctalia state on disk.
#
# Moves the legacy directories to their Hydra names. Idempotent: it never
# overwrites an existing Hydra directory and is a no-op once migrated, so it is
# safe to call from an autostart hook on every login.
#
#   ~/.config/noctalia      -> ~/.config/hydra
#   ~/.cache/noctalia       -> ~/.cache/hydra
#   ~/.config/hypr/noctalia -> ~/.config/hypr/hydra
#
# Generated theme files inside third-party app configs keep their old
# "noctalia" names until the templates are applied again (the shell does that
# on the next color-scheme change, or run Scripts/bash/template-apply.sh).

set -euo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

migrate() {
  local old="$1" new="$2"

  [[ -e $old ]] || return 0
  if [[ -e $new ]]; then
    echo "hydra-migrate: $new already exists, leaving $old untouched" >&2
    return 0
  fi

  mv -- "$old" "$new"
  echo "hydra-migrate: $old -> $new"
}

migrate "$CONFIG_HOME/noctalia" "$CONFIG_HOME/hydra"
migrate "$CACHE_HOME/noctalia" "$CACHE_HOME/hydra"
migrate "$CONFIG_HOME/hypr/noctalia" "$CONFIG_HOME/hypr/hydra"

# settings.json still carries the old brand in keys ("noctaliaPerformance",
# "showNoctaliaPerformance", "followNoctaliaPerformanceMode"), in widget ids
# ("NoctaliaPerformance"), in the ControlCenter icon name ("noctalia") and in
# the predefined color scheme name ("Noctalia (default)"). Commons/Migrations/
# Migration60.qml does the same rewrite in-shell, but only for a sane
# settingsVersion; doing it here makes the migration independent of that.
SETTINGS_FILE="${HYDRA_SETTINGS_FILE:-$CONFIG_HOME/hydra/settings.json}"
[[ -f $SETTINGS_FILE ]] || exit 0

python3 - "$SETTINGS_FILE" <<'PY'
import json
import shutil
import sys

SETTINGS_VERSION = 60
KEYS = {
    "noctaliaPerformance": "hydraPerformance",
    "showNoctaliaPerformance": "showHydraPerformance",
    "followNoctaliaPerformanceMode": "followHydraPerformanceMode",
}
VALUES = {
    "NoctaliaPerformance": "HydraPerformance",
    "Noctalia (default)": "Hydra (default)",
    "Noctalia (legacy)": "Hydra (legacy)",
    "Noctalia-default": "Hydra-default",
    "Noctalia-legacy": "Hydra-legacy",
    "noctalia": "hydra",
}

path = sys.argv[1]
with open(path) as fh:
    data = json.load(fh)

changed = False


def convert(node):
    global changed
    if isinstance(node, dict):
        out = {}
        for key, value in node.items():
            new_key = KEYS.get(key, key)
            if new_key != key:
                changed = True
            out[new_key] = convert(value)
        return out
    if isinstance(node, list):
        return [convert(item) for item in node]
    if isinstance(node, str) and node in VALUES:
        changed = True
        return VALUES[node]
    return node


data = convert(data)

# A settingsVersion outside the known range (seen in the wild after a bad
# write) permanently disables every in-shell migration. Clamp it so the
# migration ladder keeps working from here on.
version = data.get("settingsVersion")
if not isinstance(version, int) or version > SETTINGS_VERSION or version < 0:
    data["settingsVersion"] = SETTINGS_VERSION
    changed = True
    print(f"hydra-migrate: settingsVersion {version!r} -> {SETTINGS_VERSION}")

if not changed:
    sys.exit(0)

shutil.copy2(path, path + ".pre-hydra.bak")
with open(path, "w") as fh:
    json.dump(data, fh, indent=2, sort_keys=True)
    fh.write("\n")
print(f"hydra-migrate: rewrote {path} (backup at {path}.pre-hydra.bak)")
PY
