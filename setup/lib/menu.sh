#!/usr/bin/env bash
# shellcheck shell=bash
#
# Interactive menu and CLI dispatcher.

# shellcheck source=common.sh disable=SC1091
source "${SETUP_LIB_DIR}/common.sh"
# shellcheck source=system.sh disable=SC1091
source "${SETUP_LIB_DIR}/system.sh"
# shellcheck source=firefox.sh disable=SC1091
source "${SETUP_LIB_DIR}/firefox.sh"
# shellcheck source=thunderbird.sh disable=SC1091
source "${SETUP_LIB_DIR}/thunderbird.sh"
# shellcheck source=network.sh disable=SC1091
source "${SETUP_LIB_DIR}/network.sh"
# shellcheck source=bloat.sh disable=SC1091
source "${SETUP_LIB_DIR}/bloat.sh"
# shellcheck source=telemetry.sh disable=SC1091
source "${SETUP_LIB_DIR}/telemetry.sh"
# shellcheck source=hardening.sh disable=SC1091
source "${SETUP_LIB_DIR}/hardening.sh"
# shellcheck source=auth.sh disable=SC1091
source "${SETUP_LIB_DIR}/auth.sh"
# shellcheck source=apps.sh disable=SC1091
source "${SETUP_LIB_DIR}/apps.sh"
# shellcheck source=dns.sh disable=SC1091
source "${SETUP_LIB_DIR}/dns.sh"
# shellcheck source=dev.sh disable=SC1091
source "${SETUP_LIB_DIR}/dev.sh"
# shellcheck source=docker.sh disable=SC1091
source "${SETUP_LIB_DIR}/docker.sh"
# shellcheck source=hosts.sh disable=SC1091
source "${SETUP_LIB_DIR}/hosts.sh"
# shellcheck source=gnome-keyboard.sh disable=SC1091
source "${SETUP_LIB_DIR}/gnome-keyboard.sh"
# shellcheck source=terminal.sh disable=SC1091
source "${SETUP_LIB_DIR}/terminal.sh"
# shellcheck source=audit.sh disable=SC1091
source "${SETUP_LIB_DIR}/audit.sh"
# shellcheck source=ipv6.sh disable=SC1091
source "${SETUP_LIB_DIR}/ipv6.sh"
# shellcheck source=extras.sh disable=SC1091
source "${SETUP_LIB_DIR}/extras.sh"
# shellcheck source=profiles.sh disable=SC1091
source "${SETUP_LIB_DIR}/profiles.sh"
# shellcheck source=rollback.sh disable=SC1091
source "${SETUP_LIB_DIR}/rollback.sh"

# ---------------------------------------------------------------------------
# Full run
# ---------------------------------------------------------------------------

run_all() {
  log_info "Starting full setup..."
  apply_system_settings || log_error "System settings failed."
  configure_gnome_keyboard || log_error "GNOME keyboard configuration failed."
  harden_gnome || log_error "GNOME hardening failed."
  remove_fedora_bloat || log_error "Bloat removal failed."
  harden_network || log_error "Network hardening failed."
  harden_system || log_error "System hardening failed."
  cleanup_telemetry || log_error "Telemetry cleanup failed."
  install_firefox || log_error "Firefox installation failed."
  install_thunderbird || log_error "Thunderbird installation failed."

  if [[ "${SETUP_INSTALL_CURATED_APPS:-0}" == "1" ]]; then
    install_curated_apps || log_error "Curated apps installation failed."
  fi

  install_libredns || log_error "LibreDNS configuration failed."
  install_hosts_blocklist || log_error "Hosts blocklist update failed."

  if [[ "${SETUP_DISABLE_IPV6:-0}" == "1" ]]; then
    disable_ipv6 || log_error "IPv6 disable failed."
  fi

  configure_ptyxis || log_error "Terminal configuration failed."
  install_opencode || log_error "opencode installation failed."
  install_mise || log_error "mise installation failed."
  install_node || log_error "Node installation failed."
  install_pnpm || log_error "pnpm installation failed."
  install_docker || log_error "Docker installation failed."

  if [[ "${SETUP_INSTALL_EXTRAS:-0}" == "1" ]]; then
    apply_extras || log_error "Extras failed."
  fi

  log_ok "Setup complete!"
  log_warn "You may need to restart your terminal/session for some changes."
  if [[ "${SETUP_DISABLE_IPV6:-0}" == "1" ]]; then
    log_warn "IPv6 was disabled; reboot for the GRUB change to take full effect."
  fi
}

# ---------------------------------------------------------------------------
# Interactive menu
# ---------------------------------------------------------------------------

