#!/usr/bin/env bash

# Copyright (c) 2025 ColterD (Colter Dahlberg)
# Author: ColterD (Colter Dahlberg)
# License: MIT | https://github.com/ColterD/byparr-lxc/raw/main/LICENSE
# Source: https://github.com/ThePhaseless/Byparr

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y apt-transport-https
$STD apt-get install -y gpg
$STD apt-get install -y xvfb
$STD apt-get install -y python3.11
$STD apt-get install -y python3.11-dev
$STD apt-get install -y python3.11-venv
$STD apt-get install -y python3-pip
$STD apt-get install -y build-essential
$STD apt-get install -y git
msg_ok "Installed Dependencies"

msg_info "Installing Chrome"
curl -fsSL "https://dl.google.com/linux/linux_signing_key.pub" | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" >/etc/apt/sources.list.d/google-chrome.list
$STD apt update
$STD apt install -y google-chrome-stable
msg_ok "Installed Chrome"

msg_info "Installing UV Package Manager"
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
if [ -f "$HOME/.cargo/env" ]; then
  source "$HOME/.cargo/env"
fi
msg_ok "Installed UV Package Manager"

msg_info "Installing Byparr"
cd /opt
git clone -q https://github.com/ThePhaseless/Byparr.git byparr
cd byparr
uv sync >/dev/null
msg_ok "Installed Byparr"

msg_info "Creating Service"
cat <<EOF >/opt/byparr/run_byparr_with_xvfb.sh
#!/bin/bash
Xvfb :99 -screen 0 1920x1080x24 -nolisten tcp &
XVFB_PID=\$!
trap 'kill \$XVFB_PID; wait \$XVFB_PID 2>/dev/null' INT TERM EXIT
sleep 2
BYPARR_PORT=\${BYPARR_PORT:-8191} uv run python -m byparr
EOF
chmod +x /opt/byparr/run_byparr_with_xvfb.sh

cat <<EOF >/etc/systemd/system/byparr.service
[Unit]
Description=Byparr - FlareSolverr Alternative
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/byparr
Environment="PATH=/root/.local/bin:/root/.cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="DISPLAY=:99"
Environment="HOME=/root"
Environment="BYPARR_PORT=8191"
ExecStart=/opt/byparr/run_byparr_with_xvfb.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now byparr
msg_ok "Created Service"

msg_info "Creating Update Script"
cat <<'EOF' >/opt/update-byparr.sh
#!/bin/bash
set -e

echo "Stopping Byparr service..."
systemctl stop byparr

echo "Updating Byparr..."
cd /opt/byparr
git pull origin main

echo "Syncing dependencies..."
if [ -f "$HOME/.cargo/env" ]; then
  source "$HOME/.cargo/env"
fi
uv sync

echo "Starting Byparr service..."
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
