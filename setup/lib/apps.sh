#!/usr/bin/env bash
# shellcheck shell=bash
#
# Curated default applications.

if [[ -z "${SETUP_LIB_DIR:-}" ]]; then
  SETUP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
# shellcheck source=common.sh disable=SC1091
source "${SETUP_LIB_DIR}/common.sh"

# ---------------------------------------------------------------------------
# Curated default apps
# ---------------------------------------------------------------------------

install_curated_apps() {
  log_info "Installing curated default apps..."
  ensure_sudo

  _apps_install_cli_tools
  _apps_install_mpv
  _apps_install_zathura

  log_ok "Curated default apps installed."
}

_apps_install_cli_tools() {
  # Package name -> binary name
  local -A tools=(
    [tmux]=tmux
    [ripgrep]=rg
    [fzf]=fzf
    [fd-find]=fd
    [fastfetch]=fastfetch
  )
  local to_install=()
  local pkg bin

  for pkg in "${!tools[@]}"; do
    bin="${tools[$pkg]}"
    if command_exists "$bin" || package_installed "$pkg"; then
      log_ok "${pkg} already installed."
    else
      to_install+=("$pkg")
    fi
  done

  if [[ ${#to_install[@]} -eq 0 ]]; then
    return 0
  fi

  log_info "Installing CLI tools: ${to_install[*]}"
  sudo dnf install -y "${to_install[@]}"

  for pkg in "${to_install[@]}"; do
    bin="${tools[$pkg]}"
    if command_exists "$bin" || package_installed "$pkg"; then
      log_ok "${pkg} installed."
    else
      log_warn "${pkg} installation may have failed."
    fi
  done
}

_apps_install_mpv() {
  if command_exists mpv; then
    log_ok "mpv already installed."
    return 0
  fi

  log_info "Installing mpv media player..."
  sudo dnf install -y mpv

  if command_exists mpv; then
    log_ok "mpv installed."
  else
    log_warn "mpv installation may have failed."
  fi
}

_apps_install_zathura() {
  if command_exists zathura; then
    log_ok "Zathura already installed."
    return 0
  fi

  log_info "Installing Zathura PDF reader..."
  sudo dnf install -y zathura zathura-pdf-mupdf

  if command_exists zathura; then
    log_ok "Zathura installed."
  else
    log_warn "Zathura installation may have failed."
  fi
}
