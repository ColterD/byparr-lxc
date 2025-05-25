#!/usr/bin/env bash
# Copyright (c) 2025 ColterD (Colter Dahlberg)
# Author: ColterD (Colter Dahlberg)
# License: MIT | https://github.com/ColterD/byparr-lxc/raw/main/LICENSE
# Source: https://github.com/ThePhaseless/Byparr

# Download and source the build.func file
if ! source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func); then
  echo "Error: Failed to download build.func from community-scripts"
  exit 1
fi

# Define application variables
APP="Byparr"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-4}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

# Initialize variables and settings
variables
color
catch_errors

# Define update function
function update_script() {
  header_info
  if [[ ! -f /opt/byparr/run_byparr_with_xvfb.sh ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  msg_info "Updating ${APP} LXC"
  pct exec "$CTID" -- bash -c "/opt/update-byparr.sh"
  msg_ok "Updated ${APP} LXC"
  exit
}

# Start the container creation process
start
build_container
description

# Display completion message
msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8191${CL}"
