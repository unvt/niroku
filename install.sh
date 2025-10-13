#!/bin/bash
set -e

# niroku - JUMP26 (JICA UNVT Module Portable 26) Installer for Raspberry Pi OS (trixie)
# A pipe-to-shell installer for quick UNVT Portable setup
# Usage: curl -sL https://raw.githubusercontent.com/unvt/niroku/main/install.sh | bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
UNVT_REPO="https://github.com/unvt/portable.git"
INSTALL_DIR="/opt/unvt-portable"
WEB_ROOT="/var/www/html"
APACHE_USER="www-data"

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

# Check if running on Raspberry Pi OS
check_system() {
    log_info "Checking system requirements..."
    
    # Check if running on Raspberry Pi
    if [ ! -f /proc/device-tree/model ]; then
        log_warning "Cannot detect Raspberry Pi model. Proceeding anyway..."
    else
        PI_MODEL=$(cat /proc/device-tree/model)
        log_info "Detected: $PI_MODEL"
    fi
    
    # Check OS version
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        log_info "OS: $PRETTY_NAME"
        
        # Check if it's Debian-based (trixie is Debian 13)
        if [[ "$ID" != "debian" && "$ID" != "raspbian" ]]; then
            log_warning "This installer is designed for Raspberry Pi OS (Debian-based). Current OS: $ID"
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_error "Installation cancelled."
                exit 1
            fi
        fi
    fi
    
    # Check if running as root or with sudo
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run with sudo or as root"
        exit 1
    fi
}

# Update system packages
update_system() {
    log_info "Updating system packages..."
    apt-get update -qq
    log_success "System packages updated"
}

# Install dependencies
install_dependencies() {
    log_info "Installing required dependencies..."
    
    PACKAGES=(
        "git"
        "curl"
        "wget"
        "apache2"
        "nodejs"
        "npm"
        "python3"
        "python3-pip"
        "hostapd"
        "dnsmasq"
        "qrencode"
    )
    
    apt-get install -y -qq "${PACKAGES[@]}"
    log_success "Dependencies installed"
}

# Clone UNVT Portable repository
clone_repository() {
    log_info "Cloning UNVT Portable repository..."
    
    if [ -d "$INSTALL_DIR" ]; then
        log_warning "Installation directory already exists: $INSTALL_DIR"
        read -p "Remove and reinstall? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$INSTALL_DIR"
        else
            log_error "Installation cancelled."
            exit 1
        fi
    fi
    
    git clone "$UNVT_REPO" "$INSTALL_DIR"
    log_success "Repository cloned to $INSTALL_DIR"
}

# Setup Node.js dependencies
setup_nodejs() {
    log_info "Setting up Node.js dependencies..."
    
    cd "$INSTALL_DIR"
    
    if [ -f "package.json" ]; then
        npm install --silent
        log_success "Node.js dependencies installed"
    else
        log_warning "No package.json found. Skipping Node.js setup."
    fi
}

# Setup Python dependencies
setup_python() {
    log_info "Setting up Python dependencies..."
    
    cd "$INSTALL_DIR"
    
    if [ -f "requirements.txt" ]; then
        pip3 install --quiet -r requirements.txt
        log_success "Python dependencies installed"
    else
        log_warning "No requirements.txt found. Skipping Python setup."
    fi
}

# Configure Apache
configure_apache() {
    log_info "Configuring Apache web server..."
    
    # Enable required Apache modules
    a2enmod rewrite headers ssl
    
    # Set proper permissions for web root
    chown -R "$APACHE_USER:$APACHE_USER" "$WEB_ROOT"
    chmod -R 755 "$WEB_ROOT"
    
    # Restart Apache
    systemctl restart apache2
    systemctl enable apache2
    
    log_success "Apache configured and started"
}

# Setup WiFi Access Point (optional)
setup_wifi_ap() {
    log_info "WiFi Access Point setup is available but not configured automatically."
    log_info "Please refer to the UNVT Portable documentation for WiFi AP configuration."
    log_info "Wiki: https://github.com/unvt/portable/wiki"
}

# Create QR codes for WiFi connection (if configured)
generate_qr_codes() {
    log_info "QR code generation can be done after WiFi AP configuration."
    log_info "Use the qrencode tool installed on this system."
}

# Display installation summary
display_summary() {
    echo ""
    echo "=========================================="
    log_success "JUMP26 (UNVT Portable) installation complete!"
    echo "=========================================="
    echo ""
    log_info "Installation directory: $INSTALL_DIR"
    log_info "Web root: $WEB_ROOT"
    echo ""
    log_info "Next steps:"
    echo "  1. Configure your map data in $WEB_ROOT"
    echo "  2. Access the web interface at http://localhost or http://$(hostname -I | awk '{print $1}')"
    echo "  3. Refer to the manual: https://github.com/unvt/portable/wiki"
    echo "  4. For WiFi AP setup, see: https://github.com/unvt/portable/wiki"
    echo ""
    log_info "Apache status: $(systemctl is-active apache2)"
    echo ""
}

# Main installation flow
main() {
    echo "=========================================="
    echo "  niroku - JUMP26 Installer"
    echo "  JICA UNVT Module Portable 26"
    echo "  for Raspberry Pi OS (trixie)"
    echo "=========================================="
    echo ""
    
    check_system
    update_system
    install_dependencies
    clone_repository
    setup_nodejs
    setup_python
    configure_apache
    setup_wifi_ap
    generate_qr_codes
    display_summary
    
    log_success "Installation completed successfully!"
}

# Run main function
main
