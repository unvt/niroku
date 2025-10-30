#!/bin/bash
set -e

# niroku - UNVT PortableInstaller for Raspberry Pi OS (trixie)
# A pipe-to-shell installer for quick niroku setup with Caddy and Martin
# Usage: curl -fsSL https://unvt.github.io/niroku/install.sh | sudo -E bash -

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/niroku"
DATA_DIR="/opt/niroku/data"
# Conservative parallelism for building from source on unstable power
TIPPECANOE_MAKE_JOBS=2
# Note: Update these versions periodically to use latest stable releases
# Check https://github.com/caddyserver/caddy/releases
# Check https://github.com/maplibre/martin/releases
CADDY_VERSION="2.8.4"
MARTIN_VERSION="martin-v0.19.3"

# Log to a file for troubleshooting
LOG_FILE="/tmp/niroku_install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Choose a writable temporary base directory
TMP_BASE="/tmp"
if ! (touch "$TMP_BASE/.niroku_test" 2>/dev/null && rm -f "$TMP_BASE/.niroku_test" 2>/dev/null); then
    TMP_BASE="/var/tmp"
fi

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

# Detect system architecture and set compatibility flags
detect_architecture() {
    ARCH=$(uname -m)
    log_info "Detected architecture: $ARCH"
    
    # Architecture compatibility flags
    MARTIN_SUPPORTED=true
    DOCKER_SUPPORTED=true
    
    # Pi Zero (armv6l) has limited binary support
    if [[ "$ARCH" == "armv6l" ]]; then
        log_warning "Detected armv6l (Raspberry Pi Zero). Some binaries may not be available."
        MARTIN_SUPPORTED=false  # Martin doesn't provide armv6l binaries
        DOCKER_SUPPORTED=false  # Docker CE doesn't support armv6l officially
    fi
}

# Check if running on Raspberry Pi OS
check_system() {
    log_info "Checking system requirements..."
    
    # Detect architecture first
    detect_architecture
    
    # Check if running on Raspberry Pi
    if [ ! -f /proc/device-tree/model ]; then
        log_warning "Cannot detect Raspberry Pi model. Proceeding anyway..."
    else
        # Some device-tree files may include NUL bytes; strip them for safe logging
        PI_MODEL=$(tr -d '\0' </proc/device-tree/model)
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
    if [ -f /etc/apt/sources.list.d/cloudflared.list ]; then
        log_info "Removing legacy cloudflared apt repository entry"
        rm -f /etc/apt/sources.list.d/cloudflared.list
    fi
    if [ -f /etc/apt/keyrings/cloudflare-main.gpg ]; then
        rm -f /etc/apt/keyrings/cloudflare-main.gpg
    fi
    if ! apt-get update -qq; then
        log_warning "Failed to update system packages. Continuing anyway..."
    else
        log_success "System packages updated"
    fi
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
    TMPDIR=$(mktemp -d -p "$TMP_BASE")
    git clone --depth 1 https://github.com/felt/tippecanoe "$TMPDIR/tippecanoe"
    make -C "$TMPDIR/tippecanoe" -j"${TIPPECANOE_MAKE_JOBS:-2}"
    make -C "$TMPDIR/tippecanoe" install
    rm -rf "$TMPDIR"
    log_success "tippecanoe built and installed from source"
}

# Install Cloudflare Tunnel client (cloudflared)
install_cloudflared() {
    log_info "Installing cloudflared (Cloudflare Tunnel client)..."
    CLOUDFLARED_DEB_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb"
    CLOUDFLARED_DEB="$TMP_BASE/cloudflared.deb"
    try_download "$CLOUDFLARED_DEB" "$CLOUDFLARED_DEB_URL"
    dpkg -i "$CLOUDFLARED_DEB"
    rm -f "$CLOUDFLARED_DEB"
    log_success "cloudflared installed"
}

# Helper: try_download(dest, url1, url2, ...)
# Attempts to download each URL in order to dest. Exits non-zero if all fail.
try_download() {
    local dest="$1"; shift
    local url
    rm -f "$dest"
    for url in "$@"; do
        log_info "Attempting download: $url"
        if curl -fL -o "$dest" "$url"; then
            if [ -s "$dest" ]; then
                log_info "Download succeeded: $url"
                return 0
            else
                log_warning "Downloaded file is empty: $url"
            fi
        else
            log_warning "Download failed for: $url"
        fi
    done
    log_error "All download attempts failed for destination: $dest"
    return 1
}

