#!/usr/bin/env bash

# Copyright (c) 2025 Colter Dahlberg (ColterD Fork)
# Author: Colter Dahlberg (ColterD)
# License: MIT | https://github.com/ColterD/byparr-lxc/raw/main/LICENSE
# Source: https://github.com/ThePhaseless/Byparr

# Byparr Installation Script - Runs inside the container
# Installs Byparr (FlareSolverr alternative) with all dependencies
# This is a community fork - not officially part of community-scripts yet

# Source the functions file passed from the container creation script
if [[ -n "$FUNCTIONS_FILE_PATH" ]]; then
    source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
else
    echo "ERROR: Functions file not provided. This script must be run via the container creation script."
    exit 1
fi

# Initialize environment
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

# Application variables
APP="Byparr"
APP_DIR="/opt/byparr"
SERVICE_NAME="byparr"
SERVICE_PORT="8191"
PYTHON_VERSION="3.11"

# Fork notice for logs
msg_info "Installing ${APP} (ColterD Fork)"
msg_info "This is a community fork - see https://github.com/ColterD/byparr-lxc"

# Install system dependencies
msg_info "Installing System Dependencies"
$STD apt-get update
$STD apt-get install -y \
    curl \
    sudo \
    mc \
    git \
    wget \
    gnupg \
    lsb-release \
    ca-certificates \
    apt-transport-https \
    software-properties-common

# Add Chrome repository for latest version
msg_info "Adding Chrome Repository"
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/googlechrome-linux-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/googlechrome-linux-keyring.gpg] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
$STD apt-get update

# Install Python and build dependencies
msg_info "Installing Python ${PYTHON_VERSION} and Build Tools"
$STD apt-get install -y \
    python${PYTHON_VERSION} \
    python${PYTHON_VERSION}-dev \
    python${PYTHON_VERSION}-venv \
    python3-pip \
    build-essential \
    libssl-dev \
    libffi-dev \
    libxml2-dev \
    libxslt1-dev \
    zlib1g-dev

# Install Chrome and display dependencies
msg_info "Installing Chrome Browser and Display Server"
$STD apt-get install -y \
    google-chrome-stable \
    xvfb \
    x11-utils \
    xfonts-100dpi \
    xfonts-75dpi \
    xfonts-scalable \
    xfonts-cyrillic \
    fonts-liberation \
    fonts-ipafont-gothic \
    fonts-wqy-zenhei \
    fonts-tlwg-loma-otf

# Install additional Chrome dependencies
msg_info "Installing Chrome Dependencies"
$STD apt-get install -y \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libatspi2.0-0 \
    libc6 \
    libcairo2 \
    libcups2 \
    libcurl4 \
    libdbus-1-3 \
    libdrm2 \
    libexpat1 \
    libgbm1 \
    libglib2.0-0 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libpango-1.0-0 \
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
    xdg-utils

msg_ok "Installed System Dependencies"

# Install UV package manager
msg_info "Installing UV Package Manager"
export SHELL=/bin/bash
curl -LsSf https://astral.sh/uv/install.sh > /tmp/uv-installer.sh
if ! bash /tmp/uv-installer.sh; then
    msg_error "Failed to install UV package manager"
    exit 1
fi

# Source UV environment
if [[ -f /root/.local/bin/env ]]; then
    source /root/.local/bin/env
fi

# Verify UV installation
UV_PATH="/root/.local/bin/uv"
if [[ ! -x "$UV_PATH" ]]; then
    msg_error "UV installation failed - executable not found at $UV_PATH"
    exit 1
fi

# Add UV to PATH permanently
echo 'export PATH="/root/.local/bin:$PATH"' >> /root/.bashrc
export PATH="/root/.local/bin:$PATH"

msg_ok "Installed UV Package Manager"

# Clone Byparr repository
msg_info "Cloning Byparr Repository"
cd /opt

# Check network access to GitHub
if ! curl -fsSL --max-time 10 https://api.github.com/repos/ThePhaseless/Byparr >/dev/null 2>&1; then
    msg_error "Cannot access GitHub - check network connectivity"
    exit 1
