#!/usr/bin/env bash
# This script creates an LXC container for Byparr using the community-scripts framework.
# It is a fork and includes modifications to fetch the installer from a specific repository.
# shellcheck disable=SC1090,SC2034
# SC1090: Can't follow non-constant source - expected for dynamic framework loading
# SC2034: Variables appear unused - they're used by the sourced framework functions

# Define the URL for the build.func script from community-scripts
BUILD_FUNC_URL="https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func"

# Attempt to download build.func
BUILD_FUNC_CONTENT=$(curl -fsSL "$BUILD_FUNC_URL")
BUILD_FUNC_EXIT_CODE=$? # Capture curl's exit code immediately

# Check if the download was successful
if [ "$BUILD_FUNC_EXIT_CODE" -ne 0 ]; then
  # Print an informative error message to stderr
  echo "Error: Failed to download build.func from '$BUILD_FUNC_URL'. Curl exit code: $BUILD_FUNC_EXIT_CODE" >&2
  exit 1 # Exit the script with an error status
fi

# Source the downloaded build.func content
# This allows the script to use functions defined in build.func
source <(echo "$BUILD_FUNC_CONTENT")

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
variables # This function is sourced from build.func
actual_installer_url="${FORK_REPO_URL}/install/byparr-install.sh"
color # This function is sourced from build.func
catch_errors # This function is sourced from build.func

