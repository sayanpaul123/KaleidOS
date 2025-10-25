#!/usr/bin/env bash
set -euo pipefail

USER_NAME="${PAM_USER:-}"
[[ -n "$USER_NAME" ]] || exit 1

home_dir="$(getent passwd "$USER_NAME" | cut -d: -f6 || true)"
: "${home_dir:="/home/$USER_NAME"}"

dmrc="$home_dir/.dmrc"

# Must exist and contain a 'Session=' line
if [[ -r "$dmrc" ]] && grep -q '^Session=' -- "$dmrc"; then
  exit 0
fi

exit 1