#!/usr/bin/env bash

# Copyright (c) 2025 ColterD (Colter Dahlberg)
# Author: ColterD (Colter Dahlberg)  
# License: MIT
# https://github.com/ColterD/byparr-lxc/raw/main/LICENSE

# shellcheck disable=SC1091
source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

# Install essential system dependencies.
msg_info "Installing Dependencies"
$STD apt-get install -y \
  curl \
  sudo \
  mc \
  git \
  gpg \
  wget \
  gnupg \
  ca-certificates \
  apt-transport-https \
  software-properties-common \
  lsb-release
msg_ok "Installed Dependencies"

# Install Python 3.11 and related tools required by Byparr.
msg_info "Installing Python 3.11"
$STD apt-get install -y \
  python3.11 \
  python3.11-dev \
  python3.11-venv \
  python3-pip \
  build-essential
msg_ok "Installed Python 3.11"

# Install Google Chrome, which Byparr uses for browser automation.
msg_info "Installing Google Chrome"
wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
$STD apt-get update
$STD apt-get install -y google-chrome-stable
msg_ok "Installed Google Chrome"

# Install Xvfb and other display server dependencies for headless browser operation.
msg_info "Installing Display Server Dependencies"
$STD apt-get install -y \
  xvfb \
  x11-xserver-utils \
  xfonts-100dpi \
  xfonts-75dpi \
  xfonts-base \
  xfonts-scalable \
  libgtk-3-0 \
  libglib2.0-0 \
  libnss3 \
  libatk1.0-0 \
  libatk-bridge2.0-0 \
  libcups2 \
  libdrm2 \
  libxkbcommon0 \
  libxcomposite1 \
  libxdamage1 \
  libxrandr2 \
  libgbm1 \
  libpango-1.0-0 \
  libasound2
msg_ok "Installed Display Server Dependencies"

msg_info "Installing UV Package Manager"
curl -LsSf https://astral.sh/uv/install.sh | sh
# shellcheck disable=SC1091
# Source cargo environment to bring uv into PATH (uv installer convention)
source "$HOME/.cargo/env"
msg_ok "Installed UV Package Manager"

msg_info "Installing Byparr"
cd /opt || exit
git clone -q https://github.com/ThePhaseless/Byparr.git byparr
cd byparr || exit
uv sync
msg_ok "Installed Byparr"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/byparr.service
[Unit]
Description=Byparr - FlareSolverr Alternative
Documentation=https://github.com/ThePhaseless/Byparr
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/byparr
Environment="PATH=/root/.local/bin:/root/.cargo/bin:/usr/local/bin:/usr/bin:/bin"
# Set display for Xvfb
Environment="DISPLAY=:99"
Environment="HOME=/root"
ExecStartPre=/bin/bash -c 'pkill -f "Xvfb :99" || true'
# Start Xvfb before Byparr
ExecStartPre=/bin/bash -c 'Xvfb :99 -screen 0 1920x1080x24 -nolisten tcp &'
ExecStartPre=/bin/sleep 2
# Command to run Byparr using uv
ExecStart=uv run python -m byparr
# Stop Xvfb when Byparr service stops
ExecStop=/bin/bash -c 'pkill -f "Xvfb :99" || true'
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl enable -q --now byparr.service
msg_ok "Created Service"

msg_info "Creating Update Script"
cat <<'EOF' >/opt/update-byparr.sh
#!/bin/bash
set -e
echo "Updating Byparr..."
systemctl stop byparr
cd /opt/byparr || exit
git pull
uv sync
systemctl start byparr
echo "Byparr updated successfully!"
EOF
chmod +x /opt/update-byparr.sh
msg_ok "Created Update Script"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
