#!/bin/bash
set -euo pipefail

# niroku - Uninstaller for JUMP26 installations
# This script removes installations made by install.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/unvt-portable"

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
    echo "This will remove JUMP26 installations made by install.sh"
    echo ""
    
    # Check what will be removed
    local items_to_remove=()
    
    if [ -d "$INSTALL_DIR" ]; then
        items_to_remove+=("  - UNVT Portable installation at $INSTALL_DIR")
    fi
    
    if systemctl is-enabled apache2 >/dev/null 2>&1; then
        items_to_remove+=("  - Apache2 web server (will be stopped and disabled)")
    fi
    
    # Check for packages from simple install
    local packages_found=()
    for pkg in aria2 btop gdal-bin jq ruby tmux vim; do
        if dpkg -l | grep -q "^ii  $pkg "; then
            packages_found+=("$pkg")
        fi
    done
    
    if [ ${#packages_found[@]} -gt 0 ]; then
        items_to_remove+=("  - Packages: ${packages_found[*]}")
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

# Stop and disable Apache
stop_apache() {
    if systemctl is-active apache2 >/dev/null 2>&1; then
        log_info "Stopping Apache web server..."
        systemctl stop apache2
        log_success "Apache stopped"
    fi
    
    if systemctl is-enabled apache2 >/dev/null 2>&1; then
        log_info "Disabling Apache web server..."
        systemctl disable apache2 >/dev/null 2>&1
        log_success "Apache disabled"
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

# Remove packages installed by simple install.sh
remove_packages() {
    log_info "Checking for packages to remove..."
    
    local packages_to_remove=()
    
    # Packages from simple install.sh (PR #2)
    for pkg in aria2 btop gdal-bin jq ruby tmux vim; do
        if dpkg -l | grep -q "^ii  $pkg "; then
            packages_to_remove+=("$pkg")
        fi
    done
    
    if [ ${#packages_to_remove[@]} -gt 0 ]; then
        log_info "Removing packages: ${packages_to_remove[*]}"
        apt-get remove -y "${packages_to_remove[@]}"
        log_success "Packages removed"
        
        log_info "Cleaning up unused dependencies..."
        apt-get autoremove -y
        log_success "Cleanup complete"
    else
        log_info "No packages to remove"
    fi
}

# Optionally remove dependencies from comprehensive install
remove_comprehensive_packages() {
    log_info "Checking for comprehensive installation packages..."
    
    # Ask user if they want to remove comprehensive packages
    local comprehensive_packages=(
        "apache2"
        "nodejs"
        "npm"
        "python3-pip"
        "hostapd"
        "dnsmasq"
        "qrencode"
    )
    
    local installed_comprehensive=()
    for pkg in "${comprehensive_packages[@]}"; do
        if dpkg -l | grep -q "^ii  $pkg "; then
            installed_comprehensive+=("$pkg")
        fi
    done
    
    if [ ${#installed_comprehensive[@]} -gt 0 ]; then
        echo ""
        log_warning "Found packages from comprehensive installation:"
        echo "  ${installed_comprehensive[*]}"
        echo ""
        log_info "These packages may be used by other applications."
        
        if [ -t 0 ]; then
            read -p "Remove these packages? (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                log_info "Removing comprehensive packages..."
                apt-get remove -y "${installed_comprehensive[@]}"
                apt-get autoremove -y
                log_success "Comprehensive packages removed"
            else
                log_info "Keeping comprehensive packages"
            fi
        else
            log_info "Non-interactive mode: keeping comprehensive packages"
        fi
    fi
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
    
    stop_apache
    remove_unvt_portable
    remove_packages
    remove_comprehensive_packages
    
    display_summary
}

# Run main function
main
