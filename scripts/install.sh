#!/bin/bash
#
# install.sh - Comprehensive installation script for seckl0ps
#
# Features:
# 1. Root privileges check
# 2. Automatic (--auto) or Interactive mode
# 3. System package update with retries
# 4. System dependencies installation
# 5. Python dependencies installation (requirements.txt)
# 6. PhoneInfoga setup with network check
# 7. Dynamic tool setup in the "tools" directory
# 8. Configuration file handling
# 9. Optional user profile setup (with username/password)
# 10. Progress bars for overall and current tasks
# 11. Logging to "logs/install.log"
# 12. Cleanup (autoremove, apt clean)
# 13. Test execution if the "tests" directory is present
#
# Usage:
#   sudo ./install.sh [--auto]
#     --auto : Non-interactive mode; defaults selected for all prompts

###############################################################################
# 1. Root Privilege Check
###############################################################################
if [ "$EUID" -ne 0 ]; then
  echo "[ERROR] Please run as root or use sudo."
  exit 1
fi

set -e  # Exit immediately if a command returns non-zero

###############################################################################
# 2. Global Variables and Logging Setup
###############################################################################
LOG_DIR="logs"
LOG_FILE="${LOG_DIR}/install.log"
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

TOOLS_DIR="tools"
CONFIG_SOURCE="configs/seckl0ps.conf"
CONFIG_DEST="/etc/seckl0ps.conf"
PROFILE_FILE="${TOOLS_DIR}/user_profiles.txt"

# For apt-get updates (retries)
retry_attempts=3
retry_delay=5

# Handle script arguments
AUTO_MODE=false
for arg in "$@"; do
  case "$arg" in
    --auto)
      AUTO_MODE=true
      ;;
  esac
done

SCRIPT_START_TIME=$(date)
echo "[INFO] Installation script started at $SCRIPT_START_TIME"
echo "[INFO] Auto mode = $AUTO_MODE"
echo "[INFO] Logs are being recorded in $LOG_FILE"

###############################################################################
# 3. Progress Bar Functions
###############################################################################
# We'll track two bars: 
# - A 'main' bar for major sections 
# - A 'task' bar for the current operation
# For simplicity, we’ll treat them similarly but label them clearly.

function progress_bar() {
  local duration=$1
  local message="$2"
  local bar_width=40
  local progress=0

  echo -n "[INFO] $message: ["
  while [ "$progress" -lt "$bar_width" ]; do
    echo -n "#"
    sleep $(echo "$duration / $bar_width" | bc -l)
    ((progress++))
  done
  echo "]"
}

# We'll call progress_bar for both overall sections and sub-tasks, 
# adjusting "duration" to reflect time.

###############################################################################
# 4. Utility: Retry Command
###############################################################################
function retry_command() {
  local retries=$1
  local delay=$2
  shift 2
  local count=0
  local success=false

  while [ $count -lt $retries ]; do
    echo "[DEBUG] Attempt $((count + 1))/$retries: $*"
    if "$@"; then
      success=true
      break
    fi
    ((count++))
    echo "[WARNING] Command failed. Retrying in $delay seconds..."
    sleep $delay
  done

  if ! $success; then
    echo "[ERROR] Command failed after $retries attempts: $*"
    exit 1
  fi
}

###############################################################################
# 5. Update and Upgrade System
###############################################################################
echo "[DEBUG] Starting system update..."
progress_bar 2 "Overall progress (1/8) - System update phase"

update_success=false
for attempt in $(seq 1 $retry_attempts); do
  echo "[DEBUG] Attempt $attempt: Running: sudo apt update"
  if sudo apt update; then
    update_success=true
    break
  fi
  echo "[WARNING] Failed to update package list. Retrying in $retry_delay seconds..."
  sleep $retry_delay
done

if ! $update_success; then
  echo "[ERROR] Failed to update package list after $retry_attempts attempts. Exiting."
  exit 1
fi

