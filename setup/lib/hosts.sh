#!/usr/bin/env bash
# shellcheck shell=bash
#
# /etc/hosts blocklist with toggleable categories.

if [[ -z "${SETUP_LIB_DIR:-}" ]]; then
  SETUP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
# shellcheck source=common.sh disable=SC1091
source "${SETUP_LIB_DIR}/common.sh"

readonly HOSTS_BLOCKLIST_DIR="${DOTFILES_DIR}/hosts-blocklist/.config/hosts-blocklist"
readonly HOSTS_BLOCKLIST_CATEGORIES_DIR="${HOSTS_BLOCKLIST_DIR}/categories"
readonly HOSTS_BLOCKLIST_ENABLED_FILE="${HOSTS_BLOCKLIST_DIR}/enabled"
readonly HOSTS_BLOCKLIST_WHITELIST_FILE="${HOSTS_BLOCKLIST_DIR}/whitelist.txt"
readonly HOSTS_BLOCKLIST_CUSTOM_FILE="${HOSTS_BLOCKLIST_DIR}/custom.txt"

install_hosts_blocklist() {
  log_info "Setting up /etc/hosts blocklist..."
  ensure_sudo
  mkdir -p "$HOSTS_BLOCKLIST_CATEGORIES_DIR"

  _hosts_ensure_defaults

  # If a profile selected specific categories, overwrite the enabled file.
  if [[ -n "${SETUP_HOSTS_CATEGORIES:-}" ]]; then
    echo "$SETUP_HOSTS_CATEGORIES" | tr ' ' '\n' > "$HOSTS_BLOCKLIST_ENABLED_FILE"
    log_info "Profile set hosts categories: ${SETUP_HOSTS_CATEGORIES}"
  fi

  stow_package hosts-blocklist

  _hosts_rebuild

  log_info "Config directory: ${HOME}/.config/hosts-blocklist"
  log_info "Toggle categories: ./setup/bin/setup hosts enable|disable|toggle <category>"
  log_info "Whitelist domains: edit $HOSTS_BLOCKLIST_WHITELIST_FILE"
  log_info "Custom blocks: edit $HOSTS_BLOCKLIST_CUSTOM_FILE"
}

# ---------------------------------------------------------------------------
# Category toggling
# ---------------------------------------------------------------------------

enable_hosts_category() {
  local category="$1"
  _hosts_require_category "$category" || return 1

  log_info "Enabling hosts blocklist category: $category"
  _hosts_modify_category "$category" add
}

disable_hosts_category() {
  local category="$1"
  _hosts_require_category "$category" || return 1

  log_info "Disabling hosts blocklist category: $category"
  _hosts_modify_category "$category" remove
}

toggle_hosts_category() {
  local category="$1"
  _hosts_require_category "$category" || return 1

  local enabled_categories=()
  _hosts_read_enabled_categories enabled_categories

  if _hosts_array_contains "$category" enabled_categories; then
    disable_hosts_category "$category"
  else
    enable_hosts_category "$category"
  fi
}

