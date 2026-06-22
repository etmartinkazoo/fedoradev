#!/usr/bin/env bash
# shellcheck shell=bash
#
# Firefox installation and hardening via managed policies.
# Uses the Fedora Firefox package with privacy-hardening policies
# and force-installs uBlock Origin.

if [[ -z "${SETUP_LIB_DIR:-}" ]]; then
  SETUP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
# shellcheck source=common.sh disable=SC1091
source "${SETUP_LIB_DIR}/common.sh"

readonly FIREFOX_POLICY_DIR_FALLBACK="/usr/share/mozilla"

_firefox_policy_file() {
  local binary install_dir
  binary=$(command -v firefox 2>/dev/null) || { echo "${FIREFOX_POLICY_DIR_FALLBACK}/policies.json"; return; }
  # Fedora ships /usr/bin/firefox as a wrapper script; resolve the real lib dir
  if [[ -f "$binary" ]]; then
    local moz_lib_dir
    moz_lib_dir=$(grep -m1 'MOZ_LIB_DIR=' "$binary" 2>/dev/null | sed 's/.*MOZ_LIB_DIR="//;s/"$//')
    if [[ -n "$moz_lib_dir" ]]; then
      echo "${moz_lib_dir}/firefox/distribution/policies.json"
      return
    fi
  fi
  install_dir=$(dirname "$(readlink -f "$binary" 2>/dev/null)" 2>/dev/null) || { echo "${FIREFOX_POLICY_DIR_FALLBACK}/policies.json"; return; }
  echo "${install_dir}/distribution/policies.json"
}

# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------

install_firefox() {
  log_info "Checking Firefox..."
  ensure_sudo

  if ! command_exists firefox; then
    log_info "Installing Firefox from Fedora repositories..."
    sudo dnf install -y firefox || return 1
  else
    log_ok "Firefox already installed."
  fi

  _firefox_ensure_policy_dir
  _firefox_apply_policies
  _firefox_set_default_browser

  log_ok "Firefox configured."
}

# ---------------------------------------------------------------------------
# Policy file
# ---------------------------------------------------------------------------

_firefox_ensure_policy_dir() {
  local dir
  dir=$(dirname "$(_firefox_policy_file)")
  if [[ ! -d "$dir" ]]; then
    sudo mkdir -p "$dir"
  fi
}

