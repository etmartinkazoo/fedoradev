#!/usr/bin/env bash
# shellcheck shell=bash
#
# DNS configuration (LibreDNS over TLS).

if [[ -z "${SETUP_LIB_DIR:-}" ]]; then
  SETUP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
# shellcheck source=common.sh disable=SC1091
source "${SETUP_LIB_DIR}/common.sh"

install_libredns() {
  log_info "Checking LibreDNS configuration..."

  if _libredns_is_active; then
    log_ok "LibreDNS ad-blocking already active."
    return 0
  fi

  log_info "Configuring LibreDNS ad-blocking over TLS..."
  ensure_sudo

  _libredns_configure_resolved
  _libredns_configure_networkmanager

  log_info "Restarting systemd-resolved and NetworkManager..."
  sudo systemctl restart systemd-resolved
  sudo systemctl restart NetworkManager

  log_info "Verifying DNS configuration..."
  sleep 2
  if _libredns_is_active; then
    log_ok "LibreDNS ad-blocking is active."
  else
    log_warn "LibreDNS may not be active yet."
    log_warn "Per-connection DHCP DNS may still override. Run 'resolvectl status' to check."
  fi

  # Quick functional test: can we resolve a real hostname?
  if resolvectl query mirrors.fedoraproject.org >/dev/null 2>&1; then
    log_ok "DNS resolution test passed."
  else
    log_warn "DNS resolution test failed (mirrors.fedoraproject.org)."
    log_warn "You may need to reconnect to the network or reboot for DNS changes to take effect."
  fi
}

_libredns_is_active() {
  resolvectl status 2>/dev/null | grep -q "noads.libredns.gr"
}

_libredns_configure_resolved() {
  sudo mkdir -p /etc/systemd/resolved.conf.d

  local dropin="/etc/systemd/resolved.conf.d/libredns.conf"
  sudo tee "$dropin" >/dev/null <<'EOF'
[Resolve]
# Primary: LibreDNS (ad-blocking) over TLS. Secondary: Quad9, also over TLS,
# so a LibreDNS outage or a network that blocks it does not kill all name
# resolution. systemd-resolved stays on the first reachable server and only
# fails over when it stops responding, so ad-blocking is the normal path.
DNS=116.202.176.26#noads.libredns.gr 9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net
FallbackDNS=
DNSOverTLS=yes
EOF
}

_libredns_configure_networkmanager() {
  # NetworkManager often pushes the ISP's DNS servers onto the active link,
  # which systemd-resolved prefers over the global LibreDNS setting. Force
  # NetworkManager-managed connections to use the systemd-resolved stub and
  # ignore DHCP-provided DNS.
  sudo mkdir -p /etc/NetworkManager/conf.d

  sudo tee /etc/NetworkManager/conf.d/dns-systemd-resolved.conf >/dev/null <<'EOF'
[main]
dns=systemd-resolved
EOF

  # Apply to currently active connection profiles.
  if command_exists nmcli; then
    local active_conn
    active_conn=$(nmcli -t -f NAME c show --active 2>/dev/null | head -1)
    if [[ -n "$active_conn" ]]; then
      log_info "Configuring NetworkManager connection '${active_conn}' to use systemd-resolved..."
      sudo nmcli c mod "$active_conn" ipv4.ignore-auto-dns yes || true
      sudo nmcli c mod "$active_conn" ipv6.ignore-auto-dns yes || true
      sudo nmcli c mod "$active_conn" ipv4.dns "127.0.0.53" || true
      sudo nmcli c mod "$active_conn" ipv6.dns "::1" || true
    fi
  fi
}
