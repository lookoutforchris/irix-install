# IRIX Install Server

Docker-based install server for SGI IRIX network installs.

This project was modernized from the abandoned `dexter1/irix-install` image into a locally owned, documented container. The compatibility target is real SGI hardware using legacy BOOTP, TFTP, and RSH install workflows.

## Supported Deployment

Primary target:

- Linux Docker host
- External `macvlan` network
- Static LAN IP for the install server container
- Read-only `/home/guest/irix` mount containing IRIX install media

Windows Docker Desktop is not a supported runtime target for real SGI LAN installs. It may be useful for limited image development only.

## Example Deployment

Example server identity:

- Hostname: `irix-install`
- IP address: `192.168.0.9`
- Docker network: external `macvlan`

Example SGI client:

- `octane` at `192.168.0.10`
- Example BOOTP MAC: `08:00:69:c0:ff:ee`

## Important Paths

- `docker-compose.yml` - current deployment definition.
- `config/bootptab` - BOOTP client definitions.
- `config/hosts` - install server and SGI client hostname mappings.
- `config/bootptab.example` - sanitized BOOTP example.
- `config/hosts.example` - sanitized hosts example.
- `irix/` - IRIX install media mounted as `/home/guest/irix:ro`.
- `docs/` - project notes, operations, and client configuration documentation.
- `archives/` - local project-state archives that intentionally exclude install media.
- `Dockerfile` - maintained Debian Bookworm image build.
- `docker/entrypoint.sh` - generates `.rhosts` and starts `xinetd`.
- `docker/xinetd.d/` - BOOTP, TFTP, and RSH xinetd services baked into the image.

## Build and Run

On Galaxy, use the root shell for Docker operations:

```sh
cd /volume1/docker/irix-install
/usr/local/bin/docker-compose build
/usr/local/bin/docker-compose up -d
```

Galaxy may require host networking for package downloads during image builds. The compose file sets `build.network: host` for that reason.

Validate the resolved compose configuration:

```sh
/usr/local/bin/docker-compose config
```

For a fresh checkout, create local config files first:

```sh
cp config/bootptab.example config/bootptab
cp config/hosts.example config/hosts
```

Then edit both files for your SGI hardware and LAN, and place your install media under `irix/`.

## Configuration Model

Each SGI client needs:

- a hostname
- a MAC address in `bootptab`
- an IP-to-hostname mapping in `hosts`

Example `bootptab` entry:

```text
octane:ha=080069c0ffee:sa=192.168.0.9:ds=192.168.0.9:rp=/home/guest/irix
```

The fields `sa` and `ds` point to the install server. They are not the SGI client IP. The client IP is resolved by hostname through `/etc/hosts` or an equivalent explicit BOOTP configuration.

The media-relative path stays consistent between PROM/TFTP and `inst`/RSH:

```text
PROM: bootp():6530/stand/sash64 -x
inst: guest@192.168.0.9:irix/6530/dist
```

## Install Account

Use `guest` as the server-side account when opening distributions from IRIX `inst`.

The SGI target connects as its local `root` user, but it should log in to the container's `guest` account to read install media. The container generates `/home/guest/.rhosts` entries from `config/bootptab` so each configured SGI hostname is allowed as remote user `root`.

Example `inst` source format:

```text
guest@192.168.0.9:irix/6530/dist
```

The container also prepares `/root/.rhosts` for compatibility with older workflows, but `guest` is the recommended documented path.

## Safety Warning

This project intentionally runs legacy insecure services for compatibility with old UNIX install workflows. Use only on a trusted LAN or isolated install network.

Do not commit, archive, or bake `irix/` into an image.
