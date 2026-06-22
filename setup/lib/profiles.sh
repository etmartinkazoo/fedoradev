#!/usr/bin/env bash
# shellcheck shell=bash
#
# Setup profiles: strict, balanced, minimal.
#
# Profiles set environment variables that downstream modules consume:
#   SETUP_HOSTS_CATEGORIES     space-separated blocklist categories
#   SETUP_DISABLE_IPV6         1 = disable IPv6
#   SETUP_INSTALL_CURATED_APPS 1 = install CLI tools, mpv, Zathura
#   SETUP_INSTALL_EXTRAS       1 = fstrim, dnf countme, USBGuard, TLP

if [[ -z "${SETUP_LIB_DIR:-}" ]]; then
  SETUP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
# shellcheck source=common.sh disable=SC1091
source "${SETUP_LIB_DIR}/common.sh"

# ---------------------------------------------------------------------------
# Public entry points
# ---------------------------------------------------------------------------

run_profile_strict() {
  log_info "Running STRICT profile..."
  _apply_profile strict
}

run_profile_balanced() {
  log_info "Running BALANCED profile..."
  _apply_profile balanced
}

run_profile_minimal() {
  log_info "Running MINIMAL profile..."
  _apply_profile minimal
}

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

_apply_profile() {
  local profile="$1"

  # Clear any stale values.
  unset SETUP_HOSTS_CATEGORIES
  unset SETUP_DISABLE_IPV6
  unset SETUP_INSTALL_CURATED_APPS
  unset SETUP_INSTALL_EXTRAS

  case "$profile" in
    strict)
      SETUP_HOSTS_CATEGORIES="ads trackers social porn"
      SETUP_DISABLE_IPV6=1
      SETUP_INSTALL_CURATED_APPS=1
      SETUP_INSTALL_EXTRAS=1
      ;;
    balanced)
      SETUP_HOSTS_CATEGORIES="ads entertainment social trackers porn"
      SETUP_DISABLE_IPV6=0
      SETUP_INSTALL_CURATED_APPS=1
      SETUP_INSTALL_EXTRAS=1
      ;;
    minimal)
      SETUP_HOSTS_CATEGORIES="ads trackers"
      SETUP_DISABLE_IPV6=0
      SETUP_INSTALL_CURATED_APPS=0
      SETUP_INSTALL_EXTRAS=0
      ;;
    *)
      log_error "Unknown profile: $profile"
      return 1
      ;;
  esac

  export SETUP_HOSTS_CATEGORIES
  export SETUP_DISABLE_IPV6
  export SETUP_INSTALL_CURATED_APPS
  export SETUP_INSTALL_EXTRAS

  log_info "Profile settings:"
  log_info "  hosts categories: ${SETUP_HOSTS_CATEGORIES}"
  log_info "  Disable IPv6: ${SETUP_DISABLE_IPV6}"
  log_info "  Curated apps: ${SETUP_INSTALL_CURATED_APPS}"
  log_info "  Extras: ${SETUP_INSTALL_EXTRAS}"

  run_all
}
