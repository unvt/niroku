# niroku

**niroku** — a pipe‑to‑shell installer to quickly install JUMP26 on Raspberry Pi OS (trixie)

## Overview

**niroku** is a streamlined installer script that helps you quickly set up **JUMP26** (JICA UNVT Module Portable 26) on Raspberry Pi OS (trixie). It uses a modern architecture with **Caddy** (reverse proxy) and **Martin** (PMTiles tile server) to provide an offline local web map server designed for disaster response and field operations.

### Architecture

niroku follows the proven [x-24b architecture](https://github.com/unvt/x-24b):

```
Web Browser ←→ Caddy (Reverse Proxy) ←→ Martin (PMTiles Server)
```

- **Caddy**: Handles HTTP serving, CORS, and reverse proxying
- **Martin**: Serves PMTiles vector tiles with high performance
- **systemd services**: Both run as system services with automatic restart

## What is JUMP26?

JUMP26 (JICA UNVT Module Portable 26) is a version of UNVT Portable configured for JICA (Japan International Cooperation Agency) programs. It provides:

- **Offline web map server** running on Raspberry Pi
- **Local network access** to geospatial data without internet
- **QR code based WiFi connection** for easy access
- **Integration** of OpenStreetMap, aerial imagery, and custom map data
- **Disaster response** capabilities for municipal operations

## Quick Installation

### One-line Install (Pipe to Shell)

The simplest way to install JUMP26:

```bash
curl -sL https://raw.githubusercontent.com/unvt/niroku/main/install.sh | sudo bash
```

Or using wget:

```bash
wget -qO- https://raw.githubusercontent.com/unvt/niroku/main/install.sh | sudo bash
```

### Manual Installation

If you prefer to review the script before running:

```bash
# Download the script
curl -sL https://raw.githubusercontent.com/unvt/niroku/main/install.sh -o install.sh

# Review the script
less install.sh

# Make it executable
chmod +x install.sh

# Run the installer
sudo ./install.sh
```

## System Requirements

- **Hardware**: Raspberry Pi 4 or later (recommended)
- **OS**: Raspberry Pi OS (Debian trixie or compatible)
- **Storage**: Minimum 16GB microSD card (128GB+ recommended for map data)
- **Network**: Ethernet or WiFi connectivity for initial setup
- **Permissions**: Root/sudo access required

## What Gets Installed

The niroku installer will:

1. ✅ Update system packages
2. ✅ Install dependencies (git, curl, wget, etc.)
3. ✅ Install **Caddy** web server (reverse proxy)
4. ✅ Install **Martin** tile server (PMTiles hosting)
5. ✅ Create installation directory at `/opt/unvt-portable`
6. ✅ Configure both services to run automatically at boot
7. ✅ Install tools for WiFi AP and QR code generation

## Post-Installation Steps

After installation completes:

1. **Access the web interface**:
   ```bash
   # Find your Raspberry Pi's IP address
   hostname -I
   
   # Access via web browser at:
   # http://[YOUR_IP_ADDRESS]:8080
   # Martin tile server at:
   # http://[YOUR_IP_ADDRESS]:8080/martin
   ```

2. **Add your map data**:
   - Place PMTiles files in `/opt/unvt-portable/data`
   - Martin will automatically detect and serve them
   - Access tiles at: `http://[YOUR_IP]:8080/martin/[filename]/{z}/{x}/{y}`

3. **Manage services**:
   ```bash
   # Check service status
   systemctl status martin
   systemctl status caddy-niroku
   
   # View logs
   journalctl -u martin -f
   journalctl -u caddy-niroku -f
   
   # Restart services
   systemctl restart martin caddy-niroku
   ```

4. **Configure WiFi Access Point** (optional):
   - Refer to the [UNVT Portable WiFi setup guide](https://github.com/unvt/portable/wiki)
   - Generate QR codes using the installed `qrencode` tool

## Security Considerations

⚠️ **Important Security Notes**:

- **Pipe-to-shell pattern**: While convenient, piping scripts to bash can be risky. This installer:
  - Is open source and auditable
  - Uses `set -e` to exit on errors
  - Validates system requirements before making changes
  - Provides colored output for clear progress tracking

- **Review before running**: We encourage reviewing the script before execution
- **Run with sudo**: Required for system-level changes
- **Local network only**: By default, UNVT Portable is designed for local network access

## Manual and Documentation

- **UNVT Portable Wiki**: https://github.com/unvt/portable/wiki
- **Original Repository**: https://github.com/unvt/portable
- **Manual (Google Slides)**: [UNVT Portable Manual](https://docs.google.com/presentation/d/1SuDCDUfLHZ2Xw1SdpUIillYWJekY0L4TqS7-X4sDZqg/edit?usp=sharing)
- **Video Tutorial**: [YouTube - UNVT Portable Installation](https://youtube.com/shorts/XUsOE_sISLM)

## Troubleshooting

### Installation fails with permission errors
```bash
# Ensure you're using sudo
sudo ./install.sh
```

### Services don't start
```bash
# Check Martin status
sudo systemctl status martin

# Check Caddy status
sudo systemctl status caddy-niroku

# View logs
sudo journalctl -u martin -n 50
sudo journalctl -u caddy-niroku -n 50
```

### Port 8080 already in use
```bash
# Check what's using port 8080
sudo lsof -i :8080

# Stop conflicting service if needed
sudo systemctl stop [service-name]

# Or edit the Caddyfile to use a different port
sudo nano /opt/unvt-portable/Caddyfile
sudo systemctl restart caddy-niroku
```

### Martin can't find PMTiles files
```bash
# Ensure files are in the correct directory
ls -la /opt/unvt-portable/data/

# Check file permissions
sudo chmod 644 /opt/unvt-portable/data/*.pmtiles

# Restart Martin
sudo systemctl restart martin
```

## Development and Contributing

This project is part of the [UNVT (United Nations Vector Tile Toolkit)](https://github.com/unvt) ecosystem.

- **Repository**: https://github.com/unvt/niroku
- **Issues**: https://github.com/unvt/niroku/issues
- **License**: CC0 1.0 Universal (Public Domain)

## Related Projects

- [unvt/x-24b](https://github.com/unvt/x-24b) - Reference architecture for Caddy + Martin setup
- [unvt/portable](https://github.com/unvt/portable) - Main UNVT Portable repository
- [unvt/portable-j-22](https://github.com/unvt/portable-j-22) - JICA 2022 version
- [unvt/kagero](https://github.com/unvt/kagero) - Power monitoring tool
- [unvt/yata](https://github.com/unvt/yata) - Solar power supply
- [Martin](https://martin.maplibre.org/) - Blazing fast and lightweight tile server
- [Caddy](https://caddyserver.com/) - Fast and extensible multi-platform web server

## License

This project is released under the CC0 1.0 Universal license, dedicating it to the public domain. See [LICENSE](LICENSE) for details.

## Acknowledgments

niroku is developed as part of the UNVT project to support disaster response and field operations worldwide, with special focus on JICA Knowledge Co-creation Programs.
