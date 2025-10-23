# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

- (work in progress)

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