# This function is an overridden version of 'build_container' from the sourced build.func.
# It's modified to use a specific installer URL for this forked script.
build_container() {
  # Uncomment the following line for verbose debugging output
  # if [ "$VERB" == "yes" ]; then set -x; fi

  # Set container features based on whether it's privileged or unprivileged
  # shellcheck disable=SC2153 # CT_TYPE is set by sourced build.func environment
  if [ "$CT_TYPE" == "1" ]; then # Unprivileged container
    FEATURES="keyctl=1,nesting=1"
  else # Privileged container
    FEATURES="nesting=1"
  fi

  # Add FUSE support if enabled
  if [ "$ENABLE_FUSE" == "yes" ]; then
    FEATURES="$FEATURES,fuse=1"
  fi

  # Post diagnostics if enabled
  if [[ "$DIAGNOSTICS" == "yes" ]]; then
    post_to_api # This function is sourced from build.func
  fi

  # Create a temporary directory for downloads
  TEMP_DIR=$(mktemp -d)
  # Ensure we return to the original directory and clean up the temp directory on exit
  # Not using trap here as build.func might have its own trap logic.
  # Relying on TEMP_DIR cleanup within this function or by the main script's exit handlers (if any).
  pushd "$TEMP_DIR" >/dev/null || exit 1

  # Download the appropriate installation functions based on the OS
  if [ "$var_os" == "alpine" ]; then
    ALPINE_INSTALL_FUNC_URL="https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/alpine-install.func"
    FUNC_CONTENT=$(curl -fsSL "$ALPINE_INSTALL_FUNC_URL")
    FUNC_EXIT_CODE=$?
    if [ "$FUNC_EXIT_CODE" -ne 0 ]; then
      echo "Error: Failed to download alpine-install.func from '$ALPINE_INSTALL_FUNC_URL'. Curl exit code: $FUNC_EXIT_CODE" >&2
      popd >/dev/null || exit 1; rm -rf "$TEMP_DIR"; exit 1 # Cleanup and exit
    fi
    export FUNCTIONS_FILE_PATH="$FUNC_CONTENT"
  else # For Debian, Ubuntu, etc.
    INSTALL_FUNC_URL="https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/install.func"
    FUNC_CONTENT=$(curl -fsSL "$INSTALL_FUNC_URL")
    FUNC_EXIT_CODE=$?
    if [ "$FUNC_EXIT_CODE" -ne 0 ]; then
      echo "Error: Failed to download install.func from '$INSTALL_FUNC_URL'. Curl exit code: $FUNC_EXIT_CODE" >&2
      popd >/dev/null || exit 1; rm -rf "$TEMP_DIR"; exit 1 # Cleanup and exit
    fi
    export FUNCTIONS_FILE_PATH="$FUNC_CONTENT"
  fi

  # Export variables required by the sourced install functions and create_lxc.sh
  export RANDOM_UUID="$RANDOM_UUID"
  export CACHER="$APT_CACHER"
  export CACHER_IP="$APT_CACHER_IP"
  # shellcheck disable=SC2154 # timezone is set by sourced build.func environment
  export tz="$timezone"
  # shellcheck disable=SC2153 # DISABLEIP6 is set by sourced build.func environment
  export DISABLEIPV6="$DISABLEIP6"
  export APPLICATION="$APP"
  export app="$NSAPP" # Namespaced application name
  export PASSWORD="$PW"
  export VERBOSE="$VERB"
  export SSH_ROOT="${SSH}" # Note: ${SSH} is typically 'yes' or 'no', ensure quoting if it could contain spaces
  export SSH_AUTHORIZED_KEY # This variable would contain the actual key
  export CTID="$CT_ID"
  export CTTYPE="$CT_TYPE"
  export ENABLE_FUSE="$ENABLE_FUSE"
  export ENABLE_TUN="$ENABLE_TUN"
  export PCT_OSTYPE="$var_os"
  export PCT_OSVERSION="$var_version"
  export PCT_DISK_SIZE="$DISK_SIZE"
  # Define Proxmox VE container options
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
  " # Variables like $SD, $NS, $BRG, $MAC, $NET, $GATE, $VLAN, $MTU, $CORE_COUNT, $RAM_SIZE, $PW are set by 'variables' function from build.func

  # Download the create_lxc.sh script
  CREATE_LXC_URL="https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/create_lxc.sh"
  CREATE_LXC_SCRIPT=$(curl -fsSL "$CREATE_LXC_URL")
  CREATE_LXC_EXIT_CODE=$?
  if [ "$CREATE_LXC_EXIT_CODE" -ne 0 ]; then
    echo "Error: Failed to download create_lxc.sh from '$CREATE_LXC_URL'. Curl exit code: $CREATE_LXC_EXIT_CODE" >&2
    popd >/dev/null || exit 1; rm -rf "$TEMP_DIR"; exit 1 # Cleanup and exit
  fi

  # Execute the create_lxc.sh script in a subshell
  bash -c "$CREATE_LXC_SCRIPT"

  # Define the path to the LXC configuration file
  LXC_CONFIG="/etc/pve/lxc/${CTID}.conf" # CTID is the container ID

  # Add USB passthrough settings for privileged containers
  if [ "$CT_TYPE" == "0" ]; then # Privileged container
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

  # shellcheck disable=SC2050 # Structure inherited from build.func for VAAPI
  if [ "$CT_TYPE" == "0" ]; then
    if [[ "$APP" == "Channels" || "$APP" == "Emby" || "$APP" == "ErsatzTV" || "$
APP" == "Frigate" || "$APP" == "Jellyfin" || "$APP" == "Plex" || "$APP" == "Scry\
pted" || "$APP" == "Tdarr" || "$APP" == "Unmanic" || "$APP" == "Ollama" || "$APP\
" == "FileFlows" ]]; then
      # Add VAAPI hardware transcoding settings for specific applications
      cat <<EOF >>"$LXC_CONFIG"
# VAAPI hardware transcoding
lxc.cgroup2.devices.allow: c 226:0 rwm
lxc.cgroup2.devices.allow: c 226:128 rwm
lxc.cgroup2.devices.allow: c 29:0 rwm
lxc.mount.entry: /dev/fb0 dev/fb0 none bind,optional,create=file
lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir
lxc.mount.entry: /dev/dri/renderD128 dev/dri/renderD128 none bind,optional,creat\
e=file
EOF
    fi
  else # Unprivileged container
    # Check for specific applications that need VAAPI hardware transcoding
    # shellcheck disable=SC2050 # Structure inherited from build.func for VAAPI
    if [[ "$APP" == "Channels" || "$APP" == "Emby" || "$APP" == "ErsatzTV" || "$
APP" == "Frigate" || "$APP" == "Jellyfin" || "$APP" == "Plex" || "$APP" == "Scry\
pted" || "$APP" == "Tdarr" || "$APP" == "Unmanic" || "$APP" == "Ollama" || "$APP\
" == "FileFlows" ]]; then
      # Check for the existence of renderD128 and card0/card1
      if [[ -e "/dev/dri/renderD128" ]]; then
        if [[ -e "/dev/dri/card0" ]]; then # Prefer card0 if it exists
          cat <<EOF >>"$LXC_CONFIG"
# VAAPI hardware transcoding
dev0: /dev/dri/card0,gid=44
dev1: /dev/dri/renderD128,gid=104
EOF
        else # Fallback to card1 if card0 does not exist
          cat <<EOF >>"$LXC_CONFIG"
# VAAPI hardware transcoding
dev0: /dev/dri/card1,gid=44
dev1: /dev/dri/renderD128,gid=104
EOF
        fi
      fi
    fi
  fi

  # Enable TUN device passthrough if requested
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
  # This is a key modification for this forked script.
  INSTALLER_SCRIPT_CONTENT=$(curl -fsSL "${actual_installer_url}")
  INSTALLER_SCRIPT_EXIT_CODE=$?
  if [ "$INSTALLER_SCRIPT_EXIT_CODE" -ne 0 ]; then
    echo "Error: Failed to download installer script from '${actual_installer_url}'. Curl exit code: $INSTALLER_SCRIPT_EXIT_CODE" >&2
    popd >/dev/null || exit 1; rm -rf "$TEMP_DIR"; exit 1 # Cleanup and exit
  fi

  # Return to the original directory and remove the temporary directory
  popd >/dev/null || exit 1
  rm -rf "$TEMP_DIR"

  # Attach to the container and execute the downloaded installer script
  # The installer script will perform application-specific setup.
  lxc-attach -n "$CTID" -- bash -c "$INSTALLER_SCRIPT_CONTENT"

} # End of build_container function

# Main script execution starts here
start # This function is sourced from build.func, likely handles initial setup and user prompts
build_container # Call our overridden build_container function
description # This function is sourced from build.func, likely displays summary information

# Final permission settings for the container
msg_info "Setting Container Permissions"
if [[ -n "${CT_ID:-}" ]]; then # Check if CT_ID is set and not empty
  # Set container features for browser automation (nesting and FUSE)
  pct set "$CT_ID" -features nesting=1,fuse=1
fi
msg_ok "Set Container Permissions"

# Final success message
msg_ok "Completed Successfully!\n"
# Display information about the application and how to access it
echo -e "${APP} FlareSolverr Alternative by ThePhaseless
Proxmox Script by ColterD (Fork of tanujdargan's work)

${APP} should be reachable at ${BL}http://${IP}:8191${CL}
Use this URL in your *arr applications as the FlareSolverr URL\n"
# Variables like ${BL}, ${CL}, ${IP} are likely set by sourced scripts (build.func or its dependencies)
