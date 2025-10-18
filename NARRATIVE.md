# NARRATIVE

This document explains the ideas behind niroku and the history of this project.

## Why niroku exists

Making web maps available to everyone is no longer rocket science. The UN Maps platform is established, and many tools we use in the UNVT (UN Vector Tile Toolkit) ecosystem are maintained by strong open‑source communities.

Open‑source software brings value to different groups:

- For developers: freedom and programmer happiness — making programming enjoyable
- For procurement officials: fairness and transparency
- For everyone else: ease of access and learning

The UN Smart Maps Group promotes developers' freedom and happiness through community connections and mutual respect. We keep web maps open, experiment with new technologies, and practice software freedom — the freedom to run, study, modify, and redistribute software.

We define Smart Maps as applying modern web‑mapping technologies for information‑based decision‑making.

## Generative AI: agents and companions

We use generative AI in two ways:

- As agents that present information as Smart Maps
- As companions in everyday development work

As companions, AIs are not adversaries. We do not scold them, publicly attack them, or treat them as enemies. Errors made by our AI companions are our errors too. We accept these errors, and we fix them together. This is our culture.

In this niroku project, generative AI coded the scripts and the markdown files, with help from human members. 

## The portable web

We focus on the portable web so people can use and learn Smart Maps in constrained or unstable environments. Our goal is to make technologies used by full‑scale web map servers run smoothly on single‑board computers (SBCs) such as the Raspberry Pi 4B.

After experiments with object storage and the InterPlanetary File System (IPFS), we showed that tunneling technologies can deliver web maps at practical speeds for small groups, even from a home network.

We value the command‑line interface (CLI) and embrace Unix and web cultures.

## How niroku fits in

niroku is a small installer that brings together Caddy (web server) and Martin (tile server) with useful tools for field use. It focuses on:

- Simple setup with one script
- Running reliably on Raspberry Pi OS (trixie)
- Serving PMTiles and static files locally
- Using secure, verifiable package sources where practical
- Being easy to review and modify

niroku installs web map data production tools such as tippecanoe, go-pmtiles, gdal-bin. See README.md for details. 

## History (short)

- 2022–2024: UNVT Portable and related tools matured in the community
- 2025 (early): We started niroku as a simpler, focused installer for Raspberry Pi OS (trixie)
- 2025 (spring): We adopted a security‑aware approach (verified repositories, minimal changes) and added practical tools like Docker, Node.js, and cloudflared
- 2025 (summer): We enhanced reliability with robust download handling, fallback paths for temporary directories, and comprehensive logging
- 2025 (fall): We tested end-to-end on real Raspberry Pi hardware (Pi 4, Pi 400, Pi Zero W) to ensure all components work together reliably
- 2025 (October): Added architecture detection for arm64/armv6l, npm package caching with @latest tags, improved GPG operations for non-interactive mode, and default overwrite installation behavior

## Principles

- Keep things simple and understandable
- Respect the constraints of our users (power, connectivity, hardware)
- Use generative AI responsibly as companions
- Errors are common, and shared; we fix them together

## What is next

- Improve documentation that is easy to understand
- Make installation faster and safer when possible

## What this project does

niroku provides a small, auditable installer to set up a local web map server on Raspberry Pi OS (trixie). Concretely, it:

- Installs and configures Caddy (web server) and Martin (PMTiles server)
- Prepares a data directory for PMTiles and static assets
- Adds useful tools for field work: Node.js (LTS v22) + Vite, Docker Engine (CE), cloudflared (Cloudflare Tunnel), tippecanoe (vector tile tool), go‑pmtiles (PMTiles CLI)
- Adjusts Raspberry Pi OS defaults that affect reliability (e.g., /tmp tmpfs handling)
- Runs everything as systemd services with clear logs and restart policies
- Uses robust download mechanisms with multiple candidate URLs and fallback paths
- Generates detailed installation logs for troubleshooting (`/tmp/niroku_install.log`)
- Cleans up legacy repository configurations automatically

The focus is reliability, clarity, and ease of review.

## How we develop

We follow a simple and transparent workflow:

1. Keep edits small and easy to review
2. Prefer readable shell over clever shell
3. Use symmetry: anything installed by install.sh must be removable by uninstall.sh
4. Write documentation in easy English for non‑native speakers
5. Respect security: prefer verified repositories and signatures where practical
6. Test on Raspberry Pi devices when possible
7. Handle errors gracefully: provide fallback paths, multiple download candidates, and clear error messages
8. Log everything: installation and uninstallation logs help with remote troubleshooting

Our companion AI helps with edits, checks, and remote tests. We do not shift blame to the AI; errors are shared and fixed together.

### Testing and operations

- We first run light, non‑destructive checks (e.g., /tmp state, apt status)
- We then run install.sh, confirm services are active, and check logs
- We exercise the web endpoints (Caddy and Martin) locally on the device
- We verify all installed tools work correctly (node, docker, cloudflared, tippecanoe, pmtiles)
- Finally, we run uninstall.sh and verify that the system returns to a clean state

### Lessons learned

Through real-world testing, we discovered and fixed several issues:

- **Temporary directory handling**: Some Raspberry Pi setups mount /tmp as tmpfs, which can fill up quickly. We now detect this, offer to disable it, and use /var/tmp as a fallback for large downloads.
- **Repository cleanup**: Old or incompatible apt repository configurations (e.g., cloudflared for trixie) can cause update failures. The installer now cleans these up automatically.
- **Non-interactive installation**: GPG key operations can prompt for confirmation in non-interactive environments. We now use `gpg --batch --yes` flags to suppress prompts and remove existing keys before re-importing them.
- **Download robustness**: Binary releases may be available in different variants (gnu vs musl libc). We try multiple candidate URLs and verify file sizes before proceeding.
- **cloudflared installation**: The cloudflared apt repository does not support Debian trixie yet. We switched to downloading the official .deb package directly from GitHub releases, which is the recommended approach per Cloudflare's documentation.
- **Architecture detection**: Raspberry Pi Zero W (armv6l) requires different handling than Pi 4 (arm64). Martin and Docker are not available as prebuilt binaries for armv6l. We detect the architecture and skip incompatible components with clear warnings.
- **npm package versioning**: Using `npm install -g package` without version tags can install old cached versions. We now explicitly use `@latest` tags (`vite@latest`, `maplibre-gl@latest`, `pmtiles@latest`) and pre-uninstall old versions before reinstalling.
- **Installation defaults**: Requiring environment variables to overwrite existing installations was counterintuitive for testing. We inverted the logic: default to overwrite, use `NIROKU_KEEP_EXISTING=1` to preserve existing files.
- **Building on low-power devices**: Pi Zero W has limited RAM and slow CPU. Building Martin from source requires disabling /tmp tmpfs (to avoid "No space left" errors) and using `--jobs 1` to limit memory usage. Build time: 4-6 hours.

These improvements make niroku more reliable in real field deployments across different Raspberry Pi models.
