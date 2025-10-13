#!/bin/bash
set -euo pipefail

echo "=== niroku installer ==="
echo "Installing JUMP26 tools on Raspberry Pi OS (trixie)"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
  echo "Error: This script must be run as root (use sudo)"
  exit 1
fi

# Confirm installation (skip if non-interactive)
if [ -t 0 ]; then
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
else
  echo ""
  echo "Running in non-interactive mode."
  echo "Installing: aria2, btop, gdal-bin, git, jq, ruby, tmux, vim"
fi

echo ""
echo "Updating package lists..."
apt-get update

echo ""
echo "Upgrading existing packages..."
apt-get upgrade -y

echo ""
echo "Installing base packages..."
apt-get install -y \
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
