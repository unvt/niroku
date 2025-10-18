# NARRATIVE

This document explains the ideas behind niroku and the history of this project. It is written in simple English so it is easy to understand.

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

## History (short)

- 2022–2024: UNVT Portable and related tools matured in the community
- 2025: We started niroku as a simpler, focused installer for Raspberry Pi OS
- 2025: We adopted a security‑aware approach (verified repositories, minimal changes) and added optional tools like Docker and cloudflared

## Principles

- Keep things simple and understandable
- Prefer open standards and open‑source tools
- Respect the constraints of our users (power, connectivity, hardware)
- Use generative AI responsibly as agents and as companions
- Errors are shared; we fix them together

## What is next

- Improve documentation that is easy to understand
- Make installation faster and safer when possible
- Add small, practical examples to help learning
- Keep the project aligned with the UN Smart Maps Group vision

## What this project does

niroku provides a small, auditable installer to set up a local web map server on Raspberry Pi OS (trixie). Concretely, it:

- Installs and configures Caddy (web server) and Martin (PMTiles server)
- Prepares a data directory for PMTiles and static assets
- Adds useful tools for field work: Node.js (LTS) + Vite, Docker, cloudflared, tippecanoe, go‑pmtiles
- Adjusts Raspberry Pi OS defaults that affect reliability (e.g., /tmp tmpfs)
- Runs everything as systemd services with clear logs and restart policies

The focus is reliability, clarity, and ease of review.

## How we develop

We follow a simple and transparent workflow:

1. Keep edits small and easy to review
2. Prefer readable shell over clever shell
3. Use symmetry: anything installed by install.sh must be removable by uninstall.sh
4. Write documentation in easy English for non‑native speakers
5. Respect security: prefer verified repositories and signatures where practical
6. Test on real Raspberry Pi devices when possible

Our companion AI helps with edits, checks, and remote tests. We do not shift blame to the AI; errors are shared and fixed together.

### Testing and operations

- We first run light, non‑destructive checks (e.g., /tmp state, apt status)
- We then run install.sh, confirm services are active, and check logs
- We exercise the web endpoints (Caddy and Martin) locally on the device
- Finally, we run uninstall.sh and verify that the system returns to a clean state
