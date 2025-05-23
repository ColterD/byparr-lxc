#!/usr/bin/env bash
# shellcheck disable=SC1090,SC2034
# SC1090: Can't follow non-constant source - expected for dynamic framework loading
# SC2034: Variables appear unused - they're used by the sourced framework functions
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2025 ColterD (Colter Dahlberg)
# Author: ColterD (Colter Dahlberg)
# License: MIT
# https://github.com/ColterD/byparr-lxc/raw/main/LICENSE

function header_info {
  clear
  cat <<"EOF"
    ____                                  
   / __ )__  ______  ____ ___________     
  / __  / / / / __ \/ __ `/ ___/ ___/     
 / /_/ / /_/ / /_/ / /_/ / /  / /         
/_____/\__, / .___/\__,_/_/  /_/          
      /____/_/                            
                                          
EOF
}
header_info
echo -e "\n ⚠️  THIS IS A COMMUNITY FORK by ColterD"
echo -e " Not yet part of official community-scripts\n"
sleep 2

APP="Byparr"
var_disk="4"
var_cpu="2"
var_ram="2048"
var_os="debian"
var_version="12"
var_install="${FORK_REPO:-https://raw.githubusercontent.com/ColterD/byparr-lxc/main}/install/byparr-install.sh"
# These variables are used by the community-scripts framework
variables
color
catch_errors

function default_settings() {
  # All these variables are used by the framework's build_container function
  CT_TYPE="1"
  PW=""
  CT_ID=$NEXTID
  HN=$NSAPP
  DISK_SIZE="$var_disk"
  CORE_COUNT="$var_cpu"
  RAM_SIZE="$var_ram"
  BRG="vmbr0"
  NET="dhcp"
  GATE=""
  APT_CACHER=""
  APT_CACHER_IP=""
  DISABLEIP6="no"
  MTU=""
  SD=""
  NS=""
  MAC=""
  VLAN=""
  SSH="no"
  VERB="no"
  echo_default
}

function update_script() {
  if [[ ! -d /opt/byparr ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  header_info
  echo -e "\n ⚠️  Updating ColterD Fork of Byparr\n"
  
  if [[ -x /opt/byparr/update-byparr.sh ]]; then
    msg_info "Running ${APP} update script"
    /opt/byparr/update-byparr.sh
    msg_ok "Updated Successfully"
  else
    msg_error "Update script not found"
    msg_info "Attempting manual update"
    cd /opt/byparr || exit
    systemctl stop byparr
    git pull origin main
    /root/.local/bin/uv sync
    systemctl start byparr
    msg_ok "Manual update completed"
  fi
  exit
}

start
build_container
description

msg_info "Setting Container Permissions"
if [[ -n "${CT_ID:-}" ]]; then
  # Set container features for browser automation
  pct set "$CT_ID" -features nesting=1,fuse=1
fi
msg_ok "Set Container Permissions"

msg_ok "Completed Successfully!\n"
echo -e "${APP} FlareSolverr Alternative by ThePhaseless
Proxmox Script by ColterD (Fork of tanujdargan's work)

${APP} should be reachable at ${BL}http://${IP}:8191${CL}
Use this URL in your *arr applications as the FlareSolverr URL\n"
