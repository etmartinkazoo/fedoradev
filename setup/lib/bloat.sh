#!/usr/bin/env bash
# shellcheck shell=bash
#
# Remove safe Fedora defaults and bloat. Keeps Bluetooth enabled.

if [[ -z "${SETUP_LIB_DIR:-}" ]]; then
  SETUP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
# shellcheck source=common.sh disable=SC1091
source "${SETUP_LIB_DIR}/common.sh"

# Packages that are safe to remove on a minimal developer workstation.
# Bluetooth-related packages are intentionally left alone.
readonly BLOAT_PACKAGES=(
  gnome-tour
  gnome-connections
  mediawriter
  rhythmbox
  cheese
  snapshot
  simple-scan
  gnome-contacts
  gnome-calendar
  gnome-clocks
  gnome-weather
  gnome-maps
  gnome-characters
  gnome-font-viewer
  gnome-logs
  gnome-software
  yelp
  fedora-chromium-config
  fedora-bookmarks
  libreoffice-calc
  libreoffice-draw
  libreoffice-impress
  libreoffice-writer
  libreoffice-core
  libreoffice-data
  gnome-boxes
  malcontent-control
)

remove_fedora_bloat() {
  log_info "Removing Fedora bloat (keeping Bluetooth)..."
  ensure_sudo

  _remove_flatpak
  _remove_bloat_packages
  _autoremove

  log_ok "Bloat removal complete."
}

_remove_flatpak() {
  if ! command_exists flatpak; then
    log_ok "Flatpak not installed."
    return 0
  fi

  log_info "Removing Flatpak remotes and apps..."

  # Remove common remotes if present.
  sudo flatpak remote-delete --system flathub 2>/dev/null || true
  sudo flatpak remote-delete --user flathub 2>/dev/null || true

  # Remove installed flatpaks.
  local app
  while IFS= read -r app; do
    [[ -z "$app" ]] && continue
    log_info "Removing flatpak: $app"
    sudo flatpak uninstall -y "$app" 2>/dev/null || true
  done < <(flatpak list --app --columns=application 2>/dev/null || true)

  # Remove the flatpak package itself.
  if package_installed flatpak; then
    log_info "Removing flatpak package..."
    sudo dnf remove -y flatpak
  fi

  log_ok "Flatpak removed."
}

_remove_bloat_packages() {
  local to_remove=()
  local pkg

  for pkg in "${BLOAT_PACKAGES[@]}"; do
    if package_installed "$pkg"; then
      to_remove+=("$pkg")
    fi
  done

  if [[ ${#to_remove[@]} -eq 0 ]]; then
    log_ok "No bloat packages found."
    return 0
  fi

  log_info "Removing packages: ${to_remove[*]}"
  if sudo dnf remove -y "${to_remove[@]}"; then
    log_ok "Removed ${#to_remove[@]} bloat packages."
  else
    log_warn "Some bloat packages could not be removed; continuing."
  fi
}

_autoremove() {
  log_info "Running autoremove..."
  sudo dnf autoremove -y || true
  log_ok "Autoremove complete."
}


