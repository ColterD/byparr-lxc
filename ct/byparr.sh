#!/usr/bin/env bash
# This script creates an LXC container for Byparr using the community-scripts framework.
# It is a fork and includes modifications to fetch the installer from a specific repository.
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
FORK_REPO_URL="https://raw.githubusercontent.com/ColterD/byparr-lxc/main"
var_disk="4"
var_cpu="2"
var_ram="2048"
var_os="debian"
var_version="12"
# These variables are used by the community-scripts framework
variables
actual_installer_url="${FORK_REPO_URL}/install/byparr-install.sh"
color
catch_errors

# This function is an overridden version of 'build_container' from the sourced build.func.
# It's modified to use a specific installer URL for this forked script.
build_container() {
  #  if [ "$VERB" == "yes" ]; then set -x; fi

  if [ "$CT_TYPE" == "1" ]; then
    FEATURES="keyctl=1,nesting=1"
  else
    FEATURES="nesting=1"
  fi

  if [ "$ENABLE_FUSE" == "yes" ]; then
    FEATURES="$FEATURES,fuse=1"
  fi

  if [[ $DIAGNOSTICS == "yes" ]]; then
    post_to_api
  fi

  TEMP_DIR=$(mktemp -d)
  pushd "$TEMP_DIR" >/dev/null
  if [ "$var_os" == "alpine" ]; then
    export FUNCTIONS_FILE_PATH="$(curl -fsSL https://raw.githubusercontent.com/c
ommunity-scripts/ProxmoxVE/main/misc/alpine-install.func)"
  else
    export FUNCTIONS_FILE_PATH="$(curl -fsSL https://raw.githubusercontent.com/c
ommunity-scripts/ProxmoxVE/main/misc/install.func)"
  fi
  export RANDOM_UUID="$RANDOM_UUID"
  export CACHER="$APT_CACHER"
  export CACHER_IP="$APT_CACHER_IP"
  export tz="$timezone"
  export DISABLEIPV6="$DISABLEIP6"
  export APPLICATION="$APP"
  export app="$NSAPP"
  export PASSWORD="$PW"
  export VERBOSE="$VERB"
  export SSH_ROOT="${SSH}"
  export SSH_AUTHORIZED_KEY
  export CTID="$CT_ID"
  export CTTYPE="$CT_TYPE"
  export ENABLE_FUSE="$ENABLE_FUSE"
  export ENABLE_TUN="$ENABLE_TUN"
  export PCT_OSTYPE="$var_os"
  export PCT_OSVERSION="$var_version"
  export PCT_DISK_SIZE="$DISK_SIZE"
  export PCT_OPTIONS="
    -features $FEATURES
    -hostname $HN
    -tags $TAGS
    $SD
    $NS
    -net0 name=eth0,bridge=$BRG$MAC,ip=$NET$GATE$VLAN$MTU
    -onboot 1
    -cores $CORE_COUNT
    -memory $RAM_SIZE
    -unprivileged $CT_TYPE
    $PW
  "
  # This executes create_lxc.sh and creates the container and .conf file
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/Prox
moxVE/main/ct/create_lxc.sh)" $?

  LXC_CONFIG=/etc/pve/lxc/${CTID}.conf
  if [ "$CT_TYPE" == "0" ]; then
    cat <<EOF >>"$LXC_CONFIG"
# USB passthrough
lxc.cgroup2.devices.allow: a
lxc.cap.drop:
lxc.cgroup2.devices.allow: c 188:* rwm
lxc.cgroup2.devices.allow: c 189:* rwm
lxc.mount.entry: /dev/serial/by-id  dev/serial/by-id  none bind,optional,create=
dir
lxc.mount.entry: /dev/ttyUSB0       dev/ttyUSB0       none bind,optional,create=
file
lxc.mount.entry: /dev/ttyUSB1       dev/ttyUSB1       none bind,optional,create=
file
lxc.mount.entry: /dev/ttyACM0       dev/ttyACM0       none bind,optional,create=
file
lxc.mount.entry: /dev/ttyACM1       dev/ttyACM1       none bind,optional,create=
file
EOF
  fi

  if [ "$CT_TYPE" == "0" ]; then
    if [[ "$APP" == "Channels" || "$APP" == "Emby" || "$APP" == "ErsatzTV" || "$
APP" == "Frigate" || "$APP" == "Jellyfin" || "$APP" == "Plex" || "$APP" == "Scry
pted" || "$APP" == "Tdarr" || "$APP" == "Unmanic" || "$APP" == "Ollama" || "$APP
" == "FileFlows" ]]; then
      cat <<EOF >>"$LXC_CONFIG"
# VAAPI hardware transcoding
lxc.cgroup2.devices.allow: c 226:0 rwm
lxc.cgroup2.devices.allow: c 226:128 rwm
lxc.cgroup2.devices.allow: c 29:0 rwm
lxc.mount.entry: /dev/fb0 dev/fb0 none bind,optional,create=file
lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir
lxc.mount.entry: /dev/dri/renderD128 dev/dri/renderD128 none bind,optional,creat
e=file
EOF
    fi
  else
    if [[ "$APP" == "Channels" || "$APP" == "Emby" || "$APP" == "ErsatzTV" || "$
APP" == "Frigate" || "$APP" == "Jellyfin" || "$APP" == "Plex" || "$APP" == "Scry
pted" || "$APP" == "Tdarr" || "$APP" == "Unmanic" || "$APP" == "Ollama" || "$APP
" == "FileFlows" ]]; then
      if [[ -e "/dev/dri/renderD128" ]]; then
        if [[ -e "/dev/dri/card0" ]]; then
          cat <<EOF >>"$LXC_CONFIG"
# VAAPI hardware transcoding
dev0: /dev/dri/card0,gid=44
dev1: /dev/dri/renderD128,gid=104
EOF
        else
          cat <<EOF >>"$LXC_CONFIG"
# VAAPI hardware transcoding
dev0: /dev/dri/card1,gid=44
dev1: /dev/dri/renderD128,gid=104
EOF
        fi
      fi
    fi
  fi

  if [ "$ENABLE_TUN" == "yes" ]; then
    cat <<EOF >>"$LXC_CONFIG"
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
EOF
  fi

  # This starts the container and executes <app>-install.sh
  msg_info "Starting LXC Container"
  pct start "$CTID"
  msg_ok "Started LXC Container"
  if [ "$var_os" == "alpine" ]; then
    sleep 3
    pct exec "$CTID" -- /bin/sh -c 'cat <<EOF >/etc/apk/repositories
http://dl-cdn.alpinelinux.org/alpine/latest-stable/main
http://dl-cdn.alpinelinux.org/alpine/latest-stable/community
EOF'
    pct exec "$CTID" -- ash -c "apk add bash >/dev/null"
  fi
  # MODIFIED LINE: Use actual_installer_url to fetch the application install script from the fork.
  lxc-attach -n "$CTID" -- bash -c "$(curl -fsSL ${actual_installer_url})" $?

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
build_container # Called from start
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
