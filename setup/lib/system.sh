#!/usr/bin/env bash
# shellcheck shell=bash
#
# System settings and GNOME privacy hardening.

if [[ -z "${SETUP_LIB_DIR:-}" ]]; then
  SETUP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
# shellcheck source=common.sh disable=SC1091
source "${SETUP_LIB_DIR}/common.sh"

# ---------------------------------------------------------------------------
# General system settings
# ---------------------------------------------------------------------------

apply_system_settings() {
  log_info "Applying system settings..."

  if command_exists gsettings; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface show-battery-percentage true 2>/dev/null || true
    log_ok "Dark mode and battery percentage enabled."

    gsettings_set_if_exists org.gnome.desktop.peripherals.mouse natural-scroll false
    gsettings_set_if_exists org.gnome.desktop.peripherals.touchpad natural-scroll false
    log_ok "Traditional scroll direction enabled for mouse and touchpad."

    gsettings set org.gnome.settings-daemon.plugins.power idle-dim false 2>/dev/null || true
    gsettings set org.gnome.settings-daemon.plugins.power power-saver-profile-on-low-battery false 2>/dev/null || true
    gsettings set org.gnome.settings-daemon.plugins.power ambient-enabled false 2>/dev/null || true
    log_ok "Screen dim, auto brightness, and power-saver disabled."

    gsettings_set_if_exists org.gnome.nautilus.preferences default-folder-viewer 'list-view'
    log_ok "Nautilus default view set to list view."

    _install_papirus_icon_theme
  else
    log_warn "gsettings not found; skipping GNOME settings."
  fi

  log_warn "Device name must be changed manually in Settings > About."
}

_install_papirus_icon_theme() {
  if [[ -d "$HOME/.icons/Papirus" && -d "$HOME/.icons/Papirus-Dark" ]]; then
    log_ok "Papirus icon theme already installed."
  else
    log_info "Installing Papirus icon theme..."
    ensure_cmd wget wget
    wget -qO- https://git.io/papirus-icon-theme-install | env DESTDIR="$HOME/.icons" sh
    log_ok "Papirus icon theme installed."
  fi

  gsettings_set_if_exists org.gnome.desktop.interface icon-theme 'Papirus-Dark'
  log_ok "Papirus-Dark set as icon theme."
}

# ---------------------------------------------------------------------------
# GNOME privacy & security hardening
# ---------------------------------------------------------------------------

harden_gnome() {
  log_info "Hardening GNOME for privacy and security..."

  if ! command_exists gsettings; then
    log_warn "gsettings not found; skipping GNOME hardening."
    return 0
  fi

  log_info "Disabling sensors, usage tracking, and recent files..."
  gsettings_set_if_exists org.gnome.desktop.privacy disable-camera true
  gsettings_set_if_exists org.gnome.desktop.privacy disable-microphone true
  gsettings_set_if_exists org.gnome.desktop.privacy disable-sound-output true
  gsettings_set_if_exists org.gnome.desktop.privacy remember-app-usage false
  gsettings_set_if_exists org.gnome.desktop.privacy remember-recent-files false
  gsettings_set_if_exists org.gnome.desktop.privacy remove-old-temp-files true
  gsettings_set_if_exists org.gnome.desktop.privacy remove-old-trash-files true
  gsettings_set_if_exists org.gnome.desktop.privacy report-technical-problems false
  gsettings_set_if_exists org.gnome.desktop.privacy send-software-usage-stats false
  gsettings_set_if_exists org.gnome.desktop.privacy show-full-name-in-top-bar false
  gsettings_set_if_exists org.gnome.desktop.privacy usb-protection true
  gsettings_set_if_exists org.gnome.desktop.privacy usb-protection-level 'lockscreen'

  log_info "Configuring screen lock and idle timeout..."
  gsettings_set_if_exists org.gnome.desktop.session idle-delay 300
  gsettings_set_if_exists org.gnome.desktop.screensaver lock-enabled true
  gsettings_set_if_exists org.gnome.desktop.screensaver lock-activation-enabled true
  gsettings_set_if_exists org.gnome.desktop.screensaver lock-delay 0

  log_info "Disabling lock-screen notifications and external search..."
  gsettings_set_if_exists org.gnome.desktop.notifications show-in-lock-screen false
  gsettings_set_if_exists org.gnome.desktop.search-providers disable-external true

  log_info "Disabling location services..."
  gsettings_set_if_exists org.gnome.system.location enabled false
  gsettings_set_if_exists org.gnome.system.location max-accuracy-level 'country'

  log_info "Disabling GNOME Online Accounts and Evolution data services..."
  systemctl --user mask goa-daemon.service goa-identity-service.service 2>/dev/null || true
  systemctl --user mask evolution-addressbook-factory.service evolution-calendar-factory.service evolution-source-registry.service 2>/dev/null || true
  log_ok "GNOME Online Accounts and Evolution services masked."

  log_info "Tightening power/suspend timeouts..."
  gsettings_set_if_exists org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 900
  gsettings_set_if_exists org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 300

  log_ok "GNOME privacy and security settings applied."
  log_warn "Review Settings > Privacy & Security to confirm changes."
}
