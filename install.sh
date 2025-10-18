#!/bin/bash
set -e

# niroku - Installer for Raspberry Pi OS (trixie)
# A pipe-to-shell installer for quick niroku setup with Caddy and Martin
# Usage: curl -fsSL https://unvt.github.io/niroku/install.sh | sudo -E bash -

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/unvt-portable"
DATA_DIR="/opt/unvt-portable/data"
# Conservative parallelism for building from source on unstable power
TIPPECANOE_MAKE_JOBS=2
# Note: Update these versions periodically to use latest stable releases
# Check https://github.com/caddyserver/caddy/releases
# Check https://github.com/maplibre/martin/releases
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
            if [ -t 0 ]; then
                read -p "Continue anyway? (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    log_error "Installation cancelled."
                    exit 1
                fi
            else
                if [ "${NIROKU_FORCE_OS:-0}" = "1" ]; then
                    log_warning "Non-interactive mode with NIROKU_FORCE_OS=1: continuing on unsupported OS."
                else
                    log_error "Non-interactive mode: unsupported OS. Set NIROKU_FORCE_OS=1 to continue."
                    exit 1
                fi
            fi
        fi
    fi
    
    # Check if running as root or with sudo
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run with sudo or as root"
        exit 1
    fi
}

# Disable tmpfs on /tmp for Debian trixie and Raspberry Pi OS (per UNopenGIS/7#786)
disable_tmp_tmpfs() {
    log_info "Checking /tmp mount configuration..."

    # Detect if /tmp is a tmpfs mount
    if mount | awk '{print $3, $5}' | grep -qE "^/tmp tmpfs$"; then
        log_warning "/tmp is mounted as tmpfs. It can consume half of RAM and cause issues for tools using /tmp."
        log_info "Disabling tmpfs for /tmp: masking tmp.mount and unmounting /tmp"
        # Mask tmp.mount so it will not be mounted on next boot
        systemctl mask tmp.mount || true

        # Try to unmount /tmp now. This can fail if busy (e.g., SSH writing to /tmp)
        if umount /tmp 2>/dev/null; then
            log_success "/tmp unmounted successfully."
        else
            log_warning "Could not unmount /tmp now (it may be busy). It will not be mounted after reboot."
        fi

        # Ensure /tmp exists with correct sticky permissions
        if [ ! -d /tmp ]; then
            mkdir -p /tmp
        fi
        chmod 1777 /tmp || true

        log_info "If /tmp is still tmpfs, please reboot to complete the change."
    else
        log_info "/tmp is not a tmpfs mount. No change needed."
    fi
}

# Update system packages
update_system() {
    log_info "Updating system packages..."
    if ! apt-get update -qq; then
        log_error "Failed to update system packages. Please check your network connection and package sources."
        exit 1
    fi
    log_success "System packages updated"
}

# Install dependencies
install_dependencies() {
    log_info "Installing required dependencies..."
    
    # Base packages from simple installer (PR #2)
    # Plus additional packages needed for Caddy + Martin setup
    PACKAGES=(
        "aria2"
        "btop"
        "gdal-bin"
        "git"
        "jq"
        "ruby"
        "tmux"
        "vim"
        "curl"
        "wget"
        "hostapd"
        "dnsmasq"
        "qrencode"
        "debian-keyring"
        "debian-archive-keyring"
        "apt-transport-https"
        "ca-certificates"
        "lsb-release"
        "gnupg"
        "build-essential"
        "libsqlite3-dev"
        "zlib1g-dev"
        "libprotobuf-dev"
        "protobuf-compiler"
    )
    
    apt-get install -y -qq "${PACKAGES[@]}"
    log_success "Dependencies installed"
}

# Install tippecanoe (prefer Debian package, fallback to source build)
install_tippecanoe() {
    log_info "Installing tippecanoe..."
    if apt-cache show tippecanoe >/dev/null 2>&1; then
        if apt-get install -y -qq tippecanoe; then
            log_success "tippecanoe installed from Debian repo"
            return
        fi
    fi
    log_warning "tippecanoe package not available or installation failed; building from source (this may take long)"
    TMPDIR=$(mktemp -d)
    git clone --depth 1 https://github.com/felt/tippecanoe "$TMPDIR/tippecanoe"
    make -C "$TMPDIR/tippecanoe" -j"${TIPPECANOE_MAKE_JOBS:-2}"
    make -C "$TMPDIR/tippecanoe" install
    rm -rf "$TMPDIR"
    log_success "tippecanoe built and installed from source"
}

# Install Cloudflare Tunnel client (cloudflared)
install_cloudflared() {
    log_info "Installing cloudflared (Cloudflare Tunnel client)..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | gpg --dearmor -o /etc/apt/keyrings/cloudflare-main.gpg
    chmod a+r /etc/apt/keyrings/cloudflare-main.gpg
    . /etc/os-release
    echo "deb [signed-by=/etc/apt/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/ ${VERSION_CODENAME} main" \
        | tee /etc/apt/sources.list.d/cloudflared.list >/dev/null
    apt-get update -qq
    apt-get install -y -qq cloudflared
    log_success "cloudflared installed"
}

