# IRIX Install Server

Docker-based install server for SGI IRIX network installs.

This project provides BOOTP, TFTP, and RSH services for installing IRIX on real SGI hardware from a Linux Docker host. It is intended for trusted local networks only.

## Quick Start

This tutorial uses the published container image from GitHub Container Registry. You do not need to build the image yourself.

Example network used below:

- Install server hostname: `cosmos`
- Install server IP: `192.168.0.9`
- SGI client hostname: `octane`
- Domain name:  example.net
- SGI client IP: `192.168.0.10`
- Docker network: external `macvlan`
- IRIX media folder: `./irix`

Change these values for your own LAN/setup.

### 1. Create A Project Folder

On the Linux Docker host, create a folder for the install server:

```sh
mkdir -p irix-install/config irix-install/irix
cd irix-install
```

Download starter files from this repository:

```sh
curl -L -o docker-compose.yml https://raw.githubusercontent.com/lookoutforchris/irix-install/master/docker-compose.release.yml
curl -L -o config/hosts https://raw.githubusercontent.com/lookoutforchris/irix-install/master/config/hosts.example
curl -L -o config/bootptab https://raw.githubusercontent.com/lookoutforchris/irix-install/master/config/bootptab.example
```

You can also create these files manually from the examples below.

The final layout should look like this:

```text
irix-install/
  docker-compose.yml
  config/
    bootptab
    hosts
  irix/
    65/
	  dist/
	    miniroot/
	  firmware/
	  relnotes/
	  stand/
    6530/
	  apps/
	    dist/
		  dev/
	  dist/
	    miniroot/
		unbundled/
      relnotes/
	  stand/
```

Put your IRIX install media under `irix/`. The folder names are your choice; the examples in this README use `6530` for IRIX 6.5.30. I combine all the foundation/base files under irix/65/ and then all the overlays under irix/6522 or irix/6530 and so on. For the handful of common files in an install, I just munge them together. The shorter the path the easier it is to do the installs.

### 2. Create `docker-compose.yml`

Create `docker-compose.yml` with this content:

```yaml
version: "3.8"

services:
  irix-install:
    image: ghcr.io/lookoutforchris/irix-install:0.1.1
    container_name: irix-install
    hostname: cosmos
    tty: true
    stdin_open: true
    environment:
      - TZ=America/New_York
    sysctls:
      net.ipv4.ip_local_port_range: 2048 32767
      net.ipv4.ip_no_pmtu_disc: 1
    volumes:
      - ./irix:/home/guest/irix:ro
      - ./config/bootptab:/etc/bootptab:ro
      - ./config/hosts:/etc/hosts:ro
    restart: unless-stopped
    networks:
      macvlan:
        ipv4_address: 192.168.0.9

networks:
  macvlan:
    external: true
    name: macvlan
```

Edit these fields:

- `hostname`: the install server name shown to SGI clients, for example `cosmos`.
- `ipv4_address`: the install server IP on your LAN.
- `TZ`: your local timezone.
- `./irix`: your local IRIX media folder, if you use a different path.

Use the released version tag for predictable installs. Avoid `latest` unless you intentionally want automatic image changes.

A copy of this file is included in this repository as `docker-compose.release.yml`.

### 3. Create `config/hosts`

Create `config/hosts` with the install server and every SGI client:

```text
127.0.0.1       localhost
::1             localhost ip6-localhost ip6-loopback
fe00::0         ip6-localnet
ff00::0         ip6-mcastprefix
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters

192.168.0.9     cosmos cosmos.example.net
192.168.0.10    octane octane.example.net
```

Use both the short name and fully qualified domain name when you know both. The short name in `bootptab` should match a name in this file.

### 4. Create `config/bootptab`

Create one BOOTP line for each SGI client:

```text
octane:ht=ether:ha=080069c0ffee:ip=192.168.0.10:sm=255.255.255.0:sa=192.168.0.9:ds=192.168.0.9:gw=192.168.0.1:rp=/home/guest/irix
```

Edit these fields:

- `octane`: SGI client hostname.
- `ht=ether`: hardware type, explicitly Ethernet.
- `ha=080069c0ffee`: SGI client MAC address without colons.
- `ip=192.168.0.10`: SGI client IP address, should match /etc/hosts.
- `sm=255.255.255.0`: subnet mask.
- `sa=192.168.0.9`: install server IP, should match /etc/hosts.
- `ds=192.168.0.9`: distribution server address supplied to the SGI client.
- `gw=192.168.0.1`: gateway supplied to the SGI client.
- `rp=/home/guest/irix`: root path supplied to the SGI client.

