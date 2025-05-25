#!/usr/bin/env bash

# Copyright (c) 2025 ColterD (Colter Dahlberg)
# Author: ColterD (Colter Dahlberg)
# License: MIT | https://github.com/ColterD/byparr-lxc/raw/main/LICENSE
# Source: https://github.com/ThePhaseless/Byparr

# Check if functions are already sourced, if not source them
if ! command -v msg_info >/dev/null 2>&1; then
  # We're running standalone, need to source functions
  if [ -n "$FUNCTIONS_FILE_PATH" ]; then
    source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
  else
    # Fallback: create basic functions for standalone execution
    msg_info() { echo -e "\e[34m[INFO]\e[0m $1"; }
    msg_ok() { echo -e "\e[32m[OK]\e[0m $1"; }
    msg_error() { echo -e "\e[31m[ERROR]\e[0m $1"; }
    STD="DEBIAN_FRONTEND=noninteractive"
  fi
else
  # Functions already available from ct script
  source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
fi

# Initialize if functions are available
if command -v color >/dev/null 2>&1; then
  color
  verb_ip6
  catch_errors
  setting_up_container
  network_check
  update_os
fi

msg_info "Installing System Dependencies"
$STD apt-get update
$STD apt-get install -y curl
$STD apt-get install -y sudo
$STD apt-get install -y mc
$STD apt-get install -y apt-transport-https
$STD apt-get install -y gpg
$STD apt-get install -y git
$STD apt-get install -y wget
$STD apt-get install -y xvfb
$STD apt-get install -y python3.11
$STD apt-get install -y python3.11-dev
$STD apt-get install -y python3.11-venv
$STD apt-get install -y python3-pip
$STD apt-get install -y build-essential
$STD apt-get install -y ca-certificates
msg_ok "Installed System Dependencies"

msg_info "Installing Chrome"
# Remove any existing Chrome sources that might be causing issues
rm -f /etc/apt/sources.list.d/google-chrome.list
rm -f /usr/share/keyrings/google-chrome.gpg

# Install Chrome with proper key handling
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor > /usr/share/keyrings/google-chrome.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
$STD apt-get update
$STD apt-get install -y google-chrome-stable
msg_ok "Installed Chrome"

msg_info "Installing UV Package Manager"
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
if [ -f "$HOME/.cargo/env" ]; then
  source "$HOME/.cargo/env"
fi
# Verify UV is available
if ! command -v uv >/dev/null 2>&1; then
  msg_error "UV installation failed"
  exit 1
fi
msg_ok "Installed UV Package Manager"

msg_info "Installing Byparr"
cd /opt || exit 1
git clone -q https://github.com/ThePhaseless/Byparr.git byparr
cd byparr || exit 1
# Make sure UV is in PATH for this command
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
source "$HOME/.cargo/env" 2>/dev/null || true
uv sync
msg_ok "Installed Byparr"

msg_info "Creating Service"
# Create the Xvfb wrapper script
cat <<'EOF' >/opt/byparr/run_byparr_with_xvfb.sh
#!/bin/bash
# Start Xvfb in the background
Xvfb :99 -screen 0 1920x1080x24 -nolisten tcp &
XVFB_PID=$!

# Trap signals to clean up Xvfb
trap 'kill $XVFB_PID; wait $XVFB_PID 2>/dev/null' INT TERM EXIT

# Wait for Xvfb to start
sleep 2

# Set up environment and run Byparr
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
export DISPLAY=:99

# Source cargo environment if available
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

# Run Byparr
cd /opt/byparr
BYPARR_PORT=${BYPARR_PORT:-8191} uv run python -m byparr
EOF

chmod +x /opt/byparr/run_byparr_with_xvfb.sh

# Create systemd service
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

# Reload systemd and enable the service
systemctl daemon-reload
systemctl enable byparr
systemctl start byparr
msg_ok "Created and started Byparr service"

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
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
uv sync

echo "Starting Byparr service..."
systemctl start byparr

echo "Byparr updated successfully!"
EOF
chmod +x /opt/update-byparr.sh
msg_ok "Created Update Script"

# Run community functions if available
if command -v motd_ssh >/dev/null 2>&1; then
  motd_ssh
fi
if command -v customize >/dev/null 2>&1; then
  customize
fi

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Installation completed successfully"

# Final status check
msg_info "Checking installation status"
if systemctl is-active --quiet byparr; then
  msg_ok "Byparr service is running"
  msg_info "Access Byparr at: http://$(hostname -I | awk '{print $1}'):8191"
else
  msg_error "Byparr service failed to start. Check: systemctl status byparr"
fi