# Install Docker Engine (official repository)
install_docker() {
    log_info "Installing Docker Engine..."
    # Prereqs
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Add the repository
    ARCH=$(dpkg --print-architecture)
    . /etc/os-release
    echo \
"deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
${VERSION_CODENAME} stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    systemctl enable --now docker
    log_success "Docker Engine installed and started"
}

# Install Node.js LTS via NodeSource and Vite globally
install_node_and_vite() {
    log_info "Installing Node.js (LTS) and Vite..."
    # Install NodeSource setup for Debian (Raspberry Pi OS based on Debian trixie)
    # Use nodesource setup script for LTS channel; verify availability silently
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    apt-get install -y -qq nodejs
    # Ensure npm is present and then install Vite globally
    if command -v npm >/dev/null 2>&1; then
        npm install -g vite
        log_success "Node.js and Vite installed"
    else
        log_error "npm not found after nodejs installation"
        exit 1
    fi
}

# Create installation directories
create_directories() {
    log_info "Creating installation directories..."
    
    if [ -d "$INSTALL_DIR" ]; then
        log_warning "Installation directory already exists: $INSTALL_DIR"
        if [ -t 0 ]; then
            read -p "Remove and reinstall? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                rm -rf "$INSTALL_DIR"
            else
                log_error "Installation cancelled."
                exit 1
            fi
        else
            if [ "${NIROKU_FORCE_REINSTALL:-0}" = "1" ]; then
                log_warning "Non-interactive mode with NIROKU_FORCE_REINSTALL=1: removing existing directory."
                rm -rf "$INSTALL_DIR"
            else
                log_error "Non-interactive mode: existing install at $INSTALL_DIR. Set NIROKU_FORCE_REINSTALL=1 to overwrite."
                exit 1
            fi
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
    if [ "${NIROKU_SKIP_CADDY_KEY_CHECK:-0}" != "1" ]; then
        # Extract fingerprint
        CADDY_KEY_FINGERPRINT=$(gpg --show-keys --with-fingerprint "$CADDY_GPG_KEY_TMP" 2>/dev/null | grep -A1 "pub" | grep -oE "([A-F0-9]{40})" | head -n1)
        if [ "$CADDY_KEY_FINGERPRINT" != "$CADDY_KNOWN_FINGERPRINT" ]; then
            log_error "Caddy GPG key fingerprint mismatch! Aborting installation. Set NIROKU_SKIP_CADDY_KEY_CHECK=1 to bypass temporarily."
            rm -f "$CADDY_GPG_KEY_TMP"
            exit 1
        fi
    else
        log_warning "Skipping Caddy GPG fingerprint check (NIROKU_SKIP_CADDY_KEY_CHECK=1)."
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
# CORS is disabled here because it's handled by Caddy to avoid duplicate headers
cors: false
EOF
    
    # Create systemd service for Martin
    # Note: Running as root for simplicity in portable/field deployment scenarios
    # For production environments, consider creating a dedicated 'martin' user
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
    # Note: Running as root for simplicity in portable/field deployment scenarios
    # For production environments, consider using the 'caddy' user created by the package
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

# Install go-pmtiles CLI
install_go_pmtiles() {
    log_info "Installing go-pmtiles..."
    ARCH=$(dpkg --print-architecture)
    VERSION="1.18.0"
    base_url="https://github.com/protomaps/go-pmtiles/releases/download/v${VERSION}"
    case "$ARCH" in
        arm64|aarch64)
            file="go-pmtiles_${VERSION}_linux_arm64.tar.gz";;
        armhf|armv7l)
            file="go-pmtiles_${VERSION}_linux_armv6.tar.gz";;
        amd64|x86_64)
            file="go-pmtiles_${VERSION}_linux_amd64.tar.gz";;
        *)
            log_error "Unsupported architecture for go-pmtiles: $ARCH"; return 1;;
    esac
    url="${base_url}/${file}"
    tmp_tar="/tmp/${file}"
    wget -q -O "$tmp_tar" "$url"
    tar -xzf "$tmp_tar" -C /tmp/
    install -m 0755 /tmp/pmtiles /usr/local/bin/pmtiles
    rm -f "$tmp_tar" /tmp/pmtiles 2>/dev/null || true
    log_success "go-pmtiles installed as pmtiles"
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
    log_success "niroku installation complete!"
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
    echo "  niroku - Installer"
    echo "  for Raspberry Pi OS (trixie)"
    echo "  Using Caddy + Martin Architecture"
    echo "=========================================="
    echo ""
    
    check_system
    disable_tmp_tmpfs
    update_system
    install_dependencies
    create_directories
    install_caddy
    install_martin
    install_node_and_vite
    install_docker
    install_cloudflared
    install_tippecanoe
    install_go_pmtiles
    configure_martin
    configure_caddy
    setup_wifi_ap
    generate_qr_codes
    display_summary
    
    log_success "Installation completed successfully!"
}

# Run main function
main