show_menu() {
  cat <<'EOF'

==================================
       Fedora Setup Menu
==================================
1)  Run everything
2)  System settings only
3)  Harden GNOME privacy & security
4)  Configure keyboard-driven GNOME
5)  Remove Fedora bloat
6)  Harden network (firewall + NetworkManager privacy)
7)  Harden system (sysctl, services, auto-updates)
8)  Set up fingerprint unlock (opt-in)
9)  Set up FIDO2/U2F security key (opt-in)
10) Clean up telemetry
11) Install Firefox
12) Install Thunderbird email client
13) Configure LibreDNS ad-blocking over TLS
14) Update /etc/hosts blocklist
15) Configure terminal (Ptyxis)
16) Install opencode
17) Install mise
18) Install Node 24 (via mise)
19) Install pnpm
20) Install Docker
21) Run final audit
22) Manage /etc/hosts blocklist categories
23) Install curated default apps
24) Apply polish extras (fstrim, countme, USBGuard, TLP)
25) Disable IPv6
26) Re-enable IPv6
27) Run strict profile
28) Run balanced profile
29) Run minimal profile
30) Rollback /etc/hosts blocklist
31) Rollback LibreDNS DNS
32) Rollback Firefox policies
33) Rollback all managed changes
q)  Quit

EOF
}

  _run_menu_item() {
  local choice="$1"
  case "$choice" in
    1)  run_all; log_ok "Setup completed successfully." ;;
    2)  apply_system_settings; log_ok "System settings applied." ;;
    3)  harden_gnome; log_ok "GNOME hardening applied." ;;
    4)  configure_gnome_keyboard; log_ok "Keyboard-driven GNOME configured." ;;
    5)  remove_fedora_bloat; log_ok "Fedora bloat removal completed." ;;
    6)  harden_network; log_ok "Network hardening completed." ;;
    7)  harden_system; log_ok "System hardening completed." ;;
    8)  setup_fingerprint; log_ok "Fingerprint setup completed." ;;
    9)  setup_fido2; log_ok "FIDO2/U2F setup completed." ;;
    10) cleanup_telemetry; log_ok "Telemetry cleanup completed." ;;
    11) install_firefox; log_ok "Firefox module completed." ;;
    12) install_thunderbird; log_ok "Thunderbird module completed." ;;
    13) install_libredns; log_ok "LibreDNS configuration completed." ;;
    14) install_hosts_blocklist; log_ok "/etc/hosts blocklist updated." ;;
    15) configure_ptyxis; log_ok "Terminal configuration completed." ;;
    16) install_opencode; log_ok "opencode module completed." ;;
    17) install_mise; log_ok "mise module completed." ;;
    18) install_node; log_ok "Node module completed." ;;
    19) install_pnpm; log_ok "pnpm module completed." ;;
    20) install_docker; log_ok "Docker module completed." ;;
    21) run_audit; log_ok "Audit completed." ;;
    22) run_hosts_menu; log_ok "Returned to main menu." ;;
    23) install_curated_apps; log_ok "Curated apps installed." ;;
    24) apply_extras; log_ok "Polish extras applied." ;;
    25) disable_ipv6; log_ok "IPv6 disabled. Reboot to complete." ;;
    26) enable_ipv6; log_ok "IPv6 re-enabled. Reboot to complete." ;;
    27) run_profile_strict; log_ok "Strict profile completed." ;;
    28) run_profile_balanced; log_ok "Balanced profile completed." ;;
    29) run_profile_minimal; log_ok "Minimal profile completed." ;;
    30) rollback_hosts; log_ok "Hosts blocklist rolled back." ;;
    31) rollback_dns; log_ok "LibreDNS rolled back." ;;
    32) rollback_firefox; log_ok "Firefox policies rolled back." ;;
    33) rollback_all; log_ok "All managed changes rolled back." ;;
    q|Q) log_info "Goodbye."; return 1 ;;
    *)  log_warn "Invalid option." ;;
  esac
  return 0
}

run_interactive_menu() {
  local choice
  while true; do
    show_menu
    read -rp "Choose an option: " choice
    if ! _run_menu_item "$choice"; then
      break
    fi
  done
}

# ---------------------------------------------------------------------------
# CLI dispatcher
# ---------------------------------------------------------------------------

