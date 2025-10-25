#!/usr/bin/env bash
# /usr/libexec/kaleidos/ly-session-verify.sh
# PAM-executed helper: deny login if user-selected session != user's locked session.
set -euo pipefail

# PAM_USER is provided by PAM. Fallback to UID lookup if absent.
user="${PAM_USER:-}"
ses="${XDG_SESSION_DESKTOP:-${DESKTOP_SESSION:-${LY_SESSION:-}}}"

expected=""
if [[ -n "$user" && -f "/home/$user/.dmrc" ]]; then
  expected="$(awk -F= '/^Session=/{print $2}' "/home/$user/.dmrc" 2>/dev/null || true)"
fi

if [[ -n "$expected" && -n "$ses" && "$ses" != "$expected" ]]; then
  echo "Login denied: $user is locked to session '$expected' (selected: '$ses')" >&2
  exit 1
fi

exit 0