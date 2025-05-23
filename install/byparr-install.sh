#!/usr/bin/env bash
declare -g SPINNER_PID=""
export SPINNER_PID

# Copyright (c) 2025 ColterD (Colter Dahlberg)
# Author: ColterD (Colter Dahlberg)
# License: MIT
# https://github.com/ColterD/byparr-lxc/raw/main/LICENSE

# shellcheck disable=SC1091
# Source common functions from the path provided by the main script (ct/byparr.sh)
source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"

# --- Script Configuration and Constants ---
# URLs for external resources
GOOGLE_CHROME_GPG_KEY_URL="https://dl-ssl.google.com/linux/linux_signing_key.pub"
GOOGLE_CHROME_REPO_LINE="deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main"
BYPARR_GIT_URL="https://github.com/ThePhaseless/Byparr.git"
ASTRAL_UV_INSTALL_URL="https://astral.sh/uv/install.sh"
API_FUNC_URL="https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/api.func"

# --- Error Handling ---

# Override error_handler from the sourced install.func to make SPINNER_PID handling more robust with set -u
# This custom error handler ensures that any running spinner process is killed before exiting.
error_handler() {
  local api_func_content
  # Attempt to download API function content
  if api_func_content=$(curl -fsSL "$API_FUNC_URL"); then
    # Check if downloaded content is non-empty
    if [ -n "$api_func_content" ]; then
      # shellcheck disable=SC1090 # Can't follow non-constant source
      source <(echo "$api_func_content")
    else
      echo "Warning: Downloaded empty content from '$API_FUNC_URL' in overridden error_handler." >&2
      # Define dummy post_update_to_api if it wasn't sourced
      if ! command -v post_update_to_api >/dev/null; then
        post_update_to_api() {
          echo "Debug (dummy post_update_to_api): $*" >&2 # Corrected from $@ to $*
        }
      fi
    fi
  else                      # curl command itself failed
    local curl_exit_code=$? # Capture curl's exit code
    echo "Warning: Failed to download from '$API_FUNC_URL' (curl exit code ${curl_exit_code}) in overridden error_handler." >&2
    # Define dummy post_update_to_api if it wasn't sourced
    if ! command -v post_update_to_api >/dev/null; then
      post_update_to_api() {
        echo "Debug (dummy post_update_to_api): $*" >&2 # Corrected from $@ to $*
      }
    fi
  fi

  # Robustly kill the spinner process if it's running.
  # SPINNER_PID is globally declared and exported by the sourced functions.
  if [ -n "${SPINNER_PID:-}" ] && ps -p "${SPINNER_PID}" >/dev/null 2>&1; then
    kill "${SPINNER_PID}" >/dev/null 2>&1
  fi
  printf "\e[?25h" # Ensure the cursor is visible in the terminal.

  local exit_code="${?}"   # Capture the exit code of the command that triggered the ERR trap.
  local line_number="${1}" # Line number where the error occurred.
  local command="${2}"     # The command that failed.

  # Define color codes for error messages, with defaults if not already set by sourced scripts.
  local RD_COLOR="${RD:-$(echo -e "[01;31m")}" # Red
  local YW_COLOR="${YW:-$(echo -e "[33m")}"    # Yellow
  local CL_COLOR="${CL:-$(echo -e "[m")}"      # Clear

  # Construct and print the error message to stderr.
  local error_message="${RD_COLOR}[ERROR]${CL_COLOR} in line ${RD_COLOR}${line_number}${CL_COLOR}: exit code ${RD_COLOR}${exit_code}${CL_COLOR}: while executing command ${YW_COLOR}${command}${CL_COLOR}"
  echo -e "\n${error_message}" >&2

  # Call post_update_to_api (if available from sourced api.func) to report the failure.
  if command -v post_update_to_api >/dev/null; then
    # The condition 'if [[ "$line_number" -eq 50 ]]' seems specific to the original install.func context
    # and might need adjustment if it's not relevant here. For now, it's preserved.
    if [[ "$line_number" -eq 50 ]]; then
      post_update_to_api "failed" "No error message, script ran in silent mode"
    else
      post_update_to_api "failed" "${command}" # Report the failed command.
    fi
  fi
  exit "${exit_code}" # Exit the script with the original command's exit code.
}

# --- Byparr Update Function ---
# This function handles the update process for an existing Byparr installation.
function update_script() {
  msg_info "Starting Byparr update process..."
  # Check if the update script exists and is executable.
  if [[ -x "/opt/update-byparr.sh" ]]; then
    # Execute the update script.
    if /opt/update-byparr.sh; then
      msg_ok "Byparr update completed successfully."
    else
      # If the update script itself returns an error.
      msg_error "Byparr update script finished with an error."
      return 1 # Return a non-zero status to indicate failure.
    fi
  else
    msg_error "Update script /opt/update-byparr.sh not found or not executable."
    return 1 # Return a non-zero status to indicate failure.
  fi
  # Note: The original script had an 'exit' here.
  # Depending on how this function is called, 'return 1' might be more appropriate
  # if the calling code needs to know the outcome. If it's meant to always exit,
  # then 'exit 1' could be used in the error cases.
}

# --- Main Setup ---
# Initialize environment settings and traps.
color        # Initialize color variables (sourced from FUNCTIONS_FILE_PATH).
verb_ip6     # Configure verbosity for IPv6 (sourced).
catch_errors # Set up initial error catching (e.g., 'set -e') (sourced).
# Explicitly set the ERR trap to use our redefined error_handler.
# This is crucial because catch_errors() might have set a trap to the original,
# potentially problematic, error_handler from the sourced install.func.
# Our redefined error_handler is above.
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR

# --- Container Setup ---
setting_up_container # Perform initial container setup steps (sourced).
network_check        # Check network connectivity (sourced).
update_os            # Update the operating system (sourced).

# --- Dependency Installation ---

# Install essential system dependencies.
msg_info "Installing System Dependencies"
# $STD is a variable from the sourced functions, typically 'DEBIAN_FRONTEND=noninteractive apt-get -y -qq'.
# Using "$STD" ensures it's treated as a single command if it contains spaces.
"$STD" apt-get install -y \
  curl \
  sudo \
  mc \
  git \
  gpg \
  wget \
  gnupg \
  ca-certificates \
  apt-transport-https \
  software-properties-common \
  lsb-release
msg_ok "Installed Dependencies"

msg_ok "Installed System Dependencies"

# Install Python 3.11 and related tools required by Byparr.
msg_info "Installing Python 3.11 and Pip"
"$STD" apt-get install -y \
  python3.11 \
  python3.11-dev \
  python3.11-venv \
  python3-pip \
  build-essential # For compiling Python packages if needed
msg_ok "Installed Python 3.11 and Pip"

# Install Google Chrome, which Byparr uses for browser automation.
msg_info "Installing Google Chrome"
# Download Google Chrome GPG key
wget -q -O - "$GOOGLE_CHROME_GPG_KEY_URL" | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg
# Add Google Chrome repository to sources list
echo "$GOOGLE_CHROME_REPO_LINE" >/etc/apt/sources.list.d/google-chrome.list
"$STD" apt-get update
"$STD" apt-get install -y google-chrome-stable
msg_ok "Installed Google Chrome"

# Install Xvfb and other display server dependencies for headless browser operation.
msg_info "Installing Xvfb (Display Server Dependencies)"
"$STD" apt-get install -y \
  xvfb \
  x11-xserver-utils \
  xfonts-100dpi \
  xfonts-75dpi \
  xfonts-base \
  xfonts-scalable \
  libgtk-3-0 \
  libglib2.0-0 \
  libnss3 \
  libatk1.0-0 \
  libatk-bridge2.0-0 \
  libcups2 \
  libdrm2 \
  libxkbcommon0 \
  libxcomposite1 \
  libxdamage1 \
  libxrandr2 \
  libgbm1 \
  libpango-1.0-0 \
  libasound2 # For audio support, often a dependency for browser components
msg_ok "Installed Xvfb (Display Server Dependencies)"

# Install UV Package Manager from Astral
msg_info "Installing UV Package Manager"
UV_INSTALL_SCRIPT=$(mktemp) # Create a temporary file for the installer script
# Download the uv installation script
if curl -LsSf "$ASTRAL_UV_INSTALL_URL" -o "$UV_INSTALL_SCRIPT"; then
  # Execute the downloaded script
  sh "$UV_INSTALL_SCRIPT" >/dev/null 2>&1
else
  # If curl fails to download the script
  rm -f "$UV_INSTALL_SCRIPT" # Clean up the temporary file
  msg_error "Failed to download uv installation script from '$ASTRAL_UV_INSTALL_URL'."
  # error_handler will be called due to 'set -e' or explicit trap, causing script exit.
fi
rm -f "$UV_INSTALL_SCRIPT" # Clean up the temporary file after successful execution

# Source the uv environment script to bring 'uv' into the current shell's PATH.
# This is necessary because 'uv' is installed in a user-local directory.
# shellcheck disable=SC1090 # ShellCheck can't follow non-literal source.
# The path $HOME/.local/bin/env might change depending on uv's installation script.
# Using $HOME/.cargo/env as uv is written in Rust and installed via similar mechanisms to cargo tools.
# Astral's official docs use `source $HOME/.cargo/env` or similar.
# Let's assume uv creates a similar env file or adds itself to a standard user bin path.
# A more robust way would be to find 'uv' in likely paths if this direct source fails.
# For now, sticking to the previous logic of sourcing an env file.
# The original script used "$HOME/.local/bin/env". If "uv" is directly in "$HOME/.local/bin", that's simpler.
# Let's assume that `sh uv_install_script` adds `uv` to the path or we can source its env.
# Typically, Astral's installer will instruct to add `~/.cargo/bin` to PATH.
# And `uv` is installed there.
# shellcheck disable=SC1091 # File may not exist in CI environment
if [ -f "$HOME/.cargo/env" ]; then
  source "$HOME/.cargo/env"
elif [ -f "$HOME/.local/bin/env" ]; then # Fallback to the previous path if cargo/env is not found
  source "$HOME/.local/bin/env"
else
  # If 'uv' is expected to be directly in PATH after install (e.g. /usr/local/bin or $HOME/.local/bin)
  # then sourcing an env file might not be needed.
  # However, to be safe and ensure 'uv' command is found:
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
  if ! command -v uv >/dev/null; then
    msg_error "uv command not found after installation and PATH adjustment. Please check Astral's installation guide."
  fi
fi
msg_ok "Installed UV Package Manager"

# --- Application Installation (Byparr) ---

msg_info "Installing Byparr"
# Navigate to /opt directory, or exit if it fails. 'cd' has its own error check with 'set -e'.
cd /opt || exit 1
# Clone the Byparr repository from GitHub.
git clone -q "$BYPARR_GIT_URL" byparr # -q for quiet
cd byparr || exit 1
# Use 'uv' to install dependencies specified in Byparr's pyproject.toml (or similar).
uv sync >/dev/null # '> /dev/null' to suppress output unless there's an error.
msg_ok "Installed Byparr"

# --- Systemd Service Setup ---

msg_info "Creating Service Wrapper Script for Xvfb and Byparr"
# Create a wrapper script to manage Xvfb and Byparr execution.
# This script is used by the systemd service.
cat <<'EOT' >"/opt/byparr/run_byparr_with_xvfb.sh"
#!/bin/bash
# This script starts Xvfb and then runs Byparr.
# It ensures Xvfb is terminated when Byparr exits or the script is stopped.

# Start Xvfb in the background on display :99.
# -screen 0 1920x1080x24: Configures a virtual screen with 24-bit color depth.
# -nolisten tcp: Disables TCP listening for security.
Xvfb :99 -screen 0 1920x1080x24 -nolisten tcp &
XVFB_PID=$! # Store Xvfb's Process ID.

# Trap signals to ensure Xvfb is killed when the script exits.
# This handles cases like 'systemctl stop byparr' or if Byparr crashes.
trap 'kill $XVFB_PID; wait $XVFB_PID 2>/dev/null' INT TERM EXIT

# Wait briefly for Xvfb to initialize.
sleep 2

# Run Byparr using 'uv'.
# The 'uv run' command executes a command from the project's environment.
# Environment variables (PATH, DISPLAY, HOME) are set in the systemd service file.
uv run python -m byparr

# The trap will handle killing Xvfb when 'uv run python -m byparr' exits.
EOT
chmod +x "/opt/byparr/run_byparr_with_xvfb.sh"
msg_ok "Created and configured Service Wrapper Script"

msg_info "Creating systemd Service File for Byparr"
# Create the systemd service file for Byparr.
# This defines how Byparr is started, managed, and run as a background service.
cat <<EOF >"/etc/systemd/system/byparr.service"
[Unit]
Description=Byparr - FlareSolverr Alternative
Documentation=${BYPARR_GIT_URL}
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/byparr

# Environment variables for the Byparr process
Environment="PATH=/root/.local/bin:/root/.cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="DISPLAY=:99"
Environment="HOME=/root"

# Command to start Byparr using the wrapper script
ExecStart=/opt/byparr/run_byparr_with_xvfb.sh

Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the Byparr service immediately.
# -q for quiet operation. --now starts it right away.
systemctl enable -q --now byparr.service
msg_ok "Created and enabled systemd Service File"

# --- Update Script Creation ---

msg_info "Creating Update Script for Byparr"
# Create a simple script to automate Byparr updates.
cat <<'EOF' >"/opt/update-byparr.sh"
#!/bin/bash
# This script updates the Byparr installation.
set -e # Exit immediately if a command exits with a non-zero status.

echo "Updating Byparr..."

# Stop the Byparr service
echo "Stopping Byparr service..."
systemctl stop byparr

# Navigate to the Byparr directory
cd /opt/byparr || { echo "Failed to cd to /opt/byparr"; exit 1; }

# Pull the latest changes from the Git repository
echo "Pulling latest changes from Git..."
git pull origin main # Assuming 'main' is the default branch

# Sync dependencies using uv
echo "Syncing dependencies with uv..."
# Ensure uv is in PATH if this script is run directly (not via systemd service context)
# Adding this for robustness, though systemd service has PATH set.
export PATH="/root/.local/bin:/root/.cargo/bin:$PATH"
uv sync

# Start the Byparr service
echo "Starting Byparr service..."
systemctl start byparr

echo "Byparr updated successfully!"
EOF
chmod +x "/opt/update-byparr.sh"
msg_ok "Created Update Script"

# --- Finalization ---

motd_ssh  # Configure Message of the Day for SSH (sourced function)
customize # Perform further customizations (sourced function)

# Clean up unused packages.
msg_info "Cleaning up system"
"$STD" apt-get -y autoremove
"$STD" apt-get -y autoclean
msg_ok "Cleaned up system"
