#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2025 ColterD (Colter Dahlberg)
# Author: ColterD (Colter Dahlberg)
# License: MIT | https://github.com/ColterD/byparr-lxc/raw/main/LICENSE
# Source: https://github.com/ThePhaseless/Byparr

APP="Byparr"
var_tags="${var_tags:-media}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-4}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_port="${var_port:-8191}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

# Export variables for the installer script
export BYPARR_PORT="$var_port"
export FORK_REPO_URL="https://raw.githubusercontent.com/ColterD/byparr-lxc/main"
export INSTALLER_URL="${FORK_REPO_URL}/install/byparr-install.sh"

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

start
build_container
description

msg_info "Setting Container Permissions"
if [[ -n "${CT_ID:-}" ]]; then
  pct set "$CT_ID" -features nesting=1,fuse=1
fi
msg_ok "Set Container Permissions"

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} FlareSolverr Alternative setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:${var_port}${CL}"
echo -e "${INFO}${YW}Use this URL in your *arr applications as the FlareSolverr URL${CL}"
echo -e "${INFO}${YW}Container Type: $([ "$CT_TYPE" = "1" ] && echo "Unprivileged" || echo "Privileged")${CL}"
echo -e "${INFO}${YW}Service User: $([ "$CT_TYPE" = "1" ] && echo "byparr" || echo "root")${CL}"
echo -e "${INFO}${YW}Useful Commands:${CL}"
echo -e "${TAB}${YW}- Update Byparr:        ${BGN}pct exec ${CT_ID} /opt/update-byparr.sh${CL}"
echo -e "${TAB}${YW}- Check Byparr Health:  ${BGN}pct exec ${CT_ID} /opt/byparr-health-check.sh${CL}"
echo -e "${TAB}${YW}- View Service Logs:    ${BGN}pct exec ${CT_ID} journalctl -u byparr -f${CL}"
echo -e "${TAB}${YW}- Restart Service:      ${BGN}pct exec ${CT_ID} systemctl restart byparr${CL}"
