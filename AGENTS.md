# AGENTS.md

## Project Purpose

This project maintains a Docker-based SGI IRIX network install server. The goal is to replace the abandoned `dexter1/irix-install` dependency with a locally owned, documented, compatibility-first image.

The install server provides BOOTP, TFTP, and RSH services to real SGI hardware on a trusted LAN. The mounted `dist/` directory contains user-provided IRIX install media and must never be copied into the image, committed, archived by default, or modified by automation.

## Working Rules

- Inspect first, then edit.
- Preserve the current deployment before broad changes.
- Do not remove, move, or overwrite existing deployment files unless explicitly requested.
- Keep implementation Linux-only unless the user changes that decision.
- Treat Galaxy/Synology as the first supported runtime target.
- Prefer compatibility and predictable old-UNIX behavior over minimal image size.
- Avoid Alpine for the maintained image; use Debian slim unless there is a proven compatibility reason not to.
- Do not expose Docker daemon operations as assumptions. The user is the root Docker operator.

## Environment Split

- VS Code/Codex session: planning, review, documentation, and small targeted file work.
- Galaxy-local shell or Codex CLI: preferred for larger file edits and builds because UNC paths can be slow or unreliable.
- User root shell on Galaxy: Docker daemon operations, container start/stop, build/run verification, and network inspection.

When debugging Docker or runtime behavior, give one command at a time and wait for output.

## Example Runtime Model

- Maintained image: `irix-install:local`
- Example server hostname: `irix-install`
- Example server IP: `192.168.0.9`
- Example network: external Docker `macvlan`
- Mounted media path: `./dist` to `/DIST:ro`
- User config:
  - `config/bootptab`
  - `config/hosts`

Local deployments may use different hostnames, IPs, and paths.

## Modernization Direction

- Base image: `debian:bookworm-slim`
- Packages:
  - `bootp`
  - `mksh`
  - `rsh-redone-server`
  - `tftpd-hpa`
  - `xinetd`
- Keep `xinetd` as PID 1 with `-d -dontfork`.
- Bake BOOTP, TFTP, and RSH xinetd service definitions into the image.
- Mount only user-specific config and `/DIST`.
- Generate `.rhosts` from configured BOOTP client hostnames at startup.

## Safety Notes

This project intentionally uses insecure legacy services. RSH, passwordless users, and `.rhosts` trust may be required for IRIX install compatibility. These services must only be run on a trusted isolated LAN or equivalent controlled network segment.

`dist/` may contain licensed or sensitive install media. Never include it in archives, git history, Docker build context, or generated images.