Optional field:

- `bf=<tftp-root-relative-file>`: optional default boot file. Leave this unset unless you have tested a default boot path for that client; the documented workflow uses explicit PROM commands instead.

Keep each client entry on one line. The container reads `bootptab` at startup and automatically writes `.rhosts` trust entries for each client hostname.

### 5. Create The Docker `macvlan` Network

The container needs its own LAN IP so old SGI firmware can reach BOOTP and TFTP directly.

Find your Linux network interface:

```sh
ip link
```

Create the external Docker network, replacing the subnet, gateway, and parent interface for your LAN:

```sh
docker network create -d macvlan --subnet=192.168.0.0/24 --gateway=192.168.0.1 -o parent=eth0 macvlan
```

If the network already exists, Docker will report that. Confirm with:

```sh
docker network ls
```

### 6. Verify And Start

Check the Compose file:

```sh
docker compose config
```

Pull the published image:

```sh
docker compose pull
```

Start the install server:

```sh
docker compose up -d
```

Check that it is running:

```sh
docker compose ps
```

Inspect generated RSH trust entries:

```sh
docker exec irix-install cat /home/guest/.rhosts
```

You should see one line per SGI client, for example:

```text
octane root
```

### 7. Stop Or Recreate

Stop and remove the container:

```sh
docker compose down
```

Recreate it after changing `docker-compose.yml`, `config/hosts`, or `config/bootptab`:

```sh
docker compose up -d --force-recreate
```

View container logs:

```sh
docker compose logs
```

## Configuration Notes

The TFTP server is rooted at `/home/guest/irix`, which is your local `./irix` folder. PROM paths are relative to that root.

The RSH install account is `guest`. The SGI target connects as its local `root` user, so generated `.rhosts` lines look like this:

```text
octane root
```

The container also prepares `/root/.rhosts` for compatibility with older examples, but normal documentation should use `guest`.

## Development Build

The default `docker-compose.yml` in this repository builds the image locally from the Dockerfile. Use it when developing or testing changes to this project:

```sh
docker compose build
docker compose up -d --force-recreate
```

Your Linux system may use `/usr/local/bin/docker-compose` instead of `docker compose` so check that.

## Supported Deployment

Primary target:

- Linux Docker host
- External `macvlan` network
- Static LAN IP for the install server container
- Read-only `/home/guest/irix` mount containing IRIX install media

Windows Docker Desktop is not a supported runtime target for real SGI LAN installs. It may be useful for limited image development only.

## Important Paths

- `docker-compose.yml` - local development deployment definition.
- `docker-compose.release.yml` - production example using the published image.
- `config/bootptab` - BOOTP client definitions.
- `config/hosts` - install server and SGI client hostname mappings.
- `config/bootptab.example` - sanitized BOOTP example.
- `config/hosts.example` - sanitized hosts example.
- `irix/` - IRIX install media mounted as `/home/guest/irix:ro`.
- `docs/` - project notes, operations, and client configuration documentation.
- `Dockerfile` - maintained Debian Bookworm image build.
- `docker/entrypoint.sh` - generates `.rhosts` and starts `xinetd`.
- `docker/xinetd.d/` - BOOTP, TFTP, and RSH xinetd services baked into the image.

## SGI Client Boot And Install Sources

This README is not a full IRIX installation guide. It documents the server layout and the network paths that matter for this container. Use the official SGI manuals for partitioning, install stream selection, conflict handling, and post-install system setup.

Use the Command Monitor method below as the primary path. The PROM menu option `2` / `Install System Software` is intentionally not documented here because it can treat the remote directory as the default install source and behave poorly with a split media layout.

### Preferred Media Layout

Keep the install media under `irix/`, using short directory names because these paths are typed at the PROM and `Inst>` prompts:

```text
irix/
  65/
    dist/
    firmware/
    help/
    insight/
    relnotes/
    stand/
  6522/
    apps/
      dist/
    dist/
    installtools/
    relnotes/
    stand/
  6530/
    apps/
      dist/
    dist/
    installtools/
    relnotes/
    stand/
```

For Octane and Octane2, the important architecture is `IP30`, so the miniroot kernel is:

```text
6530/dist/miniroot/unix.IP30
```

### Set PROM Network Variables

