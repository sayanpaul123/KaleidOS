#!/usr/bin/env bash
set -euo pipefail
user="${PAM_USER:-}"
ses="${XDG_SESSION_DESKTOP:-${DESKTOP_SESSION:-${LY_SESSION:-}}}"
expected=""
[[ -n "$user" && -f "/home/$user/.dmrc" ]] && expected="$(awk -F= '/^Session=/{print $2}' "/home/$user/.dmrc" 2>/dev/null || true)"
if [[ -n "$expected" && -n "$ses" && "$ses" != "$expected" ]]; then
  echo "Denied: $user is locked to session '$expected' (got '$ses')" >&2
  exit 1
fi
exit 0