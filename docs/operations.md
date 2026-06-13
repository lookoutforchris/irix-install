# Operations

Commands in this file are intended for a root shell on Galaxy unless noted.

## Validate Compose

```sh
cd /volume1/docker/irix-install
/usr/local/bin/docker-compose config
```

## Build Maintained Image

The compose file sets `build.network: host` because Galaxy package downloads from temporary build containers may fail on the default Docker bridge network.

```sh
cd /volume1/docker/irix-install
/usr/local/bin/docker-compose build
```

Equivalent explicit Docker build:

```sh
cd /volume1/docker/irix-install
/usr/local/bin/docker build --network host -t irix-install:local .
```

## Start Maintained Deployment

```sh
cd /volume1/docker/irix-install
/usr/local/bin/docker-compose up -d
```

## Stop Deployment

```sh
cd /volume1/docker/irix-install
/usr/local/bin/docker-compose down
```

## Check Current Container

```sh
cd /volume1/docker/irix-install
/usr/local/bin/docker-compose ps -a
```

## Inspect Current Container

```sh
/usr/local/bin/docker inspect irix-install
```

## Inspect Current Image

```sh
/usr/local/bin/docker image inspect dexter1/irix-install:latest
```

```sh
/usr/local/bin/docker history --no-trunc dexter1/irix-install:latest
```

## Verify Bookworm Package Compatibility

Galaxy may need `--network host` for APT access from temporary containers.

```sh
/usr/local/bin/docker run --rm --network host debian:bookworm-slim sh -c 'apt-get update >/dev/null && apt-get install -y bootp mksh rsh-redone-server tftpd-hpa xinetd >/dev/null && dpkg-query -W bootp mksh rsh-redone-server tftpd-hpa xinetd && ls -l /usr/sbin/bootpd /usr/sbin/in.rshd /usr/sbin/in.tftpd /usr/sbin/xinetd && grep -E "^(bootps|tftp|shell|login|exec)[[:space:]]" /etc/services'
```

## Runtime Verification Goals

After the maintained image exists, verify:

- container starts on the external `macvlan` network
- container receives the configured static IP
- `xinetd -dontfork` is PID 1
- `/home/guest/irix` is mounted read-only
- BOOTP listens on UDP 67
- TFTP listens on UDP 69
- RSH listens on TCP 514
- `.rhosts` contains the configured SGI client hostnames
- logs show no xinetd parse errors
- xinetd writes service logs to `/var/log/xinetd.log` inside the container

Inspect generated `.rhosts` after startup:

```sh
/usr/local/bin/docker exec irix-install cat /root/.rhosts
/usr/local/bin/docker exec irix-install cat /home/guest/.rhosts
/usr/local/bin/docker exec irix-install cat /var/log/xinetd.log
```

The recommended IRIX `inst` account is `guest`. The generated `.rhosts` entries still end in `root` because that is the remote user on the SGI target.

Example source path to try from `inst`:

```text
guest@192.168.0.9:irix/6530/dist
```

## Verified Hardware Test

On 2026-06-13, an SGI Octane2 successfully reached the maintained container over `macvlan` and loaded the 64-bit standalone shell.

PROM command used on the SGI client:

```text
bootp():6530/stand/sash64 -x
```

Observed result:

- BOOTP reached the install server.
- TFTP loaded `sash64`.
- The SGI entered standalone shell `Version 6.5 ARCS Apr 30, 1998 (64 Bit)`.
- `sash` commands such as `ls` and `help` worked.

Use command-specific `--help` when uncertain:

```sh
/usr/local/bin/docker --help
/usr/local/bin/docker-compose --help
/usr/local/bin/docker-compose COMMAND --help
```

Behavior may vary by Docker Compose version. Galaxy was observed using Compose `2.20.1` when the old container was created.
