#!/usr/bin/env python3
"""Hydra-owned Umbriel keybind catalogue, validated config writer and CLI for Settings."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import tomllib

VERSION = 1
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
}


def entry(id, category, label, chord, kind, action, *, repeat=False, locked=False, inhibited=False, cooldown=0):
    return dict(id=id, category=category, label=label, chord=chord, type=kind,
                action=action, repeat=repeat, allow_when_locked=locked,
                allow_when_inhibited=inhibited, cooldown_ms=cooldown)


CATALOG = [
    entry("shell.launcher", "Hydra", "Lançador", "Mod+Space", "hydra", "launcher toggle"),
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
    entry("umbriel.scratchpad", "Umbriel", "Mostrar scratchpad", "Mod+Alt+Space", "umbriel", "scratchpad-toggle"),
    entry("umbriel.scratchpad_move", "Umbriel", "Mover ao scratchpad", "Mod+Shift+Space", "umbriel", "window-move-to-scratchpad"),
    entry("umbriel.scratchpad_next", "Umbriel", "Próximo no scratchpad", "Mod+Tab", "umbriel", "scratchpad-focus-next"),
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
    return {"version": VERSION, "rebinds": {}, "custom": []}


def validate_state(state):
    if not isinstance(state, dict) or state.get("version") != VERSION or not isinstance(state.get("rebinds"), dict) or not isinstance(state.get("custom"), list):
        raise ValueError("Estado de atalhos incompatível ou inválido")
    ids = {row["id"] for row in CATALOG}
    if set(state["rebinds"]) - ids:
        raise ValueError("Atalho original desconhecido: " + repr(set(state["rebinds"]) - ids))
    used = {}
    result = []
    for row in CATALOG:
        current = chord(state["rebinds"].get(row["id"], row["chord"]))
        result.append(dict(row, chord=current))
    for custom in state["custom"]:
        if not isinstance(custom, dict):
            raise ValueError("Atalho personalizado inválido")
        result.append(custom)
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
            if not isinstance(action, str) or not re.fullmatch(r"[a-z][a-z0-9-]*(?::[a-zA-Z0-9_./-]+)?", action):
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


def generate(state):
    rows = validate_state(state)
    lines = ["# Gerado pela Hydra. Edite em Configurações → Umbriel → Atalhos.", "[keybinds]"]
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


def commit(state):
    generated = generate(state)
    had_master = MASTER.exists()
    old_master = MASTER.read_text() if had_master else '[general]\nautostart = ["qs -c hydra-shell -d"]\n'
    old_owned = OWNED.read_text() if OWNED.exists() else None
    # Validate a staged root and staged include in their real parent directories.
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    OWNED.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=OWNED.parent, prefix=".hydra-binds-", suffix=".toml", delete=False) as binds_stream:
        staged_binds = Path(binds_stream.name)
        binds_stream.write(generated)
    staged_master = None
    final_master = old_master
    try:
        final_master = with_include(old_master, INCLUDE)
        staged_text = with_include(old_master, "hydra/" + staged_binds.name)
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=CONFIG_DIR, prefix=".hydra-check-", suffix=".toml", delete=False) as master_stream:
            staged_master = Path(master_stream.name)
            master_stream.write(staged_text)
        result = subprocess.run(["umbriel", "config", "validate", "-c", str(staged_master)], capture_output=True, text=True)
        if result.returncode:
            raise ValueError((result.stderr or result.stdout).strip() or "umbriel config validate falhou")
        if MASTER.exists() and MASTER.read_text() != old_master:
            raise ValueError("config.toml mudou durante a validação; tente novamente")
        if old_owned is not None and OWNED.read_text() != old_owned:
            raise ValueError("keybinds.toml mudou durante a validação; tente novamente")
        atomic(OWNED, generated)
        if not MASTER.exists() or final_master != old_master:
            atomic(MASTER, final_master)
        atomic(STATE, json.dumps(state, ensure_ascii=False, indent=2) + "\n")
    except Exception:
        if OWNED.exists() and OWNED.read_text() == generated:
            if old_owned is None:
                OWNED.unlink()
            else:
                atomic(OWNED, old_owned)
        if MASTER.exists() and MASTER.read_text() == final_master and final_master != old_master:
            if had_master:
                atomic(MASTER, old_master)
            else:
                MASTER.unlink()
        raise
    finally:
        staged_binds.unlink(missing_ok=True)
        if staged_master:
            staged_master.unlink(missing_ok=True)


def current_state():
    if not STATE.exists():
        return defaults()
    state = json.loads(STATE.read_text())
    validate_state(state)
    return state


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else "state"
    if command == "provision":
        state = current_state()
        master = MASTER.read_text() if MASTER.exists() else ""
        if (not STATE.exists() or not OWNED.exists()
                or OWNED.read_text() != generate(state)
                or with_include(master, INCLUDE) != master):
            commit(state)
    elif command == "save":
        commit(json.loads(sys.argv[2]))
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
