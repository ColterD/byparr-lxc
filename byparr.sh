#!/usr/bin/env bash

# Byparr LXC Container Script for Proxmox VE
# Creates a lightweight LXC container with Byparr - FlareSolverr alternative
# Provides captcha solving and browser automation for *arr applications
# Compatible with community-scripts/ProxmoxVE framework

# Check if this is being called as an install script (inside container)
if [[ -n "$FUNCTIONS_FILE_PATH" ]]; then
  # INSTALL SCRIPT PORTION - runs inside the container
  source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
  color
  verb_ip6
  catch_errors
  setting_up_container
  network_check
  update_os

  msg_info "Installing Dependencies"
  $STD apt-get install -y \
    curl \
    sudo \
    mc \
    git \
    python3 \
    python3-pip \
    python3-venv \
    build-essential \
    xvfb \
    chromium \
    chromium-driver \
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libatspi2.0-0 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libglib2.0-0 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libu2f-udev \
    libvulkan1 \
    libx11-6 \
    libxcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    libxss1 \
    libxtst6 \
    wget \
    xdg-utils
  msg_ok "Installed Dependencies"

  msg_info "Installing UV Package Manager"
  if ! curl -LsSf https://astral.sh/uv/install.sh | sh; then
    msg_error "Failed to install UV package manager"
    exit 1
  fi
  source /root/.local/bin/env
  if ! command -v uv &> /dev/null; then
    msg_error "UV installation failed - command not found"
    exit 1
  fi
  msg_ok "Installed UV Package Manager"

  msg_info "Cloning Byparr Repository"
  cd /opt
  # Check if repository is accessible
  if ! curl -fsSL --max-time 10 https://api.github.com/repos/ThePhaseless/Byparr > /dev/null; then
    msg_error "Cannot access Byparr repository - check network connection"
    exit 1
  fi
  if ! git clone https://github.com/ThePhaseless/Byparr.git byparr; then
    msg_error "Failed to clone Byparr repository"
    exit 1
  fi
  cd /opt/byparr
  msg_ok "Cloned Byparr Repository"

  msg_info "Installing Python Dependencies"
  if ! /root/.local/bin/uv sync --group test; then
    msg_error "Failed to install Python dependencies"
    exit 1
  fi
  msg_ok "Installed Python Dependencies"

  msg_info "Creating Byparr startup script"
  cat <<'EOF' >/opt/byparr/start-byparr.sh
#!/bin/bash
cd /opt/byparr
export DISPLAY=:99
export LOG_LEVEL=${LOG_LEVEL:-info}
export CAPTCHA_SOLVER=${CAPTCHA_SOLVER:-none}
export PORT=${PORT:-8191}

# Start virtual display
Xvfb :99 -screen 0 1024x768x24 &
XVFB_PID=$!

# Ensure Xvfb has started
sleep 2

# Start Byparr
exec /root/.local/bin/uv run ./cmd.sh
EOF
  chmod +x /opt/byparr/start-byparr.sh
  msg_ok "Created Byparr startup script"

  msg_info "Creating Byparr Service"
  cat <<EOF >/etc/systemd/system/byparr.service
[Unit]
Description=Byparr - FlareSolverr Alternative
Documentation=https://github.com/ThePhaseless/Byparr
After=network-online.target
Wants=network-online.target

[Service]
Type=exec
User=root
Group=root
WorkingDirectory=/opt/byparr
Environment="PATH=/root/.local/bin:/usr/local/bin:/usr/bin:/bin"
Environment="LOG_LEVEL=info"
Environment="CAPTCHA_SOLVER=none"
Environment="PORT=8191"
Environment="DISPLAY=:99"
ExecStartPre=/bin/bash -c 'pkill -f "Xvfb :99" || true'
ExecStart=/opt/byparr/start-byparr.sh
ExecStop=/bin/bash -c 'pkill -f "Xvfb :99" || true'
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=byparr

# Security settings
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/opt/byparr
PrivateTmp=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes

[Install]
WantedBy=multi-user.target
EOF
  msg_ok "Created Byparr Service"

  msg_info "Creating Update Script"
  cat <<'EOF' >/opt/byparr/update-byparr.sh
