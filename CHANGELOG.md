# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

- Change: Caddy now listens on port 80 (was 8080). Installer generates a Caddyfile with `:80` and runs `caddy-niroku` as root to allow binding to privileged port. README updated to remove `:8080` URLs.

## [0.1.2] - 2025-11-01

### Added (0.1.2)

- PM11 viewer improvements: interactive viewer template now includes URL hash synchronization (`hash: true`) and a ScaleControl (metric) for clearer units.
- PM11 smoke tests: installer now runs quick post-install checks for `style.json` and sprite endpoints and logs results to help diagnose missing assets.

### Changed (0.1.2)

- PM11 style.json rewrite is more robust: the installer rewrites `sources.protomaps.url` → `/martin/pm11`, prefers local glyphs when `/opt/niroku/data/fonts` exists, and only switches to a local sprite when `sprites/v4/light.json` and `light.png` are present.
- GlobeControl placement: when available, the viewer adds GlobeControl in the upper-right (`top-right`). GeolocateControl is omitted on HTTP builds (must be enabled on HTTPS/localhost as needed).

### Fixed (0.1.2)

- Robust sprite mirroring: installer now ensures `sprites/v4` is placed correctly, attempts to download missing `light.json`/`light.png` during install when mirroring is enabled, and creates a `light@2x.png` fallback when needed.
- PM11 build reliability: the installer validates and recreates a correct `package.json` before running `npm install` to avoid EJSONPARSE errors from corrupted heredocs or stale temps.
- Client-side style handling: viewer now fetches `style.json` and converts root-relative sprite/glyphs/source URLs to absolute URLs before applying the style to prevent "Invalid sprite URL" errors.

## [Unreleased]
## [0.1.1] - 2025-10-31

### Changed (0.1.1)

- Martin configuration now uses `base_path: /martin` to ensure TileJSON URLs include the `/martin` prefix when running behind Caddy.
- Removed the unused `public_url`/`base_url` approach from the installer; simplified to documented `base_path` behavior.
- Caddy reverse proxy configuration clarifies upstream headers forwarded to Martin: `X-Forwarded-Proto`, `X-Forwarded-Host`, `X-Forwarded-Port`, and `Host`.

### Added (0.1.1)

- Documentation updates in README and contributor instructions for:
  - Reverse proxy layout and URL prefix verification steps.
  - PM11 defaults: when `PM11=1`, `NIROKU_MIRROR_ASSETS` defaults to `1` unless explicitly set.
  - PM11 style rewrite rules: `sources.protomaps.url` → `/martin/pm11`, local glyph/sprite fallbacks.

### Fixed (0.1.1)

- TileJSON `.tiles` URLs missing `/martin` in some setups; using `base_path` makes the prefix deterministic and proxy‑agnostic.

## [0.1.0] - 2025-10-19

### Added

- Refactor: `try_download()` helper to centralize robust downloads with multiple candidate URLs.

- Refactor: `create_systemd_service()` helper to centralize systemd unit creation, enable and start logic.

- Refactor: `uninstall.sh` made symmetric to `install.sh` with `remove_*` helpers (`remove_martin`, `remove_caddy`, `remove_go_pmtiles`).

- Feature: lightweight post-install smoke checks to validate service status and basic HTTP response.

- Docs: `README.md` updated with release notes and Pi Zero (armv6l) compatibility guidance.

### Changed

- Improved logging and error reporting in install/uninstall scripts.

### Fixed

- Ensure helper functions are defined before use during script execution.

### Notes

- A cycle test (uninstall → install) was executed on device `m333` (Raspberry Pi 400 / aarch64) for verification. Logs are stored on-device at `/tmp/niroku_install.log` and `/tmp/niroku_uninstall.log`.

- Raspberry Pi Zero W (armv6l) remains supported but requires building Martin from source; Docker CE is not officially supported on armv6l.
<!--
To add new entries, append under [Unreleased] and copy to a new version section when releasing.
-->