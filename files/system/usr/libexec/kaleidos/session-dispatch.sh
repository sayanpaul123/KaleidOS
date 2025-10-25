#!/usr/bin/env bash
# Dispatcher: reads locked DE from ~/.dmrc or AccountsService, then launches it.

set -euo pipefail
USER_NAME="${USER:-$(id -un)}"
HOME_DIR="$(getent passwd "$USER_NAME" | cut -d: -f6)"
DMRC="$HOME_DIR/.dmrc"
SESSION_ID=""

read_dmrc() {
  [[ -f "$DMRC" ]] && SESSION_ID="$(awk -F= '/^Session=/{print $2}' "$DMRC" 2>/dev/null || true)"
}

read_accountsservice() {
  local f="/var/lib/AccountsService/users/$USER_NAME"
  [[ -z "$SESSION_ID" && -f "$f" ]] && SESSION_ID="$(awk -F= '/^(XSession|Session)=/{print $2}' "$f" | head -n1)"
}

read_dmrc
read_accountsservice

if [[ -z "$SESSION_ID" ]]; then
  echo "No locked DE for $USER_NAME. Run de-user-add first." >&2
  exit 1
fi

sid="$(echo "$SESSION_ID" | tr '[:upper:]' '[:lower:]')"

launch() {
  exec env XDG_SESSION_DESKTOP="$sid" XDG_CURRENT_DESKTOP="$sid" "$@"
}

case "$sid" in
  gnome|gnome-wayland)
    launch dbus-run-session gnome-session
    ;;
  plasma|kde|plasma-wayland)
    launch startplasma-wayland
    ;;
  xfce|xfce4)
    launch startxfce4
    ;;
  pantheon|io.elementary.session)
    # Adjust to your actual session binary when packaging Pantheon
    if command -v io.elementary.session >/dev/null 2>&1; then
      launch dbus-run-session io.elementary.session
    else
      launch dbus-run-session bash -lc 'gala --replace & wingpanel & plank & switchboard & wait'
    fi
    ;;
  sway|wlroots)
    launch sway
    ;;
  *)
    echo "Unknown session $sid for user $USER_NAME" >&2
    exit 1
    ;;
esac