# Helper: create_systemd_service <unit_path>
# Writes stdin to the given systemd unit path, reloads systemd, enables and starts the unit.
create_systemd_service() {
    local unit_path="$1"
    if [ -z "$unit_path" ]; then
        log_error "create_systemd_service requires a unit path argument"
        return 1
    fi
    log_info "Creating systemd unit: $unit_path"
    mkdir -p "$(dirname "$unit_path")"
    # Write unit file from stdin
    cat > "$unit_path"
    # Reload and attempt to enable/start the service
    systemctl daemon-reload || true
    local unit_name
    unit_name=$(basename "$unit_path")
    if systemctl enable "$unit_name" >/dev/null 2>&1; then
        log_info "Enabled $unit_name"
    else
        log_warning "Could not enable $unit_name"
    fi
    if systemctl start "$unit_name" >/dev/null 2>&1; then
        log_info "Started $unit_name"
    else
        log_warning "Could not start $unit_name now"
    fi
    log_success "Systemd unit created: $unit_name"
}

# Install Docker Engine (official repository)
install_docker() {
    log_info "Installing Docker Engine..."
    
    # Check if Docker is supported on this architecture
    if [[ "$DOCKER_SUPPORTED" == "false" ]]; then
        log_warning "Docker CE is not officially supported for architecture: $(uname -m)"
        log_warning "You may try alternative container runtimes or Docker builds for armv6:"
        log_warning "  https://docs.docker.com/engine/install/"
        log_warning "Skipping Docker installation."
        return 0
    fi
    
    # Prereqs
    install -m 0755 -d /etc/apt/keyrings
    rm -f /etc/apt/keyrings/docker.gpg
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
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
        # Remove any existing versions first to avoid version conflicts
        npm uninstall -g vite maplibre-gl pmtiles >/dev/null 2>&1 || true
        # Install latest versions explicitly using @latest to avoid unexpected pinned versions
        npm install -g vite@latest maplibre-gl@latest pmtiles@latest
        log_success "Node.js, Vite, and cached packages (MapLibre GL JS, PMTiles) installed"
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
        
        # Default behavior: overwrite existing installation
        # Set NIROKU_KEEP_EXISTING=1 to keep the existing installation
        if [ "${NIROKU_KEEP_EXISTING:-0}" = "1" ]; then
            log_info "NIROKU_KEEP_EXISTING=1 is set. Keeping existing installation."
            log_warning "Some installation steps may fail if files already exist."
        else
            if [ -t 0 ]; then
                # Interactive mode: ask user
                read -p "Remove and reinstall? (Y/n): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Nn]$ ]]; then
                    log_info "Keeping existing installation. Some steps may fail if files already exist."
                else
                    log_info "Removing existing directory for fresh installation."
                    rm -rf "$INSTALL_DIR"
                fi
            else
                # Non-interactive mode: default to overwrite
                log_warning "Non-interactive mode: removing existing directory for fresh installation."
                log_info "Set NIROKU_KEEP_EXISTING=1 to keep the existing installation."
                rm -rf "$INSTALL_DIR"
            fi
        fi
    fi
    
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$DATA_DIR"
    
    # Make the installation directory writable by the niroku user (if exists)
    if id -u niroku >/dev/null 2>&1; then
        chown -R niroku:niroku "$INSTALL_DIR"
        chmod -R 755 "$INSTALL_DIR"
        log_info "Set ownership of $INSTALL_DIR to niroku user"
    else
        # If niroku user doesn't exist, make it writable by all users
        chmod -R 777 "$INSTALL_DIR"
        log_warning "niroku user not found. Set $INSTALL_DIR writable by all users."
    fi
    
    log_success "Directories created at $INSTALL_DIR"
}

