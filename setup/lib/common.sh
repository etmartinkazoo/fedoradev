#!/usr/bin/env bash
# shellcheck shell=bash
#
# Common helpers sourced by all setup modules.
# This file must be sourced first.

set -euo pipefail

# Guard against multiple sources.
[[ -n "${SETUP_COMMON_SOURCED:-}" ]] && return 0
readonly SETUP_COMMON_SOURCED=1

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $*" >&2; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $*" >&2; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly DOTFILES_DIR
# shellcheck disable=SC2034
readonly SETUP_LIB_DIR="${DOTFILES_DIR}/setup/lib"

# ---------------------------------------------------------------------------
# Command / package helpers
# ---------------------------------------------------------------------------

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

package_installed() {
  rpm -q "$1" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Privilege escalation
# ---------------------------------------------------------------------------

ensure_sudo() {
  if sudo -n true 2>/dev/null; then
    return 0
  fi

  log_warn "This step requires sudo access."
  sudo -v

  # Keep sudo alive in the background while this script runs.
  if [[ -z "${SUDO_KEEPALIVE_PID:-}" ]] || ! kill -0 "$SUDO_KEEPALIVE_PID" 2>/dev/null; then
    (
      while true; do
        sudo -n true 2>/dev/null || exit
        sleep 60
        kill -0 "$$" 2>/dev/null || exit
      done
    ) &
    SUDO_KEEPALIVE_PID=$!
  fi
}

# ---------------------------------------------------------------------------
# Package installation
# ---------------------------------------------------------------------------

dnf_install() {
  ensure_sudo
  sudo dnf install -y "$@"
}

ensure_cmd() {
  local cmd="$1"
  local pkg="${2:-$1}"

  if command_exists "$cmd"; then
    return 0
  fi

  log_info "Installing $pkg..."
  dnf_install "$pkg"
}

ensure_jq() {
  ensure_cmd jq jq
}

# ---------------------------------------------------------------------------
# gsettings helper
# ---------------------------------------------------------------------------

# Set a gsettings key only if both the schema and key exist.
gsettings_set_if_exists() {
  local schema="$1" key="$2"
  shift 2
  if gsettings list-schemas 2>/dev/null | grep -qx "$schema" && \
     gsettings list-keys "$schema" 2>/dev/null | grep -qx "$key"; then
    gsettings set "$schema" "$key" "$@"
  fi
}

# ---------------------------------------------------------------------------
# Dotfile management via GNU Stow
# ---------------------------------------------------------------------------

ensure_stow() {
  ensure_cmd stow stow
}

stow_package() {
  local package="$1"
  ensure_stow
  log_info "Stowing $package..."
  stow -d "$DOTFILES_DIR" -t "$HOME" --restow "$package"
}

stow_package_all() {
  ensure_stow
  for _pkg in "$DOTFILES_DIR"/*/; do
    _pkg="$(basename "$_pkg")"
    case "$_pkg" in
      .agents|.git|docs|setup) continue ;;
    esac
    log_info "Stowing $_pkg..."
    stow -d "$DOTFILES_DIR" -t "$HOME" --restow "$_pkg"
  done
  log_ok "All packages stowed."
}