fi

# Clone the repository
if ! git clone --depth 1 https://github.com/ThePhaseless/Byparr.git byparr; then
    msg_error "Failed to clone Byparr repository"
    exit 1
fi

cd "$APP_DIR"
msg_ok "Cloned Byparr Repository"

# Install Python dependencies with UV
msg_info "Installing Python Dependencies"
cd "$APP_DIR"

# Create UV project if needed
if [[ ! -f pyproject.toml ]]; then
    msg_error "pyproject.toml not found in Byparr repository"
    exit 1
fi

# Install dependencies
if ! $UV_PATH sync --frozen; then
    msg_info "Trying without frozen lockfile"
    if ! $UV_PATH sync; then
        msg_error "Failed to install Python dependencies"
        exit 1
    fi
fi
msg_ok "Installed Python Dependencies"

# Create startup script
msg_info "Creating Startup Script"
cat << 'EOF' > "$APP_DIR/start-byparr.sh"
#!/bin/bash
# Byparr startup script with Xvfb display server

# Set up environment
cd /opt/byparr
export DISPLAY=:99
export PATH="/root/.local/bin:$PATH"
export HOME=/root

# Set Byparr environment variables
export LOG_LEVEL=${LOG_LEVEL:-info}
export CAPTCHA_SOLVER=${CAPTCHA_SOLVER:-none}
export PORT=${PORT:-8191}

# Chrome flags for stability
export CHROME_FLAGS="--no-sandbox --disable-setuid-sandbox --disable-dev-shm-usage --disable-gpu --no-first-run --no-default-browser-check"

# Kill any existing Xvfb
pkill -f "Xvfb :99" 2>/dev/null || true

# Start Xvfb
echo "Starting virtual display..."
Xvfb :99 -screen 0 1920x1080x24 -nolisten tcp &
XVFB_PID=$!

# Wait for Xvfb to start
sleep 3

# Verify Xvfb is running
if ! kill -0 $XVFB_PID 2>/dev/null; then
    echo "ERROR: Xvfb failed to start"
    exit 1
fi

echo "Virtual display started on :99"

# Function to cleanup on exit
cleanup() {
    echo "Stopping Byparr..."
    pkill -f "Xvfb :99" 2>/dev/null || true
}
trap cleanup EXIT

# Start Byparr
echo "Starting Byparr on port ${PORT}..."
exec /root/.local/bin/uv run python -m byparr
EOF

chmod +x "$APP_DIR/start-byparr.sh"
msg_ok "Created Startup Script"

# Create systemd service
msg_info "Creating Systemd Service"
cat << EOF > "/etc/systemd/system/${SERVICE_NAME}.service"
[Unit]
Description=Byparr - FlareSolverr Alternative (ColterD Fork)
Documentation=https://github.com/ThePhaseless/Byparr
After=network-online.target
Wants=network-online.target

[Service]
Type=exec
User=root
Group=root
WorkingDirectory=${APP_DIR}
Environment="PATH=/root/.local/bin:/usr/local/bin:/usr/bin:/bin"
Environment="HOME=/root"
Environment="LOG_LEVEL=info"
Environment="CAPTCHA_SOLVER=none"
Environment="PORT=${SERVICE_PORT}"
Environment="DISPLAY=:99"
Environment="PYTHONUNBUFFERED=1"
ExecStartPre=/bin/bash -c 'pkill -f "Xvfb :99" || true'
ExecStart=${APP_DIR}/start-byparr.sh
ExecStop=/bin/bash -c 'pkill -f "Xvfb :99" || true'
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}

# Security settings (balanced for browser automation)
NoNewPrivileges=yes
PrivateTmp=yes
ProtectHome=no
ProtectSystem=no
ReadWritePaths=${APP_DIR}
ReadWritePaths=/tmp

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF
msg_ok "Created Systemd Service"

# Create update script
msg_info "Creating Update Script"
cat << 'EOF' > "$APP_DIR/update-byparr.sh"
#!/bin/bash
# Byparr Update Script (ColterD Fork)
set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Functions
log_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root"
   exit 1
fi

