#!/usr/bin/env python3
"""Portal chooser UI bridge. The official backend retains all capture ownership."""
import json
import os
from pathlib import Path
import shutil
import signal
import socket
import struct
import subprocess
import sys
import tempfile
import uuid


def official_picker():
    found = shutil.which('umbriel-share-picker')
    if found:
        return found
    # Package manifests resolve distro-specific libexec locations without pinning one.
    for command in (['pacman', '-Ql', 'xdg-desktop-portal-umbriel'],
                    ['dpkg-query', '-L', 'xdg-desktop-portal-umbriel'],
                    ['rpm', '-ql', 'xdg-desktop-portal-umbriel']):
        if not shutil.which(command[0]):
            continue
        result = subprocess.run(command, capture_output=True, text=True, timeout=3)
        for line in result.stdout.splitlines():
            candidate = line.split()[-1] if line.split() else ''
            if Path(candidate).name == 'umbriel-share-picker' and os.access(candidate, os.X_OK):
                return candidate
    for prefix in ('/usr', '/usr/local'):
        for directory in ('libexec', 'lib'):
            candidate = f'{prefix}/{directory}/umbriel-share-picker'
            if os.access(candidate, os.X_OK):
                return candidate
    raise OSError('Official umbriel-share-picker is not installed')


def validate_request(request):
    if not isinstance(request, dict) or type(request.get('multiple')) is not bool:
        raise ValueError('Invalid chooser request')
    types = request.get('types')
    if not isinstance(types, list) or any(kind not in ('monitor', 'window') for kind in types):
        raise ValueError('Invalid source types')
    for collection, key in (('outputs', 'name'), ('windows', 'identifier')):
        if not isinstance(request.get(collection), list):
            raise ValueError('Missing source list')
        if any(not isinstance(row, dict) or not isinstance(row.get(key), str) or not row[key]
               for row in request[collection]):
            raise ValueError('Invalid source identity')
    return request


def validate_response(request, response):
    selections = response.get('selections') if isinstance(response, dict) else None
    if not isinstance(selections, list) or (not request['multiple'] and len(selections) > 1):
        raise ValueError('Invalid selection count')
    allowed = {('monitor', row['name']) for row in request['outputs'] if 'monitor' in request['types']}
    allowed |= {('window', row['identifier']) for row in request['windows'] if 'window' in request['types']}
    seen = set()
    result = []
    for row in selections:
        if not isinstance(row, dict):
            raise ValueError('Invalid selection')
        kind = row.get('kind')
        key = 'output' if kind == 'monitor' else 'identifier'
        if not isinstance(kind, str) or not isinstance(row.get(key), str):
            raise ValueError('Invalid source identity')
        identity = (kind, row.get(key))
        if identity not in allowed or identity in seen:
            raise ValueError('Unknown or duplicate source')
        seen.add(identity)
        result.append({'kind': kind, key: identity[1]})
    return {'selections': result}


def ipc_args():
    # Preview callers can target their exact isolated instance, never the live shell.
    path = os.environ.get('HYDRA_SHARE_PICKER_CONFIG_PATH')
    return ['qs', '-p', path] if path else ['qs', '-c', 'hydra-shell']


def choose(request):
    runtime = os.environ.get('XDG_RUNTIME_DIR', '')
    info = os.stat(runtime)
    if not Path(runtime).is_absolute() or info.st_uid != os.getuid() or info.st_mode & 0o077:
        raise OSError('A private XDG_RUNTIME_DIR is required')
    with tempfile.TemporaryDirectory(prefix='hydra-share-', dir=runtime) as temporary:
        path = str(Path(temporary) / 'chooser.sock')
        token = uuid.uuid4().hex
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as listener:
            listener.bind(path)
            os.chmod(path, 0o600)
            listener.listen(1)
            listener.settimeout(3)
            result = subprocess.run(ipc_args() + ['ipc', 'call', 'screenshare', 'open', path, token],
                                    capture_output=True, text=True, timeout=2)
            if result.returncode or result.stdout.strip() != 'ok':
                raise OSError('Hydra did not accept the request')
            with listener.accept()[0] as connection:
                _, uid, _ = struct.unpack('3i', connection.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, 12))
                if uid != os.getuid():
                    raise OSError('Unexpected chooser peer')
                connection.settimeout(6)
                connection.sendall((json.dumps({'token': token, 'request': request}) + '\n').encode())
                buffered = b''
                while True:
                    chunk = connection.recv(65536)
                    if not chunk:
                        raise OSError('Hydra disconnected before selecting')
                    buffered += chunk
                    if len(buffered) > 1024 * 1024:
                        raise ValueError('Chooser response too large')
                    while b'\n' in buffered:
                        line, buffered = buffered.split(b'\n', 1)
                        message = json.loads(line)
                        if not isinstance(message, dict) or message.get('token') != token:
                            raise ValueError('Wrong chooser request token')
                        if message.get('alive') is True:
                            continue
                        return validate_response(request, message)


def fallback(raw):
    child = subprocess.Popen([official_picker()], stdin=subprocess.PIPE, start_new_session=True)
    try:
        child.communicate(raw)
        # Never expose 127: the portal would silently select its first output.
        return 0 if child.returncode == 0 else 1
    except BaseException:
        # Signal only the child explicitly created by this helper, never a group.
        child.terminate()
        try:
            child.wait(timeout=1)
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait()
        raise


def main():
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(1))
    signal.signal(signal.SIGINT, lambda *_: sys.exit(1))
    raw = sys.stdin.buffer.read()
    request = validate_request(json.loads(raw))
    try:
        response = choose(request)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print('hydra-share-picker: ' + str(error) + '; using official picker', file=sys.stderr)
        return fallback(raw)
    print(json.dumps(response, separators=(',', ':')), flush=True)
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print('hydra-share-picker: ' + str(error), file=sys.stderr)
        sys.exit(1)
