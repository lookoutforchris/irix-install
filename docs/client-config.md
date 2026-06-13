# Client Configuration

Each SGI client that uses this install server needs entries in both `config/bootptab` and `config/hosts`.

## BOOTP Entry

Example:

```text
octane:ha=080069c0ffee:sa=192.168.0.9:ds=192.168.0.9:rp=/DIST
```

Fields:

- `octane` - SGI client hostname.
- `ha=080069c0ffee` - SGI client MAC address without separators.
- `sa=192.168.0.9` - install server address.
- `ds=192.168.0.9` - domain/DNS server address supplied to the client.
- `rp=/DIST` - root path supplied to the client.

`sa` and `ds` are server-side fields. They are not the client IP address.

## Hosts Entry

Example entries:

```text
192.168.0.9     irix-install
192.168.0.10    octane
```

The BOOTP client IP is resolved from the hostname, so the hostname in `bootptab` should match a hostname in `hosts`.

## Adding a Client

For a new SGI system:

1. Choose a hostname.
2. Assign or confirm the SGI client IP.
3. Find the SGI system MAC address.
4. Add the hostname/IP to `config/hosts`.
5. Add a matching hostname/MAC line to `config/bootptab`.
6. Keep `sa`, `ds`, and `rp` pointed at the install server unless using a different server layout.

Example:

```text
onyx:ha=080069112233:sa=192.168.0.9:ds=192.168.0.9:rp=/DIST
```

```text
192.168.0.12    onyx
```

## RSH Trust

The old upstream image hardcoded:

```text
iris root
```

in `/root/.rhosts` and `/home/guest/.rhosts`.

The maintained image should generate `.rhosts` from configured BOOTP hostnames. For the example above, it should generate:

```text
octane root
onyx root
```

This is insecure legacy behavior and should only be used on a trusted install LAN.

## Verified Client

An SGI Octane2 client was verified against the maintained install container on 2026-06-13.

Working PROM command:

```text
bootp():6.5.30/stand/sash64 -x
```

This loaded the 64-bit standalone shell and confirmed BOOTP/TFTP function against real SGI hardware.
