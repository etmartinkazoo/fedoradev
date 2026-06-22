#!/usr/bin/env bash
# shellcheck shell=bash
#
# Final audit / pre-flight checks for the privacy-first Fedora setup.
# Reports current state and prints actionable suggestions.

if [[ -z "${SETUP_LIB_DIR:-}" ]]; then
  SETUP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
# shellcheck source=common.sh disable=SC1091
source "${SETUP_LIB_DIR}/common.sh"

# Counters for the final summary.
AUDIT_OK=0
AUDIT_WARN=0
AUDIT_INFO=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_audit_ok()   { echo -e "${GREEN}[OK]${NC} $*"; AUDIT_OK=$((AUDIT_OK + 1)); }
_audit_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; AUDIT_WARN=$((AUDIT_WARN + 1)); }
_audit_info() { echo -e "${BLUE}[INFO]${NC} $*"; AUDIT_INFO=$((AUDIT_INFO + 1)); }

_audit_systemctl_is() {
  local svc="$1" state="$2"
  systemctl is-"$state" "$svc" >/dev/null 2>&1
}

_audit_gsettings_get() {
  local schema="$1" key="$2"
  gsettings get "$schema" "$key" 2>/dev/null \
    | sed -E 's/^uint32 //; s/^int32 //; s/^"//; s/"$//' || true
}

# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------

run_audit() {
  log_info "Running final audit..."

  _audit_disk_encryption
  _audit_selinux
  _audit_secure_boot
  _audit_firmware_updates
  _audit_firewall
  _audit_networkmanager_privacy
  _audit_dns
  _audit_hosts_blocklist
  _audit_firefox
  _audit_ssh
  _audit_auto_updates
  _audit_gnome_privacy
  _audit_keyboard
  _audit_caps_lock
  _audit_trackpad
  _audit_telemetry
  _audit_ntp
  _audit_docker_group
  _audit_sudo_timeout
  _audit_auth
  _audit_flatpak
  _audit_browser_launcher

  echo ""
  echo "=================================="
  echo "           Audit summary          "
  echo "=================================="
  echo -e "${GREEN}OK${NC}:    $AUDIT_OK"
  echo -e "${YELLOW}WARN${NC}:  $AUDIT_WARN"
  echo -e "${BLUE}INFO${NC}:  $AUDIT_INFO"
  echo ""
  log_ok "Audit complete. Review WARN items above for next steps."
}

# ---------------------------------------------------------------------------
# Disk encryption
# ---------------------------------------------------------------------------

_audit_disk_encryption() {
  echo ""
  echo "## Disk encryption"

  if command_exists cryptsetup; then
    if lsblk -n -o TYPE 2>/dev/null | grep -qx "crypt"; then
      _audit_ok "LUKS encrypted block device(s) detected."
    else
      _audit_warn "No LUKS encrypted block device detected. Encrypt the disk if this is a portable machine."
    fi
  else
    _audit_info "cryptsetup not found; cannot verify disk encryption."
  fi
}

# ---------------------------------------------------------------------------
# SELinux
# ---------------------------------------------------------------------------

_audit_selinux() {
  echo ""
  echo "## SELinux"

  local mode
  mode=$(getenforce 2>/dev/null || true)

  if [[ "$mode" == "Enforcing" ]]; then
    _audit_ok "SELinux is enforcing."
  elif [[ "$mode" == "Permissive" ]]; then
    _audit_warn "SELinux is permissive. Set to enforcing in /etc/selinux/config for maximum protection."
  else
    _audit_warn "SELinux status unknown or disabled."
  fi
}

# ---------------------------------------------------------------------------
# Secure Boot
# ---------------------------------------------------------------------------

_audit_secure_boot() {
  echo ""
  echo "## Secure Boot"

  if command_exists mokutil; then
    if mokutil --sb-state 2>/dev/null | grep -qi "SecureBoot enabled"; then
      _audit_ok "Secure Boot is enabled."
    else
      _audit_warn "Secure Boot is not enabled. Enable it in firmware settings if supported."
    fi
  else
    _audit_info "mokutil not found; cannot verify Secure Boot state."
  fi
}

