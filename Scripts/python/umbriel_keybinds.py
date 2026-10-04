#!/usr/bin/env python3
"""Hydra-owned Umbriel keybind catalogue, validated config writer and CLI for Settings."""
import fcntl
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import tomllib

VERSION = 2
IPC = {
    "launcher": ("toggle", "clipboard"),
    "settings": ("toggle", "open"),
    "controlCenter": ("toggle",),
    "notifications": ("toggleHistory", "toggleDND"),
    "calendar": ("toggle",),
    "bar": ("toggle",),
    "sessionMenu": ("toggle",),
    "lockScreen": ("lock",),
    "screenToolkit": ("annotate", "annotateWindow", "annotateFullscreen", "colorPicker", "record", "ocr"),
    "volume": ("increase", "decrease", "muteOutput"),
    "brightness": ("increase", "decrease"),
    "media": ("playPause", "next", "previous"),
    "windowSwitcher": ("open", "hold", "holdPrevious", "close", "next", "previous"),
}


def entry(id, category, label, chord, kind, action, *, repeat=False, locked=False, inhibited=False, cooldown=0):
    return dict(id=id, category=category, label=label, chord=chord, type=kind,
                action=action, repeat=repeat, allow_when_locked=locked,
                allow_when_inhibited=inhibited, cooldown_ms=cooldown)


CATALOG = [
    entry("shell.launcher", "Hydra", "Lançador", "Mod+Space", "hydra", "launcher toggle"),
    entry("shell.switcher", "Hydra", "Alternador de janelas", "Alt+Tab", "hydra", "windowSwitcher hold"),
    entry("shell.switcher.previous", "Hydra", "Alternador: anterior", "Alt+Shift+Tab", "hydra", "windowSwitcher holdPrevious"),
    entry("shell.clipboard", "Hydra", "Área de transferência", "Mod+V", "hydra", "launcher clipboard"),
    entry("shell.settings", "Hydra", "Configurações", "Mod+Comma", "hydra", "settings toggle"),
    entry("shell.control", "Hydra", "Central de controle", "Mod+S", "hydra", "controlCenter toggle"),
    entry("shell.notifications", "Hydra", "Notificações", "Mod+N", "hydra", "notifications toggleHistory"),
    entry("shell.calendar", "Hydra", "Calendário", "Mod+C", "hydra", "calendar toggle"),
    entry("shell.bar", "Hydra", "Barra", "Mod+B", "hydra", "bar toggle"),
    entry("shell.session", "Hydra", "Menu de sessão", "Mod+Escape", "hydra", "sessionMenu toggle"),
    entry("shell.lock", "Hydra", "Bloquear", "Mod+Alt+L", "hydra", "lockScreen lock"),
    entry("app.terminal", "Aplicativos", "Terminal", "Mod+Return", "command", "kitty"),
    entry("app.files", "Aplicativos", "Arquivos", "Mod+E", "command", "xdg-open ~"),
    entry("window.close", "Janelas", "Fechar janela", "Mod+Q", "umbriel", "window-close"),
    entry("window.floating", "Janelas", "Flutuante", "Mod+T", "umbriel", "window-toggle-floating"),
    entry("window.fullscreen", "Janelas", "Tela cheia", "Mod+F", "umbriel", "window-toggle-fullscreen"),
    entry("window.maximize", "Janelas", "Maximizar coluna", "Mod+Ctrl+F", "umbriel", "window-toggle-maximize"),
    entry("window.pin", "Janelas", "Fixar janela", "Mod+P", "umbriel", "window-toggle-pinned"),
    entry("window.extent", "Janelas", "Ciclar largura", "Mod+R", "umbriel", "window-cycle-primary-extent"),
    entry("window.extent_back", "Janelas", "Ciclar largura para trás", "Mod+Shift+R", "umbriel", "window-cycle-primary-extent-back"),
    entry("umbriel.overview", "Umbriel", "Visão geral", "Mod+O", "umbriel", "overview-toggle"),
    entry("umbriel.layout", "Umbriel", "Alternar layout", "Mod+Shift+O", "umbriel", "workspace-set-layout:toggle"),
    entry("umbriel.scratchpad", "Umbriel", "Mostrar scratchpad", "Mod+Alt+Space", "umbriel", "scratchpad-toggle:hydra-default"),
    entry("umbriel.scratchpad_move", "Umbriel", "Mover ao scratchpad", "Mod+Shift+Space", "umbriel", "window-move-to-scratchpad:hydra-default"),
    entry("umbriel.scratchpad_next", "Umbriel", "Próximo no scratchpad", "Mod+Tab", "umbriel", "scratchpad-focus-next:hydra-default"),
    entry("umbriel.inhibit", "Umbriel", "Atalhos inibidos: alternar", "Mod+Shift+Escape", "umbriel", "shortcuts-inhibit-toggle", inhibited=True),
    entry("workspace.next", "Workspaces", "Próximo workspace", "Mod+WheelDown", "umbriel", "workspace-next", cooldown=150),
    entry("workspace.previous", "Workspaces", "Workspace anterior", "Mod+WheelUp", "umbriel", "workspace-previous", cooldown=150),
]
for direction, key in (("left", "Left"), ("down", "Down"), ("up", "Up"), ("right", "Right")):
    CATALOG.append(entry("focus." + direction, "Foco", "Foco " + direction, "Mod+" + key, "umbriel", "window-focus-" + direction, repeat=True))