_firefox_apply_policies() {
  local policy_file
  policy_file=$(_firefox_policy_file)
  log_info "Applying Firefox managed policies to ${policy_file}..."

  if [[ -f "$policy_file" ]]; then
    local backup_file
    backup_file="${policy_file}.bak.$(date +%s)"
    sudo cp "$policy_file" "$backup_file"
    log_info "Backed up existing Firefox policies to $backup_file"
  fi

  sudo tee "$policy_file" >/dev/null <<'JSON'
{
  "policies": {
    "DisableTelemetry": true,
    "DisableFirefoxStudies": true,
    "DisablePocket": true,
    "DisableFirefoxAccounts": true,
    "DisableDefaultBrowserAgent": true,
    "DisableAppUpdate": true,
    "DisableFormHistory": true,
    "DisablePasswordReveal": true,
    "DisableFirefoxScreenshots": true,
    "DisableFeedbackCommands": true,
    "DisableBuiltinPDFViewer": true,
    "NetworkPrediction": false,
    "DNSOverHTTPS": {
      "Enabled": false,
      "Locked": true
    },
    "HttpsOnlyMode": "enabled",
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
    "FirefoxHome": {
      "Search": false,
      "TopSites": false,
      "SponsoredTopSites": false,
      "Highlights": false,
      "Pocket": false,
      "Stories": false,
      "SponsoredPocket": false,
      "SponsoredStories": false,
      "Snippets": false,
      "Locked": true
    },
    "NewTabPage": false,
    "OverrideFirstRunPage": "",
    "OverridePostUpdatePage": "",
    "Homepage": {
      "URL": "about:blank",
      "Locked": true,
      "StartPage": "previous-session"
    },
    "SanitizeOnShutdown": {
      "Cache": true,
      "Cookies": false,
      "Downloads": true,
      "FormData": true,
      "History": false,
      "Sessions": false,
      "SiteSettings": true,
      "OfflineApps": true,
      "Locked": true
    },
    "Preferences": {
      "browser.startup.page": {
        "Value": 3,
        "Status": "locked"
      },
      "browser.newtabpage.enabled": {
        "Value": false,
        "Status": "locked"
      },
      "browser.newtab.blank": {
        "Value": true,
        "Status": "locked"
      },
      "browser.newtabpage.activity-stream.showWeather": {
        "Value": false,
        "Status": "locked"
      },
      "browser.newtabpage.activity-stream.showSponsoredTopSites": {
        "Value": false,
        "Status": "locked"
      },
      "browser.newtabpage.activity-stream.showSponsored": {
        "Value": false,
        "Status": "locked"
      },
      "browser.newtabpage.activity-stream.feeds.topsites": {
        "Value": false,
        "Status": "locked"
      },
      "browser.newtabpage.activity-stream.feeds.section.topstories": {
        "Value": false,
        "Status": "locked"
      },
      "browser.newtabpage.activity-stream.feeds.snippets": {
        "Value": false,
        "Status": "locked"
      },
      "browser.newtabpage.activity-stream.newtabWallpapers.enabled": {
        "Value": false,
        "Status": "locked"
      },
      "browser.newtabpage.activity-stream.newtabWallpapers.v2.enabled": {
        "Value": false,
        "Status": "locked"
      },
      "browser.newtabpage.activity-stream.feeds.system.topics": {
        "Value": false,
        "Status": "locked"
      },
      "browser.newtabpage.activity-stream.discoverystream.config.enabled": {
        "Value": false,
        "Status": "locked"
      },
      "browser.newtabpage.activity-stream.discoverystream.enabled": {
        "Value": false,
        "Status": "locked"
      },
      "browser.newtabpage.activity-stream.prerender.enabled": {
        "Value": false,
        "Status": "locked"
      },
      "browser.newtabpage.activity-stream.improvesearch.topSiteSearchShortcuts": {
        "Value": false,
        "Status": "locked"
      },
      "browser.newtabpage.activity-stream.improvesearch.noSearchSet": {
        "Value": true,
        "Status": "locked"
      },
      "privacy.trackingprotection.enabled": {
        "Value": true,
        "Status": "locked"
      },
      "privacy.trackingprotection.socialtracking.enabled": {
        "Value": true,
        "Status": "locked"
      },
      "privacy.trackingprotection.cryptomining.enabled": {
        "Value": true,
        "Status": "locked"
      },
      "privacy.trackingprotection.fingerprinting.enabled": {
        "Value": true,
        "Status": "locked"
      },
      "security.mixed_content.block_active_content": {
        "Value": true,
        "Status": "locked"
      },
      "security.mixed_content.block_display_content": {
        "Value": true,
        "Status": "locked"
      },
      "security.mixed_content.upgrade_display_content": {
        "Value": true,
        "Status": "locked"
      },
      "security.OCSP.require": {
        "Value": true,
        "Status": "locked"
      },
      "dom.security.https_only_mode": {
        "Value": true,
        "Status": "locked"
      },
      "signon.autofillForms": {
        "Value": false,
        "Status": "locked"
      },
      "signon.rememberSignons": {
        "Value": false,
        "Status": "locked"
      },
      "media.peerconnection.enabled": {
        "Value": false,
        "Status": "locked"
      },
      "webgl.disabled": {
        "Value": true,
        "Status": "locked"
      }
    },
    "UserMessaging": {
      "ExtensionRecommendations": false,
      "FeatureRecommendations": false,
      "UrlbarInterventions": false,
      "SkipOnboarding": true,
      "MoreFromMozilla": false,
      "FirefoxLabs": false,
      "Locked": true
    },
    "ExtensionSettings": {
      "uBlock0@raymondhill.net": {
        "installation_mode": "force_installed",
        "install_url": "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi",
        "locked": true
      }
    }
  }
}
JSON

  log_ok "Firefox policies applied."
}

_firefox_set_default_browser() {
  log_info "Setting Firefox as default browser..."

  if command_exists xdg-settings; then
    xdg-settings set default-url-scheme-handler http firefox.desktop || true
    xdg-settings set default-url-scheme-handler https firefox.desktop || true
    xdg-settings set default-web-browser firefox.desktop || true
  fi

  log_ok "Firefox set as default browser."
}

# ---------------------------------------------------------------------------
# Rollback
# ---------------------------------------------------------------------------

rollback_firefox() {
  log_info "Rolling back Firefox policies..."
  ensure_sudo

  local policy_file
  policy_file=$(_firefox_policy_file)

  if [[ -f "$policy_file" ]]; then
    local backup_file
    backup_file="${policy_file}.bak.$(date +%s)"
    sudo cp "$policy_file" "$backup_file"
    sudo rm -f "$policy_file"
    log_ok "Removed Firefox policies (backup: $backup_file)."
  else
    log_warn "No Firefox policies found at ${policy_file}."
  fi
}