# ---------------------------------------------------------------------------
# Firmware updates
# ---------------------------------------------------------------------------

_audit_firmware_updates() {
  echo ""
  echo "## Firmware updates"

  if command_exists fwupdmgr; then
    _audit_info "fwupdmgr is available. Run 'fwupdmgr get-updates' periodically for firmware updates."
    if fwupdmgr get-updates 2>/dev/null | grep -qi "upgrade"; then
      _audit_warn "Firmware updates are available. Review with 'fwupdmgr get-updates'."
    fi
  else
    _audit_info "fwupdmgr not found; firmware update checks unavailable."
  fi
}

# ---------------------------------------------------------------------------
# Firewall
# ---------------------------------------------------------------------------

_audit_firewall() {
  echo ""
  echo "## Firewall"

  if command_exists firewall-cmd; then
    if _audit_systemctl_is firewalld active; then
      _audit_ok "firewalld is active."
      local default_zone
      default_zone=$(firewall-cmd --get-default-zone 2>/dev/null || true)
      if [[ "$default_zone" == "public" ]]; then
        _audit_ok "firewalld default zone is public."
      else
        _audit_warn "firewalld default zone is '${default_zone}', expected 'public'."
      fi
    else
      _audit_warn "firewalld is not active. Run 'setup network' to enable it."
    fi
  else
    _audit_warn "firewall-cmd not found."
  fi
}

# ---------------------------------------------------------------------------
# NetworkManager privacy
# ---------------------------------------------------------------------------

_audit_networkmanager_privacy() {
  echo ""
  echo "## NetworkManager privacy"

  local dropin="/etc/NetworkManager/conf.d/privacy.conf"
  if [[ -f "$dropin" ]]; then
    _audit_ok "NetworkManager privacy drop-in exists: $dropin"
    if grep -q "cloned-mac-address=random" "$dropin"; then
      _audit_ok "Random MAC addresses are configured."
    else
      _audit_warn "Random MAC addresses are not configured."
    fi
    if grep -q "ip6-privacy=2" "$dropin"; then
      _audit_ok "IPv6 privacy extensions are enabled."
    else
      _audit_warn "IPv6 privacy extensions are not enabled."
    fi
  else
    _audit_warn "NetworkManager privacy drop-in missing. Run 'setup network'."
  fi
}

# ---------------------------------------------------------------------------
# DNS
# ---------------------------------------------------------------------------

_audit_dns() {
  echo ""
  echo "## DNS"

  if command_exists resolvectl; then
    if resolvectl status 2>/dev/null | grep -q "noads.libredns.gr"; then
      _audit_ok "LibreDNS over TLS is active."
    else
      _audit_warn "LibreDNS over TLS is not active. Run 'setup libredns'."
    fi
  else
    _audit_info "resolvectl not found; cannot verify DNS configuration."
  fi
}

# ---------------------------------------------------------------------------
# /etc/hosts blocklist
# ---------------------------------------------------------------------------

_audit_hosts_blocklist() {
  echo ""
  echo "## /etc/hosts blocklist"

  if grep -q "# === BEGIN HOSTS-BLOCKLIST ===" /etc/hosts 2>/dev/null; then
    local count
    count=$(grep -cE '^0\.0\.0\.0 ' /etc/hosts 2>/dev/null || true)
    _audit_ok "/etc/hosts blocklist is active ($count blocked domains)."
    _audit_info "Toggle categories in ~/.config/hosts-blocklist/enabled."
  else
    _audit_warn "/etc/hosts blocklist not applied. Run 'setup hosts'."
  fi
}

# ---------------------------------------------------------------------------
# Firefox / uBlock Origin
# ---------------------------------------------------------------------------