log_info "Starting Byparr update process..."
log_info "This is the ColterD fork version"

# Stop the service
log_info "Stopping Byparr service..."
systemctl stop byparr || {
    log_error "Failed to stop service"
    exit 1
}

# Create backup
BACKUP_DIR="/opt/byparr_backup_$(date +%Y%m%d_%H%M%S)"
log_info "Creating backup at $BACKUP_DIR..."
cp -r /opt/byparr "$BACKUP_DIR" || {
    log_error "Failed to create backup"
    systemctl start byparr
    exit 1
}

# Change to app directory
cd /opt/byparr || {
    log_error "Failed to change to app directory"
    exit 1
}

# Fetch updates
log_info "Fetching updates from repository..."
if ! git fetch --all; then
    log_error "Failed to fetch updates"
    log_info "Restoring from backup..."
    rm -rf /opt/byparr
    mv "$BACKUP_DIR" /opt/byparr
    systemctl start byparr
    exit 1
fi

# Check for updates
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse @{u})

if [ "$LOCAL" = "$REMOTE" ]; then
    log_info "Already up to date!"
else
    # Pull updates
    log_info "Pulling updates..."
    if ! git pull origin main; then
        log_error "Failed to pull updates"
        log_info "Restoring from backup..."
        rm -rf /opt/byparr
        mv "$BACKUP_DIR" /opt/byparr
        systemctl start byparr
        exit 1
    fi
    
    # Update dependencies
    log_info "Updating Python dependencies..."
    export PATH="/root/.local/bin:$PATH"
    if ! /root/.local/bin/uv sync; then
        log_error "Failed to update dependencies"
        log_info "Restoring from backup..."
        rm -rf /opt/byparr
        mv "$BACKUP_DIR" /opt/byparr
        systemctl start byparr
        exit 1
    fi
fi

# Restart service
log_info "Starting Byparr service..."
systemctl start byparr || {
    log_error "Failed to start service"
    exit 1
}

# Verify service is running
sleep 5
if systemctl is-active --quiet byparr; then
    log_success "Byparr updated and running successfully!"
    
    # Test the API endpoint
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:8191/health | grep -q "200"; then
        log_success "API endpoint is responding"
    else
        log_error "API endpoint not responding - check logs: journalctl -u byparr -f"
    fi
else
    log_error "Service failed to start - check logs: journalctl -u byparr -f"
    exit 1
fi

# Clean up old backups (keep last 3)
log_info "Cleaning up old backups..."
cd /opt
ls -t byparr_backup_* 2>/dev/null | tail -n +4 | xargs -r rm -rf

log_success "Update completed successfully!"
log_info "Fork maintained by ColterD - https://github.com/ColterD/byparr-lxc"
EOF

chmod +x "$APP_DIR/update-byparr.sh"
msg_ok "Created Update Script"

# Enable and start service
msg_info "Enabling and Starting Byparr Service"
systemctl daemon-reload
systemctl enable "${SERVICE_NAME}.service"
systemctl start "${SERVICE_NAME}.service"
msg_ok "Enabled and Started Byparr Service"

# Wait for service to stabilize
msg_info "Waiting for Service to Initialize"
sleep 10

# Verify service is running
if systemctl is-active --quiet "$SERVICE_NAME"; then
    msg_ok "Byparr Service is Running"
    
    # Test API endpoint
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:${SERVICE_PORT}/" | grep -q "200\|404"; then
        msg_ok "API Endpoint is Responding"
    else
        msg_error "API Endpoint Not Responding - Check Logs"
    fi
else
    msg_error "Byparr Service Failed to Start"
    msg_info "Check logs with: journalctl -u ${SERVICE_NAME} -f"
fi

# Configure message of the day
motd_ssh
customize

# Final cleanup
msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
rm -rf /tmp/uv-installer.sh
msg_ok "Cleaned"

# Installation complete
msg_ok "Byparr Installation Complete (ColterD Fork)"
msg_info "Access URL: http://$(hostname -I | awk '{print $1}'):${SERVICE_PORT}"
msg_info "Fork repository: https://github.com/ColterD/byparr-lxc"
