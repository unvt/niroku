# Copilot Instructions

## Core Rules

- **Symmetry**: install.sh and uninstall.sh must be symmetric. When you change one, you must also change the other.
- **Simple English**: All code and documentation must use English that is easy for non-native English speakers to understand.

## Architecture Support

- **Multi-architecture**: Support both arm64 (Pi 4/400) and armv6l (Pi Zero W)
- **Architecture detection**: Always detect architecture using `uname -m` and `dpkg --print-architecture`
- **Compatibility flags**: Use `MARTIN_SUPPORTED` and `DOCKER_SUPPORTED` flags to skip incompatible components on armv6l
- **Clear warnings**: When skipping components, provide clear warnings with workarounds or alternatives
 - **Service layout**: Run Martin on `127.0.0.1:3000` behind Caddy on `:8080`; enable Martin Web UI for all users

## Installation Patterns

- **Default behavior**: Default to overwrite existing installations. Use `NIROKU_KEEP_EXISTING=1` to preserve existing files.
- **Non-interactive mode**: Always use `DEBIAN_FRONTEND=noninteractive` and `apt-get install -y -qq` for non-interactive installations
- **GPG operations**: Use `gpg --batch --yes` flags to suppress prompts in non-interactive environments
- **Package removal**: Before reinstalling, always remove existing keys/files to avoid conflicts (e.g., `rm -f /etc/apt/keyrings/*.gpg`)

## Reverse Proxy and URL Generation

- **Martin base path**: Always configure `base_path: /martin` in `martin.yml` so TileJSON URLs include the `/martin` prefix.
	- Do not use `public_url` or `base_url` (not supported for this purpose).
- **Caddy proxy**: Strip the `/martin` prefix and proxy to `localhost:3000`.
	- Pass upstream headers: `X-Forwarded-Proto`, `X-Forwarded-Host`, `X-Forwarded-Port`, and `Host`.
	- `X-Forwarded-Prefix` is optional and not used by Martin when `base_path` is set.
	- Only use `X-Rewrite-URL` if you do not set `base_path` (not recommended here).
 - **Verification**: After install, `curl http://<host>:8080/martin/<source> | jq '.tiles[0]'` should include `/martin/` in the URL.

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
- `PM11=1`: Enable optional PM11 download and viewer setup
- `NIROKU_MIRROR_ASSETS=1|0`: Mirror Protomaps assets (fonts & sprites). Defaults to `1` when `PM11=1` unless explicitly set.
- `NIROKU_MIRROR_FONTS=1|0`: Alias that enables the same mirroring behavior (treated as assets toggle when set).

## PM11 and Assets (Fonts & Sprites)

- **Defaults**: When `PM11=1`, default to `NIROKU_MIRROR_ASSETS=1` unless the user explicitly sets a value.
- **Mirroring**: Clone `protomaps/basemaps-assets` and place:
	- Fonts (PBF) into `/opt/niroku/data/fonts`
	- Sprites (v4) into `/opt/niroku/data/sprites`
- **Style rewrite**: For the PM11 viewer `style.json`, always:
	- Set `sources.protomaps.url` to `/martin/pm11`
	- Set `glyphs` to `/fonts/{fontstack}/{range}.pbf` when local fonts exist, otherwise use Protomaps remote URL
	- Set `sprite` to `/sprites/v4/light` when local sprites exist, otherwise use Protomaps remote URL
	- Use `localIdeographFontFamily` on the client for CJK ideographs
- **Service reload**: After downloading `pm11.pmtiles`, restart Martin so it re-scans `/opt/niroku/data`.
- **Uninstall symmetry**: Ensure mirrored fonts/sprites and PM11 viewer are removed in `uninstall.sh` with clear logs.

## Testing

- **Test devices**: m333.local (Pi 4/400, arm64), m0.local (Pi Zero W, armv6l)
- **Test credentials**: niroku/niroku (do not hard-code in production)
- **expect wrappers**: Use expect for automated testing with ssh/scp
- **Smoke tests**: Verify Caddy responds, Martin UI accessible, services active
	- Additionally verify TileJSON prefix: `/martin` appears in `.tiles` URLs for served sources