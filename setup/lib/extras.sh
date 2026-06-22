#!/usr/bin/env bash
# shellcheck shell=bash
#
# Small polish extras: SSD trim, DNF countme disable, USBGuard, TLP.

if [[ -z "${SETUP_LIB_DIR:-}" ]]; then
  SETUP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
# shellcheck source=common.sh disable=SC1091
source "${SETUP_LIB_DIR}/common.sh"

# ---------------------------------------------------------------------------
# Public entry points
# ---------------------------------------------------------------------------

apply_extras() {
  log_info "Applying small polish extras..."
  ensure_sudo

  _extras_fstrim
  _extras_dnf_countme
  _extras_usbguard
  _extras_tlp

  log_ok "Extras applied."
}

# ---------------------------------------------------------------------------
# fstrim timer
# ---------------------------------------------------------------------------

_extras_fstrim() {
  if systemctl list-unit-files fstrim.timer >/dev/null 2>&1; then
    sudo systemctl enable --now fstrim.timer
    log_ok "fstrim.timer enabled (weekly SSD trim)."
  else
    log_info "fstrim.timer not available on this system."
  fi
}

# ---------------------------------------------------------------------------
# DNF countme disable
# ---------------------------------------------------------------------------

_extras_dnf_countme() {
  local dnf_conf="/etc/dnf/dnf.conf"

  if [[ ! -f "$dnf_conf" ]]; then
    log_warn "$dnf_conf not found; cannot disable countme."
    return 0
  fi

  if grep -qE '^\s*countme\s*=\s*false' "$dnf_conf"; then
    log_ok "DNF countme already disabled."
    return 0
  fi

  if grep -qE '^\s*countme\s*=' "$dnf_conf"; then
    sudo sed -i 's/^\s*countme\s*=\s*.*/countme=false/' "$dnf_conf"
  elif grep -qE '^\s*\[main\]' "$dnf_conf"; then
    # Insert into the [main] section rather than appending to end-of-file,
    # which could land the key under a different section.
    sudo sed -i '0,/^\s*\[main\]/s//&\ncountme=false/' "$dnf_conf"
  else
    sudo tee -a "$dnf_conf" >/dev/null <<'EOF'
[main]
countme=false
EOF
  fi

  log_ok "DNF countme disabled (stops weekly Fedora install-base ping)."
}

# ---------------------------------------------------------------------------
# USBGuard
# ---------------------------------------------------------------------------

_extras_usbguard() {
  log_info "Checking USBGuard..."

  if ! command_exists usbguard; then
    if ! package_installed usbguard; then
      sudo dnf install -y usbguard
    fi
  fi

  if ! command_exists usbguard; then
    log_warn "USBGuard installation failed."
    return 0
  fi

  # Generate an allow-list for currently attached USB devices so the keyboard
  # and mouse keep working. New/unknown devices will be blocked.
  if [[ ! -f /etc/usbguard/rules.conf ]] || [[ ! -s /etc/usbguard/rules.conf ]]; then
    log_info "Generating USBGuard policy for currently attached devices..."
    sudo sh -c 'usbguard generate-policy > /etc/usbguard/rules.conf'
    sudo chmod 0600 /etc/usbguard/rules.conf
    log_ok "USBGuard policy generated."
  else
    log_ok "USBGuard rules already exist."
  fi

  # Ensure the daemon starts in enforcing mode with the generated rules.
  sudo systemctl enable --now usbguard.service
  log_ok "USBGuard enabled and started."
  log_warn "New USB devices will be blocked until added to /etc/usbguard/rules.conf."
}

# ---------------------------------------------------------------------------
# TLP laptop power tuning
# ---------------------------------------------------------------------------

_extras_tlp() {
  log_info "Checking TLP..."

  if ! command_exists tlp; then
    if ! package_installed tlp; then
      sudo dnf install -y tlp
    fi
  fi

  if ! command_exists tlp; then
    log_warn "TLP installation failed."
    return 0
  fi

  sudo systemctl enable --now tlp.service
  log_ok "TLP enabled and started."
}
