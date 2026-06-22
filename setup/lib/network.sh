#!/usr/bin/env bash
# shellcheck shell=bash
#
# Network hardening: firewall and NetworkManager privacy.

if [[ -z "${SETUP_LIB_DIR:-}" ]]; then
  SETUP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
# shellcheck source=common.sh disable=SC1091
source "${SETUP_LIB_DIR}/common.sh"

harden_network() {
  log_info "Hardening network..."
  ensure_sudo

  _harden_firewalld
  _harden_networkmanager

  log_ok "Network hardening complete."
}

_harden_firewalld() {
  log_info "Configuring firewalld..."

  if ! command_exists firewall-cmd; then
    log_warn "firewalld not installed; skipping firewall configuration."
    return 0
  fi

  sudo systemctl enable --now firewalld

  # Ensure the default public zone blocks inbound traffic except explicitly
  # allowed services. Remove SSH if it was opened on a workstation.
  sudo firewall-cmd --set-default-zone=public
  sudo firewall-cmd --permanent --zone=public --remove-service=ssh 2>/dev/null || true
  sudo firewall-cmd --permanent --zone=public --add-service=mdns 2>/dev/null || true
  sudo firewall-cmd --reload

  log_ok "firewalld configured: public zone, inbound blocked, mDNS allowed."
}

_harden_networkmanager() {
  log_info "Configuring NetworkManager privacy..."

  if ! command_exists nmcli; then
    log_warn "NetworkManager not installed; skipping NetworkManager privacy."
    return 0
  fi

  sudo mkdir -p /etc/NetworkManager/conf.d

  local dropin="/etc/NetworkManager/conf.d/privacy.conf"
  sudo tee "$dropin" >/dev/null <<'EOF'
[connection]
# Use randomized MAC addresses for every new connection.
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=random

# Enable IPv6 privacy extensions (RFC 7217 stable addresses).
ipv6.ip6-privacy=2

[connectivity]
# Disable the captive-portal / connectivity check to avoid leaking online
# status to a third-party endpoint. Captive portals may need manual handling.
uri=
interval=0
EOF

  sudo systemctl restart NetworkManager

  log_ok "NetworkManager privacy configured: random MAC, IPv6 privacy, no connectivity check."
}
