#!/usr/bin/env bash
# shellcheck shell=bash
#
# Optional IPv6 disable. Use only if you do not need IPv6; it reduces leak
# surface but may break IPv6-only networks or some VPN/remote-access setups.

if [[ -z "${SETUP_LIB_DIR:-}" ]]; then
  SETUP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
# shellcheck source=common.sh disable=SC1091
source "${SETUP_LIB_DIR}/common.sh"

readonly IPV6_SYSCTL_FILE="/etc/sysctl.d/99-disable-ipv6.conf"

# ---------------------------------------------------------------------------
# Public entry points
# ---------------------------------------------------------------------------

disable_ipv6() {
  log_info "Disabling IPv6..."
  ensure_sudo

  _ipv6_sysctl_disable
  _ipv6_grub_disable

  log_ok "IPv6 disabled. Reboot for the GRUB change to take full effect."
  log_warn "If you lose network connectivity, re-enable IPv6 with: setup ipv6-enable"
}

enable_ipv6() {
  log_info "Re-enabling IPv6..."
  ensure_sudo

  _ipv6_sysctl_enable
  _ipv6_grub_enable

  log_ok "IPv6 re-enabled. Reboot for the GRUB change to take full effect."
}

# ---------------------------------------------------------------------------
# Sysctl runtime + persistent
# ---------------------------------------------------------------------------

_ipv6_sysctl_disable() {
  sudo tee "$IPV6_SYSCTL_FILE" >/dev/null <<'EOF'
# Disable IPv6 system-wide.
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
EOF
  sudo sysctl --system >/dev/null
  log_ok "IPv6 disabled via sysctl."
}

_ipv6_sysctl_enable() {
  if [[ -f "$IPV6_SYSCTL_FILE" ]]; then
    sudo rm -f "$IPV6_SYSCTL_FILE"
  fi

  # Re-enable immediately for active interfaces.
  sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0 >/dev/null
  sudo sysctl -w net.ipv6.conf.default.disable_ipv6=0 >/dev/null
  sudo sysctl --system >/dev/null
  log_ok "IPv6 sysctl settings removed and runtime re-enabled."
}

# ---------------------------------------------------------------------------
# GRUB kernel parameter
# ---------------------------------------------------------------------------

_ipv6_grub_disable() {
  if command_exists grubby; then
    sudo grubby --update-kernel=ALL --args="ipv6.disable=1" >/dev/null 2>&1 || true
    log_ok "Added ipv6.disable=1 to all GRUB kernels."
  else
    log_warn "grubby not found; cannot update GRUB kernel parameters."
  fi
}

_ipv6_grub_enable() {
  if command_exists grubby; then
    sudo grubby --update-kernel=ALL --remove-args="ipv6.disable=1" >/dev/null 2>&1 || true
    log_ok "Removed ipv6.disable=1 from all GRUB kernels."
  else
    log_warn "grubby not found; cannot update GRUB kernel parameters."
  fi
}
