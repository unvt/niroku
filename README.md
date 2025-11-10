# niroku

**niroku** — a new implementation of UNVT Portable with JICA, for 2026 (Raspberry Pi OS trixie)

[NARRATIVE](NARRATIVE.md)

## Overview

**niroku** is a new implementation of UNVT Portable. It is co‑developed with JICA Quick Mapping Project and targeted for 2026 use. niroku sets up an offline local web map server on Raspberry Pi OS (trixie). It uses **Caddy** (reverse proxy) and **Martin** (PMTiles tile server). It is designed for field operations where power and connectivity can be unstable.

## Quick Installation

### One-line Install (Pipe to Shell)

The simplest way to install niroku:

```bash
curl -fsSL https://unvt.github.io/niroku/install.sh | sudo -E bash -
```

Or using wget:

```bash
wget -qO- https://unvt.github.io/niroku/install.sh | sudo -E bash -
```

### Manual Installation

If you prefer to review the script before running:

```bash
# Download the script
curl -fsSL https://unvt.github.io/niroku/install.sh -o install.sh

# Review the script
less install.sh

# Make it executable
chmod +x install.sh

# Run the installer
sudo ./install.sh
```

## Architecture

niroku follows the proven [x-24b architecture](https://github.com/unvt/x-24b):

```text
Web Browser ←→ Caddy (Reverse Proxy) ←→ Martin (PMTiles Server)
```

- **Caddy**: Handles HTTP serving, CORS, and reverse proxying
- **Martin**: Serves PMTiles vector tiles with high performance
- **systemd services**: Both run as system services with automatic restart

## What is niroku?

niroku is the next iteration of UNVT Portable. Compared to earlier versions, it:

- Focuses on a simpler, auditable install process
- Adds practical tools (Node.js+Vite, Docker, cloudflared, tippecanoe, go‑pmtiles)
- Improves defaults for Raspberry Pi OS trixie (e.g., /tmp tmpfs handling)
- Keeps architecture minimal: **Caddy** + **Martin**

What you get:

- **Local web map server** running on Raspberry Pi
- **Local network access** to geospatial data without internet
- **Simple setup** using one script
- **Caddy + Martin** based architecture

## System Requirements

- **Hardware**:
  - Raspberry Pi 4 or later (recommended, full feature support)
  - Raspberry Pi Zero W (supported, Martin requires source build)
- **Architecture**: arm64/aarch64, armv6l (32-bit)
- **OS**: Raspberry Pi OS (Debian trixie or compatible)
- **Storage**: Minimum 16GB microSD card (128GB+ recommended for map data)
- **Network**: Ethernet or WiFi connectivity for initial setup
- **Permissions**: Root/sudo access required

### Architecture-Specific Notes

- **Raspberry Pi 4/400 (arm64)**: Full support with prebuilt binaries for all components
- **Raspberry Pi Zero W (armv6l)**:
  - Martin tile server not available as prebuilt binary (requires source build with Rust)
  - Docker CE not officially supported (alternative container runtimes may work)
  - All other components install normally

## What Gets Installed

The niroku installer will:

1. ✅ **Update system packages** and clean up legacy repositories
2. ✅ **Install base tools**: `aria2`, `btop`, `gdal-bin`, `libgdal-dev`, `git`, `jq`, `ruby`, `tmux`, `vim`
3. ✅ **Install dependencies**: `curl`, `wget`, `hostapd`, `dnsmasq`, `qrencode`, build tools, and related packages
4. ✅ **Detect architecture** and set compatibility flags for arm64/armv6l
5. ✅ **Install Caddy** web server (v2.10.2, reverse proxy with CORS support)
6. ✅ **Install Martin** tile server (v0.19.3, PMTiles hosting with web UI, skipped on armv6l)
7. ✅ **Install Node.js LTS** (v22) via NodeSource and **npm packages** (`vite@latest`, `maplibre-gl@latest`, `pmtiles@latest`)
8. ✅ **Install Docker Engine** (CE 28.5.1) from official Docker repository (skipped on armv6l)
9. ✅ **Install cloudflared** (2025.10.0) for Cloudflare Tunnel support
10. ✅ **Install tippecanoe** (vector tile tool, from Debian repo or built from source)
11. ✅ **Install go-pmtiles** (PMTiles CLI tool, v1.18.0)
12. ✅ **Create installation directory** at `/opt/niroku` with data subdirectory
13. ✅ **Configure services**: Both Caddy and Martin run as systemd services with automatic restart
14. ✅ **Set up configurations**: `martin.yml` (PMTiles paths, web UI, base_path: `/martin`) and `Caddyfile` (reverse proxy, CORS; forwards `X-Forwarded-Proto`, `X-Forwarded-Host`, `X-Forwarded-Port`, and `Host`)
15. ✅ **Disable /tmp tmpfs** if present (prevents RAM exhaustion on Raspberry Pi)
16. ✅ **Generate installation log** at `/tmp/niroku_install.log` for troubleshooting
17. ✅ **Install PM11 (optional)**: When `PM11=1` is set, downloads pm11.pmtiles (~1.4 GB, 11-country subset) and creates an interactive web viewer accessible at `http://localhost/pm11/`
18. ✅ **Mirror assets (default with PM11)**: When `PM11=1` is set, the installer mirrors Protomaps basemaps assets (fonts and sprites) by default for offline use

## PM11 Feature (Optional)

PM11 is a lightweight planet.pmtiles subset covering 11 countries, created by the [hfu/pm11](https://github.com/hfu/pm11) project. It's useful for testing and demonstrations without downloading the full planet dataset.

### Installing PM11

To install PM11 along with niroku:

```bash
# Install niroku with PM11
sudo PM11=1 ./install.sh

# Or using one-line install
curl -fsSL https://unvt.github.io/niroku/install.sh | sudo -E PM11=1 bash -
```

### Offline assets (fonts and sprites) for PM11

By default, when you enable PM11 (`PM11=1`), niroku mirrors basemaps assets so the viewer can run offline. You can also control this explicitly:

```bash
# Install niroku with PM11 (assets mirroring is ON by default)
sudo PM11=1 ./install.sh

# Disable mirroring explicitly
sudo NIROKU_MIRROR_ASSETS=0 PM11=1 ./install.sh

# Force enable mirroring explicitly
sudo NIROKU_MIRROR_ASSETS=1 PM11=1 ./install.sh

# One-line (with explicit enable)
curl -fsSL https://unvt.github.io/niroku/install.sh | sudo -E NIROKU_MIRROR_ASSETS=1 PM11=1 bash -
```

What this does:

- Clones the Protomaps basemaps assets repo ([protomaps/basemaps-assets](https://github.com/protomaps/basemaps-assets)) and copies:
  - fonts PBFs to `/opt/niroku/data/fonts`
  - sprites (v4) to `/opt/niroku/data/sprites`
- Rewrites the PM11 viewer `style.json` so it prefers local cache:
  - `sources.protomaps.url` → `/martin/pm11`
  - `glyphs` → `/fonts/{fontstack}/{range}.pbf` if local fonts exist, otherwise remote Protomaps URL
  - `sprite` → `/sprites/v4/light` if local sprites exist, otherwise remote Protomaps URL

Notes:

- When `PM11=1` and you did not set any mirroring flags, niroku defaults to `NIROKU_MIRROR_ASSETS=1`.
- Asset mirroring flag is `NIROKU_MIRROR_ASSETS`. For backward compatibility, `NIROKU_MIRROR_FONTS=1` also enables assets mirroring.
- If you set the flag but mirroring fails (e.g., network issue), the installer keeps remote URLs to avoid 404s.
- Uninstaller removes `/opt/niroku/data/fonts` and `/opt/niroku/data/sprites` for symmetry.

### What PM11 Installs

When `PM11=1` is set, the installer will:

1. Download `pm11.pmtiles` (~1.4 GB) from <https://tunnel.optgeo.org/pm11.pmtiles> to `/opt/niroku/data/pm11.pmtiles`
2. Create an interactive map viewer using Vite, MapLibre GL JS, and PMTiles
3. Install the viewer site at `/opt/niroku/data/pm11/`
4. Configure the viewer to use the local `/pm11.pmtiles` file

Notes:

- The download size is approximately 1.4 GB. On slow or metered connections, consider preloading the file or using a wired connection.
- Ensure at least 2 GB of free space on the device for the dataset and viewer.

### Accessing PM11

After installation with PM11:

```bash
# Access the PM11 viewer
http://localhost/pm11/

# Or from another device on the network
http://[YOUR_PI_IP]/pm11/
```

The viewer provides:

- Interactive map with zoom and pan controls
- Vector tile rendering using MapLibre GL JS
- Layers: water, transportation, buildings, and place labels
- Direct PMTiles access without a tile server

### Verifying sprites & viewer (headless)

If you want to verify the PM11 viewer and sprites without opening a browser (useful on headless devices), the repository includes a small check script.

On the device (or where Caddy is serving):

```bash
# Run quick checks against localhost (or pass host as the first arg)
sudo bash /opt/niroku/scripts/check_pm11_sprites.sh
```

The script checks:
- `http://<host>/pm11/style.json` is reachable
- `http://<host>/sprites/v4/light.json` and `light.png` are reachable
- Validates `light.json` is parseable JSON (requires `jq`)

If the script reports failures, inspect `/opt/niroku/data/sprites/v4` and `/opt/niroku/data/pm11/style.json`, and view Caddy logs:

```bash
sudo journalctl -u caddy-niroku -n 200
sudo cat /tmp/niroku_install.log
```

Skip the bundled verification script

If you prefer not to run the bundled PM11 verification script as part of post-install smoke checks, set the environment variable `NIROKU_SKIP_PM11_CHECK=1` when running the installer. This is useful for automated deployments or when you want to postpone checks.

```bash
# Skip the PM11 verification step during install
sudo NIROKU_SKIP_PM11_CHECK=1 ./install.sh

# Or when piping the installer
curl -fsSL https://unvt.github.io/niroku/install.sh | sudo -E NIROKU_SKIP_PM11_CHECK=1 bash -
```

### Removing PM11

PM11 is automatically removed when you run the uninstall script:

```bash
sudo ./uninstall.sh
```

This will remove both `/opt/niroku/data/pm11.pmtiles` and `/opt/niroku/data/pm11/` directory.

## Post-Installation Steps

After installation completes:

1. **Access the web interface**:

```bash
# Find your Raspberry Pi's IP address
hostname -I

# Access via web browser at:
# http://[YOUR_IP_ADDRESS]
# Martin tile server at:
# http://[YOUR_IP_ADDRESS]/martin
```

Verify TileJSON URLs include the `/martin` prefix:

```bash
# Replace [SOURCE] with your PMTiles source name (e.g., pm11)
curl -fsSL http://[YOUR_IP_ADDRESS]/martin/[SOURCE] | jq '.tiles[0]'
# Expected: a URL containing "/martin/", e.g. "http://[YOUR_IP_ADDRESS]/martin/[SOURCE]/{z}/{x}/{y}"
```

1. **Add your map data**:

Place PMTiles files in `/opt/niroku/data`. Martin will automatically detect and serve them.

Access tiles at: `http://[YOUR_IP]/martin/[filename]/{z}/{x}/{y}`

1. **Manage services**:

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

1. **Configure WiFi Access Point** (optional):

- Refer to the [UNVT Portable WiFi setup guide](https://github.com/unvt/portable/wiki)
- Generate QR codes using the installed `qrencode` tool

1. **Use installed tools**:

```bash
# Check installed versions
node --version           # Node.js LTS
npm --version
vite --version
docker --version         # Docker Engine
cloudflared --version    # Cloudflare Tunnel
tippecanoe --version     # Vector tile tool
pmtiles --version        # PMTiles CLI
martin --version         # Tile server
caddy version            # Web server

# Example: Convert GeoJSON to PMTiles
tippecanoe -o output.pmtiles input.geojson

# Example: Inspect PMTiles metadata
pmtiles show /opt/niroku/data/yourfile.pmtiles
```

## Environment Variables

For non-interactive installations (e.g., automated deployments), you can use these environment variables:

```bash
# Skip OS compatibility check
export NIROKU_FORCE_OS=1

# Keep existing installation (default is to overwrite)
export NIROKU_KEEP_EXISTING=1

# Install PM11 (11-country planet.pmtiles subset) and viewer
export PM11=1

# Mirror basemaps assets (fonts + sprites)
# Default: enabled when PM11=1 (set NIROKU_MIRROR_ASSETS=0 to disable)
export NIROKU_MIRROR_ASSETS=1
# Backward-compatible alias (also enables asset mirroring when set to 1)
export NIROKU_MIRROR_FONTS=1

# Example: Full non-interactive install (overwrites existing by default)
sudo NIROKU_FORCE_OS=1 ./install.sh

# Example: Non-interactive install that keeps existing installation
sudo NIROKU_FORCE_OS=1 NIROKU_KEEP_EXISTING=1 ./install.sh

# Example: Install with PM11 feature (mirroring ON by default)
sudo PM11=1 ./install.sh

# Example: Install with PM11 but disable assets mirroring
sudo NIROKU_MIRROR_ASSETS=0 PM11=1 ./install.sh
```

## Reverse Proxy and URL Prefix

- Martin runs behind Caddy at `http://[YOUR_IP]/martin`.
- Martin configuration sets `base_path: /martin` so that TileJSON URLs always include the `/martin` prefix.
- Caddy strips `/martin` and proxies to `127.0.0.1:3000`, forwarding these headers upstream:
      - `X-Forwarded-Proto`, `X-Forwarded-Host`, `X-Forwarded-Port`, and `Host`.
- You do not need `X-Rewrite-URL` because `base_path` is used.
- To verify, fetch a TileJSON and check that `.tiles[0]` includes `/martin/`.

## Security Considerations

⚠️ **Important Security Notes**:

- **Pipe-to-shell pattern**: While convenient, piping scripts to bash can be risky. This installer:
  - Is open source and auditable
  - Uses `set -e` to exit on errors
  - Validates system requirements before making changes
  - Provides colored output for clear progress tracking

- **Review before running**: We encourage reviewing the script before execution
- **Run with sudo**: Required for system-level changes
- **Local network only**: By default, niroku is designed for local network access

## Documentation

- UNVT Portable Wiki: <https://github.com/unvt/portable/wiki>

## Troubleshooting

### Installation fails with permission errors

```bash
# Ensure you're using sudo
sudo ./install.sh
```

### Installation log for debugging

The installer creates a detailed log file for troubleshooting:

```bash
# View installation log
sudo cat /tmp/niroku_install.log

# View uninstallation log
sudo cat /tmp/niroku_uninstall.log
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

### apt-get update fails with repository errors

If you see errors about missing repository files (e.g., legacy cloudflared repository), the installer will automatically clean them up. If issues persist:

```bash
# Manually remove problematic repository files
sudo rm -f /etc/apt/sources.list.d/cloudflared.list
sudo rm -f /etc/apt/keyrings/cloudflare-main.gpg
sudo apt-get update
```

### Building Martin on Raspberry Pi Zero (armv6l)

Martin does not provide prebuilt binaries for armv6l architecture (Raspberry Pi Zero W). If you need Martin on Pi Zero, you must build it from source:

```bash
# Prerequisites: Rust toolchain and build dependencies
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source ~/.cargo/env

# Install build dependencies
sudo apt-get install -y cmake protobuf-compiler libsqlite3-dev libssl-dev build-essential

# Disable /tmp tmpfs to avoid "No space left" errors
sudo systemctl mask tmp.mount
sudo reboot

# Build Martin (takes several hours on Pi Zero)
cargo install martin --locked --jobs 1

# Install the binary
sudo install -m 0755 ~/.cargo/bin/martin /usr/local/bin/martin

# Verify installation
martin --version
```

**Note**: Building Martin on Pi Zero W with `--jobs 1` can take 4-6 hours. Consider building on a faster machine with cross-compilation, or use Pi Zero for Caddy-only setups.

## Offline npm caching

niroku can cache some npm packages during installation so devices with limited or no internet access can still install required frontend packages.

- The installer pre-installs global npm packages using the `@latest` tag for certainty: `vite@latest`, `maplibre-gl@latest`, `pmtiles@latest`.
- If you need to move the npm global cache to an offline device, you can archive the global node_modules and restore it on the target machine. Example workflow:

```bash
# On a machine with internet access (after running install.sh):
sudo tar -C /usr/lib -czf /tmp/npm-global-cache.tar.gz node_modules
sudo chown $USER:$USER /tmp/npm-global-cache.tar.gz

# Copy the archive to the offline device (e.g., via USB or scp)
sudo tar -C /usr/lib -xzf /tmp/npm-global-cache.tar.gz
sudo npm rebuild -g || true
```

Note: Global package paths vary by distribution and Node.js packaging. On Debian-based NodeSource installs, global modules typically live under `/usr/lib/node_modules`.

## Using expect to upload scripts (niroku/niroku)

For automated testing we use `expect` to wrap `scp` and `ssh` so the test harness can authenticate to test devices using the `niroku` user with password `niroku`. Example `expect` one-liners used in testing:

```bash
expect -c 'set timeout 30; spawn scp -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 ./install.sh niroku@m333.local:/var/tmp/install.sh; expect -re {password:}; send "niroku\r"; expect eof'

expect -c 'set timeout 1200; spawn ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 niroku@m333.local "sudo /var/tmp/install.sh"; expect -re {password:}; send "niroku\r"; expect eof'
```

Use these only for temporary testing harnesses. Do not hard-code credentials or expose them in production documentation.

### Port 80 already in use

```bash
# Check what's using port 80
sudo lsof -i :80

# Stop conflicting service if needed
sudo systemctl stop [service-name]

# Or edit the Caddyfile to use a different port
sudo nano /opt/niroku/Caddyfile
sudo systemctl restart caddy-niroku
```

### Martin can't find PMTiles files

```bash
# Ensure files are in the correct directory
ls -la /opt/niroku/data/

# Check file permissions
sudo chmod 644 /opt/niroku/data/*.pmtiles

# Restart Martin
sudo systemctl restart martin
```

### /tmp write errors during installation

The installer automatically falls back to `/var/tmp` if `/tmp` is not writable. If you encounter issues:

```bash
# Check /tmp permissions
ls -ld /tmp

# Should be: drwxrwxrwt (permissions 1777)
sudo chmod 1777 /tmp
```

### Docker installation issues

If Docker fails to install or the GPG key conflicts occur:

```bash
# Remove existing Docker GPG key
sudo rm -f /etc/apt/keyrings/docker.gpg

# Re-run the installer
sudo ./install.sh
```

## Uninstallation

To remove niroku and all installed components:

### Quick Uninstall (Pipe to Shell)

```bash
curl -fsSL https://unvt.github.io/niroku/uninstall.sh | sudo -E bash -
```

### Manual Uninstall (Recommended for Review)

```bash
# Download the uninstall script
curl -fsSL https://unvt.github.io/niroku/uninstall.sh -o uninstall.sh

# Review the script
less uninstall.sh

# Make it executable
chmod +x uninstall.sh

# Run the uninstaller
sudo ./uninstall.sh
```

### What Gets Removed

The uninstaller will:

1. Stop and remove Martin tile server service
2. Stop and remove Caddy-niroku web server service
3. Remove Martin binary from `/usr/local/bin/martin`
4. Remove Caddy package and repository configuration
5. Remove Node.js packages and NodeSource repository

## Release v0.1.0 — 2025-10-19

This release contains a small but important refactor to make the installer and uninstaller more maintainable and more robust in the field.

Highlights

- refactor: add a reusable download helper `try_download()` to centralize robust curl downloads and candidate URL attempts

- refactor: add `create_systemd_service()` helper to centralize systemd unit creation, enable and start logic

- refactor: make `uninstall.sh` symmetric with `install.sh` by adding `remove_*` helpers (e.g. `remove_martin`, `remove_caddy`, `remove_go_pmtiles`) so each install step has a clear uninstall counterpart

- feature: lightweight post-install smoke checks to verify service status and basic HTTP responses

Why this matters

- Reduces duplicated code paths and makes future changes safe and easier to audit

- Better logging and clearer failure points when used in automated test harnesses

Compatibility notes

- Raspberry Pi 4/400 (arm64): Full support — prebuilt binaries are used for Martin and other components

- Raspberry Pi Zero W (armv6l): Limited support — Martin prebuilt binaries are not available and must be built from source on-device (see "Building Martin on Raspberry Pi Zero (armv6l)" in Troubleshooting). Docker CE is also not officially supported on armv6l.

Testing

- A basic cycle test (uninstall -> install) was executed on device `m333` (Raspberry Pi 400 / aarch64) as part of this release verification. Logs are available on the device at `/tmp/niroku_install.log` and `/tmp/niroku_uninstall.log`.

If you depend on automatic deployments or CI, consider running the installer in a VM or test device first and reviewing `/tmp/niroku_install.log` after the run.

## Release v0.1.2 — 2025-11-01

This is a maintenance release focused on PM11 viewer reliability and offline asset handling.

Highlights

- fix: PM11 viewer now synchronizes the map position with the URL hash (`hash: true`) and adds a ScaleControl using metric units for consistent measurements.
- fix: GlobeControl (when available in MapLibre) is placed at the upper-right for consistent UI placement; GeolocateControl is intentionally disabled for non-HTTPS viewers.
- fix: installer now validates and recreates `package.json` before running `npm install` to avoid JSON parse errors during the PM11 build.
- fix: improved sprite mirroring: installer ensures `sprites/v4/light.json` and `light.png` are present, attempts to download missing sprites when mirroring is enabled, and creates a `light@2x.png` fallback when necessary.
- add: PM11 smoke tests run automatically after install to verify `style.json` and sprite endpoints and log the results to `/tmp/niroku_install.log`.

Why this matters

- Reduces visible client-side errors like "Invalid sprite URL" and missing sprite images in the PM11 viewer.
- Makes PM11 installation more resilient on devices with flaky networks or partial mirrors.

Testing

- The full PM11 install flow (download pm11.pmtiles, mirror assets, build viewer) was exercised on `m333` (Raspberry Pi 400 / aarch64). Installation logs live at `/tmp/niroku_install.log` on-device.
6. Remove Docker Engine packages and repository
7. Remove cloudflared package
8. Remove tippecanoe (if installed from source)
9. Remove go-pmtiles binary from `/usr/local/bin/pmtiles`
10. Remove UNVT Portable installation directory (`/opt/niroku`)
11. Remove base packages (`aria2`, `btop`, `gdal-bin`, `libgdal-dev`, `jq`, `ruby`, `tmux`, `vim`)
12. Optionally remove comprehensive packages (you'll be prompted)
13. Clean up unused dependencies
14. Generate uninstallation log at `/tmp/niroku_uninstall.log`

The script will ask for confirmation before removing anything and show you exactly what will be removed.

## Development and Contributing

This project is part of the [UNVT (United Nations Vector Tile Toolkit)](https://github.com/unvt) ecosystem.

- Repository: <https://github.com/unvt/niroku>
- Issues: <https://github.com/unvt/niroku/issues>
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