From the System Maintenance Menu, choose `5` for the Command Monitor. Check and set the SGI client's IP address:

```text
printenv netaddr
setenv netaddr 192.168.0.10
```

If your PROM has `dlserver`, set it to the install server IP:

```text
setenv dlserver 192.168.0.9
```

### Command Monitor Boot

For late 64-bit systems such as Octane2, boot the standalone shell from the current install tools `dist/sa` file. This was verified on a dual R14000/V12 Octane2 and loaded `Standalone Shell SGI Version 6.5 ARCS Jul 20, 2006 (64 Bit)`:

```text
boot -f bootp():6530/dist/sa(sash64)
```

Use `sashARCS` instead of `sash64` on 32-bit ARCS systems when the media supports it.

From the standalone shell, run `fx.64` for Octane/Octane2. Use `fx.ARCS` instead on 32-bit ARCS systems:

```text
boot -f bootp():6530/stand/fx.64 --x
```

The double dash is intentional here. The SGI boot layer removes one leading dash when passing arguments to the next program, so `--x` becomes `-x` for `fx`.

To boot the miniroot for Octane/Octane2 from the standalone shell:

```text
boot -f bootp():6530/dist/miniroot/unix.IP30
```

Some systems can boot the miniroot directly from the Command Monitor:

```text
bootp():6530/dist/miniroot/unix.IP30
```

Avoid using an old `stand/sash64` when a current `dist/sa(sash64)` is available. In one tested 6.5.30 media layout, `6530/stand/sash64` was from 1998 while `6530/dist/sa`, `fx.64`, and `unix.IP30` were from 2006.
### Opening Distributions In `inst`

Inside `inst`, use the `guest` account. For this container, the path is relative to `/home/guest`, so include `irix/`:

```text
from guest@192.168.0.9:irix/6530/dist
open guest@192.168.0.9:irix/6530/apps/dist
open guest@192.168.0.9:irix/65/dist
```

Use the full remote source for each additional distribution unless you have tested shorter forms on your IRIX version.

Official SGI examples often show paths like `mars:/CDROM/dist`. This container uses the same remote-distribution idea, but the recommended account-qualified form is:

```text
guest@192.168.0.9:irix/6530/dist
```

Use the IP address unless hostname resolution works inside the SGI miniroot.

### Official Installation References

For the full IRIX installation process, read the SGI manuals. Local copies are kept in `reference/`, and direct PDF links are available from the IRIX7 TechPubs archive:

