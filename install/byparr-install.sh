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

  # Perform cleanup operations
  echo -e "\n${YW_COLOR}[CLEANUP]${CL_COLOR} Performing cleanup operations..." >&2
  
  # Stop the Byparr service if it exists and is running
  if systemctl is-active --quiet byparr 2>/dev/null; then
    echo "Stopping Byparr service..." >&2
    systemctl stop byparr 2>/dev/null || true
  fi
  
  # Remove systemd service file if it exists
  if [ -f "/etc/systemd/system/byparr.service" ]; then
    echo "Removing systemd service file..." >&2
    rm -f "/etc/systemd/system/byparr.service" 2>/dev/null || true
    systemctl daemon-reload 2>/dev/null || true
  fi
  
  # Create a failure report
  FAILURE_REPORT="/root/byparr-install-failure-$(date '+%Y%m%d%H%M%S').log"
  echo "Creating failure report at $FAILURE_REPORT..." >&2
  {
    echo "Byparr Installation Failure Report"
    echo "=================================="
    echo "Date: $(date)"
    echo "Error in line: $line_number"
    echo "Command: $command"
    echo "Exit code: $exit_code"
    echo ""
    echo "System Information:"
    echo "------------------"
    echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')"
    echo "Kernel: $(uname -r)"
    echo "CPU: $(grep "model name" /proc/cpuinfo | head -n1 | cut -d: -f2 | sed 's/^[ \t]*//')"
    echo "Memory: $(free -h | awk '/^Mem:/ {print $2}')"
    echo "Disk: $(df -h /opt | awk 'NR==2 {print $2}')"
    echo ""
    echo "Last 20 lines of journalctl:"
    journalctl -n 20 --no-pager
  } > "$FAILURE_REPORT" 2>&1 || true
  
  echo -e "${YW_COLOR}[INFO]${CL_COLOR} A failure report has been created at: ${FAILURE_REPORT}" >&2
  echo -e "${YW_COLOR}[INFO]${CL_COLOR} Please include this file when seeking help." >&2

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
  
  echo -e "\n${RD_COLOR}[INSTALLATION FAILED]${CL_COLOR} Please check the error message above and the failure report." >&2
  echo -e "If you need help, visit: ${YW_COLOR}https://github.com/ThePhaseless/Byparr/issues${CL_COLOR}" >&2
  
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

# --- System Requirements Validation ---
msg_info "Validating system requirements"

# Check CPU cores
CPU_CORES=$(nproc)
if [ "$CPU_CORES" -lt 2 ]; then
  msg_warning "Only $CPU_CORES CPU core(s) detected. Byparr recommends at least 2 cores."
  echo "Performance may be degraded with fewer than 2 CPU cores."
  sleep 2
else
  msg_ok "CPU cores: $CPU_CORES (meets minimum requirement of 2)"
fi

# Check available memory
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
if [ "$TOTAL_MEM" -lt 2048 ]; then
  msg_warning "Only $TOTAL_MEM MB RAM detected. Byparr recommends at least 2048 MB."
  echo "Performance may be degraded with less than 2048 MB RAM."
  sleep 2
else
  msg_ok "Memory: $TOTAL_MEM MB (meets minimum requirement of 2048 MB)"
fi

# Check available disk space
DISK_SPACE=$(df -m /opt | awk 'NR==2 {print $4}')
if [ "$DISK_SPACE" -lt 4096 ]; then
  msg_warning "Only $DISK_SPACE MB free disk space detected in /opt. Byparr recommends at least 4096 MB."
  echo "You may run out of disk space during installation or operation."
  sleep 2
else
  msg_ok "Disk space: $DISK_SPACE MB available (meets minimum requirement of 4096 MB)"
fi

msg_ok "System requirements validation completed"

# --- Container Setup ---
setting_up_container # Perform initial container setup steps (sourced).
network_check        # Check network connectivity (sourced).

