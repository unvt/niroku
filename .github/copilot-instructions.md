# Copilot Instructions

## Core Rules

- **Symmetry**: install.sh and uninstall.sh must be symmetric. When you change one, you must also change the other.
- **Simple English**: All code and documentation must use English that is easy for non-native English speakers to understand.

## Architecture Support

- **Multi-architecture**: Support both arm64 (Pi 4/400) and armv6l (Pi Zero W)
- **Architecture detection**: Always detect architecture using `uname -m` and `dpkg --print-architecture`
- **Compatibility flags**: Use `MARTIN_SUPPORTED` and `DOCKER_SUPPORTED` flags to skip incompatible components on armv6l
- **Clear warnings**: When skipping components, provide clear warnings with workarounds or alternatives

## Installation Patterns

- **Default behavior**: Default to overwrite existing installations. Use `NIROKU_KEEP_EXISTING=1` to preserve existing files.
- **Non-interactive mode**: Always use `DEBIAN_FRONTEND=noninteractive` and `apt-get install -y -qq` for non-interactive installations
- **GPG operations**: Use `gpg --batch --yes` flags to suppress prompts in non-interactive environments
- **Package removal**: Before reinstalling, always remove existing keys/files to avoid conflicts (e.g., `rm -f /etc/apt/keyrings/*.gpg`)

## Package Management

- **npm packages**: Always use `@latest` tags explicitly (`vite@latest`, `maplibre-gl@latest`, `pmtiles@latest`)
- **Pre-cleanup**: Uninstall old versions before installing new ones to avoid version conflicts
- **Package detection**: Use `dpkg -l package 2>/dev/null | grep -q "^ii"` pattern (no spacing dependencies)

## Resource Constraints

- **Low-memory builds**: On Pi Zero, use `--jobs 1` for cargo builds to limit memory usage
- **tmpfs handling**: Disable /tmp tmpfs on Pi Zero to avoid "No space left" errors during builds
- **Build time**: Expect 4-6 hours for Martin source builds on Pi Zero W

## Logging and Debugging

- **Installation logs**: Always write to `/tmp/niroku_install.log` for troubleshooting
- **Uninstallation logs**: Always write to `/tmp/niroku_uninstall.log` for troubleshooting
- **Service status**: Check systemd service status after installation/configuration

## Environment Variables

- `NIROKU_FORCE_OS=1`: Skip OS compatibility checks
- `NIROKU_KEEP_EXISTING=1`: Keep existing installation (default is to overwrite)

## Testing

- **Test devices**: m333.local (Pi 4/400, arm64), m0.local (Pi Zero W, armv6l)
- **Test credentials**: niroku/niroku (do not hard-code in production)
- **expect wrappers**: Use expect for automated testing with ssh/scp
- **Smoke tests**: Verify Caddy responds, Martin UI accessible, services active