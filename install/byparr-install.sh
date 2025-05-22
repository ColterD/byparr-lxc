#!/usr/bin/env bash

# Copyright (c) 2025 Colter Dahlberg (ColterD Fork)
# Author: Colter Dahlberg (ColterD)
# License: MIT | https://github.com/ColterD/byparr-lxc/raw/main/LICENSE
# Source: https://github.com/ThePhaseless/Byparr

# Byparr LXC Container Creation Script for Proxmox VE
# Creates a lightweight LXC container with Byparr - FlareSolverr alternative
# This is a community fork - not officially part of community-scripts yet

# Script metadata
SCRIPT_VERSION="1.0.2"
FORK_REPO_URL="https://raw.githubusercontent.com/ColterD/byparr-lxc/main"
COMMUNITY_SCRIPTS_URL="https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func"

# Application metadata
APP="Byparr"
APP_FULL="Byparr (ColterD Fork)"
var_tags="captcha;solver;arr;proxy;flaresolverr;alternative;browser;automation"
var_cpu="2"
var_ram="2048"
var_disk="4"
var_os="debian"
var_version="12"
var_unprivileged="1"
INSTALL_SCRIPT_URL="${FORK_REPO_URL}/install/byparr-install.sh"

# Color definitions (used before framework loads)
CL='\033[0m'
RD='\033[1;31m'
GN='\033[1;32m'
YW='\033[1;33m'
BL='\033[1;34m'
CM='\033[1;35m'
DGN='\033[0;32m'
BGN='\033[1;96m'
INFO="${GN}[INFO]${CL}"
TAB='  '
CREATING="${YW}Creating...${CL}"
GATEWAY="${YW}Gateway:${CL}"

# Basic functions (used before framework loads)
msg_info() { echo -e "${YW}[INFO]${CL} $1"; }
msg_ok() { echo -e "${GN}[OK]${CL} $1"; }
msg_error() { echo -e "${RD}[ERROR]${CL} $1"; }

# Fork notice function
show_fork_notice() {
    echo -e "${YW}╔════════════════════════════════════════════════════════════════╗${CL}"
    echo -e "${YW}║${CL} ${RD}⚠️  NOTICE: ColterD Community Fork${CL}                              ${YW}║${CL}"
    echo -e "${YW}║${CL} This is NOT an official community-scripts project (yet)        ${YW}║${CL}"
    echo -e "${YW}║${CL} Official scripts: https://community-scripts.github.io/         ${YW}║${CL}"
    echo -e "${YW}║${CL} Fork repo: https://github.com/ColterD/byparr-lxc             ${YW}║${CL}"
    echo -e "${YW}╚════════════════════════════════════════════════════════════════╝${CL}"
    echo
    sleep 3
}

# Check if running on Proxmox
check_proxmox() {
    # Multiple checks for Proxmox VE
    local is_proxmox=false
    
    # Check 1: pveversion command exists
    if command -v pveversion >/dev/null 2>&1; then
        is_proxmox=true
        msg_ok "Detected Proxmox VE (pveversion found)"
    # Check 2: pvesh command exists
    elif command -v pvesh >/dev/null 2>&1; then
        is_proxmox=true
        msg_ok "Detected Proxmox VE (pvesh found)"
    # Check 3: pct command exists (container management)
    elif command -v pct >/dev/null 2>&1; then
        is_proxmox=true
        msg_ok "Detected Proxmox VE (pct found)"
    # Check 4: /etc/pve directory exists
    elif [[ -d /etc/pve ]]; then
        is_proxmox=true
        msg_ok "Detected Proxmox VE (/etc/pve found)"
    # Check 5: proxmox-ve package installed
    elif dpkg -l proxmox-ve >/dev/null 2>&1; then
        is_proxmox=true
        msg_ok "Detected Proxmox VE (proxmox-ve package)"
    fi
    
    if [[ "$is_proxmox" != "true" ]]; then
        msg_error "This script must be run on a Proxmox VE host"
        msg_error "Current system: $(uname -n) - $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2 2>/dev/null || uname -a)"
        echo
        echo -e "${YW}Required for this script:${CL}"
        echo "  - Proxmox VE 7.0 or higher"
        echo "  - Root access on the Proxmox host"
        echo "  - Not inside a container or VM"
        echo
        echo -e "${YW}If you're sure this is Proxmox, check:${CL}"
        echo "  - Are you running as root?"
        echo "  - Are you on the host, not in a container?"
        echo "  - Is Proxmox VE properly installed?"
        exit 1
    fi
}

# Show fork notice immediately
show_fork_notice

# Check Proxmox before attempting framework
check_proxmox

# Attempt to source the community-scripts framework
msg_info "Loading community-scripts framework..."
if curl -fsSL --max-time 10 "$COMMUNITY_SCRIPTS_URL" >/dev/null 2>&1; then
    # Framework is accessible, source it
    source <(curl -fsSL "$COMMUNITY_SCRIPTS_URL")
    USING_FRAMEWORK=true
    msg_ok "Framework loaded successfully"