echo "[DEBUG] System packages updated successfully."
echo "[DEBUG] Running: sudo apt upgrade -y"
progress_bar 2 "System upgrade"
if ! sudo apt upgrade -y; then
  echo "[ERROR] Failed to upgrade packages. Exiting."
  exit 1
fi
echo "[DEBUG] System packages upgraded successfully."

###############################################################################
# 6. Install Essential System Tools
###############################################################################
SYSTEM_DEPENDENCIES=(curl whois traceroute nmap wireshark python3-pip git)
echo "[DEBUG] Installing system dependencies: ${SYSTEM_DEPENDENCIES[*]}"
progress_bar 2 "Overall progress (2/8) - Installing system dependencies"
if ! sudo apt install -y "${SYSTEM_DEPENDENCIES[@]}"; then
  echo "[ERROR] Failed to install system dependencies. Exiting."
  exit 1
fi

# Verify pip3 and git
for tool in pip3 git; do
  if ! command -v "$tool" &>/dev/null; then
    echo "[ERROR] $tool is not installed. Exiting."
    exit 1
  fi
done
echo "[DEBUG] System dependencies installed successfully."

###############################################################################
# 7. Install Python Dependencies
###############################################################################
progress_bar 2 "Overall progress (3/8) - Installing Python dependencies"
echo "[DEBUG] Checking for requirements.txt in current directory."
if [ ! -f "requirements.txt" ]; then
  echo "[ERROR] requirements.txt file is missing. Ensure it exists in the current directory. Exiting."
  exit 1
fi
if [ ! -r "requirements.txt" ]; then
  echo "[ERROR] requirements.txt exists but is not readable. Check file permissions. Exiting."
  exit 1
fi

progress_bar 2 "pip3 install -r requirements.txt into $TOOLS_DIR"
echo "[DEBUG] Running: sudo pip3 install --target=${TOOLS_DIR} -r requirements.txt"
if sudo pip3 install --target="${TOOLS_DIR}" -r requirements.txt; then
  echo "[DEBUG] Installed Python packages:" > "${TOOLS_DIR}/python_packages.log"
  pip3 freeze >> "${TOOLS_DIR}/python_packages.log"
  echo "[DEBUG] Python package versions logged to ${TOOLS_DIR}/python_packages.log"
else
  echo "[ERROR] Failed to install Python dependencies. Exiting."
  exit 1
fi
echo "[DEBUG] Python dependencies installed successfully."

###############################################################################
# 8. Configuration File Handling
###############################################################################
# We'll attempt to copy configs/seckl0ps.conf to /etc/seckl0ps.conf
progress_bar 1 "Overall progress (4/8) - Configuration file"
if [ -f "$CONFIG_SOURCE" ]; then
  echo "[DEBUG] Copying $CONFIG_SOURCE to $CONFIG_DEST"
  sudo cp "$CONFIG_SOURCE" "$CONFIG_DEST"
  sudo chmod 644 "$CONFIG_DEST"
  echo "[DEBUG] Configuration file placed at $CONFIG_DEST"
else
  echo "[WARNING] Configuration file $CONFIG_SOURCE not found. Skipping configuration copy."
fi

###############################################################################
# 9. Dynamic Tools Installation
###############################################################################
# We'll iterate over all subdirectories in "tools" except for PhoneInfoga 
# (which we handle separately below).
progress_bar 1 "Overall progress (5/8) - Setting up other tools"
if [ ! -d "$TOOLS_DIR" ]; then
  echo "[DEBUG] Tools directory does not exist. Creating it now."
  sudo mkdir -p "$TOOLS_DIR"
fi

