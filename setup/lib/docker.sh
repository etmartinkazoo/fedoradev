#!/usr/bin/env bash
# shellcheck shell=bash
#
# Docker CE installation.

if [[ -z "${SETUP_LIB_DIR:-}" ]]; then
  SETUP_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
# shellcheck source=common.sh disable=SC1091
source "${SETUP_LIB_DIR}/common.sh"

install_docker() {
  log_info "Checking Docker..."

  if command_exists docker; then
    log_ok "Docker already installed."
  else
    log_info "Removing any old Docker packages..."
    ensure_sudo
    sudo dnf remove -y \
      docker docker-client docker-client-latest docker-common \
      docker-latest docker-latest-logrotate docker-logrotate \
      docker-selinux docker-engine-selinux docker-engine || true

    log_info "Adding Docker CE repository..."
    sudo dnf install -y dnf-plugins-core
    sudo dnf config-manager addrepo --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo

    log_info "Installing Docker CE..."
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    log_info "Enabling Docker service..."
    sudo systemctl enable --now docker
  fi

  # Post-install Linux steps: always ensure the docker group exists and the
  # current user is a member, even if Docker was already installed.
  ensure_sudo

  if ! getent group docker >/dev/null; then
    sudo groupadd docker
  fi

  if ! id -nG "$USER" | grep -qw docker; then
    sudo usermod -aG docker "$USER"
    log_ok "User added to docker group."
    log_warn "Run 'newgrp docker' or log out/in for group changes to take effect."
  else
    log_ok "User is already in the docker group."
  fi
}