for direction, key in (("left", "H"), ("down", "J"), ("up", "K"), ("right", "L")):
    CATALOG.append(entry("focus.vim." + direction, "Foco", "Foco " + direction + " (Vim)", "Mod+" + key, "umbriel", "window-focus-" + direction, repeat=True))
for direction, action in (("left", "column-move-left"), ("right", "column-move-right"), ("up", "window-move-up"), ("down", "window-move-down")):
    CATALOG.append(entry("move." + direction, "Janelas", "Mover " + direction, "Mod+Shift+" + direction.title(), "umbriel", action, repeat=True))
for number in range(1, 10):
    CATALOG.append(entry("workspace." + str(number), "Workspaces", "Workspace " + str(number), "Mod+" + str(number), "umbriel", "workspace-switch:" + str(number)))
    CATALOG.append(entry("workspace.move." + str(number), "Workspaces", "Mover janela para " + str(number), "Mod+Shift+" + str(number), "umbriel", "window-move-to-workspace:" + str(number)))
for name, chord, action in (
    ("region", "Print", "annotate"), ("window", "Shift+Print", "annotateWindow"),
    ("fullscreen", "Ctrl+Print", "annotateFullscreen"), ("color", "Mod+Print", "colorPicker"),
    ("record", "Mod+Shift+Print", "record"), ("ocr", "Mod+Alt+Print", "ocr"),
):
    CATALOG.append(entry("tool." + name, "Captura", name.title(), chord, "hydra", "screenToolkit " + action))
for name, chord, target, function, repeat in (
    ("volume_up", "XF86AudioRaiseVolume", "volume", "increase", True),
    ("volume_down", "XF86AudioLowerVolume", "volume", "decrease", True),
    ("mute", "XF86AudioMute", "volume", "muteOutput", False),
    ("bright_up", "XF86MonBrightnessUp", "brightness", "increase", True),
    ("bright_down", "XF86MonBrightnessDown", "brightness", "decrease", True),
    ("play", "XF86AudioPlay", "media", "playPause", False),
    ("pause", "XF86AudioPause", "media", "playPause", False),
    ("next", "XF86AudioNext", "media", "next", False),
    ("previous", "XF86AudioPrev", "media", "previous", False),
):
    CATALOG.append(entry("media." + name, "Mídia", name.replace("_", " ").title(), chord, "hydra", target + " " + function, locked=True, repeat=repeat))

XF86_KEYS = {row["chord"].lower(): row["chord"] for row in CATALOG if row["chord"].startswith("XF86")}

