#!/usr/bin/env bash
# shellcheck shell=bash
#
# Rollback helpers for the most invasive setup changes.
# These restore the previous state, not a pristine Fedora default.

if [[ -z "${SETUP_LIB_DIR:-}" ]]; then
  SETUP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
# shellcheck source=common.sh disable=SC1091
source "${SETUP_LIB_DIR}/common.sh"

# ---------------------------------------------------------------------------
# Public entry points
# ---------------------------------------------------------------------------

rollback_all() {
  log_info "Rolling back all managed changes..."
  rollback_hosts
  rollback_dns
  rollback_firefox
  rollback_thunderbird
  log_ok "Rollback complete."
}

rollback_hosts() {
  log_info "Rolling back /etc/hosts blocklist..."
  ensure_sudo

  if ! grep -q "# === BEGIN HOSTS-BLOCKLIST ===" /etc/hosts 2>/dev/null; then
    log_warn "No managed blocklist section found in /etc/hosts."
    return 0
  fi

  local backup_file
  backup_file="/etc/hosts.bak.$(date +%s)"
  sudo cp /etc/hosts "$backup_file"

  local cleaned_file
  cleaned_file=$(mktemp)
  sed '/# === BEGIN HOSTS-BLOCKLIST ===/,$d' /etc/hosts > "$cleaned_file"
  sudo cp "$cleaned_file" /etc/hosts
  rm -f "$cleaned_file"

  log_ok "Removed managed blocklist from /etc/hosts (backup: $backup_file)."
  log_info "To restore the blocklist, run: setup hosts"
}

rollback_dns() {
  log_info "Rolling back LibreDNS configuration..."
  ensure_sudo

  local dropin="/etc/systemd/resolved.conf.d/libredns.conf"
  if [[ ! -f "$dropin" ]]; then
    log_warn "LibreDNS drop-in not found."
    return 0
  fi

  local backup_file
  backup_file="${dropin}.bak.$(date +%s)"
  sudo cp "$dropin" "$backup_file"
  sudo rm -f "$dropin"
  sudo systemctl restart systemd-resolved

  log_ok "Removed LibreDNS drop-in (backup: $backup_file)."
}