# --- External Resource Connectivity Test ---
msg_info "Testing connectivity to external resources"

# Function to test connectivity to a URL
test_connectivity() {
  local url="$1"
  local description="$2"
  local max_retries=3
  local retry_count=0
  local success=false
  
  while [ $retry_count -lt $max_retries ] && [ "$success" != "true" ]; do
    if curl -s --head --connect-timeout 10 "$url" >/dev/null; then
      msg_ok "Connection to $description ($url) successful"
      success=true
    else
      retry_count=$((retry_count + 1))
      if [ $retry_count -lt $max_retries ]; then
        msg_warning "Connection to $description failed, retrying ($retry_count/$max_retries)..."
        sleep 2
      else
        msg_warning "Connection to $description ($url) failed after $max_retries attempts"
        echo "Installation may fail if this resource is unavailable."
        sleep 2
        return 1
      fi
    fi
  done
  
  return 0
}

# Test connectivity to all required external resources
test_connectivity "https://github.com" "GitHub (for Byparr repository)"
test_connectivity "https://dl.google.com" "Google Chrome repository"
test_connectivity "https://astral.sh" "Astral (for UV package manager)"
test_connectivity "https://raw.githubusercontent.com" "GitHub Raw Content"

msg_ok "External resource connectivity test completed"

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

# Function to find and set up UV in PATH
setup_uv_path() {
  # Add all possible UV locations to PATH
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/local/bin:$PATH"
  
  # Source cargo environment if available
  if [ -f "$HOME/.cargo/env" ]; then
    # shellcheck disable=SC1091
    source "$HOME/.cargo/env"
  fi
  
  # Verify UV is in PATH
  if command -v uv >/dev/null; then
    return 0
  else
    return 1
  fi
}

# Try to find UV first in case it's already installed
if setup_uv_path && command -v uv >/dev/null; then
  msg_info "UV Package Manager already installed, skipping installation"
else
  # Create a temporary file for the installer script
  UV_INSTALL_SCRIPT=$(mktemp)
  
  # Download the UV installation script with retry mechanism
  MAX_RETRIES=3
  RETRY_COUNT=0
  DOWNLOAD_SUCCESS=false
  
  while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ "$DOWNLOAD_SUCCESS" != "true" ]; do
    if [ $RETRY_COUNT -gt 0 ]; then
      msg_info "Retry attempt $RETRY_COUNT for downloading UV installer..."
      sleep 2
    fi
    
    if curl -LsSf "$ASTRAL_UV_INSTALL_URL" -o "$UV_INSTALL_SCRIPT"; then
      DOWNLOAD_SUCCESS=true
    else
      RETRY_COUNT=$((RETRY_COUNT + 1))
    fi
  done
  
  # Check if download was successful
  if [ "$DOWNLOAD_SUCCESS" != "true" ]; then
    rm -f "$UV_INSTALL_SCRIPT"
    msg_error "Failed to download UV installation script after $MAX_RETRIES attempts."
    exit 1
  fi
  
  # Execute the downloaded script
  msg_info "Running UV installer..."
  sh "$UV_INSTALL_SCRIPT"
  INSTALL_RESULT=$?
  
  # Clean up the temporary file
  rm -f "$UV_INSTALL_SCRIPT"
  
  # Check installation result
  if [ $INSTALL_RESULT -ne 0 ]; then
    msg_error "UV installation failed with exit code $INSTALL_RESULT"
    exit 1
  fi
  
  # Set up UV path after installation
  setup_uv_path
  
  # Final verification
  if ! command -v uv >/dev/null; then
    msg_error "UV command not found after installation. Installation may have failed."
    exit 1
  fi
fi

# Display UV version for verification
UV_VERSION=$(uv --version 2>/dev/null || echo "Unknown")
msg_ok "UV Package Manager installed (version: $UV_VERSION)"

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

