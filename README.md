# niroku

niroku — a pipe‑to‑shell installer to quickly install JUMP26 on Raspberry Pi OS (trixie)

## Installation

### Preview the installer script

Before running the installer, you can preview its contents:

```bash
curl -fsSL https://unvt.github.io/niroku/install.sh | less
```

### Run the installer

To install niroku and its dependencies:

```bash
curl -fsSL https://unvt.github.io/niroku/install.sh | sudo -E bash -
```

**Note:** This script requires root privileges and will:
1. Update the system package lists
2. Upgrade existing packages
3. Install base packages: `aria2`, `btop`, `gdal-bin`, `git`, `jq`, `ruby`, `tmux`, `vim`

The script will ask for confirmation before making changes.

## What gets installed

The base installation includes:
- **aria2** - Download utility with support for multiple protocols
- **btop** - Resource monitor
- **gdal-bin** - Geospatial data abstraction library tools
- **git** - Version control system
- **jq** - Command-line JSON processor
- **ruby** - Programming language
- **tmux** - Terminal multiplexer
- **vim** - Text editor

Additional tools (docker, node, tippecanoe, caddy, martin, etc.) will be added in future updates.

## License

CC0 1.0 Universal - See [LICENSE](LICENSE) for details.
