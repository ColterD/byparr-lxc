#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2025 ColterD (Colter Dahlberg)
# Author: ColterD (Colter Dahlberg)
# License: MIT | https://github.com/ColterD/byparr-lxc/raw/main/LICENSE
# Source: https://github.com/ThePhaseless/Byparr

APP="Byparr"
var_tags="${var_tags:-networking;web;proxy}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-4}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

# Override get_header function to handle missing headers gracefully
get_header() {
  echo -e "${BL}[Info]${GN} Using ${APP} (Community Fork)${CL}"
}

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  if [[ ! -f /opt/byparr/run_byparr_with_xvfb.sh ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  msg_info "Updating ${APP} LXC"
  if [[ -x "/opt/update-byparr.sh" ]]; then
    pct exec "$CTID" -- bash -c "/opt/update-byparr.sh"
    msg_ok "Updated ${APP} LXC"
  else
    msg_error "Update script not found or not executable"
  fi
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8191${CL}"