_audit_firefox() {
  echo ""
  echo "## Firefox"

  if command_exists firefox; then
    _audit_ok "Firefox is installed."
  else
    _audit_warn "Firefox is not installed. Run 'setup firefox'."
    return 0
  fi

  # Resolve the policy path the same way firefox.sh wrote it. Guard for when
  # audit.sh is run standalone (firefox.sh not sourced).
  local policy_file
  if declare -F _firefox_policy_file >/dev/null; then
    policy_file=$(_firefox_policy_file)
  else
    policy_file="/usr/lib64/firefox/distribution/policies.json"
  fi
  if [[ -f "$policy_file" ]]; then
    _audit_ok "Firefox policies present: $policy_file"
    if grep -q '"DisableTelemetry": true' "$policy_file"; then
      _audit_ok "Firefox telemetry is disabled by policy."
    fi
    if grep -qE '"installation_mode":\s*"force_installed"' "$policy_file" && \
       grep -q "uBlock0@raymondhill.net" "$policy_file"; then
      _audit_ok "uBlock Origin is force-installed."
    else
      _audit_warn "uBlock Origin is not force-installed in policies. Run 'setup firefox'."
    fi
  else
    _audit_warn "Firefox policies not found. Run 'setup firefox'."
  fi

  if command_exists xdg-settings; then
    local default_browser
    default_browser=$(xdg-settings get default-web-browser 2>/dev/null || true)
    if [[ "$default_browser" == "firefox.desktop" ]]; then
      _audit_ok "Firefox is the default web browser."
    else
      _audit_warn "Default browser is '${default_browser}'. Run 'setup firefox'."
    fi
  fi
}

# ---------------------------------------------------------------------------
# SSH
# ---------------------------------------------------------------------------

_audit_ssh() {
  echo ""
  echo "## SSH"

  if systemctl list-unit-files sshd.service >/dev/null 2>&1; then
    if _audit_systemctl_is sshd enabled; then
      _audit_warn "sshd is enabled. Disable it on a workstation: sudo systemctl disable --now sshd"
    else
      _audit_ok "sshd is not enabled."
    fi
  else
    _audit_ok "sshd unit not installed."
  fi
}

# ---------------------------------------------------------------------------
# Automatic updates
# ---------------------------------------------------------------------------

_audit_auto_updates() {
  echo ""
  echo "## Automatic updates"

  local timer=""
  if systemctl list-unit-files dnf5-automatic.timer >/dev/null 2>&1; then
    timer="dnf5-automatic.timer"
  elif systemctl list-unit-files dnf-automatic.timer >/dev/null 2>&1; then
    timer="dnf-automatic.timer"
  fi

  if [[ -n "$timer" ]] && _audit_systemctl_is "$timer" enabled; then
    _audit_ok "${timer} is enabled."
  else
    _audit_warn "Automatic update timer is not enabled. Run 'setup harden'."
  fi
}

# ---------------------------------------------------------------------------
# GNOME privacy
# ---------------------------------------------------------------------------

_audit_gnome_privacy() {
  echo ""
  echo "## GNOME privacy"

  if ! command_exists gsettings; then
    _audit_info "gsettings not found; skipping GNOME privacy checks."
    return 0
  fi

  local val
  val=$(_audit_gsettings_get org.gnome.desktop.privacy disable-camera)
  if [[ "$val" == "true" ]]; then
    _audit_ok "GNOME camera is disabled."
  else
    _audit_warn "GNOME camera is not disabled. Run 'setup gnome'."
  fi

  val=$(_audit_gsettings_get org.gnome.desktop.privacy disable-microphone)
  if [[ "$val" == "true" ]]; then
    _audit_ok "GNOME microphone is disabled."
  else
    _audit_warn "GNOME microphone is not disabled. Run 'setup gnome'."
  fi

  val=$(_audit_gsettings_get org.gnome.desktop.privacy remember-recent-files)
  if [[ "$val" == "false" ]]; then
    _audit_ok "GNOME recent files are disabled."
  else
    _audit_warn "GNOME recent files are enabled. Run 'setup gnome'."
  fi

  val=$(_audit_gsettings_get org.gnome.system.location enabled)
  if [[ "$val" == "false" ]]; then
    _audit_ok "GNOME location services are disabled."
  else
    _audit_warn "GNOME location services are enabled. Run 'setup gnome'."
  fi
}

