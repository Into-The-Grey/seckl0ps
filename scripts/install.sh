#!/bin/bash

echo "Installing dependencies for seckl0ps..."

# Update and install system dependencies
sudo apt update
sudo apt install -y nmap curl whois traceroute python3-pip

# Install Python dependencies
pip3 install -r requirements.txt

# Clone and install PhoneInfoga
echo "Setting up PhoneInfoga..."
git clone https://github.com/sundowndev/PhoneInfoga.git tools/PhoneInfoga
cd tools/PhoneInfoga
python3 -m pip install -r requirements.txt
cd ../../

echo "All dependencies installed successfully!"
