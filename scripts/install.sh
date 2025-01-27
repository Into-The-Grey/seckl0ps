#!/bin/bash

# Install.sh - Installation script for seckl0ps dependencies
#
# This script installs all necessary system and Python dependencies required for seckl0ps.
# It performs the following steps:
# 1. Checks for root privileges.
# 2. Updates and upgrades the system package list.
# 3. Installs essential system tools (curl, whois, traceroute, nmap, wireshark, python3-pip, git).
# 4. Installs Python dependencies listed in requirements.txt.
# 5. Clones and sets up the PhoneInfoga tool.
#
# Usage:
#   sudo ./install.sh
#
# Ensure that the script is run from the directory containing the requirements.txt file.
# The script must be executed with root privileges.

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo "[ERROR] Please run as root or use sudo."
  exit 1
fi

set -e  # Exit immediately if a command exits with a non-zero status

# Banner
echo "Installing dependencies for seckl0ps..."
echo "[DEBUG] Starting installation script at $(date)"

# Update system package list
retry_attempts=3
retry_delay=5
update_success=false

for attempt in $(seq 1 $retry_attempts); do
  echo "[DEBUG] Attempt $attempt: Running: sudo apt update"
  sudo apt update && update_success=true && break
  echo "[WARNING] Failed to update package list. Retrying in $retry_delay seconds..."
  sleep $retry_delay
done

if ! $update_success; then
  echo "[ERROR] Failed to update package list after $retry_attempts attempts. Exiting."
  exit 1
fi

echo "[DEBUG] System packages updated successfully."

# Upgrade installed packages
echo "Upgrading installed packages..."
echo "[DEBUG] Running: sudo apt upgrade -y"
sudo apt upgrade -y
if [ $? -ne 0 ]; then
  echo "[ERROR] Failed to upgrade packages. Exiting."
  exit 1
fi

echo "[DEBUG] System packages upgraded successfully."

# Install system dependencies
TOOLS_DIR="tools"
echo "Installing system dependencies into ${TOOLS_DIR}..."
echo "[DEBUG] Running: sudo apt install -y curl whois traceroute nmap wireshark python3-pip git"
sudo apt install -y curl whois traceroute nmap wireshark python3-pip git

if ! command -v pip3 &> /dev/null; then
  echo "[ERROR] pip3 is not installed. Ensure Python3 and pip3 are correctly installed. Exiting."
  exit 1
fi
if ! command -v git &> /dev/null; then
  echo "[ERROR] git is not installed. Please install git and try again. Exiting."
  exit 1
fi

echo "[DEBUG] System dependencies installed successfully."

# Install Python dependencies
echo "Installing Python dependencies into ${TOOLS_DIR}..."
echo "[DEBUG] Verifying requirements.txt exists before installation."
if [ ! -f "requirements.txt" ]; then
  echo "[ERROR] requirements.txt file is missing. Ensure it exists in the current directory. Exiting."
  exit 1
fi
if [ ! -r "requirements.txt" ]; then
  echo "[ERROR] requirements.txt exists but is not readable. Check file permissions. Exiting."
  exit 1
fi
echo "[DEBUG] Running: pip3 install --target=${TOOLS_DIR} -r requirements.txt"
sudo pip3 install --target="${TOOLS_DIR}" -r requirements.txt
if [ $? -eq 0 ]; then
  echo "[DEBUG] Installed Python packages:" > "${TOOLS_DIR}/python_packages.log"
  pip3 freeze >> "${TOOLS_DIR}/python_packages.log"
  echo "[DEBUG] Python package versions logged to ${TOOLS_DIR}/python_packages.log"
else
  echo "[ERROR] Failed to install Python dependencies. Exiting."
  exit 1
fi

echo "[DEBUG] Python dependencies installed successfully."

# Install PhoneInfoga
echo "Cloning and setting up PhoneInfoga into ${TOOLS_DIR}..."
echo "[DEBUG] Checking if PhoneInfoga directory exists."
if [ ! -d "${TOOLS_DIR}/PhoneInfoga" ]; then
  echo "[DEBUG] Directory does not exist. Checking existence of tools directory."
  if [ ! -d "${TOOLS_DIR}" ]; then
    echo "[DEBUG] Tools directory does not exist. Creating tools directory."
    sudo mkdir -p "${TOOLS_DIR}"
  fi
  echo "[DEBUG] Checking write permissions for tools directory."
  if [ ! -w "${TOOLS_DIR}" ]; then
    echo "[ERROR] No write permission for tools directory. Exiting."
    exit 1
  fi
  echo "[DEBUG] Checking network connectivity before cloning repository."
  if ! ping -c 3 -W 5 github.com &> /dev/null; then
    echo "[ERROR] Network is unreachable. Please check your internet connection. Exiting."
    exit 1
  fi
  echo "[DEBUG] Cloning PhoneInfoga repository into ${TOOLS_DIR}/PhoneInfoga with sudo"
  sudo git clone https://github.com/sundowndev/PhoneInfoga.git "${TOOLS_DIR}/PhoneInfoga"
  echo "[DEBUG] Cloned PhoneInfoga repository. Navigating to directory."
  sudo bash -c "cd '${TOOLS_DIR}/PhoneInfoga'" || { echo "[ERROR] Failed to change directory to ${TOOLS_DIR}/PhoneInfoga. Exiting."; exit 1; }
  echo "[DEBUG] Installing PhoneInfoga dependencies."
  sudo pip3 install --target="${TOOLS_DIR}/PhoneInfoga" -r requirements.txt
  sudo bash -c "cd ../.." || { echo "[ERROR] Failed to change directory back. Exiting."; exit 1; }
  echo "[DEBUG] PhoneInfoga setup completed successfully."
else
  echo "PhoneInfoga already installed. Skipping..."
  echo "[DEBUG] Skipped PhoneInfoga installation as the directory exists."
fi

# Complete
echo "All dependencies installed successfully! Ready to use seckl0ps."
echo "[DEBUG] Installation script completed at $(date)"
