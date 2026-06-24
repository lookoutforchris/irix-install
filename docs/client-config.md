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
- `ds=192.168.0.9` - distribution server address supplied to the client.
- `gw=192.168.0.1` - gateway supplied to the client.
- `rp=/home/guest/irix` - root path supplied to the client.

`sa` and `ds` are server-side fields. `ip` is the SGI client IP address.

Optional field:

- `bf=<tftp-root-relative-file>` - optional default boot file. Leave this unset unless you have tested a default boot path for that client; the documented workflow uses explicit PROM commands instead.

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
PROM: boot -f bootp():6530/dist/sa(sash64)
inst: guest@192.168.0.9:irix/6530/dist
```

This is insecure legacy behavior and should only be used on a trusted install LAN.

## Verified Client

An SGI Octane2 client was verified against the maintained install container during June 2026 testing.

Working PROM command:

```text
boot -f bootp():6530/dist/sa(sash64)
```

This loaded the 6.5.30 64-bit standalone shell from `dist/sa` and confirmed BOOTP/TFTP function against real SGI hardware. Miniroot boot testing remained hardware/PROM-sensitive and should be debugged separately from basic TFTP service checks.

