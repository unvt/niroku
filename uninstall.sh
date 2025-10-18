#!/bin/bash
set -euo pipefail

# niroku - Uninstaller
# This script removes installations made by install.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/unvt-portable"

# Package lists
# Base packages from simple installer (PR #2)
BASE_PACKAGES=(aria2 btop gdal-bin jq ruby tmux vim)
# Additional packages for Caddy + Martin setup
# Note: Caddy and Martin are handled separately as they have their own services
COMPREHENSIVE_PACKAGES=(git curl wget hostapd dnsmasq qrencode debian-keyring debian-archive-keyring apt-transport-https ca-certificates)

# Node.js uninstall support (NodeSource repo cleanup)
NODESOURCE_LIST="/etc/apt/sources.list.d/nodesource.list"
NODESOURCE_KEYRING="/usr/share/keyrings/nodesource.gpg"

# Docker uninstall support
DOCKER_LIST="/etc/apt/sources.list.d/docker.list"
DOCKER_KEYRING="/etc/apt/keyrings/docker.gpg"

# cloudflared uninstall support
CLOUDFLARED_LIST="/etc/apt/sources.list.d/cloudflared.list"
CLOUDFLARED_KEYRING="/etc/apt/keyrings/cloudflare-main.gpg"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Confirm uninstallation
confirm_uninstall() {
    echo "=== niroku uninstaller ==="
    echo "This will remove niroku (Caddy + Martin) installations made by install.sh"
    echo ""
    
    # Check what will be removed
    local items_to_remove=()
    
    if [ -d "$INSTALL_DIR" ]; then
        items_to_remove+=("  - UNVT Portable installation at $INSTALL_DIR")
    fi
    
    if systemctl is-enabled martin >/dev/null 2>&1; then
        items_to_remove+=("  - Martin tile server (service will be stopped and removed)")
    fi
    
    if systemctl is-enabled caddy-niroku >/dev/null 2>&1; then
        items_to_remove+=("  - Caddy-niroku web server (service will be stopped and removed)")
    fi
    
    if command -v martin &> /dev/null; then
        items_to_remove+=("  - Martin binary from /usr/local/bin/martin")
    fi
    
    if dpkg -l | grep -q "^ii  caddy "; then
        items_to_remove+=("  - Caddy web server package")
    fi
    
    if [ ${#items_to_remove[@]} -eq 0 ]; then
        log_warning "No niroku installations found."
        log_info "Nothing to uninstall."
        exit 0
    fi
    
    echo "The following will be removed:"
    printf '%s\n' "${items_to_remove[@]}"
    echo ""
    log_warning "This action cannot be undone!"
    
    # Only prompt if interactive
    if [ -t 0 ]; then
        read -p "Continue with uninstallation? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Uninstallation cancelled."
            exit 0
        fi
    else
        log_warning "Running in non-interactive mode. Proceeding with uninstallation."
    fi
}

# Stop and remove Martin service
stop_martin() {
    if systemctl is-active martin >/dev/null 2>&1; then
        log_info "Stopping Martin tile server..."
        systemctl stop martin
        log_success "Martin stopped"
    fi
    
    if systemctl is-enabled martin >/dev/null 2>&1; then
        log_info "Disabling Martin service..."
        systemctl disable martin >/dev/null 2>&1
        log_success "Martin disabled"
    fi
    
    if [ -f "/etc/systemd/system/martin.service" ]; then
        log_info "Removing Martin service file..."
        rm -f /etc/systemd/system/martin.service
        systemctl daemon-reload
        log_success "Martin service file removed"
    fi
    
    if [ -f "/usr/local/bin/martin" ]; then
        log_info "Removing Martin binary..."
        rm -f /usr/local/bin/martin
        log_success "Martin binary removed"
    fi
}

# Stop and remove Caddy-niroku service
stop_caddy() {
    if systemctl is-active caddy-niroku >/dev/null 2>&1; then
        log_info "Stopping Caddy-niroku web server..."
        systemctl stop caddy-niroku
        log_success "Caddy-niroku stopped"
    fi
    
    if systemctl is-enabled caddy-niroku >/dev/null 2>&1; then
        log_info "Disabling Caddy-niroku service..."
        systemctl disable caddy-niroku >/dev/null 2>&1
        log_success "Caddy-niroku disabled"
    fi
    
    if [ -f "/etc/systemd/system/caddy-niroku.service" ]; then
        log_info "Removing Caddy-niroku service file..."
        rm -f /etc/systemd/system/caddy-niroku.service
        systemctl daemon-reload
        log_success "Caddy-niroku service file removed"
    fi
}

# Remove Caddy package
remove_caddy_package() {
    if dpkg -l | grep -q "^ii  caddy "; then
        log_info "Removing Caddy package..."
        apt-get purge -y caddy >/dev/null 2>&1
        log_success "Caddy package removed"
        
        # Remove Caddy repository files
        if [ -f "/etc/apt/sources.list.d/caddy-stable.list" ]; then
            log_info "Removing Caddy repository configuration..."
            rm -f /etc/apt/sources.list.d/caddy-stable.list
            rm -f /usr/share/keyrings/caddy-stable-archive-keyring.gpg
            log_success "Caddy repository configuration removed"
        fi
    fi
}

# Remove UNVT Portable installation
remove_unvt_portable() {
    if [ -d "$INSTALL_DIR" ]; then
        log_info "Removing UNVT Portable installation from $INSTALL_DIR..."
        rm -rf "$INSTALL_DIR"
        log_success "UNVT Portable installation removed"
    fi
}

# Remove base packages
remove_base_packages() {
    log_info "Checking for base packages to remove..."
    
    # Get installed packages once for efficiency
    local dpkg_list
    dpkg_list=$(dpkg -l 2>/dev/null || true)
    
    local packages_to_remove=()
    for pkg in "${BASE_PACKAGES[@]}"; do
        if echo "$dpkg_list" | grep -q "^ii  $pkg "; then
            packages_to_remove+=("$pkg")
        fi
    done
    
    if [ ${#packages_to_remove[@]} -gt 0 ]; then
        log_info "Purging base packages: ${packages_to_remove[*]}"
        apt-get purge -y "${packages_to_remove[@]}"
        log_success "Base packages purged"
    else
        log_info "No base packages to remove"
    fi
}

# Optionally remove comprehensive packages
remove_optional_packages() {
    log_info "Checking for comprehensive packages..."
    
    # Get installed packages once for efficiency
    local dpkg_list
    dpkg_list=$(dpkg -l 2>/dev/null || true)
    
    local installed_packages=()
    for pkg in "${COMPREHENSIVE_PACKAGES[@]}"; do
        if echo "$dpkg_list" | grep -q "^ii  $pkg "; then
            installed_packages+=("$pkg")
        fi
    done
    
    if [ ${#installed_packages[@]} -gt 0 ]; then
        echo ""
        log_warning "Found comprehensive packages installed by niroku:"
        echo "  ${installed_packages[*]}"
        echo ""
        log_info "These packages may be used by other applications."
        
        if [ -t 0 ]; then
            read -p "Remove these packages? (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                log_info "Purging comprehensive packages..."
                apt-get purge -y "${installed_packages[@]}"
                apt-get autoremove -y
                log_success "Comprehensive packages purged"
            else
                log_info "Keeping comprehensive packages"
            fi
        else
            log_info "Non-interactive mode: keeping comprehensive packages"
        fi
    else
        log_info "No comprehensive packages to remove"
    fi
    
    log_info "Cleaning up unused dependencies..."
    apt-get autoremove -y
    log_success "Cleanup complete"
}

# Remove Node.js (NodeSource) and global Vite
remove_node_and_vite() {
    log_info "Checking Node.js and Vite..."
    if dpkg -l | grep -q "^ii  nodejs "; then
        log_info "Purging nodejs..."
        apt-get purge -y nodejs >/dev/null 2>&1 || true
    fi
    # Remove NodeSource repo files if present
    if [ -f "$NODESOURCE_LIST" ]; then
        log_info "Removing NodeSource repository configuration..."
        rm -f "$NODESOURCE_LIST" || true
    fi
    if [ -f "$NODESOURCE_KEYRING" ]; then
        rm -f "$NODESOURCE_KEYRING" || true
    fi
    # Attempt to remove global vite if npm still available
    if command -v npm >/dev/null 2>&1; then
        npm uninstall -g vite >/dev/null 2>&1 || true
    fi
    apt-get update -qq || true
    log_success "Node.js/Vite cleanup complete"
}

# Display uninstallation summary
display_summary() {
    echo ""
    echo "=========================================="
    log_success "Uninstallation complete!"
    echo "=========================================="
    echo ""
    log_info "niroku has been removed from your system."
    echo ""
}

# Main uninstallation flow
main() {
    check_root
    confirm_uninstall
    
    echo ""
    log_info "Starting uninstallation..."
    echo ""
    
    stop_martin
    stop_caddy
    remove_caddy_package
    remove_unvt_portable
    remove_base_packages
    remove_optional_packages
    remove_node_and_vite
    
    # Uninstall Docker Engine and cleanup repository
    log_info "Checking Docker installation..."
    if systemctl is-active docker >/dev/null 2>&1; then
        log_info "Stopping Docker..."
        systemctl stop docker || true
    fi
    if systemctl is-enabled docker >/dev/null 2>&1; then
        systemctl disable docker || true
    fi
    # Purge Docker packages if installed
    DOCKER_PKGS=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)
    TO_PURGE=()
    for p in "${DOCKER_PKGS[@]}"; do
        if dpkg -l | grep -q "^ii  ${p} "; then
            TO_PURGE+=("$p")
        fi
    done
    if [ ${#TO_PURGE[@]} -gt 0 ]; then
        log_info "Purging Docker packages: ${TO_PURGE[*]}"
        apt-get purge -y "${TO_PURGE[@]}" || true
    else
        log_info "No Docker packages to purge"
    fi
    # Remove Docker repo and keyring
    if [ -f "$DOCKER_LIST" ]; then
        rm -f "$DOCKER_LIST" || true
    fi
    if [ -f "$DOCKER_KEYRING" ]; then
        rm -f "$DOCKER_KEYRING" || true
    fi
    apt-get update -qq || true
    
    # Optional data cleanup
    if [ -t 0 ] && [ -d "/var/lib/docker" ]; then
        echo ""
        log_warning "Docker data directory /var/lib/docker exists."
        read -p "Remove /var/lib/docker and /var/lib/containerd? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf /var/lib/docker /var/lib/containerd || true
            log_success "Docker data directories removed"
        else
            log_info "Keeping Docker data directories"
        fi
    fi
    
    # Uninstall cloudflared and cleanup repository
    log_info "Checking cloudflared installation..."
    # Stop possible service if exists
    if systemctl list-units --type=service --all | grep -q "cloudflared"; then
        systemctl stop cloudflared 2>/dev/null || true
        systemctl disable cloudflared 2>/dev/null || true
    fi
    if dpkg -l | grep -q "^ii  cloudflared "; then
        log_info "Purging cloudflared..."
        apt-get purge -y cloudflared || true
    fi
    if [ -f "$CLOUDFLARED_LIST" ]; then
        rm -f "$CLOUDFLARED_LIST" || true
    fi
    if [ -f "$CLOUDFLARED_KEYRING" ]; then
        rm -f "$CLOUDFLARED_KEYRING" || true
    fi
    apt-get update -qq || true
    
    # Remove tippecanoe (package or binaries)
    if dpkg -l | grep -q "^ii  tippecanoe "; then
        log_info "Purging tippecanoe package..."
        apt-get purge -y tippecanoe || true
    else
        # If installed from source, binaries are in /usr/local/bin
        for bin in tippecanoe tile-join tippecanoe-enumerate; do
            if [ -f "/usr/local/bin/$bin" ]; then
                rm -f "/usr/local/bin/$bin" || true
                log_info "Removed /usr/local/bin/$bin"
            fi
        done
    fi
    
    # Remove go-pmtiles CLI
    if [ -f "/usr/local/bin/pmtiles" ]; then
        rm -f /usr/local/bin/pmtiles || true
        log_info "Removed /usr/local/bin/pmtiles"
    fi
    
    # Optionally restore tmpfs on /tmp (symmetry with install.sh)
    if [ -t 0 ]; then
        echo ""
        log_warning "Optionally restore default tmpfs on /tmp (systemctl unmask tmp.mount)."
        read -p "Restore tmpfs on /tmp? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Restoring tmpfs on /tmp..."
            systemctl unmask tmp.mount || true
            # Try to start the mount unit immediately; may require reboot on some systems
            if systemctl start tmp.mount 2>/dev/null; then
                log_success "/tmp tmpfs mount started."
            else
                log_warning "Could not start tmp.mount now. It should mount on next boot."
            fi
            # Ensure sticky bit permissions remain correct
            if [ -d /tmp ]; then
                chmod 1777 /tmp || true
            fi
        else
            log_info "Keeping current /tmp mount configuration."
        fi
    else
        log_info "Non-interactive mode: not changing /tmp mount configuration."
    fi
    
    display_summary
}

# Run main function
main
