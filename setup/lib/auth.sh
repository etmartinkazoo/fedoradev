#!/usr/bin/env bash
# shellcheck shell=bash
#
# Optional strong-authentication helpers: fingerprint unlock and FIDO2/U2F.
#
# Both are OPT-IN and additive. They are configured through authselect features
# (the Fedora-supported path) rather than by hand-editing PAM, and your password
# is always kept as a fallback so these cannot lock you out. FIDO2 is never
# enabled unless a security key has actually been registered first.

if [[ -z "${SETUP_LIB_DIR:-}" ]]; then
  SETUP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
# shellcheck source=common.sh disable=SC1091
source "${SETUP_LIB_DIR}/common.sh"

_auth_require_authselect() {
  if ! command_exists authselect; then
    log_warn "authselect not found; cannot configure PAM safely. Skipping."
    return 1
  fi
  if ! authselect current >/dev/null 2>&1; then
    log_warn "No authselect profile is active; refusing to hand-edit PAM. Skipping."
    return 1
  fi
  return 0
}

_auth_feature_enabled() {
  authselect current 2>/dev/null | grep -q -- "$1"
}

# ---------------------------------------------------------------------------
# Fingerprint unlock (fprintd)
# ---------------------------------------------------------------------------

setup_fingerprint() {
  log_info "Setting up fingerprint authentication..."
  ensure_sudo
  _auth_require_authselect || return 0

  package_installed fprintd || dnf_install fprintd
  package_installed fprintd-pam || dnf_install fprintd-pam

  if ! command_exists fprintd-enroll; then
    log_warn "fprintd-enroll unavailable; cannot enroll. Skipping."
    return 0
  fi

  # Confirm a reader exists before asking the user to swipe.
  if ! fprintd-list "$USER" >/dev/null 2>&1 \
     && ! fprintd-list "$USER" 2>&1 | grep -qiE 'device|no fingers'; then
    log_warn "No fingerprint reader detected. Skipping enrollment."
  fi

  if fprintd-list "$USER" 2>&1 | grep -qi "has no fingers enrolled"; then
    log_info "No fingerprints enrolled. Starting enrollment — follow the prompts and lift/touch the reader repeatedly."
    if ! fprintd-enroll; then
      log_warn "Fingerprint enrollment failed or was cancelled; PAM left unchanged."
      return 0
    fi
    log_ok "Fingerprint enrolled."
  else
    log_ok "A fingerprint is already enrolled for ${USER}."
  fi

  if _auth_feature_enabled with-fingerprint; then
    log_ok "authselect 'with-fingerprint' already enabled."
  else
    sudo authselect enable-feature with-fingerprint
    sudo authselect apply-changes
    log_ok "Enabled fingerprint authentication."
  fi

  log_warn "Fingerprint is an ADDITIONAL factor: your password still works everywhere (GDM, sudo, lock screen)."
  log_info "To undo: sudo authselect disable-feature with-fingerprint && sudo authselect apply-changes"
}

# ---------------------------------------------------------------------------
# FIDO2 / U2F security key (pam-u2f)
# ---------------------------------------------------------------------------
#
# Set SETUP_FIDO2_2FA=1 to require the key IN ADDITION to your password (2FA).
# The default is 1FA: the key OR your password is accepted.

setup_fido2() {
  log_info "Setting up FIDO2/U2F security-key authentication..."
  ensure_sudo
  _auth_require_authselect || return 0

  package_installed pam-u2f || dnf_install pam-u2f
  if ! command_exists pamu2fcfg; then
    log_error "pamu2fcfg not available after install; aborting with NO PAM changes."
    return 1
  fi

  local keyfile="${HOME}/.config/Yubico/u2f_keys"
  mkdir -p "$(dirname "$keyfile")"
  chmod 700 "$(dirname "$keyfile")"

  # Register a key for this user if one is not already mapped.
  if [[ -s "$keyfile" ]] && grep -q "^${USER}:" "$keyfile"; then
    log_ok "A FIDO2 key is already registered for ${USER}."
  else
    log_info "Insert your FIDO2/U2F security key and touch it when it blinks..."
    local tmp
    tmp=$(mktemp)
    if pamu2fcfg -u "$USER" >"$tmp" 2>/dev/null && [[ -s "$tmp" ]]; then
      cat "$tmp" >"$keyfile"
      chmod 600 "$keyfile"
      rm -f "$tmp"
      log_ok "Registered FIDO2 key for ${USER}."
    else
      rm -f "$tmp"
      log_error "No key registered (no key present, or the touch timed out). Aborting with NO PAM changes."
      return 1
    fi
  fi

  # Safety gate: never enable U2F PAM without a registered key.
  if [[ ! -s "$keyfile" ]]; then
    log_error "Key mapping file is empty; refusing to enable U2F PAM."
    return 1
  fi

  local feature="with-pam-u2f" mode="1FA (security key OR password)"
  if [[ "${SETUP_FIDO2_2FA:-0}" == "1" ]]; then
    feature="with-pam-u2f-2fa"
    mode="2FA (password AND security key)"
    log_warn "2FA mode: every login and sudo will REQUIRE the key in addition to your password."
  fi

  if _auth_feature_enabled "$feature"; then
    log_ok "authselect '${feature}' already enabled."
  else
    sudo authselect enable-feature "$feature"
    sudo authselect apply-changes
    log_ok "Enabled FIDO2/U2F authentication: ${mode}."
  fi

  # nouserok is left in place (we do NOT enable without-pam-u2f-nouserok), so an
  # account without a registered key is never hard-locked.
  log_warn "TEST in a SEPARATE terminal before logging out:  sudo -k; sudo true"
  log_warn "Recovery: log in on a text TTY (Ctrl+Alt+F3) with your password if needed, then disable below."
  log_info "To undo: sudo authselect disable-feature ${feature} && sudo authselect apply-changes"
}

# ---------------------------------------------------------------------------
# Disable / rollback
# ---------------------------------------------------------------------------

disable_fingerprint() {
  log_info "Disabling fingerprint authentication..."
  ensure_sudo
  _auth_require_authselect || return 0

  if _auth_feature_enabled with-fingerprint; then
    sudo authselect disable-feature with-fingerprint
    sudo authselect apply-changes
    log_ok "Disabled fingerprint PAM feature (enrolled prints left intact; remove with 'fprintd-delete \$USER')."
  else
    log_warn "Fingerprint feature was not enabled."
  fi
}

disable_fido2() {
  log_info "Disabling FIDO2/U2F authentication..."
  ensure_sudo
  _auth_require_authselect || return 0

  local changed=0 f
  for f in with-pam-u2f with-pam-u2f-2fa; do
    if _auth_feature_enabled "$f"; then
      sudo authselect disable-feature "$f"
      changed=1
    fi
  done

  if [[ "$changed" -eq 1 ]]; then
    sudo authselect apply-changes
    log_ok "Disabled FIDO2/U2F PAM feature(s) (registered keys left in ~/.config/Yubico/u2f_keys)."
  else
    log_warn "No FIDO2/U2F feature was enabled."
  fi
}