MODS = {"super": "Mod", "logo": "Mod", "win": "Mod", "mod": "Mod", "control": "Ctrl", "ctrl": "Ctrl", "alt": "Alt", "shift": "Shift"}
KEYS = {"esc": "Escape", "escape": "Escape", "enter": "Return", "return": "Return", "space": "Space",
        "comma": "Comma", "period": "Period", "print": "Print", "left": "Left", "right": "Right", "up": "Up", "down": "Down",
        "tab": "Tab", "backspace": "BackSpace", "delete": "Delete", "home": "Home", "end": "End", "insert": "Insert",
        "pageup": "Prior", "pagedown": "Next", "prior": "Prior", "next": "Next",
        "wheelup": "WheelUp", "wheeldown": "WheelDown", "wheelleft": "WheelLeft", "wheelright": "WheelRight",
        "mouseleft": "MouseLeft", "mouseright": "MouseRight", "mousemiddle": "MouseMiddle", "mouseback": "MouseBack", "mouseforward": "MouseForward"}


def chord(value):
    parts = [part.strip() for part in value.split("+")]
    if not parts or any(not part for part in parts):
        raise ValueError("Atalho vazio ou incompleto: " + repr(value))
    mods = set()
    keys = []
    for part in parts:
        lower = part.lower()
        if lower in MODS:
            mods.add(MODS[lower])
        elif len(part) == 1 and part.isascii() and part.isalnum():
            keys.append(part.upper())
        elif re.fullmatch(r"f(?:[1-9]|1[0-9]|2[0-4])", lower):
            keys.append(lower.upper())
        elif lower in KEYS or re.fullmatch(r"xf86[a-z0-9]+", lower):
            keys.append(KEYS.get(lower, XF86_KEYS.get(lower, part)))
        else:
            raise ValueError("Tecla não suportada: " + part)
    if len(keys) != 1 or (keys[0].startswith(("Wheel", "Mouse")) and not mods):
        raise ValueError("Escolha uma tecla e modificador para mouse/roda: " + value)
    return "+".join([m for m in ("Mod", "Ctrl", "Alt", "Shift") if m in mods] + keys)


def defaults():
    return {"version": VERSION, "overrides": {}, "custom": []}


EDITABLE = {"chord", "type", "action", "repeat", "allow_when_locked",
            "allow_when_inhibited", "cooldown_ms"}


def migrate_state(state):
    if isinstance(state, dict) and state.get("version") == 1:
        rebinds = state.get("rebinds")
        if not isinstance(rebinds, dict) or not isinstance(state.get("custom"), list):
            raise ValueError("Estado de atalhos V1 inválido")
        state = {"version": VERSION,
                 "overrides": {key: {"chord": value} for key, value in rebinds.items()},
                 "custom": state["custom"]}
    return state


def validate_state(state):
    if (not isinstance(state, dict) or state.get("version") != VERSION
            or not isinstance(state.get("overrides"), dict)
            or not isinstance(state.get("custom"), list)
            or set(state) != {"version", "overrides", "custom"}):
        raise ValueError("Estado de atalhos incompatível ou inválido")
    ids = {row["id"] for row in CATALOG}
    if set(state["overrides"]) - ids:
        raise ValueError("Atalho original desconhecido: " + repr(set(state["overrides"]) - ids))
    used = {}
    result = []
    for row in CATALOG:
        override = state["overrides"].get(row["id"], {})
        if not isinstance(override, dict) or set(override) - EDITABLE:
            raise ValueError("Override de atalho inválido: " + row["id"])
        result.append(dict(row, **override))
    for custom in state["custom"]:
        if not isinstance(custom, dict):
            raise ValueError("Atalho personalizado inválido")
        result.append(custom)
    # A newly introduced default must not take a chord already owned by a
    # personal bind. Explicit switcher overrides still obey normal conflicts.
    result = [row for row in result if not (
        row.get("id") in ("shell.switcher", "shell.switcher.previous")
        and row["id"] not in state["overrides"]
        and any(other is not row and chord(other.get("chord", "")) == chord(row["chord"])
                for other in result))]
    for row in result:
        value = chord(row.get("chord", ""))
        if value in used:
            raise ValueError("Conflito em " + value + ": " + used[value] + " / " + row.get("label", "sem descrição"))
        used[value] = row.get("label", "sem descrição")
        kind, action = row.get("type"), row.get("action", "")
        if kind == "hydra":
            parts = action.split()
            if len(parts) != 2 or parts[0] not in IPC or parts[1] not in IPC[parts[0]]:
                raise ValueError("IPC Hydra desconhecido: " + action)
        elif kind == "command":
            if not isinstance(action, str) or not action.strip() or "\n" in action or "\r" in action:
                raise ValueError("Comando vazio ou com quebras de linha")
        elif kind == "umbriel":
            if (not isinstance(action, str) or not re.fullmatch(r"[a-z][a-z0-9-]*(?::[^\r\n]+)?", action)
                    or action.endswith((':', '/'))):
                raise ValueError("Ação Umbriel inválida: " + str(action))
        else:
            raise ValueError("Tipo de ação inválido: " + str(kind))
        for field in ("repeat", "allow_when_locked", "allow_when_inhibited"):
            if type(row.get(field, False)) is not bool:
                raise ValueError("Opção inválida: " + field)
        cooldown = row.get("cooldown_ms", 0)
        if type(cooldown) is not int or not 0 <= cooldown <= 3600000:
            raise ValueError("cooldown_ms fora do intervalo")
    return result


