#!/bin/bash
set -e

# niroku - JUMP26 (JICA UNVT Module Portable 26) Installer for Raspberry Pi OS (trixie)
# A pipe-to-shell installer for quick UNVT Portable setup with Caddy and Martin
# Usage: curl -sL https://raw.githubusercontent.com/unvt/niroku/main/install.sh | bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/unvt-portable"
DATA_DIR="/opt/unvt-portable/data"
CADDY_VERSION="2.8.4"
MARTIN_VERSION="0.14.2"

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
        "hostapd"
        "dnsmasq"
        "qrencode"
        "debian-keyring"
        "debian-archive-keyring"
        "apt-transport-https"
        "ca-certificates"
    )
    
    apt-get install -y -qq "${PACKAGES[@]}"
    log_success "Dependencies installed"
}

# Create installation directories
create_directories() {
    log_info "Creating installation directories..."
    
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
    
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$DATA_DIR"
    
    log_success "Directories created at $INSTALL_DIR"
}

# Install Caddy
install_caddy() {
    log_info "Installing Caddy web server..."
    
    # Add Caddy repository
    # Download Caddy GPG key to a temporary file
    CADDY_GPG_KEY_URL="https://dl.cloudsmith.io/public/caddy/stable/gpg.key"
    CADDY_GPG_KEY_TMP="/tmp/caddy.gpg.key"
    CADDY_KNOWN_FINGERPRINT="E2C0DDE2C6B4D7B5CA2C4E2AA7B2C3B5A3A3F0B6" # Replace with official fingerprint from https://github.com/caddyserver/caddy/wiki/Repository-signing-keys
    curl -1sLf "$CADDY_GPG_KEY_URL" -o "$CADDY_GPG_KEY_TMP"
    # Extract fingerprint
    CADDY_KEY_FINGERPRINT=$(gpg --show-keys --with-fingerprint "$CADDY_GPG_KEY_TMP" 2>/dev/null | grep -A1 "pub" | grep -oE "([A-F0-9]{40})" | head -n1)
    if [ "$CADDY_KEY_FINGERPRINT" != "$CADDY_KNOWN_FINGERPRINT" ]; then
        log_error "Caddy GPG key fingerprint mismatch! Aborting installation."
        rm -f "$CADDY_GPG_KEY_TMP"
        exit 1
    fi
    # Install the verified key
    gpg --dearmor < "$CADDY_GPG_KEY_TMP" > /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    rm -f "$CADDY_GPG_KEY_TMP"
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
    
    # Update and install Caddy
    apt-get update -qq
    apt-get install -y -qq caddy
    
    log_success "Caddy installed successfully"
}

# Install Martin
install_martin() {
    log_info "Installing Martin tile server..."
    
    # Detect architecture
    ARCH=$(dpkg --print-architecture)
    
    # Download Martin binary based on architecture
    if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
        MARTIN_URL="https://github.com/maplibre/martin/releases/download/v${MARTIN_VERSION}/martin-v${MARTIN_VERSION}-aarch64-unknown-linux-gnu.tar.gz"
    elif [ "$ARCH" = "armhf" ] || [ "$ARCH" = "armv7l" ]; then
        MARTIN_URL="https://github.com/maplibre/martin/releases/download/v${MARTIN_VERSION}/martin-v${MARTIN_VERSION}-armv7-unknown-linux-gnueabihf.tar.gz"
    elif [ "$ARCH" = "amd64" ] || [ "$ARCH" = "x86_64" ]; then
        MARTIN_URL="https://github.com/maplibre/martin/releases/download/v${MARTIN_VERSION}/martin-v${MARTIN_VERSION}-x86_64-unknown-linux-gnu.tar.gz"
    else
        log_error "Unsupported architecture: $ARCH"
        exit 1
    fi
    
    # Download and extract Martin
    wget -q -O /tmp/martin.tar.gz "$MARTIN_URL"
    tar -xzf /tmp/martin.tar.gz -C /tmp/
    mv /tmp/martin /usr/local/bin/martin
    chmod +x /usr/local/bin/martin
    rm /tmp/martin.tar.gz
    
    log_success "Martin installed successfully"
}

# Configure Martin
configure_martin() {
    log_info "Configuring Martin tile server..."
    
    # Create martin.yml configuration
    cat > "$INSTALL_DIR/martin.yml" << 'EOF'
pmtiles:
  paths:
    - /opt/unvt-portable/data
web_ui: enable-for-all
listen_addresses: "127.0.0.1:3000"
cors: false
EOF
    
    # Create systemd service for Martin
    cat > /etc/systemd/system/martin.service << EOF
[Unit]
Description=Martin Tile Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/local/bin/martin --config $INSTALL_DIR/martin.yml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start Martin service
    systemctl daemon-reload
    systemctl enable martin
    systemctl start martin
    
    log_success "Martin configured and started"
}