- [IRIX 6.5 Installation Instructions](https://www.irix7.com/techpubs/007-3862-007.pdf): read `How to Install Operating System Software`, `How to Install IRIX 6.5.x on a Pre-6.5 Release or a Clean Disk`, `Installations for Nongraphical Systems`, and `Troubleshooting Remote Installations`.
- [IRIX Admin: Software Installation and Licensing](https://www.irix7.com/techpubs/007-1364-140.pdf): read Part I, especially Chapter 2, `Preparing for Installation`, including installation server setup, BOOTP/TFTP, installation accounts, and distribution directories.
- [IRIX Admin: System Configuration and Operation](https://www.irix7.com/techpubs/007-2859-021.pdf): use as the general IRIX administration reference for PROM/boot behavior, network setup, and service configuration.

The full IRIX7 archive is here: [Silicon Graphics Technical Document Archive](https://www.irix7.com/techpubs.html).

## Troubleshooting

### SGI Client Gets No Response From The Server

Confirm the container is running and has the expected LAN IP:

```sh
docker compose ps
docker inspect -f 'IP={{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}} Hostname={{.Config.Hostname}}' irix-install
```

The container IP should match the `sa=` value in `config/bootptab` and the install server entry in `config/hosts`.

Watch the container logs while testing an SGI boot:

```sh
docker logs -f irix-install
```

If the SGI never reaches TFTP, verify that BOOTP requests are reaching this container and that no other BOOTP/DHCP-style install server is answering first.

If the Linux host has a firewall, allow the legacy install services on the install LAN:

```text
UDP 67   BOOTP
UDP 69   TFTP
TCP 514  RSH
```

The verified Galaxy/Synology setup did not require a special project-specific firewall change, but any host firewall or router ACL that blocks those ports can break installs.

### BOOTP Works But TFTP Cannot Find The File

PROM paths are relative to the TFTP root, which is `/home/guest/irix` inside the container and `./irix` on the Docker host.

Use this from the PROM:

```text
boot -f bootp():6530/dist/sa(sash64)
```

Do not include `irix/` in PROM/TFTP paths. This is wrong for the PROM:

```text
boot -f bootp():irix/6530/dist/sa(sash64)
```

But `inst` uses RSH through the `guest` account, so `inst` paths do include `irix/`:

```text
guest@192.168.0.9:irix/6530/dist
```

Also confirm the requested file actually exists for the target system architecture. For example, Octane/Octane2 systems use IP30 miniroots and 64-bit standalone tools:

```sh
docker exec irix-install test -f /home/guest/irix/6530/dist/sa
docker exec irix-install test -f /home/guest/irix/6530/dist/miniroot/unix.IP30
```

Older systems may need a different IRIX release or a different standalone tool, such as `.ARCS` instead of `.64`.

### Hostname Mismatch

If you specify a server name in a `bootp()` path, the server name should match the container hostname and a name in `config/hosts`.

For this README's example:

```yaml
hostname: cosmos
```

```text
192.168.0.9     cosmos cosmos.example.net
```

For named PROM boot paths, use the hostname form, not the IP address form:

```text
boot -f bootp()cosmos:6530/dist/sa(sash64)
```

The named server must match the container hostname. Keep the matching short hostname in `config/hosts`, even if you also include a fully qualified name.

If you change the Compose hostname or either config file, recreate the container:

```sh
docker compose up -d --force-recreate
```

### `.rhosts` Does Not Include A Client

The container generates `/home/guest/.rhosts` and `/root/.rhosts` from the hostnames in `config/bootptab` when it starts.

Check the generated file:

```sh
docker exec irix-install cat /home/guest/.rhosts
```

Expected example:

```text
octane root
```

Keep each `bootptab` client entry on one line. If you edit `config/bootptab`, recreate the container so `.rhosts` is regenerated.

If `inst` can reach the server but cannot open distributions, check for RSH authentication failures:

```sh
docker logs irix-install
```

Messages about denied access, `.rhosts`, or PAM usually mean the client hostname in `config/bootptab`, `config/hosts`, and the generated `/home/guest/.rhosts` do not agree. This image is built to avoid the common manual Linux setup problem where `/etc/pam.d/rsh` blocks passwordless RSH, so hostname trust is the first thing to check.

### `fx.64` Does Not Boot Directly

On Octane/Octane2, direct `fx.64` boot may fail even when BOOTP/TFTP are working. Boot the current standalone shell first:

```text
boot -f bootp():6530/dist/sa(sash64)
```

Then run `fx.64` from that shell:

```text
boot -f bootp():6530/stand/fx.64 --x
```

The `--x` form is intentional in this context because one leading dash is stripped while passing the argument through the boot layer.

### Miniroot Kernel Panics Or Reboots

If `unix.IP30` transfers and starts but then panics or reboots, the problem is no longer a basic Docker/TFTP path issue. In Octane2 testing, a separate container on the same `macvlan` network fetched `6530/dist/miniroot/unix.IP30` over TFTP and its SHA256 matched the source file exactly.

Things to check next:

- Boot through the current `dist/sa(sash64)` path, not an older `stand/sash64`.
- Verify that the miniroot matches the target architecture, for example `unix.IP30` for Octane/Octane2.
- Check PROM/NVRAM state, especially on systems reporting a lost battery-backed clock.
- As a diagnostic only, try disabling multiprocessing from PROM with `setenv disable_mp 1` before booting the miniroot.

### Multiple BOOTP Servers

If more than one BOOTP server is active on the same LAN, the wrong server can answer. Temporarily disable other BOOTP/DHCP-style install services, or specify the intended install server hostname in the boot path if your PROM and server setup support it.

When specifying the server name, keep the hostname consistent with the container hostname.

### Development Build Cannot Reach Debian Packages

On Galaxy/Synology, temporary Docker build containers could resolve DNS but could not reach Debian package mirrors on the default Docker bridge network. The local development Compose file uses host networking for builds:

```yaml
build:
  context: .
  network: host
```

For a manual development build on Galaxy, use:

```sh
/usr/local/bin/docker build --network host -t irix-install:local .
```

This does not affect the release Compose file because the release file pulls the published image instead of building it.
## Safety Warning

This project intentionally runs legacy insecure services for compatibility with old UNIX install workflows. Use only on a trusted LAN or isolated install network.

Do not commit, archive, or bake `irix/` into an image.

