# niroku

**niroku** — a pipe‑to‑shell installer to quickly install JUMP26 on Raspberry Pi OS (trixie)

## Overview

**niroku** is a streamlined installer script that helps you quickly set up **JUMP26** (JICA UNVT Module Portable 26) on Raspberry Pi OS (trixie). It automates the installation of [UNVT Portable](https://github.com/unvt/portable), an offline local web map server designed for disaster response and field operations.

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
2. ✅ Install dependencies (Apache, Node.js, Python, git, etc.)
3. ✅ Clone the UNVT Portable repository to `/opt/unvt-portable`
4. ✅ Set up Node.js and Python dependencies
5. ✅ Configure Apache web server
6. ✅ Install tools for WiFi AP and QR code generation

## Post-Installation Steps

After installation completes:

1. **Access the web interface**:
   ```bash
   # Find your Raspberry Pi's IP address
   hostname -I
   
   # Access via web browser at:
   # http://[YOUR_IP_ADDRESS]
   ```

2. **Add your map data**:
   - Place tile data in `/var/www/html`
   - Follow the [UNVT Portable documentation](https://github.com/unvt/portable/wiki)

3. **Configure WiFi Access Point** (optional):
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

### Apache doesn't start
```bash
# Check Apache status
sudo systemctl status apache2

# View logs
sudo journalctl -u apache2 -n 50
```

### Port 80 already in use
```bash
# Check what's using port 80
sudo lsof -i :80

# Stop conflicting service if needed
sudo systemctl stop [service-name]
```

## Development and Contributing

This project is part of the [UNVT (United Nations Vector Tile Toolkit)](https://github.com/unvt) ecosystem.

- **Repository**: https://github.com/unvt/niroku
- **Issues**: https://github.com/unvt/niroku/issues
- **License**: CC0 1.0 Universal (Public Domain)

## Related Projects

- [unvt/portable](https://github.com/unvt/portable) - Main UNVT Portable repository
- [unvt/portable-j-22](https://github.com/unvt/portable-j-22) - JICA 2022 version
- [unvt/kagero](https://github.com/unvt/kagero) - Power monitoring tool
- [unvt/yata](https://github.com/unvt/yata) - Solar power supply

## License

This project is released under the CC0 1.0 Universal license, dedicating it to the public domain. See [LICENSE](LICENSE) for details.

## Acknowledgments

niroku is developed as part of the UNVT project to support disaster response and field operations worldwide, with special focus on JICA Knowledge Co-creation Programs.
