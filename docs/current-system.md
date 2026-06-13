# Current System Notes

## Upstream Image

The current deployment uses `dexter1/irix-install:latest`.

Observed image metadata:

- Created: `2021-06-28`
- OS/platform: `linux/amd64`
- Debian version: `10.10`
- Size: about `206 MB`
- Entrypoint: `/usr/sbin/xinetd`
- Command: `-d -dontfork`
- Declared volume: `/DIST`

Installed upstream packages:

- `bootp 2.4.3-18+b2`
- `mksh 57-1`
- `rsh-redone-server 85-2+b1`
- `tftpd 0.17-22`
- `xinetd 1:2.3.15.3-1`

The upstream image exposes many TCP ports, including `67`, `69`, `514`, and `2048-32767`. In the current macvlan deployment this is image metadata only; the compose file does not publish ports.

## Previous Compose Deployment

The pre-modernization compose file:

- image: `dexter1/irix-install:latest`
- container name: `irix-install`
- hostname: site-specific install server hostname
- network: external `macvlan`
- static IP: `192.168.0.9`
- restart policy: no restart

Mounted files:

- `/volume1/docker/irix-install/dist` to `/DIST:ro`
- `/volume1/docker/irix-install/config/bootptab` to `/etc/bootptab:ro`
- `/volume1/docker/irix-install/config/hosts` to `/etc/hosts:ro`
- `/volume1/docker/irix-install/config/xinetd.d` to `/etc/xinetd.d:ro`

Compose validation succeeded on Galaxy with:

```sh
/usr/local/bin/docker-compose config
```

## Maintained Compose Deployment

The maintained compose file now builds a local image:

- build context: `.`
- build network: `host`
- image: `irix-install:local`
- container name: `irix-install`
- hostname: `irix-install`
- network: external `macvlan`
- static IP: `192.168.0.9`

Normal runtime mounts are reduced to user-specific config and media:

- `./irix` to `/home/guest/irix:ro`
- `/volume1/docker/irix-install/config/bootptab` to `/etc/bootptab:ro`
- `/volume1/docker/irix-install/config/hosts` to `/etc/hosts:ro`

The xinetd service definitions are now baked into the image from `docker/xinetd.d/`.
The maintained image also bakes `docker/xinetd.conf` into `/etc/xinetd.conf` so xinetd logs to `/var/log/xinetd.log` instead of relying on syslog inside the minimal container.
The maintained entrypoint runs `xinetd -dontfork`; Bookworm `xinetd` failed during log initialization with the old upstream `-d -dontfork` debug-mode combination.

## Service Model

The old image uses `xinetd` and includes `/etc/xinetd.d`.

Enabled services:

- `bootps` on UDP 67 via `/usr/sbin/bootpd`
- `tftp` on UDP 69 via `/usr/sbin/in.tftpd -s /home/guest/irix`
- `shell` on TCP 514 via `/usr/sbin/in.rshd`

No `/etc/inetd.conf` is used.

Required service names exist in `/etc/services`:

- `bootps 67/udp`
- `tftp 69/udp`
- `shell 514/tcp`

## Authentication Behavior

The old image:

- creates `guest`
- sets root shell to `/bin/mksh`
- gives `root` and `guest` no password
- writes `.rhosts` files containing `iris root`
- uses PAM `pam_rhosts.so` for RSH

This means the old image hardcodes RSH trust for `iris root`. A generalized maintained image should generate `.rhosts` from real BOOTP client hostnames.

## Modern Base Findings

`debian:trixie-slim` was not selected for v1 because `rsh-redone-server` and old TFTP package compatibility are worse.

`debian:bookworm-slim` was verified as the best compatibility-first base.

Bookworm package check:

- `bootp 2.4.3-19.1`
- `mksh 59c-28+deb12u1`
- `rsh-redone-server 85-4`
- `tftpd-hpa 5.2+20150808-1.4`
- `xinetd 1:2.3.15.3-1+b1`

Bookworm provides expected binaries:

- `/usr/sbin/bootpd`
- `/usr/sbin/in.rshd`
- `/usr/sbin/in.tftpd`
- `/usr/sbin/xinetd`

`tftpd-hpa` replaces old Debian `tftpd`. It provides `/usr/sbin/in.tftpd`, and Debian documentation confirms `-s` is secure/chroot mode and compatible with some boot ROMs.

The maintained image uses this package set in `Dockerfile`.

## Galaxy Build Note

Temporary containers on Galaxy could resolve DNS but could not reach `deb.debian.org:80` on the default Docker bridge network. Running with host networking fixed APT access.

Use host networking for build/package checks on Galaxy when needed.
