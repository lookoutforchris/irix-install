# Implementation Plan

## Summary

Replace the abandoned `dexter1/irix-install:latest` dependency with a locally owned, documented Docker image for SGI IRIX network installs. Preserve compatibility first: keep the BOOTP, xinetd, RSH, `.rhosts`, and install-media service model, modernize the base image to Debian Bookworm slim, and replace old Debian `tftpd` with `tftpd-hpa`.

Primary deployment target is Linux Docker, with Synology/Galaxy as the first supported environment.

Implementation status: image source, compose changes, startup `.rhosts` generation, archive, and project documentation have been added. Runtime build/start verification still requires the Galaxy root shell.

## Steps

1. Preserve the current state.
   - Keep `archives/2026-06-13-pre-modernization.tar.gz`.
   - Do not include install media in archives, git, image layers, or Docker build context.

2. Add a maintained image build.
   - Create a `Dockerfile` based on `debian:bookworm-slim`.
   - Install `bootp`, `mksh`, `rsh-redone-server`, `tftpd-hpa`, and `xinetd`.
   - Create `guest`.
   - Set root and guest shells to `/bin/mksh`.
   - Preserve passwordless root/guest compatibility unless live testing proves it unnecessary.

3. Bake static service config into the image.
   - Add xinetd service files for `bootps`, `tftp`, and `shell`.
   - Keep `bootpd` args as `-i -t0 -d4 /etc/bootptab`.
   - Keep TFTP args as `-s /home/guest/irix`.
   - Keep RSH service as `/usr/sbin/in.rshd`.

4. Add startup generation.
   - Add an entrypoint script that parses client hostnames from `/etc/bootptab`.
   - Generate `/root/.rhosts` and `/home/guest/.rhosts` with `<hostname> root`.
   - Start `/usr/sbin/xinetd -dontfork`.

5. Simplify compose.
   - Build/use the local image instead of `dexter1/irix-install:latest`.
   - Remove the `config/xinetd.d` mount from normal deployment.
   - Keep mounts for `config/bootptab`, `config/hosts`, and `dist`.
   - Keep external `macvlan` and static IP `192.168.0.9` for the first local deployment.

6. Add build hygiene.
   - Add `.dockerignore`.
   - Exclude `irix/`, legacy `dist/`, `archives/`, Synology `@eaDir`, and temporary files.

7. Verify on Galaxy.
   - Build with host networking if APT requires it.
   - Validate compose.
   - Start the container.
   - Verify IP, mounts, xinetd, service listeners, and generated `.rhosts`.
   - Test with real SGI hardware before removing rollback options.

## Relevant Files

- `Dockerfile` - maintained image definition.
- `docker-compose.yml` - local deployment.
- `config/bootptab` - SGI BOOTP clients.
- `config/hosts` - server/client host mappings.
- `docker/xinetd.d/` or similar - source xinetd service files baked into the image.
- `docker/entrypoint.sh` - generates `.rhosts` and starts xinetd.
- `.dockerignore` - keeps install media and local archives out of build context.

## Verification

Use root shell on Galaxy.

```sh
cd /volume1/docker/irix-install
/usr/local/bin/docker-compose config
```

Build/package checks may require host networking:

```sh
/usr/local/bin/docker build --network host -t irix-install:local .
```

Runtime checks should confirm:

- `irix-install` is running.
- container IP is `192.168.0.9`.
- `/home/guest/irix` is read-only.
- `xinetd -dontfork` is running as PID 1.
- BOOTP, TFTP, and RSH services are loaded.
- `.rhosts` contains each configured BOOTP hostname followed by `root`.

## Decisions

- Linux-only runtime support.
- Debian Bookworm slim for first maintained image.
- Keep macvlan as recommended deployment mode.
- Keep insecure legacy RSH compatibility, but document it clearly.
- Do not include install media in any project-generated artifact.