# Configure Caddy
configure_caddy() {
    log_info "Configuring Caddy web server..."
    
    # Create Caddyfile
    cat > "$INSTALL_DIR/Caddyfile" << 'EOF'
:8080 {
    # Serve static files from the data folder
    root * /opt/unvt-portable/data
    file_server

    # Add CORS headers to all responses
    header Access-Control-Allow-Origin "*"
    header Access-Control-Allow-Methods "GET, POST, OPTIONS"
    header Access-Control-Allow-Headers "*"

    # Reverse-proxy requests to martin
    handle_path /martin/* {
        # Handle OPTIONS preflight requests for martin paths
        @martin_preflight method OPTIONS
        handle @martin_preflight {
            header Access-Control-Allow-Origin "*"
            header Access-Control-Allow-Methods "GET, POST, OPTIONS"
            header Access-Control-Allow-Headers "*"
            header Access-Control-Max-Age "86400"
            respond 204
        }
        
        uri strip_prefix /martin
        reverse_proxy localhost:3000 {
            header_up X-Forwarded-Proto "http"
            header_up X-Forwarded-Host {host}
            header_up X-Forwarded-Port "8080"
        }
    }
}
EOF
    
    # Create systemd service for Caddy with custom Caddyfile
    cat > /etc/systemd/system/caddy-niroku.service << EOF
[Unit]
Description=Caddy Web Server for UNVT Portable
After=network.target martin.service

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/caddy run --config $INSTALL_DIR/Caddyfile
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    # Stop default Caddy if running
    systemctl stop caddy 2>/dev/null || true
    systemctl disable caddy 2>/dev/null || true
    
    # Enable and start Caddy-niroku service
    systemctl daemon-reload
    systemctl enable caddy-niroku
    systemctl start caddy-niroku
    
    log_success "Caddy configured and started"
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
    log_info "Data directory: $DATA_DIR"
    log_info "Configuration: $INSTALL_DIR/martin.yml"
    log_info "Caddy config: $INSTALL_DIR/Caddyfile"
    echo ""
    log_info "Service Status:"
    echo "  - Martin: $(systemctl is-active martin)"
    echo "  - Caddy: $(systemctl is-active caddy-niroku)"
    echo ""
    log_info "Next steps:"
    echo "  1. Place your PMTiles files in $DATA_DIR"
    
    # Get primary IP address with better error handling
    # Try multiple methods to get the primary IP
    PRIMARY_IP=""
    if command -v ip &> /dev/null; then
        PRIMARY_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7}' | head -1)
    fi
    if [ -z "$PRIMARY_IP" ]; then
        PRIMARY_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
    
    if [ -n "$PRIMARY_IP" ] && [ "$PRIMARY_IP" != "127.0.0.1" ]; then
        echo "  2. Access the web interface at:"
        echo "     - http://localhost:8080"
        echo "     - http://$PRIMARY_IP:8080"
        echo "  3. Access Martin tile server at:"
        echo "     - http://localhost:8080/martin"
        echo "     - http://$PRIMARY_IP:8080/martin"
    else
        echo "  2. Access the web interface at http://localhost:8080"
        echo "  3. Access Martin tile server at http://localhost:8080/martin"
    fi
    
    echo "  4. For WiFi AP setup, see: https://github.com/unvt/portable/wiki"
    echo ""
    log_info "Useful commands:"
    echo "  - Check Martin logs: journalctl -u martin -f"
    echo "  - Check Caddy logs: journalctl -u caddy-niroku -f"
    echo "  - Restart services: systemctl restart martin caddy-niroku"
    echo ""
    log_info "For more information, see:"
    echo "  - https://github.com/unvt/x-24b (reference architecture)"
    echo "  - https://martin.maplibre.org/ (Martin documentation)"
    echo "  - https://caddyserver.com/docs/ (Caddy documentation)"
    echo ""
}

# Main installation flow
main() {
    echo "=========================================="
    echo "  niroku - JUMP26 Installer"
    echo "  JICA UNVT Module Portable 26"
    echo "  for Raspberry Pi OS (trixie)"
    echo "  Using Caddy + Martin Architecture"
    echo "=========================================="
    echo ""
    
    check_system
    update_system
    install_dependencies
    create_directories
    install_caddy
    install_martin
    configure_martin
    configure_caddy
    setup_wifi_ap
    generate_qr_codes
    display_summary
    
    log_success "Installation completed successfully!"
}

# Run main function
main
