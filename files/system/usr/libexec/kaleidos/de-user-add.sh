#!/usr/bin/env bash
set -euo pipefail

require_root(){ [[ $EUID -eq 0 ]] || { echo "Run as root"; exit 1; }; }
have_cmd(){ command -v "$1" >/dev/null 2>&1; }

pick_de(){
  local -a items=() f key name
  shopt -s nullglob
  for f in /usr/share/xsessions/*.desktop /usr/share/wayland-sessions/*.desktop; do
    key="$(basename "$f" .desktop)"
    name="$(grep -m1 '^Name=' "$f" | cut -d= -f2- || echo "$key")"
    items+=("$key" "$name")
  done
  shopt -u nullglob
  (( ${#items[@]} )) || { echo "No sessions found"; exit 1; }

  if have_cmd dialog; then
    exec 3>&1
    local chosen
    chosen=$(dialog --backtitle "DE User Creator" --menu "Select Desktop" 15 70 8 "${items[@]}" 2>&1 1>&3) || { echo "Cancelled"; exit 1; }
    exec 3>&- ; echo "$chosen"
  else
    local i n idx
    for ((i=0;i<${#items[@]};i+=2)); do printf " %2d) %-18s %s\n" "$((i/2+1))" "${items[i]}" "${items[i+1]}"; done
    read -rp "Enter number: " n
    [[ "$n" =~ ^[0-9]+$ ]] || { echo "Invalid"; exit 1; }
    idx=$(( (n-1)*2 ))
    [[ $idx -ge 0 && $idx -lt ${#items[@]} ]] || { echo "Out of range"; exit 1; }
    echo "${items[idx]}"
  fi
}

prompt_userpass(){
  local u p1 p2
  while :; do
    read -rp "New username (lowercase, no spaces): " u
    [[ "$u" =~ ^[a-z_][a-z0-9_-]*$ ]] || { echo "Invalid username."; continue; }
    id "$u" &>/dev/null && { echo "User exists."; continue; }
    break
  done
  if have_cmd dialog; then
    exec 3>&1
    p1=$(dialog --insecure --passwordbox "Set password for $u" 10 60 2>&1 1>&3) || { echo "Cancelled"; exit 1; }
    exec 3>&-
    exec 3>&1
    p2=$(dialog --insecure --passwordbox "Confirm password" 10 60 2>&1 1>&3) || { echo "Cancelled"; exit 1; }
    exec 3>&-
  else
    read -srp "Password: " p1; echo
    read -srp "Confirm : " p2; echo
  fi
  [[ "$p1" == "$p2" ]] || { echo "Passwords do not match"; exit 1; }
  echo "$u:$p1"
}

write_dmrc(){
  local user="$1" session="$2"
  install -d -m 700 -o "$user" -g "$user" "/home/$user"
  cat > "/home/$user/.dmrc" <<EOF
[Desktop]
Session=$session
EOF
  chown "$user:$user" "/home/$user/.dmrc"
  chmod 600 "/home/$user/.dmrc"
  chattr +i "/home/$user/.dmrc" || true
}

write_accounts(){
  local user="$1" session="$2" f="/var/lib/AccountsService/users/$user"
  install -d -m 755 /var/lib/AccountsService/users
  cat > "$f" <<EOF
[User]
XSession=$session
Session=$session
SystemAccount=false
EOF
  chmod 644 "$f"
  chattr +i "$f" || true
}

lock_store_access(){
  local user="$1" session="$2"
  local bins=(/usr/bin/gnome-software /usr/bin/plasma-discover /usr/bin/io.elementary.appcenter)
  for b in "${bins[@]}"; do [[ -x "$b" ]] && { setfacl -b "$b" 2>/dev/null || true; chmod 700 "$b" || true; }; done
  case "$session" in
    gnome*|ubuntu|cosmic) [[ -x /usr/bin/gnome-software ]] && setfacl -m u:"$user":x /usr/bin/gnome-software ;;
    plasma*|kde*)         [[ -x /usr/bin/plasma-discover ]] && setfacl -m u:"$user":x /usr/bin/plasma-discover ;;
    pantheon*)            [[ -x /usr/bin/io.elementary.appcenter ]] && setfacl -m u:"$user":x /usr/bin/io.elementary.appcenter ;;
    xfce*|lxqt*)          [[ -x /usr/bin/gnome-software ]] && setfacl -m u:"$user":x /usr/bin/gnome-software ;;
  esac
}

main(){
  require_root
  local session_id userpass username password
  session_id="$(pick_de)"
  userpass="$(prompt_userpass)"
  username="${userpass%%:*}"; password="${userpass#*:}"

  useradd -m -s /bin/bash "$username"
  echo "$username:$password" | chpasswd
  usermod -aG wheel "$username"
  chmod 700 "/home/$username"
  loginctl enable-linger "$username" || true

  write_dmrc "$username" "$session_id"
  write_accounts "$username" "$session_id"
  lock_store_access "$username" "$session_id"

  echo "✅ Created '$username' locked to '$session_id'. Log in via ly."
}
main "$@"