#!/bin/bash
set -e

echo "Updating Byparr..."

# Stop the service
systemctl stop byparr

# Backup current installation
backup_dir="/opt/byparr_backup_$(date +%Y%m%d_%H%M%S)"
cp -r /opt/byparr "$backup_dir"
echo "Backup created at: $backup_dir"

# Update source code
cd /opt/byparr
git pull origin main

# Update dependencies
/root/.local/bin/uv sync --group test

# Start the service
systemctl start byparr

# Clean up old backups (keep last 3)
cd /opt
ls -t byparr_backup_* 2>/dev/null | tail -n +4 | xargs -r rm -rf

echo "Byparr updated successfully!"
echo "Check status with: systemctl status byparr"
EOF
  chmod +x /opt/byparr/update-byparr.sh
  msg_ok "Created Update Script"

  msg_info "Enabling and Starting Byparr Service"
  systemctl daemon-reload
  systemctl enable byparr
  systemctl start byparr
  msg_ok "Enabled and Started Byparr Service"

  msg_info "Testing Byparr Service"
  sleep 10
  if systemctl is-active --quiet byparr; then
    msg_ok "Byparr Service is running"
  else
    msg_error "Byparr Service failed to start - check logs with: journalctl -u byparr -f"
  fi

  motd_ssh
  customize

  msg_info "Cleaning up"
  $STD apt-get -y autoremove
  $STD apt-get -y autoclean
  msg_ok "Cleaned"

  exit 0
fi

# MAIN SCRIPT PORTION - runs on Proxmox host
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2025 Colter Dahlberg
# Author: Colter Dahlberg (ColterD)
# License: MIT | https://github.com/ColterD/byparr-lxc/raw/main/LICENSE
# Source: https://github.com/ThePhaseless/Byparr

APP="Byparr"
var_tags="${var_tags:-captcha;solver;arr;proxy;flaresolverr;alternative;browser;automation}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-4}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
# TODO: Remove this notice when integrated into main community-scripts project
echo -e "${YW}⚠️  NOTICE: This is a ColterD community fork - Not officially supported by community-scripts yet${CL}"
echo -e "${BL}   For official scripts visit: https://community-scripts.github.io/ProxmoxVE/${CL}\n"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/byparr ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  msg_info "Stopping ${APP}"
  systemctl stop byparr
  msg_ok "Stopped ${APP}"

  msg_info "Backing up current installation"
  cp -r /opt/byparr /opt/byparr_backup_$(date +%Y%m%d_%H%M%S)
  msg_ok "Backup created"

  msg_info "Updating ${APP}"
  cd /opt/byparr
  if ! git pull origin main; then
    msg_error "Failed to update source code"
    exit 1
  fi
  msg_ok "Updated ${APP} source code"

  msg_info "Updating dependencies"
  if ! /root/.local/bin/uv sync --group test; then
    msg_error "Failed to update dependencies"
    exit 1
  fi
  msg_ok "Updated dependencies"

  msg_info "Starting ${APP}"
  systemctl start byparr
  msg_ok "Started ${APP}"

  msg_info "Cleaning up old backups (keeping last 3)"
  cd /opt
  ls -t byparr_backup_* 2>/dev/null | tail -n +4 | xargs -r rm -rf
  msg_ok "Cleaned up old backups"

  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8191${CL}"
echo -e "${INFO}${YW} Default port: ${CL}${DGN}8191${CL}"
echo -e "${INFO}${YW} To configure your *arr applications:${CL}"
echo -e "${TAB}${YW}Set FlareSolverr URL to: ${CL}${DGN}http://${IP}:8191${CL}"
echo -e "${INFO}${YW} For logs and service management:${CL}"
echo -e "${TAB}${YW}systemctl status byparr${CL}"
echo -e "${TAB}${YW}journalctl -u byparr -f${CL}"
echo -e "${INFO}${YW} To update Byparr:${CL}"
echo -e "${TAB}${YW}/opt/byparr/update-byparr.sh${CL}"