# Get the port from environment variable or use default
BYPARR_PORT="${BYPARR_PORT:-8191}"
msg_info "Creating Service Wrapper Script for Xvfb and Byparr (port: $BYPARR_PORT)"

# Create a wrapper script to manage Xvfb and Byparr execution.
# This script is used by the systemd service.
cat <<EOT >"/opt/byparr/run_byparr_with_xvfb.sh"
#!/bin/bash
# This script starts Xvfb and then runs Byparr.
# It ensures Xvfb is terminated when Byparr exits or the script is stopped.

# Start Xvfb in the background on display :99.
# -screen 0 1920x1080x24: Configures a virtual screen with 24-bit color depth.
# -nolisten tcp: Disables TCP listening for security.
Xvfb :99 -screen 0 1920x1080x24 -nolisten tcp &
XVFB_PID=\$! # Store Xvfb's Process ID.

# Trap signals to ensure Xvfb is killed when the script exits.
# This handles cases like 'systemctl stop byparr' or if Byparr crashes.
trap 'kill \$XVFB_PID; wait \$XVFB_PID 2>/dev/null' INT TERM EXIT

# Wait briefly for Xvfb to initialize.
sleep 2

# Run Byparr using 'uv' with the configured port
# The 'uv run' command executes a command from the project's environment.
# Environment variables (PATH, DISPLAY, HOME) are set in the systemd service file.
BYPARR_PORT=${BYPARR_PORT} uv run python -m byparr

# The trap will handle killing Xvfb when 'uv run python -m byparr' exits.
EOT
chmod +x "/opt/byparr/run_byparr_with_xvfb.sh"
msg_ok "Created and configured Service Wrapper Script"

msg_info "Creating systemd Service File for Byparr"

# Determine if we should run as non-root user based on container type
# CT_TYPE is exported from the main script: 1 = unprivileged, 0 = privileged
CT_TYPE="${CTTYPE:-1}"  # Default to unprivileged if not set

if [ "$CT_TYPE" = "1" ]; then
  # For unprivileged containers, create a dedicated user for better security
  msg_info "Setting up dedicated byparr user for unprivileged container"
  
  # Create byparr user if it doesn't exist
  if ! id -u byparr >/dev/null 2>&1; then
    useradd -r -m -d /opt/byparr-home -s /bin/bash byparr
  fi
  
  # Set proper permissions
  chown -R byparr:byparr /opt/byparr
  
  # Service will run as byparr user
  SERVICE_USER="byparr"
  HOME_DIR="/opt/byparr-home"
else
  # For privileged containers, run as root as requested by user
  msg_info "Container is privileged, service will run as root"
  SERVICE_USER="root"
  HOME_DIR="/root"
fi

# Create the systemd service file for Byparr.
# This defines how Byparr is started, managed, and run as a background service.
cat <<EOF >"/etc/systemd/system/byparr.service"
[Unit]
Description=Byparr - FlareSolverr Alternative
Documentation=${BYPARR_GIT_URL}
After=network.target

[Service]
Type=simple
User=${SERVICE_USER}
WorkingDirectory=/opt/byparr

# Environment variables for the Byparr process
Environment="PATH=${HOME_DIR}/.local/bin:${HOME_DIR}/.cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="DISPLAY=:99"
Environment="HOME=${HOME_DIR}"
Environment="BYPARR_PORT=${BYPARR_PORT}"

# Command to start Byparr using the wrapper script
ExecStart=/opt/byparr/run_byparr_with_xvfb.sh

# Security settings
ProtectSystem=full
PrivateTmp=true
NoNewPrivileges=true
RestrictSUIDSGID=true

# Restart policy
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
# Create a robust script to automate Byparr updates.
cat <<'EOF' >"/opt/update-byparr.sh"
#!/bin/bash
# This script updates the Byparr installation.
set -e # Exit immediately if a command exits with a non-zero status.