list_hosts_categories() {
  local enabled_categories=()
  _hosts_read_enabled_categories enabled_categories

  printf "%-15s %s\n" "CATEGORY" "STATUS"
  local cat_file category
  for cat_file in "$HOSTS_BLOCKLIST_CATEGORIES_DIR"/*.txt; do
    [[ -f "$cat_file" ]] || continue
    category=$(basename "$cat_file" .txt)
    if _hosts_array_contains "$category" enabled_categories; then
      printf "%-15s %s\n" "$category" "enabled"
    else
      printf "%-15s %s\n" "$category" "disabled"
    fi
  done
}

run_hosts_menu() {
  local choice category
  while true; do
    echo ""
    echo "## /etc/hosts blocklist categories"
    list_hosts_categories
    echo ""
    echo "e) enable category"
    echo "d) disable category"
    echo "t) toggle category"
    echo "r) rebuild /etc/hosts"
    echo "q) back"
    read -rp "Choice: " choice

    case "$choice" in
      e)
        read -rp "Category to enable: " category
        enable_hosts_category "$category"
        ;;
      d)
        read -rp "Category to disable: " category
        disable_hosts_category "$category"
        ;;
      t)
        read -rp "Category to toggle: " category
        toggle_hosts_category "$category"
        ;;
      r)
        install_hosts_blocklist
        ;;
      q|Q)
        break
        ;;
      *)
        log_warn "Invalid choice."
        ;;
    esac
  done
}

_hosts_require_category() {
  local category="$1"
  if [[ -z "$category" ]]; then
    log_error "No category specified."
    log_info "Available categories: $(_hosts_available_categories | tr '\n' ' ')"
    return 1
  fi

  if [[ ! -f "${HOSTS_BLOCKLIST_CATEGORIES_DIR}/${category}.txt" ]]; then
    log_error "Unknown category: $category"
    log_info "Available categories: $(_hosts_available_categories | tr '\n' ' ')"
    return 1
  fi
  return 0
}

_hosts_available_categories() {
  local cat_file category
  for cat_file in "$HOSTS_BLOCKLIST_CATEGORIES_DIR"/*.txt; do
    [[ -f "$cat_file" ]] || continue
    basename "$cat_file" .txt
  done
}

_hosts_array_contains() {
  local value="$1"
  local -n arr="$2"
  local item
  for item in "${arr[@]}"; do
    [[ "$item" == "$value" ]] && return 0
  done
  return 1
}

_hosts_modify_category() {
  local category="$1" action="$2"

  ensure_sudo
  _hosts_ensure_defaults
  stow_package hosts-blocklist

  local enabled_categories=()
  _hosts_read_enabled_categories enabled_categories

  local new_categories=()
  local item found=0

  for item in "${enabled_categories[@]}"; do
    if [[ "$item" == "$category" ]]; then
      found=1
      [[ "$action" == "add" ]] && new_categories+=("$item")
    else
      new_categories+=("$item")
    fi
  done

  if [[ "$action" == "add" && "$found" -eq 0 ]]; then
    new_categories+=("$category")
  fi

  printf "%s\n" "${new_categories[@]}" > "$HOSTS_BLOCKLIST_ENABLED_FILE"
  _hosts_rebuild
}

_hosts_read_enabled_categories() {
  local -n out="$1"
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    out+=("$line")
  done < "$HOSTS_BLOCKLIST_ENABLED_FILE"
}

_hosts_rebuild() {
  local enabled_categories=()
  _hosts_read_enabled_categories enabled_categories

  if [[ ${#enabled_categories[@]} -eq 0 ]]; then
    log_warn "No categories enabled. /etc/hosts blocklist section will be removed."
  else
    log_info "Enabled categories: ${enabled_categories[*]}"
  fi

  local blocklist_file formatted_file
  blocklist_file=$(mktemp)
  formatted_file=$(mktemp)

  _hosts_build_blocklist enabled_categories "$blocklist_file"
  _hosts_format_blocklist "$blocklist_file" "$formatted_file"

  local blocked_count
  blocked_count=$(wc -l < "$formatted_file" | awk '{print $1}')

  _hosts_apply "$formatted_file" enabled_categories "$blocked_count"

  rm -f "$blocklist_file" "$formatted_file"

  log_ok "/etc/hosts blocklist applied ($blocked_count domains blocked)."
}

_hosts_ensure_defaults() {
  if [[ ! -f "$HOSTS_BLOCKLIST_WHITELIST_FILE" ]]; then
    cat > "$HOSTS_BLOCKLIST_WHITELIST_FILE" <<'EOF'
# Whitelisted domains (one per line)
# Example:
# example.com
EOF
  fi

  if [[ ! -f "$HOSTS_BLOCKLIST_CUSTOM_FILE" ]]; then
    cat > "$HOSTS_BLOCKLIST_CUSTOM_FILE" <<'EOF'
# Custom blocked domains (one per line)
# Example:
# example.com
EOF
  fi

  if [[ ! -f "$HOSTS_BLOCKLIST_ENABLED_FILE" ]]; then
    printf "%s\n" ads entertainment social trackers porn > "$HOSTS_BLOCKLIST_ENABLED_FILE"
  fi
}

_hosts_build_blocklist() {
  local -n categories="$1"
  local out_file="$2"
  local category cat_file

  for category in "${categories[@]}"; do
    cat_file="${HOSTS_BLOCKLIST_CATEGORIES_DIR}/${category}.txt"
    if [[ -f "$cat_file" ]]; then
      log_info "Adding category: $category"
      grep -vE '^\s*(#|$)' "$cat_file" >> "$out_file" || true
    else
      log_warn "Category file not found: $cat_file"
    fi
  done

  if [[ -s "$HOSTS_BLOCKLIST_CUSTOM_FILE" ]]; then
    log_info "Adding custom entries..."
    grep -vE '^\s*(#|$)' "$HOSTS_BLOCKLIST_CUSTOM_FILE" >> "$out_file" || true
  fi
}

_hosts_format_blocklist() {
  local in_file="$1"
  local out_file="$2"
  local sorted_file filtered_file valid_file
  sorted_file=$(mktemp)
  filtered_file=$(mktemp)
  valid_file=$(mktemp)

  # Deduplicate.
  sort -u "$in_file" > "$sorted_file"

  # Apply whitelist (grep exits 1 when every line is filtered; that is OK).
  grep -vxF -f "$HOSTS_BLOCKLIST_WHITELIST_FILE" "$sorted_file" > "$filtered_file" || [[ $? -eq 1 ]]

  # Validate domains (grep exits 1 when no lines match; that is OK).
  grep -E '^[a-zA-Z0-9][-a-zA-Z0-9.]*[a-zA-Z0-9]$' "$filtered_file" > "$valid_file" || [[ $? -eq 1 ]]

  # Format as hosts entries.
  sed 's/^/0.0.0.0 /' "$valid_file" > "$out_file"

  rm -f "$sorted_file" "$filtered_file" "$valid_file"
}

_hosts_apply() {
  local formatted_file="$1"
  local -n categories="$2"
  local blocked_count="$3"

  ensure_sudo

  local backup_file
  backup_file="/etc/hosts.bak.$(date +%s)"
  sudo cp /etc/hosts "$backup_file"
  log_ok "Backed up /etc/hosts to $backup_file"

  local preserved_file
  preserved_file=$(mktemp)
  if grep -q "# === BEGIN HOSTS-BLOCKLIST ===" /etc/hosts; then
    sed '/# === BEGIN HOSTS-BLOCKLIST ===/,$d' /etc/hosts > "$preserved_file"
  else
    cat /etc/hosts > "$preserved_file"
  fi

  {
    cat "$preserved_file"
    echo ""
    echo "# === BEGIN HOSTS-BLOCKLIST ==="
    echo "# Managed by ${HOME}/.dotfiles/setup/bin/setup"
    echo "# Categories: ${categories[*]}"
    echo "# Blocked domains: $blocked_count"
    echo "#"
    cat "$formatted_file"
    echo "# === END HOSTS-BLOCKLIST ==="
  } | sudo tee /etc/hosts >/dev/null

  rm -f "$preserved_file"
}