else
    msg_error "Cannot access community-scripts framework"
    echo -e "${YW}Possible causes:${CL}"
    echo "  - GitHub is unreachable"
    echo "  - Network connectivity issues"
    echo "  - DNS resolution problems"
    echo
    echo -e "${YW}Troubleshooting:${CL}"
    echo "1. Check internet connection:"
    echo "   ping -c 4 github.com"
    echo
    echo "2. Test GitHub access:"
    echo "   curl -I https://github.com"
    echo
    echo "3. Try alternative installation:"
    echo "   wget ${FORK_REPO_URL}/ct/byparr.sh"
    echo "   wget ${FORK_REPO_URL}/install/byparr-install.sh"
    echo "   bash byparr.sh"
    echo
    msg_error "Cannot continue without framework access"
    exit 1
fi

# Override description function to include fork notice
description() {
    cat <<EOF
${APP_FULL} - FlareSolverr Alternative

Byparr is a self-hosted drop-in replacement for FlareSolverr, providing
reliable captcha solving and browser automation for your *arr applications.
Built with FastAPI and nodriver for when FlareSolverr's solver is broken.

${YW}⚠️  ColterD Fork Notice:${CL}
This is a community fork, not yet part of official community-scripts.
Once accepted, this notice will be removed.

${GN}Key Features:${CL}
- FlareSolverr-compatible API (port 8191)
- Advanced browser automation with Chrome
- Captcha solving capabilities
- FastAPI-based for performance
- Automatic updates with backup

${BL}Resource Requirements:${CL}
- CPU: 2 cores (browser operations)
- RAM: 2GB minimum
- Disk: 4GB
- Network: Port 8191

${RD}Credits:${CL}
- Byparr by @ThePhaseless
- Original script by @tanujdargan
- Fork maintained by @ColterD
EOF
}

# Update script function
update_script() {
    header_info
    show_fork_notice
    
    if [[ ! -d /opt/byparr ]]; then
        msg_error "No ${APP} Installation Found!"
        exit 1
    fi
    
    # Check if we have the update script
    if [[ -x /opt/byparr/update-byparr.sh ]]; then
        msg_info "Running ${APP} update script"
        if /opt/byparr/update-byparr.sh; then
            msg_ok "${APP} updated successfully"
            echo -e "\n${GN}Update completed!${CL}"
            echo -e "${YW}Note: This is the ColterD fork version${CL}"
        else
            msg_error "Update failed - check logs with: journalctl -u byparr -f"
            exit 1
        fi
    else
        msg_error "Update script not found at /opt/byparr/update-byparr.sh"
        exit 1
    fi
    exit 0
}

# Custom install_script function for our fork
custom_install_script() {
    local install_url="$INSTALL_SCRIPT_URL"
    
    msg_info "Downloading installation script..."
    if ! curl -fsSL --max-time 10 "$install_url" >/dev/null 2>&1; then
        msg_error "Cannot access install script at: $install_url"
        msg_error "Please check your internet connection and try again"
        exit 1
    fi
    
    # Download the install script
    INSTALL_SCRIPT=$(curl -fsSL "$install_url")
    if [[ -z "$INSTALL_SCRIPT" ]]; then
        msg_error "Install script is empty or download failed"
        exit 1
    fi
    
    msg_info "Running installation inside container..."
    # Pass the script content through STDIN with framework functions
    if ! pct exec "$CTID" -- bash -c "
        export FUNCTIONS_FILE_PATH='$(curl -fsSL ${COMMUNITY_SCRIPTS_URL})'
        bash -s" <<< "$INSTALL_SCRIPT"; then
        msg_error "Installation failed"
        exit 1
    fi
}

# Main execution with framework
header_info "$APP"
show_fork_notice

# Check if this is an update request
if command -v update_script >/dev/null 2>&1 && [[ "$1" == "update" ]]; then
    update_script
fi

# Run the framework build process
variables
color
catch_errors

# Build container using framework
msg_info "Starting container creation process..."
start
build_container
description

# Install Byparr using our custom function
msg_info "Installing ${APP} (ColterD Fork)"
custom_install_script

# Get container IP for display
if [[ -n "$CTID" ]]; then
    IP=$(pct exec "$CTID" hostname -I 2>/dev/null | awk '{print $1}')
    if [[ -z "$IP" ]]; then
        IP="[CONTAINER-IP]"
    fi
else
    IP="[CONTAINER-IP]"
fi

# Completion message
msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${YW}╔════════════════════════════════════════════════════════════════╗${CL}"
echo -e "${YW}║${CL} ${GN}✓ Byparr (ColterD Fork) Installation Complete${CL}                 ${YW}║${CL}"
echo -e "${YW}╚════════════════════════════════════════════════════════════════╝${CL}\n"
echo -e "${INFO}${YW} Access Byparr at:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8191${CL}\n"
echo -e "${INFO}${YW} Configure your *arr applications:${CL}"
echo -e "${TAB}${YW}FlareSolverr URL: ${CL}${DGN}http://${IP}:8191${CL}\n"
echo -e "${INFO}${YW} Service Management:${CL}"
echo -e "${TAB}${CM}systemctl status byparr${CL} - Check status"
echo -e "${TAB}${CM}journalctl -u byparr -f${CL} - View logs"
echo -e "${TAB}${CM}/opt/byparr/update-byparr.sh${CL} - Update Byparr\n"
echo -e "${INFO}${YW} Fork Information:${CL}"
echo -e "${TAB}Repo: ${DGN}https://github.com/ColterD/byparr-lxc${CL}"
echo -e "${TAB}Based on: ${DGN}https://github.com/ThePhaseless/Byparr${CL}"