# Install Caddy
install_caddy() {
    log_info "Installing Caddy web server..."
    
    # Add Caddy repository
    # Note: GPG key verification is skipped because the official Caddy documentation
    # does not provide a reliable way to verify the key fingerprint.
    # The key is still used for apt's signature verification.
    rm -f /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --batch --yes --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
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
    
    # Check if Martin is supported on this architecture
    if [[ "$MARTIN_SUPPORTED" == "false" ]]; then
        log_warning "Martin prebuilt binaries are not available for architecture: $ARCH"
        log_warning "You can build Martin from source manually:"
        log_warning "  https://github.com/maplibre/martin#building-from-source"
        log_warning "Skipping Martin installation."
        return 0
    fi
    
    # Download Martin binary based on architecture
    TAR_PATH="$TMP_BASE/martin.tar.gz"
    EXTRACT_DIR="$TMP_BASE/martin-extract"
    rm -rf "$EXTRACT_DIR" "$TAR_PATH"

    CANDIDATES=()
    case "$ARCH" in
        arm64|aarch64)
            CANDIDATES=(
                "https://github.com/maplibre/martin/releases/download/${MARTIN_VERSION}/martin-aarch64-unknown-linux-gnu.tar.gz"
                "https://github.com/maplibre/martin/releases/download/${MARTIN_VERSION}/martin-aarch64-unknown-linux-musl.tar.gz"
            )
            ;;
        armhf|armv7l)
            CANDIDATES=(
                "https://github.com/maplibre/martin/releases/download/${MARTIN_VERSION}/martin-armv7-unknown-linux-gnueabihf.tar.gz"
                "https://github.com/maplibre/martin/releases/download/${MARTIN_VERSION}/martin-armv7-unknown-linux-musleabihf.tar.gz"
            )
            ;;
        amd64|x86_64)
            CANDIDATES=(
                "https://github.com/maplibre/martin/releases/download/${MARTIN_VERSION}/martin-x86_64-unknown-linux-gnu.tar.gz"
                "https://github.com/maplibre/martin/releases/download/${MARTIN_VERSION}/martin-x86_64-unknown-linux-musl.tar.gz"
            )
            ;;
        *)
            log_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac

    if ! try_download "$TAR_PATH" "${CANDIDATES[@]}"; then
        log_error "Failed to download Martin for arch $ARCH (v${MARTIN_VERSION})."
        log_error "See available assets: https://github.com/maplibre/martin/releases/tag/v${MARTIN_VERSION}"
        exit 1
    fi

    mkdir -p "$EXTRACT_DIR"
    tar -xzf "$TAR_PATH" -C "$EXTRACT_DIR"
    # Locate the martin binary in the extracted files
    MARTIN_BIN_PATH=$(find "$EXTRACT_DIR" -type f -name martin -perm -u+x -print -quit)
    if [ -z "$MARTIN_BIN_PATH" ]; then
        # Fallback: pick a file named martin even if not marked executable
        MARTIN_BIN_PATH=$(find "$EXTRACT_DIR" -type f -name martin -print -quit)
    fi
    if [ -z "$MARTIN_BIN_PATH" ]; then
        log_error "Failed to locate martin binary in archive"
        rm -rf "$EXTRACT_DIR" "$TAR_PATH"
        exit 1
    fi
    install -m 0755 "$MARTIN_BIN_PATH" /usr/local/bin/martin
    rm -rf "$EXTRACT_DIR" "$TAR_PATH"
    
    log_success "Martin installed successfully"
}

# Configure Martin
configure_martin() {
    log_info "Configuring Martin tile server..."
    
    # Skip if Martin is not installed
    if [[ "$MARTIN_SUPPORTED" == "false" ]] || ! command -v martin >/dev/null 2>&1; then
        log_warning "Martin is not installed. Skipping Martin configuration."
        return 0
    fi
    
    # Create martin.yml configuration
    cat > "$INSTALL_DIR/martin.yml" << 'EOF'
pmtiles:
  paths:
    - /opt/niroku/data
web_ui: enable-for-all
listen_addresses: "127.0.0.1:3000"
# CORS is disabled here because it's handled by Caddy to avoid duplicate headers
cors: false
EOF
    
    # Create systemd service for Martin using helper
    create_systemd_service /etc/systemd/system/martin.service << EOF
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

    log_success "Martin configured (systemd unit created)"
}

