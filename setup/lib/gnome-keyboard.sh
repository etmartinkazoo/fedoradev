#!/usr/bin/env bash
# shellcheck shell=bash
#
# Keyboard-driven GNOME configuration via dconf/gsettings.
# No extensions required.

if [[ -z "${SETUP_LIB_DIR:-}" ]]; then
  SETUP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
# shellcheck source=common.sh disable=SC1091
source "${SETUP_LIB_DIR}/common.sh"

readonly GNOME_KEYBOARD_WORKSPACES=4

# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------

configure_gnome_keyboard() {
  log_info "Configuring keyboard-driven GNOME..."

  if ! command_exists gsettings; then
    log_warn "gsettings not found; skipping GNOME keyboard configuration."
    return 0
  fi

  if ! command_exists dconf; then
    log_warn "dconf not found; skipping custom app launchers."
  fi

  # Disable mouse-triggered distractions.
  gsettings_set_if_exists org.gnome.desktop.interface enable-hot-corners false
  gsettings_set_if_exists org.gnome.desktop.interface enable-animations false

  # Faster key repeat for keyboard-driven workflows.
  # These values are aggressive: short delay and tight repeat interval for a
  # snappier feel. Tune via Settings > Keyboard if they feel too twitchy.
  gsettings_set_if_exists org.gnome.desktop.peripherals.keyboard repeat true
  gsettings_set_if_exists org.gnome.desktop.peripherals.keyboard repeat-interval 18
  gsettings_set_if_exists org.gnome.desktop.peripherals.keyboard delay 150

  # Disable dash-to-dock hotkeys so Super+number maps to workspaces.
  gsettings_set_if_exists org.gnome.shell.extensions.dash-to-dock hot-keys false

  # Disable "switch to application" keybindings so Super+number maps to workspaces.
  local i
  for i in $(seq 1 9); do
    gsettings_set_if_exists "org.gnome.shell.keybindings" "switch-to-application-${i}" "@as []"
  done

  # Fixed number of workspaces is easier to navigate by number.
  gsettings_set_if_exists org.gnome.mutter dynamic-workspaces false
  gsettings_set_if_exists org.gnome.desktop.wm.preferences num-workspaces "$GNOME_KEYBOARD_WORKSPACES"

  # Don't steal focus on accidental clicks.
  gsettings_set_if_exists org.gnome.desktop.wm.preferences raise-on-click false
  gsettings_set_if_exists org.gnome.desktop.wm.preferences focus-mode 'click'

  # Window management.
  gsettings_set_if_exists org.gnome.desktop.wm.keybindings close "['<Alt>w']"
  gsettings_set_if_exists org.gnome.desktop.wm.keybindings toggle-fullscreen "['<Alt>f']"
  gsettings_set_if_exists org.gnome.desktop.wm.keybindings toggle-maximized "['<Alt>m']"
  gsettings_set_if_exists org.gnome.desktop.wm.keybindings minimize "['<Alt>h']"
  gsettings_set_if_exists org.gnome.desktop.wm.keybindings show-desktop "['<Alt>d']"

  # Window tiling.
  gsettings_set_if_exists org.gnome.mutter.keybindings toggle-tiled-left "['<Alt>a']"
  gsettings_set_if_exists org.gnome.mutter.keybindings toggle-tiled-right "['<Alt>s']"

  # Window switching.
  gsettings_set_if_exists org.gnome.desktop.wm.keybindings switch-applications "['<Alt>Tab']"
  gsettings_set_if_exists org.gnome.desktop.wm.keybindings switch-applications-backward "['<Alt><Shift>Tab']"
  gsettings_set_if_exists org.gnome.desktop.wm.keybindings switch-windows "['<Super>Tab']"
  gsettings_set_if_exists org.gnome.desktop.wm.keybindings switch-windows-backward "['<Super><Shift>Tab']"

  # Workspace navigation.
  _gnome_keyboard_workspace_bindings

  # Custom app launchers.
  if command_exists dconf; then
    _gnome_keyboard_custom_launchers
  fi

  log_ok "Keyboard-driven GNOME configuration applied."
  log_warn "Review Settings > Keyboard if any shortcut conflicts with your muscle memory."
}

# ---------------------------------------------------------------------------
# Workspace keybindings
# ---------------------------------------------------------------------------

_gnome_keyboard_workspace_bindings() {
  local i
  for i in $(seq 1 "$GNOME_KEYBOARD_WORKSPACES"); do
    gsettings_set_if_exists org.gnome.desktop.wm.keybindings "switch-to-workspace-$i" "['<Super>$i']"
    gsettings_set_if_exists org.gnome.desktop.wm.keybindings "move-to-workspace-$i" "['<Super><Shift>$i']"
  done

  gsettings_set_if_exists org.gnome.desktop.wm.keybindings switch-to-workspace-left "['<Super>Page_Up']"
  gsettings_set_if_exists org.gnome.desktop.wm.keybindings switch-to-workspace-right "['<Super>Page_Down']"
  gsettings_set_if_exists org.gnome.desktop.wm.keybindings move-to-workspace-left "['<Super><Shift>Page_Up']"
  gsettings_set_if_exists org.gnome.desktop.wm.keybindings move-to-workspace-right "['<Super><Shift>Page_Down']"
}

# ---------------------------------------------------------------------------
# Custom app launchers via dconf
# ---------------------------------------------------------------------------

_gnome_keyboard_custom_launchers() {
  local base="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/"

  dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings \
    "['${base}custom0/', '${base}custom1/', '${base}custom2/', '${base}custom3/']"

  _gnome_keyboard_write_launcher "${base}custom0/" "Terminal" "kgx" "<Super>Return"
  _gnome_keyboard_write_launcher "${base}custom1/" "Browser" "firefox" "<Super><Shift>b"
  _gnome_keyboard_write_launcher "${base}custom2/" "Files" "nautilus" "<Super><Shift>f"
  _gnome_keyboard_write_launcher "${base}custom3/" "Terminal (Ptyxis)" "ptyxis --new-window" "<Super><Shift>t"
}

_gnome_keyboard_write_launcher() {
  local path="$1" name="$2" command="$3" binding="$4"

  dconf write "${path}name" "'$name'"
  dconf write "${path}command" "'$command'"
  dconf write "${path}binding" "'$binding'"
}