def app_id_to_scratchpad_name(app_id):
    slug = str(app_id or "").lower().strip()
    if slug.endswith(".desktop"):
        slug = slug[:-8]
    slug = re.sub(r"[^a-z0-9_-]+", "-", slug).strip("-")
    return f"hydra-edge-{slug}" if slug else "hydra-edge-app"


def get_edge_apps():
    config_home = Path(os.environ.get("HYDRA_CONFIG_DIR", os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config")) + "/hydra"))
    settings_file = config_home / "settings.json"
    if not settings_file.exists():
        return []
    try:
        data = json.loads(settings_file.read_text(encoding="utf-8"))
        pinned = data.get("edgeShelf", {}).get("pinnedApps", [])
        return [str(p) for p in pinned if p]
    except Exception:
        return []


def generate(state, edge_apps=None):
    rows = validate_state(state)
    if edge_apps is None:
        edge_apps = get_edge_apps()

    lines = ["# Gerado pela Hydra. Edite em Configurações → Umbriel → Atalhos.", ""]

    # Always define hydra-default scratchpad
    lines.append("[[scratchpad]]")
    lines.append('name = "hydra-default"')
    lines.append("")

    # Emit each distinct edge app scratchpad
    seen_scratchpads = {"hydra-default"}
    for app_id in edge_apps:
        sp_name = app_id_to_scratchpad_name(app_id)
        if sp_name not in seen_scratchpads:
            seen_scratchpads.add(sp_name)
            lines.append("[[scratchpad]]")
            lines.append(f'name = "{sp_name}"')
            lines.append("")

    lines.append("[keybinds]")
    for row in rows:
        action = row["action"] if row["type"] == "umbriel" else "spawn:" + ("qs -c hydra-shell ipc call " + row["action"] if row["type"] == "hydra" else row["action"])
        values = ["action = " + json.dumps(action, ensure_ascii=False),
                  "repeat = " + str(row.get("repeat", False)).lower()]
        for field in ("allow_when_locked", "allow_when_inhibited"):
            if row.get(field, False):
                values.append(field + " = true")
        if row.get("cooldown_ms", 0):
            values.append("cooldown_ms = " + str(row["cooldown_ms"]))
        lines.append(json.dumps(chord(row["chord"])) + " = { " + ", ".join(values) + " }")
    return "\n".join(lines) + "\n"


CONFIG_DIR = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "umbriel"
MASTER = CONFIG_DIR / "config.toml"
OWNED = CONFIG_DIR / "hydra" / "keybinds.toml"
STATE = CONFIG_DIR / "hydra" / "keybinds.json"
INCLUDE = "hydra/keybinds.toml"


def with_include(master, included):
    """Add Hydra's include and autostart without changing unrelated TOML."""
    data = tomllib.loads(master)
    if "keybinds" in data:
        raise ValueError("config.toml já define [keybinds]; mova atalhos próprios para o editor da Hydra antes de adotar")
    includes = data.get("include", {})
    if not isinstance(includes, dict):
        raise ValueError("[include] inválido")
    files = includes.get("files", [])
    if not isinstance(files, list) or any(not isinstance(item, str) for item in files):
        raise ValueError("[include].files inválido")
    seen = [f for f in files if f == INCLUDE]
    if len(seen) > 1:
        raise ValueError("Include Hydra duplicado")
    replacement = [f for f in files if f != INCLUDE] + [included]
    block = "files = " + json.dumps(replacement, ensure_ascii=False)
    # A fresh installation must start Hydra on the next Umbriel session too.
    general = data.get("general", {})
    if not isinstance(general, dict):
        raise ValueError("[general] inválido")
    autostart = general.get("autostart", [])
    if not isinstance(autostart, list) or any(not isinstance(item, str) for item in autostart):
        raise ValueError("[general].autostart inválido")
    if not any("qs -c hydra-shell" in item for item in autostart):
        general_section = re.search(r"(?m)^\[general\]\s*(?:\#.*)?$", master)
        new_line = "autostart = " + json.dumps(autostart + ["qs -c hydra-shell -d"])
        if general_section:
            end = re.search(r"(?m)^\[", master[general_section.end():])
            boundary = general_section.end() + end.start() if end else len(master)
            contents = master[general_section.end():boundary]
            if "autostart" in general:
                match = re.search(r"(?m)^autostart\s*=\s*\[(?:[^\]\"]|\"(?:\\.|[^\"])*\")*\]", contents)
                if not match:
                    raise ValueError("Não foi possível editar [general].autostart com segurança")
                contents = contents[:match.start()] + new_line + contents[match.end():]
            else:
                contents = "\n" + new_line + contents
            master = master[:general_section.end()] + contents + master[boundary:]
        elif "general" in data:
            raise ValueError("Não foi possível editar [general] com segurança")
        else:
            master = master.rstrip() + "\n\n[general]\n" + new_line + "\n"
    section = re.search(r"(?m)^\[include\]\s*(?:\#.*)?$", master)
    if section:
        end = re.search(r"(?m)^\[", master[section.end():])
        boundary = section.end() + end.start() if end else len(master)
        contents = master[section.end():boundary]
        pattern = r"(?m)^files\s*=\s*\[(?:[^\]\"]|\"(?:\\.|[^\"])*\")*\]"
        matches = list(re.finditer(pattern, contents))
        if "files" in includes and len(matches) != 1:
            raise ValueError("Não foi possível editar [include].files com segurança")
        if matches:
            match = matches[0]
            contents = contents[:match.start()] + block + contents[match.end():]
        else:
            contents = "\n" + block + contents
        return master[:section.end()] + contents + master[boundary:]
    return master.rstrip() + "\n\n[include]\n" + block + "\n"


def atomic(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent, prefix=".hydra-", suffix=".tmp", delete=False) as stream:
        temp = Path(stream.name)
        if path.exists():
            os.fchmod(stream.fileno(), path.stat().st_mode & 0o777)
        stream.write(text)
        stream.flush()
        os.fsync(stream.fileno())
    try:
        os.replace(temp, path)
    finally:
        temp.unlink(missing_ok=True)


def commit(state, edge_apps=None, expected_state=None):
    generated = generate(state, edge_apps=edge_apps)
    if MASTER.is_symlink() or OWNED.is_symlink() or STATE.is_symlink():
        raise ValueError("Recusando substituir configuração Umbriel por link simbólico")
    OWNED.parent.mkdir(parents=True, exist_ok=True)
    with (OWNED.parent / ".config.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        _commit_locked(state, generated, expected_state)


def _commit_locked(state, generated, expected_state):
    had_master = MASTER.exists()
    old_master = MASTER.read_text() if had_master else '[general]\nautostart = ["qs -c hydra-shell -d"]\n'
    old_owned = OWNED.read_text() if OWNED.exists() else None
    old_state = STATE.read_text() if STATE.exists() else None
    if expected_state is not None:
        current = migrate_state(json.loads(old_state)) if old_state is not None else defaults()
        if current != expected_state:
            raise ValueError("Atalhos Umbriel mudaram desde a leitura; recarregue a página")
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=OWNED.parent, prefix=".hydra-binds-", suffix=".toml", delete=False) as stream:
        staged_binds = Path(stream.name)
        stream.write(generated)
    staged_master = None
    final_master = old_master
    saved_state = json.dumps(state, ensure_ascii=False, indent=2) + "\n"
    try:
        final_master = with_include(old_master, INCLUDE)
        from umbriel_config import settings_sources
        owners, sources = settings_sources(old_master, CONFIG_DIR, ('keybinds',), 'keybinds.toml')
        if owners:
            raise ValueError("Atalhos Umbriel controlados externamente: " + ", ".join(owners))
        staged_text = with_include(old_master, "hydra/" + staged_binds.name)
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=CONFIG_DIR, prefix=".hydra-check-", suffix=".toml", delete=False) as stream:
            staged_master = Path(stream.name)
            stream.write(staged_text)
        result = subprocess.run(["umbriel", "config", "validate", "-c", str(staged_master)], capture_output=True, text=True)
        if result.returncode:
            raise ValueError((result.stderr or result.stdout).strip() or "umbriel config validate falhou")
        if (MASTER.read_text() if MASTER.exists() else None) != (old_master if had_master else None):
            raise ValueError("config.toml mudou durante a validação; tente novamente")
        if (OWNED.read_text() if OWNED.exists() else None) != old_owned:
            raise ValueError("keybinds.toml mudou durante a validação; tente novamente")
        if settings_sources(old_master, CONFIG_DIR, ('keybinds',), 'keybinds.toml') != (owners, sources):
            raise ValueError("Um include Umbriel mudou durante a validação; tente novamente")
        if (STATE.read_text() if STATE.exists() else None) != old_state:
            raise ValueError("keybinds.json mudou durante a validação; tente novamente")
        atomic(OWNED, generated)
        if not had_master or final_master != old_master:
            atomic(MASTER, final_master)
        atomic(STATE, saved_state)
        result = subprocess.run(["umbriel", "msg", "config-reload"], capture_output=True, text=True)
        if result.returncode:
            raise ValueError((result.stderr or result.stdout).strip() or "Umbriel reload falhou")
    except Exception:
        if OWNED.exists() and OWNED.read_text() == generated:
            if old_owned is None:
                OWNED.unlink()
            else:
                atomic(OWNED, old_owned)
        if MASTER.exists() and MASTER.read_text() == final_master and (not had_master or final_master != old_master):
            if had_master:
                atomic(MASTER, old_master)
            else:
                MASTER.unlink()
        if STATE.exists() and STATE.read_text() == saved_state:
            if old_state is None:
                STATE.unlink()
            else:
                atomic(STATE, old_state)
        raise
    finally:
        staged_binds.unlink(missing_ok=True)
        if staged_master:
            staged_master.unlink(missing_ok=True)

def current_state():
    if not STATE.exists():
        return defaults()
    state = migrate_state(json.loads(STATE.read_text()))
    validate_state(state)
    return state


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else "state"
    if command == "provision":
        state = current_state()
        master = MASTER.read_text() if MASTER.exists() else ""
        if (not STATE.exists() or json.loads(STATE.read_text()).get("version") != VERSION or not OWNED.exists()
                or OWNED.read_text() != generate(state)
                or with_include(master, INCLUDE) != master):
            commit(state)
    elif command == "save":
        commit(migrate_state(json.loads(sys.argv[2])),
               expected_state=json.loads(sys.argv[3]) if len(sys.argv) > 3 else None)
    elif command == "sync":
        edge_apps = json.loads(sys.argv[2]) if len(sys.argv) > 2 else None
        state = current_state()
        commit(state, edge_apps=edge_apps)
    elif command == "state":
        print(json.dumps({"catalog": CATALOG, "state": current_state(), "ipc": IPC}, ensure_ascii=False))
    else:
        raise ValueError("Comando desconhecido: " + command)
    if command != "state":
        print(json.dumps({"ok": True}, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.SubprocessError, tomllib.TOMLDecodeError, json.JSONDecodeError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