for tool_dir in "$TOOLS_DIR"/*; do
  if [ -d "$tool_dir" ]; then
    # Skip PhoneInfoga here, because we have a dedicated section for it
    if [[ "$(basename "$tool_dir")" == "PhoneInfoga" ]]; then
      continue
    fi

    tool_name=$(basename "$tool_dir")
    echo "[INFO] Found tool directory: $tool_name"
    # If a tool has a requirements.txt, install them
    if [ -f "$tool_dir/requirements.txt" ]; then
      progress_bar 1 "Installing Python deps for $tool_name"
      echo "[DEBUG] pip3 install --target='$tool_dir' -r '$tool_dir/requirements.txt'"
      pip3 install --target="$tool_dir" -r "$tool_dir/requirements.txt"
    fi
  fi
done

###############################################################################
# 10. Install/Setup PhoneInfoga (As in Original Script)
###############################################################################
progress_bar 2 "Overall progress (6/8) - Installing PhoneInfoga"
PHONEINFOGA_DIR="${TOOLS_DIR}/PhoneInfoga"
if [ ! -d "$PHONEINFOGA_DIR" ]; then
  echo "[DEBUG] Checking network connectivity before cloning PhoneInfoga..."
  if ! ping -c 3 -W 5 github.com &> /dev/null; then
    echo "[ERROR] Network is unreachable. Please check your internet connection. Exiting."
    exit 1
  fi

  echo "[DEBUG] Cloning PhoneInfoga repository into ${PHONEINFOGA_DIR}"
  sudo git clone https://github.com/sundowndev/PhoneInfoga.git "$PHONEINFOGA_DIR"

  # Ensure the tools directory is writable
  if [ ! -w "${TOOLS_DIR}" ]; then
    echo "[ERROR] No write permission for tools directory. Exiting."
    exit 1
  fi

  echo "[DEBUG] Installing PhoneInfoga dependencies."
  (
    cd "$PHONEINFOGA_DIR" || { echo "[ERROR] Failed to change directory to $PHONEINFOGA_DIR. Exiting."; exit 1; }
    sudo pip3 install --target="${PHONEINFOGA_DIR}" -r requirements.txt
  )
  echo "[DEBUG] PhoneInfoga setup completed successfully."
else
  echo "[DEBUG] PhoneInfoga already installed. Skipping..."
fi

###############################################################################
# 11. Optional User Profile Setup
###############################################################################
progress_bar 1 "Overall progress (7/8) - User profile setup"
if [ "$AUTO_MODE" = false ]; then
  read -rp "Would you like to set up a user profile? (y/n): " setup_profile
  if [[ "$setup_profile" =~ ^[Yy]$ ]]; then
    read -rp "Enter a username: " username
    read -rp "Enter a password (will be stored locally for now): " password
    echo "[DEBUG] Creating or appending to $PROFILE_FILE"
    echo "$username:$password" >>"$PROFILE_FILE"
    echo "[INFO] Profile created for $username."
  else
    echo "[INFO] Skipping user profile setup."
  fi
else
  echo "[INFO] Auto mode: skipping user profile setup."
fi

###############################################################################
# 12. Run Tests (If Present)
###############################################################################
if [ -d "tests" ]; then
  echo "[DEBUG] Tests directory found, running tests..."
  progress_bar 2 "Testing seckl0ps environment"
  if ! command -v python3 &>/dev/null; then
    echo "[ERROR] python3 is not installed or not available in the PATH. Skipping tests."
  elif ! python3 -m unittest discover tests; then
    echo "[ERROR] Some tests failed. Check the logs for details."
    # Not exiting here so user can decide to continue using the tool or fix tests
  fi
else
  echo "[DEBUG] No tests directory found. Skipping tests..."
fi

###############################################################################
# 13. Cleanup
###############################################################################
progress_bar 1 "Overall progress (8/8) - Cleanup"
echo "[DEBUG] Running apt autoremove and apt clean..."
sudo apt autoremove -y
sudo apt clean

###############################################################################
# Completion
SCRIPT_END_TIME=$(date)
echo "All dependencies installed successfully! Ready to use seckl0ps."
echo "To start using seckl0ps, run the following command:"
echo "  ./seckl0ps.sh"
echo "[DEBUG] Installation script completed at $SCRIPT_END_TIME"
echo "[INFO] For detailed logs, check $LOG_FILE"
