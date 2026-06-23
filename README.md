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

Put your IRIX install media under `irix/`. The folder names are your choice; the examples in this README use `6530` for IRIX 6.5.30. I combine all the foundation/base files under irix/65/ and then all the overlays under irix/652 or irix/6530 and so on. For the handful of common files in an install, I just munge them together. The shorter the path the easier it is to do the installs.

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
- `ds=192.168.0.9`: DNS/server address supplied to the SGI client.
- `gw=192.168.0.1`: gateway supplied to the SGI client.
- `rp=/home/guest/irix`: root path supplied to the SGI client.

Optional field:

- `bf=6530/stand/sash64`: default boot file, relative to the TFTP root. Explicit PROM commands such as `bootp():6530/stand/sash64 -x` do not require it.

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

Galaxy/Synology may use `/usr/local/bin/docker-compose` instead of `docker compose`.

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

## SGI Client Setup And Boot Commands

This section uses the local file layout shown below. The command syntax was checked against the SGI reference PDFs in `reference/`, especially `IRIX Admin - System Configuration and Operation`, `IRIX 6.5 Installation Guide`, and the saved remote-install guide.

### Preferred Media Layout

Keep the install media under `irix/`, using short directory names because these paths are typed at the PROM and `Inst>` prompts:

```text
irix/
  65/
    dist/
	  miniroot/
	firmware/
	help/
	insight/
	relnotes/
	stand/
  6522/
    apps/
	  dist/
	    dev/
		extras/
	  NT/
	  relnotes/
	dist/
	  minroot/
	  unbundled/
	installtools/
	relnotes/
	stand/
	WhatsNew/
  6530/
    apps/
	  dist/
	    dev/
		extras/
	  NT/
	  relnotes/
	dist/
	  miniroot/
	  unbundled/
	installtools/
	relnotes/
	stand/
	WhatsNew/
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

If your PROM has `dserver`, set it to the install server IP:

```text
setenv dserver 192.168.0.9
```

Then return to the menu when needed:

```text
exit
```

### Command Monitor Method

From the Command Monitor, boot `sash64` first:

```text
bootp():6530/stand/sash64 -x
```

On Octane/Octane2, run `fx.64` from `sash64`:

```text
boot -f bootp():6530/stand/fx.64 --x
```

The double dash is intentional here. The SGI boot layer removes one leading dash when passing arguments to the next program, so `--x` becomes `-x` for `fx`.

To boot the miniroot for Octane/Octane2 from `sash64`:

```text
boot -f bootp():6530/dist/miniroot/unix.IP30
```

Some systems can boot the miniroot directly from the Command Monitor:

```text
bootp():6530/dist/miniroot/unix.IP30
```

If direct `fx.64` boot fails but `sash64` works, use the `sash64` two-step method above.

### PROM Menu Method

From the System Maintenance Menu, use the guided install path:

1. Choose `2` for `Install System Software`.
2. Choose `Remote Directory`.
3. Enter the install server hostname:

```text
cosmos
```

4. Enter the TFTP-root-relative distribution path:

```text
6530/dist
```

The install server hostname should match the container hostname and a name in `config/hosts`. In this project, that is `cosmos`:

```text
192.168.0.9     cosmos cosmos.example.net
```

The PROM menu method uses the early BOOTP/TFTP install path. After the miniroot starts and you reach `Inst>`, access to distributions uses RSH instead.

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

## Safety Warning

This project intentionally runs legacy insecure services for compatibility with old UNIX install workflows. Use only on a trusted LAN or isolated install network.

Do not commit, archive, or bake `irix/` into an image.

