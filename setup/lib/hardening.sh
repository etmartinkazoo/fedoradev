#!/usr/bin/env bash
# shellcheck shell=bash
#
# System hardening: sysctl, services, auto-updates, sudo timeout.

if [[ -z "${SETUP_LIB_DIR:-}" ]]; then
  SETUP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
# shellcheck source=common.sh disable=SC1091
source "${SETUP_LIB_DIR}/common.sh"

readonly DISABLE_SERVICES=(
  sshd
  cups-browsed
  cups
  ModemManager
)

harden_system() {
  log_info "Hardening system..."
  ensure_sudo

  _apply_sysctl
  _disable_services
  _configure_time_sync
  _configure_auto_updates
  _shorten_sudo_timeout
  _verify_selinux

  log_ok "System hardening complete."
}

_apply_sysctl() {
  log_info "Applying sysctl hardening..."

  local sysctl_file="/etc/sysctl.d/99-hardening.conf"
  sudo tee "$sysctl_file" >/dev/null <<'EOF'
# Kernel hardening
kernel.randomize_va_space=2
kernel.kptr_restrict=2
kernel.yama.ptrace_scope=1
fs.suid_dumpable=0
fs.protected_hardlinks=1
fs.protected_symlinks=1

# IPv4 hardening
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.secure_redirects=0
net.ipv4.conf.default.secure_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.default.accept_source_route=0

# IPv6 hardening
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.default.accept_redirects=0
net.ipv6.conf.all.accept_source_route=0
net.ipv6.conf.default.accept_source_route=0
EOF

  sudo sysctl --system
  log_ok "Sysctl hardening applied."
}

_disable_services() {
  log_info "Disabling unnecessary services..."

  local svc
  for svc in "${DISABLE_SERVICES[@]}"; do
    if systemctl list-unit-files "${svc}.service" >/dev/null 2>&1; then
      sudo systemctl disable --now "${svc}.service" 2>/dev/null || true
      log_ok "Disabled ${svc}."
    fi
  done
}

_configure_time_sync() {
  log_info "Configuring authenticated time sync (chrony + NTS)..."

  # Accurate time is a security dependency: TLS certificate validation,
  # DNS-over-TLS, and DNSSEC all break if the clock drifts. Use chrony with
  # NTS (RFC 8915) so time sources are authenticated and the request leaks no
  # more than the chosen providers already see.
  if ! package_installed chrony; then
    if ! sudo dnf install -y chrony; then
      log_warn "Could not install chrony; time sync NOT configured."
      return 0
    fi
  fi

  local confdir="/etc/chrony/conf.d"
  sudo mkdir -p "$confdir"
  sudo tee "${confdir}/20-nts.conf" >/dev/null <<'EOF'
# Authenticated time over NTS (RFC 8915). The default sources in chrony.conf
# remain as an availability fallback if these providers are unreachable.
server time.cloudflare.com iburst nts
server nts.netnod.se iburst nts
EOF

  # Fedora's default chrony.conf does not enable a confdir, so the drop-in
  # above would be ignored. Ensure it is included exactly once.
  local chrony_conf="" f
  for f in /etc/chrony.conf /etc/chrony/chrony.conf; do
    [[ -f "$f" ]] && { chrony_conf="$f"; break; }
  done
  if [[ -n "$chrony_conf" ]] && ! grep -qxF "confdir ${confdir}" "$chrony_conf"; then
    echo "confdir ${confdir}" | sudo tee -a "$chrony_conf" >/dev/null
    log_ok "Enabled chrony confdir (${confdir}) so the NTS drop-in is read."
  fi

  sudo systemctl enable chronyd
  sudo systemctl restart chronyd || log_warn "chronyd restart failed; check 'systemctl status chronyd'."
  sudo timedatectl set-ntp true 2>/dev/null || true
  log_ok "Time sync enabled via chrony with NTS."
}

_configure_auto_updates() {
  log_info "Configuring automatic security updates..."

  local pkg="dnf-automatic"
  local timer="dnf-automatic.timer"

  # Fedora 41+ uses dnf5 and the new plugin package/unit names.
  if command_exists dnf5 || package_installed dnf5; then
    pkg="dnf5-plugin-automatic"
    timer="dnf5-automatic.timer"
  fi

  if ! package_installed "$pkg"; then
    if ! sudo dnf install -y "$pkg"; then
      log_warn "Could not install ${pkg}. Are you offline or is DNS misconfigured?"
      log_warn "Automatic security updates were NOT enabled. Re-run 'setup harden' after fixing network."
      return 0
    fi
  fi

  # Write the config to the main file. Both dnf-automatic and
  # dnf5-plugin-automatic read /etc/dnf/automatic.conf.
  if [[ -f /etc/dnf/automatic.conf ]]; then
    local backup_file
    backup_file="/etc/dnf/automatic.conf.bak.$(date +%s)"
    sudo cp /etc/dnf/automatic.conf "$backup_file"
    log_ok "Backed up existing /etc/dnf/automatic.conf to $backup_file"
  fi

  sudo mkdir -p /etc/dnf
  sudo tee /etc/dnf/automatic.conf >/dev/null <<'EOF'
[commands]
upgrade_type = security
random_sleep = 0
download_updates = yes
apply_updates = yes
reboot = never
EOF

  if systemctl list-unit-files "${timer}" >/dev/null 2>&1; then
    sudo systemctl enable --now "${timer}"
    log_ok "Automatic security updates enabled via ${timer} (applied automatically; no auto-reboot)."
  else
    log_warn "Timer unit ${timer} not found. Automatic updates may not be active."
  fi
}

_shorten_sudo_timeout() {
  log_info "Shortening sudo password timeout..."

  local sudoers_file="/etc/sudoers.d/timeout"
  sudo tee "$sudoers_file" >/dev/null <<'EOF'
# Reset sudo authentication after 5 minutes of inactivity.
Defaults timestamp_timeout=5
EOF

  if sudo visudo -c -f "$sudoers_file" >/dev/null 2>&1; then
    log_ok "Sudo timeout set to 5 minutes."
  else
    log_warn "Sudoers file syntax check failed; removing custom timeout."
    sudo rm -f "$sudoers_file"
  fi
}

_verify_selinux() {
  log_info "Verifying SELinux status..."

  local mode
  mode=$(getenforce 2>/dev/null || true)

  if [[ "$mode" == "Enforcing" ]]; then
    log_ok "SELinux is enforcing."
  else
    log_warn "SELinux is not enforcing (current mode: ${mode:-unknown}). Review /etc/selinux/config."
  fi
}
