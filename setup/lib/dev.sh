#!/usr/bin/env bash
# shellcheck shell=bash
#
# Development tools: opencode, mise, Node, pnpm.

if [[ -z "${SETUP_LIB_DIR:-}" ]]; then
  SETUP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
# shellcheck source=common.sh disable=SC1091
source "${SETUP_LIB_DIR}/common.sh"

# ---------------------------------------------------------------------------
# AI / CLI tools
# ---------------------------------------------------------------------------

install_opencode() {
  log_info "Checking opencode..."
  if ! command_exists opencode; then
    log_info "Installing opencode..."
    curl -fsSL https://opencode.ai/install | bash
  fi

  log_info "Stowing opencode config..."
  stow_package opencode
  log_ok "opencode installed and Dracula theme stowed."
}

# ---------------------------------------------------------------------------
# mise version manager
# ---------------------------------------------------------------------------

install_mise() {
  log_info "Checking mise..."
  if command_exists mise; then
    log_ok "mise already installed."
    return 0
  fi

  log_info "Installing mise..."
  curl -fsSL https://mise.run | sh

  local shell_rc
  if [[ "$SHELL" == */zsh ]]; then
    shell_rc="$HOME/.zshrc"
  else
    shell_rc="$HOME/.bashrc"
  fi

  # shellcheck disable=SC2016
  if ! grep -q 'eval "$(~/.local/bin/mise activate' "$shell_rc" 2>/dev/null; then
    # shellcheck disable=SC2016
    echo 'eval "$(~/.local/bin/mise activate bash)"' >> "$shell_rc"
    log_ok "Added mise activation to $shell_rc."
  fi

  eval "$("$HOME/.local/bin/mise" activate bash)"
  log_ok "mise installed."
}

# ---------------------------------------------------------------------------
# Node, pnpm via mise
# ---------------------------------------------------------------------------

install_node() {
  install_mise
  log_info "Checking Node.js via mise..."
  if mise list node 2>/dev/null | grep -q '24'; then
    log_ok "Node 24 already managed by mise."
    return 0
  fi

  log_info "Installing Node 24 via mise..."
  mise use -g node@24
  log_ok "Node 24 installed."
}

install_pnpm() {
  install_node
  log_info "Checking pnpm via mise..."
  if mise list pnpm 2>/dev/null | grep -q '9'; then
    log_ok "pnpm already managed by mise."
    return 0
  fi

  log_info "Installing pnpm via mise..."
  mise use -g pnpm@9
  log_ok "pnpm installed."
}
