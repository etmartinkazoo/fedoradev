#!/usr/bin/env bash
# shellcheck shell=bash
#
# Telemetry and phone-home cleanup.

if [[ -z "${SETUP_LIB_DIR:-}" ]]; then
  SETUP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
# shellcheck source=common.sh disable=SC1091
source "${SETUP_LIB_DIR}/common.sh"

cleanup_telemetry() {
  log_info "Cleaning up telemetry and phone-home services..."
  ensure_sudo

  _disable_abrt
  _disable_fwupd_reporting
  _disable_coredump
  _disable_packagekit_offline_updates

  log_ok "Telemetry cleanup complete."
}

_disable_abrt() {
  log_info "Disabling ABRT crash reporting..."

  local svc
  for svc in abrt-journal-core abrt-oops abrt-pstoreoops abrt-vmcore abrt-xorg abrtd; do
    if systemctl list-unit-files "${svc}.service" >/dev/null 2>&1; then
      sudo systemctl disable --now "${svc}.service" 2>/dev/null || true
    fi
  done

  sudo mkdir -p /etc/abrt
  sudo tee /etc/abrt/abrt.conf >/dev/null 2>/dev/null <<'EOF'
[Common]
MaxCrashReportsSize = 0
EOF

  log_ok "ABRT disabled."
}

_disable_fwupd_reporting() {
  log_info "Disabling fwupd reporting..."

  sudo mkdir -p /etc/fwupd
  sudo tee /etc/fwupd/fwupd.conf >/dev/null 2>/dev/null <<'EOF'
[fwupd]
DisabledPlugins=test;invalid;
ReportURI=
EOF

  log_ok "fwupd reporting disabled."
}

_disable_coredump() {
  log_info "Disabling systemd-coredump..."

  sudo mkdir -p /etc/systemd/coredump.conf.d
  sudo tee /etc/systemd/coredump.conf.d/disable.conf >/dev/null <<'EOF'
[Coredump]
Storage=none
ProcessSizeMax=0
EOF

  sudo systemctl daemon-reload
  log_ok "systemd-coredump disabled."
}

_disable_packagekit_offline_updates() {
  log_info "Disabling PackageKit offline updates..."

  if systemctl list-unit-files packagekit-offline-update.service >/dev/null 2>&1; then
    sudo systemctl disable packagekit-offline-update.service 2>/dev/null || true
  fi

  if systemctl list-unit-files packagekit.service >/dev/null 2>&1; then
    sudo systemctl disable --now packagekit.service 2>/dev/null || true
  fi

  log_ok "PackageKit offline updates disabled."
}
