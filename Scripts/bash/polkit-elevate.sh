#!/usr/bin/env bash
# Privilege-escalation helper for tools the shell runs on the user's behalf
# (Shelly package operations, via SHELLY_ELEVATOR).
#
# Plain `pkexec` cannot be used here. Before it consults the session's polkit
# agent, pkexec unconditionally builds its own *internal textual* agent, which
# opens /dev/tty — and a process spawned by the shell has no controlling
# terminal, so that fails and pkexec aborts with
#
#   Error creating textual authentication agent: Error opening current
#   controlling terminal for the process (`/dev/tty'): No such device or address
#
# even though a perfectly good graphical agent is registered. --disable-internal-agent
# skips that fallback, so the request reaches the session agent (the shell's own
# polkit dialog) and the password is asked for on screen.
set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "usage: ${0##*/} <program> [args...]" >&2
  exit 2
fi

exec pkexec --disable-internal-agent "$@"