# Function to log messages with timestamps
log() {
  msg_info "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to handle errors
error_exit() {
  msg_error "ERROR: $1"
  # Try to restart the service if it was running before
  if [ "$SERVICE_WAS_ACTIVE" = "true" ]; then
    msg_info "Attempting to restart Byparr service..."
    systemctl start byparr || msg_error "Failed to restart service. Please check manually."
  fi
  exit 1
}

# Function to find and set up UV in PATH
setup_uv_path() {
  # Add all possible UV locations to PATH
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/local/bin:$PATH"
  
  # Source cargo environment if available
  if [ -f "$HOME/.cargo/env" ]; then
    source "$HOME/.cargo/env"
  fi
  
  # Verify UV is in PATH
  if command -v uv >/dev/null; then
    return 0
  else
    return 1
  fi
}

log "Starting Byparr update process..."

# Check if the service is currently running
if systemctl is-active --quiet byparr; then
  SERVICE_WAS_ACTIVE="true"
  log "Byparr service is currently running. Stopping service..."
  systemctl stop byparr || error_exit "Failed to stop Byparr service"
else
  SERVICE_WAS_ACTIVE="false"
  log "Byparr service is not currently running."
fi

# Create a backup of the current installation
log "Creating backup of current installation..."
BACKUP_DIR="/opt/byparr-backup-$(date '+%Y%m%d%H%M%S')"
cp -r /opt/byparr "$BACKUP_DIR" || error_exit "Failed to create backup"
log "Backup created at $BACKUP_DIR"

# Navigate to the Byparr directory
cd /opt/byparr || error_exit "Failed to cd to /opt/byparr"

# Check for local changes
if ! git diff --quiet; then
  log "Warning: Local changes detected in the repository."
  log "Creating patch file of local changes..."
  git diff > "$BACKUP_DIR/local-changes.patch"
  log "Local changes saved to $BACKUP_DIR/local-changes.patch"
  
  # Ask if we should continue
  read -p "Continue with update and discard local changes? (y/n): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Update aborted by user."
    if [ "$SERVICE_WAS_ACTIVE" = "true" ]; then
      log "Restarting Byparr service..."
      systemctl start byparr || error_exit "Failed to restart service"
    fi
    exit 0
  fi
  
  # Reset local changes
  log "Resetting local changes..."
  git reset --hard || error_exit "Failed to reset local changes"
fi

# Pull the latest changes from the Git repository
log "Pulling latest changes from Git..."
if ! git pull origin main; then
  error_exit "Failed to pull latest changes from Git"
fi

# Set up UV path
log "Setting up UV package manager..."
setup_uv_path || error_exit "Failed to set up UV package manager"

# Sync dependencies using uv
log "Syncing dependencies with uv..."
if ! uv sync; then
  error_exit "Failed to sync dependencies with uv"
fi

# Start the Byparr service if it was running before
if [ "$SERVICE_WAS_ACTIVE" = "true" ]; then
  log "Starting Byparr service..."
  if ! systemctl start byparr; then
    error_exit "Failed to start Byparr service"
  fi
  
  # Verify the service is running
  sleep 3
  if ! systemctl is-active --quiet byparr; then
    error_exit "Byparr service failed to start properly"
  fi
  log "Byparr service started successfully"
else
  log "Byparr service was not running before update, not starting it"
fi

log "Byparr updated successfully!"
EOF
chmod +x "/opt/update-byparr.sh"
msg_ok "Created Update Script"

# --- Health Check Script Creation ---

msg_info "Creating Health Check Script for Byparr"
# Create a health check script to help diagnose issues
cat <<'EOF' >"/opt/byparr-health-check.sh"
#!/bin/bash
# Byparr Health Check Script
# This script checks the health of the Byparr installation and helps diagnose issues.

# Function to log messages with timestamps
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Print header
echo "======================================"
echo "      Byparr Health Check Script      "
echo "======================================"
echo ""

# Check system resources
log "Checking system resources..."
echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')%"
echo "Memory Usage: $(free -m | awk 'NR==2{printf "%.2f%%", $3*100/$2}')"
echo "Disk Usage: $(df -h /opt | awk 'NR==2{print $5}')"
echo ""

# Check if Byparr service is running
log "Checking Byparr service status..."
if systemctl is-active --quiet byparr; then
  echo "✅ Byparr service is running"
else
  echo "❌ Byparr service is NOT running"
  echo "Last 10 lines of service logs:"
  journalctl -u byparr -n 10 --no-pager
fi
echo ""

# Check if Xvfb is running
log "Checking Xvfb process..."
if pgrep Xvfb >/dev/null; then
  echo "✅ Xvfb is running"
else
  echo "❌ Xvfb is NOT running"
  echo "This may cause browser automation issues."
fi
echo ""

# Check if Chrome is installed
log "Checking Chrome installation..."
if command_exists google-chrome; then
  CHROME_VERSION=$(google-chrome --version 2>/dev/null || echo "Unknown")
  echo "✅ Chrome is installed (Version: $CHROME_VERSION)"
else
  echo "❌ Chrome is NOT installed"
  echo "This will prevent Byparr from functioning correctly."
fi
echo ""

# Check if UV package manager is available
log "Checking UV package manager..."
if command_exists uv; then
  UV_VERSION=$(uv --version 2>/dev/null || echo "Unknown")
  echo "✅ UV package manager is available (Version: $UV_VERSION)"
else
  echo "❌ UV package manager is NOT available"
  echo "This may cause issues with dependency management."
fi
echo ""

# Check network connectivity to port 8191
log "Checking network connectivity..."
PORT=$(grep -o 'BYPARR_PORT=[0-9]*' /etc/systemd/system/byparr.service 2>/dev/null | cut -d= -f2)
PORT=${PORT:-8191}  # Default to 8191 if not found

if command_exists ss; then
  if ss -tuln | grep -q ":$PORT "; then
    echo "✅ Port $PORT is open and listening"
  else
    echo "❌ Port $PORT is NOT listening"
    echo "This means Byparr is not accepting connections."
  fi
elif command_exists netstat; then
  if netstat -tuln | grep -q ":$PORT "; then
    echo "✅ Port $PORT is open and listening"
  else
    echo "❌ Port $PORT is NOT listening"
    echo "This means Byparr is not accepting connections."
  fi
else
  echo "⚠️ Cannot check port status (ss/netstat not available)"
fi
echo ""

# Check if Byparr API is responding
log "Checking Byparr API response..."
if command_exists curl; then
  RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT/v1 2>/dev/null || echo "failed")
  if [ "$RESPONSE" = "200" ]; then
    echo "✅ Byparr API is responding (HTTP 200)"
  else
    echo "❌ Byparr API is NOT responding properly (Response: $RESPONSE)"
    echo "This indicates Byparr is not functioning correctly."
  fi
else
  echo "⚠️ Cannot check API response (curl not available)"
fi
echo ""

# Print summary
echo "======================================"
echo "      Health Check Summary            "
echo "======================================"
echo ""
echo "If you're experiencing issues, please check:"
echo "1. Service logs: journalctl -u byparr -n 50"
echo "2. Chrome: google-chrome --version"
echo "3. Xvfb: ps aux | grep Xvfb"
echo "4. Network: ss -tulpn | grep $PORT"
echo ""
echo "For more help, visit: https://github.com/ThePhaseless/Byparr"
echo ""
EOF

chmod +x "/opt/byparr-health-check.sh"
msg_ok "Created Health Check Script"

# --- Finalization ---

motd_ssh  # Configure Message of the Day for SSH (sourced function)
customize # Perform further customizations (sourced function)

# Clean up unused packages.
msg_info "Cleaning up system"
"$STD" apt-get -y autoremove
"$STD" apt-get -y autoclean
msg_ok "Cleaned up system"