# Configure Caddy
configure_caddy() {
    log_info "Configuring Caddy web server..."
    
    # Create Caddyfile
    cat > "$INSTALL_DIR/Caddyfile" << 'EOF'
:8080 {
    # Serve static files from the data folder
    root * /opt/niroku/data
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
    
    # Create systemd service for Caddy with custom Caddyfile using helper
    create_systemd_service /etc/systemd/system/caddy-niroku.service << EOF
[Unit]
Description=Caddy Web Server for niroku
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

    log_success "Caddy configured (systemd unit created)"
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
    tmp_tar="$TMP_BASE/${file}"
    if ! try_download "$tmp_tar" "$url"; then
        log_error "Failed to download go-pmtiles archive: $url"
        return 1
    fi
    tar -xzf "$tmp_tar" -C "$TMP_BASE/"
    install -m 0755 "$TMP_BASE/pmtiles" /usr/local/bin/pmtiles
    rm -f "$tmp_tar" "$TMP_BASE/pmtiles" 2>/dev/null || true
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
    
    if [[ "$MARTIN_SUPPORTED" == "true" ]] && command -v martin >/dev/null 2>&1; then
        log_info "Configuration: $INSTALL_DIR/martin.yml"
    fi
    
    log_info "Caddy config: $INSTALL_DIR/Caddyfile"
    echo ""
    log_info "Service Status:"
    
    if [[ "$MARTIN_SUPPORTED" == "true" ]] && systemctl list-unit-files martin.service >/dev/null 2>&1; then
        echo "  - Martin: $(systemctl is-active martin 2>/dev/null || echo 'not installed')"
    else
        echo "  - Martin: not available on this architecture"
    fi
    
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
        
        if [[ "$MARTIN_SUPPORTED" == "true" ]] && command -v martin >/dev/null 2>&1; then
            echo "  3. Access Martin tile server at:"
            echo "     - http://localhost:8080/martin"
            echo "     - http://$PRIMARY_IP:8080/martin"
        fi
    else
        echo "  2. Access the web interface at http://localhost:8080"
        
        if [[ "$MARTIN_SUPPORTED" == "true" ]] && command -v martin >/dev/null 2>&1; then
            echo "  3. Access Martin tile server at http://localhost:8080/martin"
        fi
    fi
    
    echo "  4. For WiFi AP setup, see: https://github.com/unvt/portable/wiki"
    echo ""
    log_info "Useful commands:"
    
    if [[ "$MARTIN_SUPPORTED" == "true" ]] && command -v martin >/dev/null 2>&1; then
        echo "  - Check Martin logs: journalctl -u martin -f"
        echo "  - Check Caddy logs: journalctl -u caddy-niroku -f"
        echo "  - Restart services: systemctl restart martin caddy-niroku"
    else
        echo "  - Check Caddy logs: journalctl -u caddy-niroku -f"
        echo "  - Restart Caddy: systemctl restart caddy-niroku"
    fi
    echo ""
    log_info "For more information, see:"
    echo "  - https://github.com/unvt/x-24b (reference architecture)"
    echo "  - https://martin.maplibre.org/ (Martin documentation)"
    echo "  - https://caddyserver.com/docs/ (Caddy documentation)"
    echo ""
}

# Lightweight smoke checks run after installation to provide quick feedback.
post_install_smoke_checks() {
    log_info "Running post-install smoke checks..."

    # Check Martin binary and service
    if command -v martin >/dev/null 2>&1; then
        log_info "martin binary found: $(command -v martin)"
    else
        log_warning "martin binary not found"
    fi

    if systemctl list-unit-files martin.service >/dev/null 2>&1; then
        MARTIN_ACTIVE=$(systemctl is-active martin 2>/dev/null || echo inactive)
        log_info "Martin service status: $MARTIN_ACTIVE"
    else
        log_info "Martin service not present on this architecture or not installed"
    fi

    # Check Caddy service
    if systemctl list-unit-files caddy-niroku.service >/dev/null 2>&1; then
        CADDY_ACTIVE=$(systemctl is-active caddy-niroku 2>/dev/null || echo inactive)
        log_info "Caddy-niroku service status: $CADDY_ACTIVE"
    else
        log_warning "Caddy-niroku service not found"
    fi

    # Quick HTTP check for Caddy root (localhost:8080)
    if command -v curl >/dev/null 2>&1; then
        if curl -s --max-time 5 http://127.0.0.1:8080/ >/dev/null 2>&1; then
            log_info "Caddy responded on http://127.0.0.1:8080/"
        else
            log_warning "No HTTP response from Caddy on http://127.0.0.1:8080/ (this may be expected until files are placed in $DATA_DIR)"
        fi
    fi

    log_success "Post-install smoke checks completed"
}

# Install PM11 PMTiles and viewer (optional, controlled by PM11 environment variable)
install_pm11() {
    # Check if PM11 environment variable is set
    if [ -z "${PM11:-}" ]; then
        log_info "PM11 environment variable not set. Skipping PM11 installation."
        return 0
    fi
    
    log_info "Installing PM11 PMTiles and viewer..."
    
    # Download pm11.pmtiles to /opt/niroku/data/
    log_info "Downloading pm11.pmtiles (this may take a while)..."
    PM11_PMTILES_PATH="$DATA_DIR/pm11.pmtiles"
    PM11_URL="https://tunnel.optgeo.org/pm11.pmtiles"
    
    if [ -f "$PM11_PMTILES_PATH" ]; then
        log_warning "pm11.pmtiles already exists at $PM11_PMTILES_PATH"
        if [ "${NIROKU_KEEP_EXISTING:-0}" != "1" ]; then
            log_info "Removing existing pm11.pmtiles for fresh download"
            rm -f "$PM11_PMTILES_PATH"
        else
            log_info "Keeping existing pm11.pmtiles"
        fi
    fi
    
    if [ ! -f "$PM11_PMTILES_PATH" ]; then
        # Check if aria2c is available (should be installed via install_dependencies)
        if ! command -v aria2c >/dev/null 2>&1; then
            log_error "aria2c is not installed. PM11 requires aria2 for downloading."
            log_error "Please ensure install_dependencies has been run before install_pm11."
            return 1
        fi
        
        if ! aria2c -x 2 -s 2 -o "$PM11_PMTILES_PATH" "$PM11_URL"; then
            log_error "Failed to download pm11.pmtiles from $PM11_URL"
            return 1
        fi
        log_success "Downloaded pm11.pmtiles to $PM11_PMTILES_PATH"
    fi
    
    # Create PM11 viewer site using Vite
    log_info "Creating PM11 viewer site..."
    PM11_VIEWER_DIR="$DATA_DIR/pm11"
    PM11_TMP_DIR="$TMP_BASE/pm11-vite-project"
    
    # Clean up any existing temporary directory
    rm -rf "$PM11_TMP_DIR"
    
    # Create Vite project
    mkdir -p "$PM11_TMP_DIR"
    cd "$PM11_TMP_DIR"
    
    # Create package.json
    cat > package.json << 'EOF'
{
  "name": "pm11-viewer",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "build": "vite build"
  },
  "devDependencies": {
    "vite": "latest"
  },
  "dependencies": {
    "maplibre-gl": "latest",
    "pmtiles": "latest"
  }
}
EOF
    
    # Create index.html (based on pm11 repo)
    cat > index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>PM11 Demo</title>
</head>
<body>
  <div id="map"></div>
  <script type="module" src="/index.js"></script>
</body>
</html>
EOF
    
    # Create index.js (based on pm11 repo, modified to use local pmtiles)
    cat > index.js << 'EOF'
import maplibregl from 'maplibre-gl';
import 'maplibre-gl/dist/maplibre-gl.css';
import './index.css';
import { Protocol } from 'pmtiles';

// Register PMTiles protocol
const protocol = new Protocol();
maplibregl.addProtocol('pmtiles', protocol.tile);

// Initialize map
const map = new maplibregl.Map({
  container: 'map',
  style: {
    version: 8,
    sources: {
      pm11: {
        type: 'vector',
        url: 'pmtiles:///pm11.pmtiles',
        attribution: '<a href="https://github.com/hfu/pm11">PM11</a>'
      }
    },
    layers: [
      {
        id: 'background',
        type: 'background',
        paint: {
          'background-color': '#f0f0f0'
        }
      },
      {
        id: 'water',
        type: 'fill',
        source: 'pm11',
        'source-layer': 'water',
        paint: {
          'fill-color': '#80deea'
        }
      },
      {
        id: 'transportation',
        type: 'line',
        source: 'pm11',
        'source-layer': 'transportation',
        paint: {
          'line-color': '#ffa726',
          'line-width': 1
        }
      },
      {
        id: 'building',
        type: 'fill',
        source: 'pm11',
        'source-layer': 'building',
        paint: {
          'fill-color': '#bdbdbd',
          'fill-opacity': 0.7
        }
      },
      {
        id: 'place_label',
        type: 'symbol',
        source: 'pm11',
        'source-layer': 'place',
        layout: {
          'text-field': ['get', 'name'],
          'text-size': 12
        },
        paint: {
          'text-color': '#333',
          'text-halo-color': '#fff',
          'text-halo-width': 1
        }
      }
    ]
  },
  center: [0, 0],
  zoom: 2
});

map.addControl(new maplibregl.NavigationControl());
EOF
    
    # Create index.css
    cat > index.css << 'EOF'
body {
  margin: 0;
  padding: 0;
}

#map {
  position: absolute;
  top: 0;
  bottom: 0;
  width: 100%;
}
EOF
    
    # Create vite.config.js to customize build output
    cat > vite.config.js << 'EOF'