# ---------------------------------------------------------------------------
# Keyboard feel
# ---------------------------------------------------------------------------

_audit_keyboard() {
  echo ""
  echo "## Keyboard feel"

  if ! command_exists gsettings; then
    _audit_info "gsettings not found; skipping keyboard checks."
    return 0
  fi

  local delay interval
  delay=$(_audit_gsettings_get org.gnome.desktop.peripherals.keyboard delay)
  interval=$(_audit_gsettings_get org.gnome.desktop.peripherals.keyboard repeat-interval)

  _audit_info "Key repeat delay: ${delay}ms, interval: ${interval}ms."
  if [[ "${delay}" == "150" && "${interval}" == "18" ]]; then
    _audit_ok "Keyboard repeat is configured for maximum snappiness."
  else
    _audit_warn "Keyboard repeat is not at the snappy target (delay=150, interval=18). Run 'setup gnome-keyboard'."
  fi

  local animations
  animations=$(_audit_gsettings_get org.gnome.desktop.interface enable-animations)
  if [[ "$animations" == "false" ]]; then
    _audit_ok "GNOME animations are disabled (snappier feel)."
  else
    _audit_warn "GNOME animations are enabled. Run 'setup gnome-keyboard'."
  fi
}

# ---------------------------------------------------------------------------
# Caps Lock mapping
# ---------------------------------------------------------------------------

_audit_caps_lock() {
  echo ""
  echo "## Caps Lock mapping"

  if ! command_exists gsettings; then
    _audit_info "gsettings not found; skipping Caps Lock check."
    return 0
  fi

  local xkb_opts
  xkb_opts=$(_audit_gsettings_get org.gnome.desktop.input-sources xkb-options)

  if [[ "$xkb_opts" == *"ctrl:nocaps"* || "$xkb_opts" == *"caps:escape"* ]]; then
    _audit_ok "Caps Lock is remapped (${xkb_opts})."
  else
    _audit_info "Caps Lock is not remapped. Consider setting org.gnome.desktop.input-sources xkb-options to ['ctrl:nocaps'] or ['caps:escape']."
  fi
}

# ---------------------------------------------------------------------------
# Trackpad
# ---------------------------------------------------------------------------

_audit_trackpad() {
  echo ""
  echo "## Trackpad"

  if ! command_exists gsettings; then
    _audit_info "gsettings not found; skipping trackpad checks."
    return 0
  fi

  local tap
  tap=$(_audit_gsettings_get org.gnome.desktop.peripherals.touchpad tap-to-click)
  if [[ "$tap" == "true" ]]; then
    _audit_info "Tap-to-click is enabled. Disable it if you prefer physical clicks."
  else
    _audit_info "Tap-to-click is disabled. Enable it in Settings > Mouse & Touchpad if desired."
  fi
}

# ---------------------------------------------------------------------------
# Telemetry
# ---------------------------------------------------------------------------

_audit_telemetry() {
  echo ""
  echo "## Telemetry"

  local svc
  for svc in abrtd abrt-oops abrt-xorg; do
    if systemctl list-unit-files "${svc}.service" >/dev/null 2>&1; then
      if _audit_systemctl_is "$svc" enabled; then
        _audit_warn "${svc} is enabled. Run 'setup telemetry'."
      else
        _audit_ok "${svc} is disabled."
      fi
    fi
  done

  if [[ -f /etc/systemd/coredump.conf.d/disable.conf ]]; then
    _audit_ok "systemd-coredump is disabled."
  else
    _audit_warn "systemd-coredump may be active. Run 'setup telemetry'."
  fi
}

# ---------------------------------------------------------------------------
# NTP / time sync
# ---------------------------------------------------------------------------

