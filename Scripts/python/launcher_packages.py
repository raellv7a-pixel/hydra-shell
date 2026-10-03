#!/usr/bin/env python3
"""Read-only Launcher package metadata; bounded cancellation and an atomic cache."""

import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time

SCHEMA = 1
TTL_SECONDS = 30 * 60
BACKENDS = {"Packages": "standard", "Aur": "aur", "AppImage": "appimage", "Flatpak": "flatpak"}
_child = None
_cancelled = False


def cancel_scan(signum, frame):
    global _cancelled
    _cancelled = True
    if _child is not None:
        stop_child(_child)


def stop_child(child):
    # Shelly can spawn backend helpers. Reaping its leader alone is insufficient.
    try:
        os.killpg(child.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        child.wait(timeout=2)
    except subprocess.TimeoutExpired:
        pass
    try:
        os.killpg(child.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    child.wait()


def run_command(command, *, optional=False):
    global _child
    if _cancelled:
        raise InterruptedError("Scanner cancelled")
    try:
        _child = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                  text=True, start_new_session=True)
    except FileNotFoundError:
        if optional:
            return ""
        raise
    try:
        if _cancelled:
            stop_child(_child)
            raise InterruptedError("Scanner cancelled")
        out, err = _child.communicate()
        if _cancelled:
            raise InterruptedError("Scanner cancelled")
        if _child.returncode:
            if optional:
                return ""
            raise RuntimeError(err.strip() or out.strip() or f"{command[0]} exited {_child.returncode}")
        return out
    finally:
        _child = None


def normalize_id(value):
    return str(value or "").lower().removesuffix(".desktop").strip()


def valid_name(name):
    return isinstance(name, str) and re.fullmatch(r"[A-Za-z0-9@_+][A-Za-z0-9@._+\-]*", name) is not None


def record(raw, backend):
    name = (raw.get("ApplicationId") or raw.get("AppId")) if backend == "flatpak" else None
    name = name or raw.get("Name") or raw.get("name")
    if not valid_name(name):
        raise ValueError("Invalid package identity")
    aliases = {normalize_id(raw.get(key)) for key in
               ("Name", "DesktopName", "PackageBase", "ApplicationId", "AppId")}
    return {"type": backend, "name": name,
            "version": str(raw.get("NewVersion") or raw.get("Version") or raw.get("LatestVersion") or ""),
            "currentVersion": str(raw.get("CurrentVersion") or raw.get("InstalledVersion") or ""),
            "aliases": sorted(aliases - {""})}


def update_records(payload):
    if not isinstance(payload, dict) or not any(key in payload for key in BACKENDS):
        raise ValueError("Invalid Shelly update response")
    result = []
    for key, backend in BACKENDS.items():
        values = payload.get(key) or []
        if not isinstance(values, list) or any(not isinstance(value, dict) for value in values):
            raise ValueError("Invalid Shelly update records")
        result.extend(record(value, backend) for value in values)
    return result


def load_cache(path, now=None):
    now = time.time() if now is None else now
    try:
        data = json.loads(Path(path).read_text())
        stamp = data["timestamp"]
        if (type(data["schema"]) is not int or data["schema"] != SCHEMA or isinstance(stamp, bool) or
                not isinstance(stamp, (int, float)) or not 0 < stamp <= now + 300 or
                not isinstance(data["updates"], list)):
            raise ValueError("Invalid cache header")
        for entry in data["updates"]:
            if (entry["type"] not in BACKENDS.values() or not valid_name(entry["name"]) or
                    not isinstance(entry["aliases"], list) or
                    any(not isinstance(alias, str) for alias in entry["aliases"]) or
                    not isinstance(entry["version"], str) or
                    not isinstance(entry["currentVersion"], str)):
                raise ValueError("Invalid cached package")
        # Copy the allowlisted fields; never propagate arbitrary cached commands.
        updates = [{key: entry[key] for key in ("type", "name", "version", "currentVersion", "aliases")}
                   for entry in data["updates"]]
        return {"timestamp": stamp, "updates": updates, "fresh": now - stamp < TTL_SECONDS}
    except (OSError, ValueError, KeyError, TypeError):
        return {"timestamp": 0, "updates": [], "fresh": False}


def save_cache(path, updates, timestamp):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, staged = tempfile.mkstemp(prefix=path.name + ".", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump({"schema": SCHEMA, "timestamp": timestamp, "updates": updates}, stream)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(staged, path)
    finally:
        if os.path.exists(staged):
            os.unlink(staged)


def application_dirs():
    home = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share")))
    return [home / "applications"] + [Path(value) / "applications" for value in
           os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":") if value]


def native_packages(files, versions, foreign, dirs):
    """Map the winning desktop file to its ALPM owner; local overrides aren't owners."""
    result = {}
    for line in files.splitlines():
        parts = line.split(" ", 1)
        if len(parts) != 2:
            continue
        owner, filename = parts
        path = Path(filename)
        if path.suffix != ".desktop" or not valid_name(owner):
            continue
        for directory in dirs:
            try:
                relative = path.relative_to(directory)
            except ValueError:
                continue
            # XDG precedence can replace a packaged desktop with an unmanaged copy.
            winning = next((base / relative for base in dirs if (base / relative).is_file()), None)
            if winning is not None and winning.resolve() == path.resolve():
                identity = normalize_id("-".join(relative.parts))
                result[identity] = {"name": owner, "type": "aur" if owner in foreign else "standard",
                                    "currentVersion": versions.get(owner, "")}
            break
    return result


def flatpak_packages(output):
    result = {}
    for line in output.splitlines():
        identity, _, version = line.partition("\t")
        if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_-]*(\.[A-Za-z_][A-Za-z0-9_-]*){2,}", identity):
            result[identity] = {"name": identity, "type": "flatpak", "currentVersion": version.strip()}
    return result


def installed_packages():
    versions = dict(line.split(" ", 1) for line in run_command(["pacman", "-Q"], optional=True).splitlines()
                    if " " in line)
    foreign = set(run_command(["pacman", "-Qmq"], optional=True).splitlines())
    files = run_command(["pacman", "-Ql"], optional=True)
    native = native_packages(files, versions, foreign, application_dirs())
    appimages = []
    output = run_command(["shelly", "list", "appimage", "--json"], optional=True)
    if output:
        try:
            appimages = [record(value, "appimage") for value in json.loads(output)]
            for item in appimages:
                item["currentVersion"] = item["currentVersion"] or item["version"]
        except (ValueError, TypeError, AttributeError):
            pass
    flatpak = flatpak_packages(run_command(["flatpak", "list", "--app", "--columns=application:f,version:f"], optional=True))
    return {"native": native, "appimages": appimages, "flatpak": flatpak}


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    action, cache = argv
    signal.signal(signal.SIGTERM, cancel_scan)
    signal.signal(signal.SIGINT, cancel_scan)
    available = shutil.which("shelly") is not None
    if action == "bootstrap":
        result = load_cache(cache)
    elif action == "scan":
        updates = update_records(json.loads(run_command(["shelly", "list-updates", "all", "--json"])))
        result = {"timestamp": time.time(), "updates": updates, "fresh": True}
    else:
        raise ValueError("Unknown metadata action")
    result["available"] = available
    result["installed"] = installed_packages()
    if _cancelled:
        raise InterruptedError("Scanner cancelled")
    if action == "scan":
        save_cache(cache, result["updates"], result["timestamp"])
    print(json.dumps(result))


if __name__ == "__main__":
    try:
        main()
    except InterruptedError:
        sys.exit(130)
    except (OSError, ValueError, RuntimeError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