import { defineConfig } from 'vite';

export default defineConfig({
  base: '/pm11/',
  build: {
    outDir: 'dist',
    assetsDir: 'assets',
    rollupOptions: {
      output: {
        entryFileNames: 'index.js',
        chunkFileNames: 'assets/[name].js',
        assetFileNames: 'assets/[name].[ext]'
      }
    }
  }
});
EOF
    
    # Install dependencies and build
    log_info "Installing npm dependencies for PM11 viewer..."
    if ! npm install --quiet 2>&1 | grep -v "npm WARN"; then
        log_error "Failed to install npm dependencies for PM11 viewer"
        log_error "Check /tmp/niroku_install.log for details"
        cd /
        rm -rf "$PM11_TMP_DIR"
        return 1
    fi
    
    log_info "Building PM11 viewer with Vite..."
    if ! npm run build; then
        log_error "Failed to build PM11 viewer with Vite"
        log_error "Check /tmp/niroku_install.log for details"
        cd /
        rm -rf "$PM11_TMP_DIR"
        return 1
    fi
    
    # Copy built files to destination
    if [ -d "$PM11_VIEWER_DIR" ]; then
        if [ "${NIROKU_KEEP_EXISTING:-0}" != "1" ]; then
            log_info "Removing existing PM11 viewer directory"
            rm -rf "$PM11_VIEWER_DIR"
        fi
    fi
    
    mkdir -p "$PM11_VIEWER_DIR"
    cp -r dist/* "$PM11_VIEWER_DIR/"
    
    # Clean up temporary directory
    cd /
    rm -rf "$PM11_TMP_DIR"
    
    log_success "PM11 viewer installed at $PM11_VIEWER_DIR"
    log_info "Access PM11 viewer at: http://localhost:8080/pm11/"
}


# Main installation flow
main() {
    echo "=========================================="
    echo "  niroku - UNVT Portable Installer"
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
    install_pm11
    setup_wifi_ap
    generate_qr_codes
    display_summary
    # Run lightweight smoke checks to validate services and binaries
    post_install_smoke_checks
    
    log_success "Installation completed successfully!"
}

# Run main function
main

# Lightweight smoke checks run after installation to provide quick feedback.
post_install_smoke_checks() {
    log_info "Running post-install smoke checks..."

    # Check Martin binary and service
    if command -v martin >/dev/null 2>&1; then
        log_info "martin binary found: $(command -v martin)"
    else
        log_warning "martin binary not found"
    fi

    if systemctl list-unit-files martin.service >/dev/null 2>&1; then
        MARTIN_ACTIVE=$(systemctl is-active martin 2>/dev/null || echo inactive)
        log_info "Martin service status: $MARTIN_ACTIVE"
    else
        log_info "Martin service not present on this architecture or not installed"
    fi

    # Check Caddy service
    if systemctl list-unit-files caddy-niroku.service >/dev/null 2>&1; then
        CADDY_ACTIVE=$(systemctl is-active caddy-niroku 2>/dev/null || echo inactive)
        log_info "Caddy-niroku service status: $CADDY_ACTIVE"
    else
        log_warning "Caddy-niroku service not found"
    fi

    # Quick HTTP check for Caddy root (localhost:8080)
    if command -v curl >/dev/null 2>&1; then
        if curl -s --max-time 5 http://127.0.0.1:8080/ >/dev/null 2>&1; then
            log_info "Caddy responded on http://127.0.0.1:8080/"
        else
            log_warning "No HTTP response from Caddy on http://127.0.0.1:8080/ (this may be expected until files are placed in $DATA_DIR)"
        fi
    fi

    log_success "Post-install smoke checks completed"
}