_audit_ntp() {
  echo ""
  echo "## NTP / time sync"

  # Accurate time is a security dependency (TLS, DNS-over-TLS, DNSSEC), so an
  # active time-sync service is the desired state.
  local svc active=0
  for svc in chronyd systemd-timesyncd; do
    if systemctl list-unit-files "${svc}.service" >/dev/null 2>&1; then
      if _audit_systemctl_is "$svc" active; then
        _audit_ok "${svc} is active (time sync running)."
        active=1
      fi
    fi
  done

  if [[ "$active" -eq 0 ]]; then
    _audit_warn "No time-sync service is active. Clock drift can break TLS/DNSSEC. Run 'setup harden'."
  elif command_exists chronyc; then
    if chronyc -N authdata 2>/dev/null | grep -qiE '\bNTS\b'; then
      _audit_ok "chrony is using NTS (authenticated time)."
    else
      _audit_info "chrony is running but NTS was not detected. Run 'setup harden' to apply the NTS sources."
    fi
  fi
}

# ---------------------------------------------------------------------------
# Docker group
# ---------------------------------------------------------------------------

_audit_docker_group() {
  echo ""
  echo "## Docker group"

  if getent group docker >/dev/null 2>&1; then
    if id -nG "$USER" 2>/dev/null | grep -qw docker; then
      _audit_warn "User is in the 'docker' group. This grants effective root privileges; consider rootless Docker for better isolation."
    else
      _audit_ok "User is not in the 'docker' group."
    fi
  else
    _audit_info "Docker group does not exist."
  fi
}

# ---------------------------------------------------------------------------
# Sudo timeout
# ---------------------------------------------------------------------------

_audit_sudo_timeout() {
  echo ""
  echo "## Sudo timeout"

  if [[ -f /etc/sudoers.d/timeout ]]; then
    _audit_ok "Custom sudo timeout is configured."
  else
    _audit_warn "Custom sudo timeout not found. Run 'setup harden'."
  fi
}

# ---------------------------------------------------------------------------
# Strong authentication (opt-in)
# ---------------------------------------------------------------------------

_audit_auth() {
  echo ""
  echo "## Strong authentication (opt-in)"

  if ! command_exists authselect; then
    _audit_info "authselect not present; skipping authentication checks."
    return 0
  fi

  local features
  features=$(authselect current 2>/dev/null || true)

  if grep -q "with-fingerprint" <<<"$features"; then
    if command_exists fprintd-list \
       && ! fprintd-list "$USER" 2>&1 | grep -qi "has no fingers enrolled"; then
      _audit_ok "Fingerprint unlock enabled and a finger is enrolled."
    else
      _audit_warn "Fingerprint PAM enabled but no finger enrolled. Run 'setup fingerprint'."
    fi
  else
    _audit_info "Fingerprint unlock not enabled (optional). Run 'setup fingerprint'."
  fi

  if grep -qE "with-pam-u2f(-2fa)?" <<<"$features"; then
    _audit_ok "FIDO2/U2F security-key authentication is enabled."
  else
    _audit_info "FIDO2/U2F not enabled (optional). Run 'setup fido2'."
  fi
}

# ---------------------------------------------------------------------------
# Flatpak
# ---------------------------------------------------------------------------

_audit_flatpak() {
  echo ""
  echo "## Flatpak"

  if command_exists flatpak; then
    _audit_warn "Flatpak is installed. This setup intentionally avoids Flatpak for supply-chain simplicity."
  else
    _audit_ok "Flatpak is not installed."
  fi
}

# ---------------------------------------------------------------------------
# Browser launcher shortcut
# ---------------------------------------------------------------------------

_audit_browser_launcher() {
  echo ""
  echo "## Browser launcher shortcut"

  if command_exists dconf && command_exists gsettings; then
    local browser_cmd
    browser_cmd=$(dconf read /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/command 2>/dev/null || true)
    if [[ "$browser_cmd" == *"firefox"* ]]; then
      _audit_ok "Super+Shift+b browser shortcut points to Firefox."
    else
      _audit_warn "Super+Shift+b browser shortcut does not point to Firefox. Run 'setup gnome-keyboard'."
    fi
  else
    _audit_info "dconf/gsettings not found; skipping browser launcher check."
  fi
}
