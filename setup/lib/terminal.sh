#!/usr/bin/env bash
# shellcheck shell=bash
#
# Terminal configuration (Ptyxis / GNOME Console).

if [[ -z "${SETUP_LIB_DIR:-}" ]]; then
  SETUP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
# shellcheck source=common.sh disable=SC1091
source "${SETUP_LIB_DIR}/common.sh"

readonly NERD_FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/0xProto.zip"
readonly NERD_FONT_DIR="${HOME}/.local/share/fonts/0xProto"
readonly NERD_FONT_FAMILY="0xProto Nerd Font Mono"
readonly NERD_FONT_SIZE=10

# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------

configure_ptyxis() {
  log_info "Configuring Ptyxis terminal..."

  if ! command_exists ptyxis; then
    log_warn "Ptyxis not found; skipping terminal configuration."
    return 0
  fi

  if ! gsettings list-schemas 2>/dev/null | grep -qx "org.gnome.Ptyxis"; then
    log_warn "Ptyxis schema not found; skipping terminal configuration."
    return 0
  fi

  _install_0xproto_font

  # Ensure the default profile uses the Dracula palette.
  local profile_uuid
  profile_uuid=$(gsettings get org.gnome.Ptyxis default-profile-uuid 2>/dev/null | tr -d "'")
  if [[ -n "$profile_uuid" ]]; then
    dconf write "/org/gnome/Ptyxis/Profiles/${profile_uuid}/palette" "'dracula'"
    log_ok "Set Dracula palette for profile $profile_uuid."
  fi

  # Set the Nerd Font if it is available; otherwise fall back to Monospace.
  gsettings set org.gnome.Ptyxis use-system-font false
  if _font_is_available "$NERD_FONT_FAMILY"; then
    gsettings set org.gnome.Ptyxis font-name "${NERD_FONT_FAMILY} ${NERD_FONT_SIZE}"
    log_ok "Set Ptyxis font to ${NERD_FONT_FAMILY} ${NERD_FONT_SIZE}."
  else
    gsettings set org.gnome.Ptyxis font-name 'Monospace 11'
    log_warn "Nerd Font not detected; falling back to Monospace 11."
  fi

  log_ok "Ptyxis terminal configuration applied."
}

# ---------------------------------------------------------------------------
# 0xProto Nerd Font
# ---------------------------------------------------------------------------

_install_0xproto_font() {
  if _font_is_available "$NERD_FONT_FAMILY"; then
    log_ok "0xProto Nerd Font already installed."
    return 0
  fi

  log_info "Downloading 0xProto Nerd Font..."
  ensure_cmd unzip unzip
  ensure_cmd curl curl

  local tmp_dir tmp_zip
  tmp_dir=$(mktemp -d)
  tmp_zip="${tmp_dir}/0xProto.zip"

  local attempt=0
  until curl -fsSL -o "$tmp_zip" "$NERD_FONT_URL"; do
    attempt=$((attempt + 1))
    if (( attempt >= 5 )); then
      log_error "Failed to download 0xProto Nerd Font after ${attempt} attempts."
      rm -rf "$tmp_dir"
      return 1
    fi
    log_warn "Download failed (attempt ${attempt}/5), retrying in 3 seconds..."
    sleep 3
  done

  log_info "Installing 0xProto Nerd Font to ${NERD_FONT_DIR}..."
  mkdir -p "$NERD_FONT_DIR"
  unzip -q "$tmp_zip" -d "$NERD_FONT_DIR"
  rm -rf "$tmp_dir"

  if command_exists fc-cache; then
    fc-cache -fv "$HOME/.local/share/fonts" >/dev/null 2>&1 || true
  fi

  if _font_is_available "$NERD_FONT_FAMILY"; then
    log_ok "0xProto Nerd Font installed."
  else
    log_warn "0xProto Nerd Font may not have installed correctly."
  fi
}

_font_is_available() {
  local family="$1"
  command_exists fc-list && fc-list : family 2>/dev/null | grep -qi "$family"
}