show_usage() {
  cat <<EOF
Usage: $(basename "$0") [COMMAND]

Fedora setup orchestrator.

Commands:
  all             Run everything
  settings        Apply system settings
  gnome           Harden GNOME privacy & security
  gnome-keyboard  Configure keyboard-driven GNOME
  bloat           Remove safe Fedora defaults / bloat
  network         Harden network (firewall + NetworkManager privacy)
  harden          Harden system (sysctl, services, auto-updates)
  telemetry       Clean up telemetry
  fingerprint     Set up fingerprint unlock (opt-in; fprintd + authselect)
  fido2           Set up FIDO2/U2F security-key auth (opt-in; SETUP_FIDO2_2FA=1 for 2FA)
  firefox         Install Firefox with hardened policies
  thunderbird     Install Thunderbird with hardened policies
  libredns        Configure LibreDNS ad-blocking over TLS
  hosts           Update /etc/hosts blocklist
  hosts list      List blocklist categories and their status
  hosts enable <category>   Enable a blocklist category
  hosts disable <category>  Disable a blocklist category
  hosts toggle <category>   Toggle a blocklist category
  terminal        Configure terminal (Ptyxis)
  opencode        Install opencode
  mise            Install mise
  node            Install Node 24 via mise
  pnpm            Install pnpm via mise
  docker          Install Docker CE
  audit           Run final privacy/security audit
  curated-apps    Install CLI tools, mpv, Zathura
  extras          Apply polish extras (fstrim, countme, USBGuard, TLP)
  ipv6-disable    Disable IPv6 via sysctl + GRUB
  ipv6-enable     Re-enable IPv6
  strict          Run strict setup profile
  balanced        Run balanced setup profile
  minimal         Run minimal setup profile
  rollback hosts  Rollback /etc/hosts blocklist
  rollback dns    Rollback LibreDNS
  rollback firefox  Rollback Firefox policies
  rollback thunderbird  Rollback Thunderbird policies
  rollback fingerprint  Disable fingerprint PAM feature
  rollback fido2  Disable FIDO2/U2F PAM feature
  rollback all    Rollback all managed changes
   stow            Stow all dotfile packages
   stow <package>  Stow a specific dotfile package (e.g. nvim, tmux)
   -h, --help      Show this help

With no arguments, an interactive menu is shown.
EOF
}

_dispatch_cli() {
  local command="$1"
  shift
  case "$command" in
    all)             run_all ;;
    settings)        apply_system_settings ;;
    gnome)           harden_gnome ;;
    gnome-keyboard)  configure_gnome_keyboard ;;
    bloat)           remove_fedora_bloat ;;
    network)         harden_network ;;
    harden)          harden_system ;;
    telemetry)       cleanup_telemetry ;;
    fingerprint)     setup_fingerprint ;;
    fido2)           setup_fido2 ;;
    firefox)         install_firefox ;;
    thunderbird)     install_thunderbird ;;
    libredns)        install_libredns ;;
    hosts)           _dispatch_hosts "$@" ;;
    terminal)        configure_ptyxis ;;
    opencode)        install_opencode ;;
    mise)            install_mise ;;
    node)            install_node ;;
    pnpm)            install_pnpm ;;
    docker)          install_docker ;;
    audit)           run_audit ;;
    curated-apps)    install_curated_apps ;;
    extras)          apply_extras ;;
    ipv6-disable)    disable_ipv6 ;;
    ipv6-enable)     enable_ipv6 ;;
    strict)          run_profile_strict ;;
    balanced)        run_profile_balanced ;;
    minimal)         run_profile_minimal ;;
    rollback)        _dispatch_rollback "$@" ;;
    stow)            if [[ $# -gt 0 ]]; then stow_package "$1"; else stow_package_all; fi ;;
    -h|--help|help)  show_usage; return 0 ;;
    *)
      log_error "Unknown command: $command"
      show_usage >&2
      return 1
      ;;
  esac
  log_ok "Setup module '$command' completed successfully."
}

_dispatch_hosts() {
  local subcommand="${1:-}"
  [[ -n "$subcommand" ]] && shift
  case "$subcommand" in
    enable)  enable_hosts_category "$1" ;;
    disable) disable_hosts_category "$1" ;;
    toggle)  toggle_hosts_category "$1" ;;
    list)    list_hosts_categories ;;
    "")      install_hosts_blocklist ;;
    *)
      log_error "Unknown hosts subcommand: $subcommand"
      log_info "Usage: setup hosts [enable|disable|toggle|list] <category>"
      return 1
      ;;
  esac
}

_dispatch_rollback() {
  local subcommand="${1:-}"
  case "$subcommand" in
    hosts)       rollback_hosts ;;
    dns)         rollback_dns ;;
    firefox)     rollback_firefox ;;
    thunderbird) rollback_thunderbird ;;
    fingerprint) disable_fingerprint ;;
    fido2)       disable_fido2 ;;
    all)         rollback_all ;;
    "")
      log_error "No rollback target specified."
      log_info "Usage: setup rollback [hosts|dns|firefox|thunderbird|fingerprint|fido2|all]"
      return 1
      ;;
    *)
      log_error "Unknown rollback target: $subcommand"
      log_info "Usage: setup rollback [hosts|dns|firefox|thunderbird|fingerprint|fido2|all]"
      return 1
      ;;
  esac
}

main() {
  if [[ $# -eq 0 ]]; then
    run_interactive_menu
  else
    _dispatch_cli "$@"
  fi
}
