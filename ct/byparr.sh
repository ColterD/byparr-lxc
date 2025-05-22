#!/usr/bin/env bash

# Copyright (c) 2025 Colter Dahlberg (ColterD Fork)
# Author: Colter Dahlberg (ColterD)
# License: MIT | https://github.com/ColterD/byparr-lxc/raw/main/LICENSE
# Source: https://github.com/ThePhaseless/Byparr

# Byparr LXC Container Creation Script for Proxmox VE
# Creates a lightweight LXC container with Byparr - FlareSolverr alternative
# This is a community fork - not officially part of community-scripts yet

# Attempt to source the community-scripts framework
COMMUNITY_SCRIPTS_URL="https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func"
FORK_REPO_URL="https://raw.githubusercontent.com/ColterD/byparr-lxc/main"

# Try to detect if we can use the community framework
if curl -fsSL --max-time 5 "$COMMUNITY_SCRIPTS_URL" >/dev/null 2>&1; then
    source <(curl -fsSL "$COMMUNITY_SCRIPTS_URL")
    USING_FRAMEWORK=true
else
    echo "Warning: Cannot access community-scripts framework, using embedded version"
    USING_FRAMEWORK=false
fi

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

# Fork notice function
show_fork_notice() {
    if [ "$USING_FRAMEWORK" = true ]; then
        echo -e "${YW}╔════════════════════════════════════════════════════════════════╗${CL}"
        echo -e "${YW}║${CL} ${RD}⚠️  NOTICE: ColterD Community Fork${CL}                              ${YW}║${CL}"
        echo -e "${YW}║${CL} This is NOT an official community-scripts project (yet)        ${YW}║${CL}"
        echo -e "${YW}║${CL} Official scripts: https://community-scripts.github.io/         ${YW}║${CL}"
        echo -e "${YW}║${CL} Fork repo: https://github.com/ColterD/byparr-lxc             ${YW}║${CL}"
        echo -e "${YW}╚════════════════════════════════════════════════════════════════╝${CL}"
    else
        echo "╔════════════════════════════════════════════════════════════════╗"
        echo "║ ⚠️  NOTICE: ColterD Community Fork                              ║"
        echo "║ This is NOT an official community-scripts project (yet)        ║"
        echo "║ Official scripts: https://community-scripts.github.io/         ║"
        echo "║ Fork repo: https://github.com/ColterD/byparr-lxc             ║"
        echo "╚════════════════════════════════════════════════════════════════╝"
    fi
    echo
    sleep 3
}

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

# Main execution based on framework availability
if [ "$USING_FRAMEWORK" = true ]; then
    # Use community-scripts framework
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
    
    # Custom function to handle our install script location
    function install_script() {
        local install_url="$INSTALL_SCRIPT_URL"
        
        if ! curl -fsSL --max-time 10 "$install_url" >/dev/null 2>&1; then
            msg_error "Cannot access install script at: $install_url"
            msg_error "Please check your internet connection and try again"
            exit 1
        fi
        
        # Use STDIN method to pass script to container
        INSTALL_SCRIPT=$(curl -fsSL "$install_url")
        if [[ -z "$INSTALL_SCRIPT" ]]; then
            msg_error "Install script is empty or download failed"
            exit 1
        fi
        
        # Pass the script content through STDIN
        pct exec "$CTID" -- bash -c "
            export FUNCTIONS_FILE_PATH='$(curl -fsSL ${COMMUNITY_SCRIPTS_URL})'
            bash -s" <<< "$INSTALL_SCRIPT"
    }
    
    # Override the default install_script behavior
    sed -i 's|^install_script$|# Overridden by custom install_script|g' /tmp/build.func 2>/dev/null || true
    
    # Build container
    start
    build_container
    description
    
    # Run our custom install
    msg_info "Installing ${APP} (ColterD Fork)"
    install_script
    
    # Completion message
    msg_ok "Completed Successfully!\n"
    echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
    echo -e "${YW}╔════════════════════════════════════════════════════════════════╗${CL}"
    echo -e "${YW}║${CL} ${GN}✓ Byparr (ColterD Fork) Installation Complete${CL}                 ${YW}║${CL}"
    echo -e "${YW}╚════════════════════════════════════════════════════════════════╝${CL}\n"
    IP=$(pct exec "$CTID" hostname -I | awk '{print $1}')
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
    
else
    # Fallback: Embedded minimal framework
    echo "Using embedded framework (limited functionality)"
    show_fork_notice
    
    # Basic color definitions
    CL='\033[0m'
    RD='\033[1;31m'
    GN='\033[1;32m'
    YW='\033[1;33m'
    BL='\033[1;34m'
    CM='\033[1;35m'
    DGN='\033[0;32m'
    
    # Basic functions
    msg_info() { echo -e "${YW}[INFO]${CL} $1"; }
    msg_ok() { echo -e "${GN}[OK]${CL} $1"; }
    msg_error() { echo -e "${RD}[ERROR]${CL} $1"; }
    
    # Check if running on Proxmox
    if ! command -v pct >/dev/null 2>&1; then
        msg_error "This script must be run on a Proxmox VE host"
        exit 1
    fi
    
    # Simple container creation
    msg_info "Creating container without full framework support"
    msg_error "For best experience, ensure access to:"
    echo "  ${COMMUNITY_SCRIPTS_URL}"
    msg_info "Attempting basic container creation..."
    
    # You would need to implement basic container creation here
    # This is complex without the framework, so we'll exit with instructions
    
    echo
    msg_error "Cannot proceed without framework access"
    echo "Please try:"
    echo "1. Check your internet connection"
    echo "2. Ensure GitHub is accessible"
    echo "3. Try again later"
    echo
    echo "Alternative: Download and run locally:"
    echo "  wget ${FORK_REPO_URL}/ct/byparr.sh"
    echo "  wget ${FORK_REPO_URL}/install/byparr-install.sh"
    echo "  bash byparr.sh"
    exit 1
fi
