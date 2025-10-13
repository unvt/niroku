#!/bin/bash
set -e

echo "=== niroku installer ==="
echo "Installing JUMP26 tools on Raspberry Pi OS (trixie)"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
  echo "Error: This script must be run as root (use sudo)"
  exit 1
fi

# Confirm installation
echo ""
echo "This will update the system and install the following packages:"
echo "  aria2, btop, gdal-bin, git, jq, ruby, tmux, vim"
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Installation cancelled."
  exit 0
fi

echo ""
echo "Updating package lists..."
apt update

echo ""
echo "Upgrading existing packages..."
apt upgrade -y

echo ""
echo "Installing base packages..."
apt install -y \
  aria2 \
  btop \
  gdal-bin \
  git \
  jq \
  ruby \
  tmux \
  vim

echo ""
echo "=== Installation complete ==="
echo "Base tools have been installed successfully."
