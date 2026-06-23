# Client Configuration

Each SGI client that uses this install server needs entries in both `config/bootptab` and `config/hosts`.

## BOOTP Entry

Example:

```text
octane:ht=ether:ha=080069c0ffee:ip=192.168.0.10:sm=255.255.255.0:sa=192.168.0.9:ds=192.168.0.9:gw=192.168.0.1:rp=/home/guest/irix
```

Fields:

- `octane` - SGI client hostname.
- `ht=ether` - hardware type, explicitly Ethernet.
- `ha=080069c0ffee` - SGI client MAC address without separators.
- `ip=192.168.0.10` - SGI client IP address.
- `sm=255.255.255.0` - subnet mask supplied to the client.
- `sa=192.168.0.9` - install server address.
- `ds=192.168.0.9` - domain/DNS server address supplied to the client.
- `gw=192.168.0.1` - gateway supplied to the client.
- `rp=/home/guest/irix` - root path supplied to the client.

`sa` and `ds` are server-side fields. `ip` is the SGI client IP address.

Optional field:

- `bf=6530/stand/sash64` - default boot file, relative to the TFTP root. This is useful for menu-driven installs or default boots, but explicit PROM commands such as `bootp():6530/stand/sash64 -x` do not require it.

Keep each client entry on one line. The container uses the hostname before the first colon to generate `.rhosts` trust entries at startup.

## Hosts Entry

Example entries:

```text
192.168.0.9     cosmos cosmos.example.net
192.168.0.10    octane octane.example.net
```

The BOOTP client IP is resolved from the hostname, so the hostname in `bootptab` should match a hostname in `hosts`.

When you know the full domain name, include both the short name and the FQDN in `hosts`.

## Adding a Client

For a new SGI system:

1. Choose a hostname.
2. Assign or confirm the SGI client IP.
3. Find the SGI system MAC address.
4. Add the hostname/IP to `config/hosts`.
5. Add a matching hostname/MAC/IP line to `config/bootptab`.
6. Keep `sa`, `ds`, `gw`, and `rp` aligned with your LAN and install server unless using a different server layout.

Example:

```text
onyx:ht=ether:ha=080069112233:ip=192.168.0.12:sm=255.255.255.0:sa=192.168.0.9:ds=192.168.0.9:gw=192.168.0.1:rp=/home/guest/irix
```

```text
192.168.0.12    onyx onyx.example.net
```

## RSH Trust

The old upstream image hardcoded:

```text
iris root
```

in `/root/.rhosts` and `/home/guest/.rhosts`.

The maintained image generates `.rhosts` from configured BOOTP hostnames. For the examples above, it generates:

```text
octane root
onyx root
```

The second field is the SGI target's remote user, not the container account. During installation the SGI runs `inst` as root, then uses RSH to access the install server.

Recommended server-side install account:

```text
guest
```

Recommended `inst` source form:

```text
guest@192.168.0.9:irix/6530/dist
```

The container writes the generated trust entries to both `/home/guest/.rhosts` and `/root/.rhosts`. Use `guest` in documentation and normal workflows; root access is kept only for compatibility with older examples and troubleshooting.

The TFTP server is rooted at `/home/guest/irix`, so the media-relative path is the same in both phases:

```text
PROM: bootp():6530/stand/sash64 -x
inst: guest@192.168.0.9:irix/6530/dist
```

This is insecure legacy behavior and should only be used on a trusted install LAN.

## Verified Client

An SGI Octane2 client was verified against the maintained install container on 2026-06-13.

Working PROM command:

```text
bootp():6530/stand/sash64 -x
```

This loaded the 64-bit standalone shell and confirmed BOOTP/TFTP function against real SGI hardware.

