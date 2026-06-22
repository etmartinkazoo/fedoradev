#!/usr/bin/env bash
# shellcheck shell=bash
#
# Thunderbird installation and hardening via managed policies.
# Configures Thunderbird to be ultra-minimal, private, and secure.

if [[ -z "${SETUP_LIB_DIR:-}" ]]; then
  SETUP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
# shellcheck source=common.sh disable=SC1091
source "${SETUP_LIB_DIR}/common.sh"

readonly THUNDERBIRD_POLICY_DIR="/etc/thunderbird/policies"
readonly THUNDERBIRD_POLICY_FILE="${THUNDERBIRD_POLICY_DIR}/policies.json"

# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------

install_thunderbird() {
  log_info "Checking Thunderbird..."
  ensure_sudo

  if ! command_exists thunderbird; then
    log_info "Installing Thunderbird from Fedora repositories..."
    sudo dnf install -y thunderbird || return 1
  else
    log_ok "Thunderbird already installed."
  fi

  _thunderbird_ensure_policy_dir
  _thunderbird_apply_policies
  _thunderbird_set_default_client

  log_ok "Thunderbird configured."
}

# ---------------------------------------------------------------------------
# Policy file
# ---------------------------------------------------------------------------

_thunderbird_ensure_policy_dir() {
  if [[ ! -d "$THUNDERBIRD_POLICY_DIR" ]]; then
    sudo mkdir -p "$THUNDERBIRD_POLICY_DIR"
  fi
}

_thunderbird_apply_policies() {
  log_info "Applying Thunderbird managed policies..."

  if [[ -f "$THUNDERBIRD_POLICY_FILE" ]]; then
    local backup_file
    backup_file="${THUNDERBIRD_POLICY_FILE}.bak.$(date +%s)"
    sudo cp "$THUNDERBIRD_POLICY_FILE" "$backup_file"
    log_info "Backed up existing Thunderbird policies to $backup_file"
  fi

  sudo tee "$THUNDERBIRD_POLICY_FILE" >/dev/null <<'JSON'
{
  "policies": {
    "DisableTelemetry": true,
    "DisableFirefoxStudies": true,
    "DisablePocket": true,
    "DisableFirefoxAccounts": true,
    "DisableDefaultBrowserAgent": true,
    "DisableAppUpdate": true,
    "NetworkPrediction": false,
    "DNSOverHTTPS": {
      "Enabled": false,
      "Locked": true
    },
    "OfferToSaveLogins": false,
    "PasswordManagerEnabled": false,
    "AutofillAddressEnabled": false,
    "AutofillCreditCardEnabled": false,
    "SearchSuggestEnabled": false,
    "NoDefaultBookmarks": true,
    "Cookies": {
      "Default": 3,
      "AcceptThirdParty": "never",
      "RejectTracker": true,
      "Locked": true
    },
    "EnableTrackingProtection": {
      "Value": true,
      "Locked": true,
      "Cryptomining": true,
      "Fingerprinting": true
    },
    "UserMessaging": {
      "ExtensionRecommendations": false,
      "FeatureRecommendations": false,
      "UrlbarInterventions": false,
      "SkipOnboarding": true,
      "MoreFromMozilla": false,
      "Locked": true
    },
    "Preferences": {
      "mailnews.message_display.disable_remote_image": {
        "Value": true,
        "Locked": true
      },
      "mailnews.default_html_action": {
        "Value": 1,
        "Locked": true
      },
      "network.cookie.cookieBehavior": {
        "Value": 2,
        "Locked": true
      },
      "places.history.enabled": {
        "Value": false,
        "Locked": true
      },
      "mailnews.start_page.enabled": {
        "Value": false,
        "Locked": true
      },
      "mail.server.default.attachPgpKeys": {
        "Value": false,
        "Locked": false
      }
    }
  }
}
JSON

  log_ok "Thunderbird policies applied."
}

_thunderbird_set_default_client() {
  log_info "Setting Thunderbird as default email client..."

  if command_exists xdg-mime; then
    xdg-mime default thunderbird.desktop x-scheme-handler/mailto || true
  fi

  log_ok "Thunderbird set as default email client."
}

# ---------------------------------------------------------------------------
# Rollback
# ---------------------------------------------------------------------------

rollback_thunderbird() {
  log_info "Rolling back Thunderbird policies..."
  ensure_sudo

  if [[ -f "$THUNDERBIRD_POLICY_FILE" ]]; then
    local backup_file
    backup_file="${THUNDERBIRD_POLICY_FILE}.bak.$(date +%s)"
    sudo cp "$THUNDERBIRD_POLICY_FILE" "$backup_file"
    sudo rm -f "$THUNDERBIRD_POLICY_FILE"
    log_ok "Removed Thunderbird policies (backup: $backup_file)."
  else
    log_warn "No Thunderbird policies found at $THUNDERBIRD_POLICY_FILE."
  fi
}
