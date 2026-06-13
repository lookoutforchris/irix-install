# Reference Review Report

Date: 2026-06-13

## Sources Reviewed

- `reference/IRIX 6.5 Installation Guide 007-3862-007.pdf`
- `reference/IRIX Admin - Software Installation and Licensing 007-1364-140.pdf`
- `reference/IRIX Admin - System Configuration and Operation 007-2859-021.pdf`
- `reference/IRIX Advanced Site and Server Administration Guide 007-0603-100.pdf`
- `reference/IRIX Network Programming Guide 007-0810-110.pdf`
- `reference/SGI IRIX 6.5_ Remote, network install using GNU_Linux install server.pdf`
- `reference/SGI IRIX 6.5- Remote, network install using GNU-Linux install server.url`
- Live website: `http://techpubs.spinlocksolutions.com/irix/remote-irix-6.5-installation-from-linux.html`

The live Spinlock Solutions page was reachable from Galaxy and returned HTTP 200 on 2026-06-13. The saved PDF appears to be a local print/export of the same guide.

## Executive Findings

The new references support the modernization plan. They do not require changing the current Docker image design before the first build.

The main impact is documentation: the project should include a clear user guide that explains the full client-side IRIX workflow, not just the Docker service setup. The references confirm that BOOTP and TFTP are only the early boot/miniroot path, while `inst` later uses RSH to access distribution directories. That validates keeping RSH and `.rhosts` behavior in the container.

The official SGI manuals also confirm that an installation account must allow root from target systems to access the server, either through a passwordless account or `.rhosts`. Our startup-generated `.rhosts` behavior is therefore aligned with SGI documentation, and is better than the upstream image's hardcoded `iris root`.

## Impact on Container Plan

No immediate container implementation changes are required.

Confirmed design choices:

- Keep BOOTP, TFTP, and RSH together; all are part of the remote install flow.
- Keep a `guest` account available because SGI documentation says Inst defaults to `guest` on the installation server.
- Keep `.rhosts` generation for target hostnames because SGI documentation permits installation accounts to use `.rhosts` entries for each target system.
- Keep TFTP rooted at `/DIST`; the Spinlock guide uses `/srv/tftp` plus a symlink to the install tree, but our Docker design simplifies that by making `/DIST` the TFTP root.
- Keep short, typeable distribution paths under `/DIST`; the Spinlock guide emphasizes that users must type paths in SGI PROM and `inst`.
- Keep Linux-only/macvlan focus; the workflow depends on LAN-style BOOTP/TFTP/RSH behavior.

Potential future enhancement:

- Add an optional non-root installation account mode, for example `irix`, if we want to align more closely with the Spinlock guide's non-root account model. This is not required for the first build because SGI documentation explicitly discusses `guest`, and the upstream image already used root/guest compatibility behavior.

## Documentation Additions Needed

Create or expand a user guide covering:

1. How the remote install protocol flow works.
   - SGI PROM uses BOOTP first.
   - The client then uses TFTP to fetch early boot/install files.
   - Once `inst` is running, it uses RSH to read install distributions.

2. How to prepare `/DIST`.
   - IRIX install files may come from physical CDs, EFS CD images, or extracted tarballs.
   - The first remotely booted files are from the Installation Tools and Overlays media.
   - Important paths include `stand/`, `dist/sa`, and `dist/miniroot/`.
   - Keep directory names short because they are typed at PROM and `inst` prompts.

3. How to configure SGI clients.
   - Set the client IP in PROM with `setenv netaddr <client-ip>`.
   - Match the client hostname and IP in `config/hosts`.
   - Match the hostname and MAC address in `config/bootptab`.
   - Use `sa`, `ds`, and `rp=/DIST` to point clients at the install server.

4. How to test BOOTP and TFTP before installing.
   - From the SGI System Maintenance menu, enter Command Monitor.
   - Use a PROM `bootp()` command to fetch `sash` from the install media.
   - If `sash` boots, BOOTP/TFTP/server path basics are working.
   - `ping` inside `sash` is not a reliable network test according to the Spinlock guide.

5. How to run `fx` before installation.
   - The Spinlock guide strongly recommends running `fx` before installation to verify or set disk partitions.
   - `fx.64`/`fx.ARCS` are expected under the Installation Tools and Overlays media.

6. How to start miniroot/`inst`.
   - Boot the correct `unix.IPXX` miniroot for the SGI hardware type.
   - The user must verify the relevant `unix.IPXX` exists under the installation media.
   - The PROM menu method can work, but explicit PROM `bootp()` commands are easier to reason about and troubleshoot.

7. How to open distributions in `inst`.
   - The first distribution is opened with `from`.
   - Additional distributions are opened with `open`.
   - At this stage, access is via RSH, not TFTP.
   - Paths should be written relative to the remote user's home or absolute as appropriate for our container. For this project, document the exact container-supported path convention after runtime testing.

8. Troubleshooting.
   - Watch container logs while testing.
   - Confirm xinetd is listening on UDP 67, UDP 69, and TCP 514.
   - Confirm the SGI PROM `netaddr` matches `config/hosts` and `config/bootptab`.
   - Confirm the requested TFTP path exists below `/DIST`.
   - Confirm generated `.rhosts` includes `<client-hostname> root`.
   - Be aware that multiple BOOTP servers on the same LAN can cause confusing behavior.

## Source-Specific Notes

### IRIX Admin - Software Installation and Licensing

Most important official source for server behavior.

Relevant findings:

- Installation servers must be reachable by target systems.
- Miniroot installs require BOOTP and TFTP support between target and server.
- Inst defaults to using `guest` on the server to accept target connections.
- If using another account, Inst can be pointed at `alternate_user@installation_server:distdir`.
- Installation accounts may use `.rhosts`; entries should allow each target system's `root` user.
- The `.rhosts` entry permits install access to the server; it does not grant root privileges on the server.
- Distribution directories should preserve the expected installable software structure.

Project impact:

- Validates keeping `guest`.
- Validates generating `.rhosts` entries as `<target-hostname> root`.
- Supports documenting alternate install account concepts later, but not required for v1.

### IRIX Admin - System Configuration and Operation

Most important official source for PROM/network boot syntax.

Relevant findings:

- `sash` is the standalone shell used as an intermediary boot program.
- SGI PROM can boot across the network using BOOTP.
- `setenv netaddr <ip>` sets the client IP used for network boot.
- BOOTP file syntax is `bootp()[hostname:] path`.
- Omitting the hostname broadcasts to any server on the same network.
- A specified hostname must run a BOOTP server.
- Examples use `boot -f bootp()host:/path` and `boot -f bootp()/path`.

Project impact:

- Documentation should teach `netaddr` explicitly.
- Documentation should warn about omitted hostnames if multiple BOOTP servers exist.
- The Docker service model should keep plain BOOTP/TFTP LAN behavior.

### IRIX 6.5 Installation Guide

Useful for high-level remote install troubleshooting.

Relevant findings:

- Remote installation failures commonly involve TFTP access, incorrect NVRAM IP address, network connection, or inability to reach a distribution server.
- Official troubleshooting directs users to inspect or correct `netaddr` from the System Maintenance / System Monitor environment.
- Remote installation can use remote distribution paths.

Project impact:

- Add troubleshooting guidance around `printenv netaddr` and `setenv netaddr`.
- Add user docs explaining that SGI-side IP mismatch can look like a server failure.

### IRIX Advanced Site and Server Administration Guide

Useful for `.rhosts` and trusted access background.

Relevant findings:

- `.rhosts` is an extension of trusted host/user access.
- Entry format is the same style as `hosts.equiv`.
- The remote station name and remote user must match for access.
- Root authentication treats `.rhosts` specially; `/etc/hosts.equiv` is not enough for root.

Project impact:

- Reinforces per-client `.rhosts` generation.
- Reinforces documenting the security risk and trusted-LAN requirement.

### IRIX Network Programming Guide

Low direct impact on this project.

Relevant findings:

- Confirms TFTP and RSH are standard network services in the IRIX networking context.
- Contains broader protocol/programming material but little direct remote-install setup guidance.

Project impact:

- Keep as background reference, not a primary documentation source.

### Spinlock Solutions Remote Install Guide

Most useful practical workflow source.

Relevant findings:

- Remote IRIX install needs BOOTP, TFTP, and RSH.
- `mksh` is used as the shell for the install account in the guide.
- The guide uses a non-root `irix` account and `.rhosts` for passwordless RSH.
- It uses openbsd-inetd examples; our container uses xinetd, but the service roles are equivalent.
- The guide configures TFTP with `-s` and a TFTP root directory.
- The first remotely booted files are from Installation Tools and Overlays media: `stand/`, `dist/sa`, and `dist/miniroot/`.
- Example early boot tests include booting `sash64` or `sashARCS`.
- Example disk preparation uses `fx.64 -x` or equivalent architecture-specific `fx`.
- `inst` later uses RSH, not TFTP, so distribution paths must work through the install account.
- The guide warns that HTTP support in IRIX `inst` is unreliable and recommends local/served distribution repositories instead.

Project impact:

- Add a practical "using the install server" guide based on the flow: test `sash`, run `fx`, boot miniroot, open distributions, install.
- Keep RSH support as first-class.
- Validate `tftpd-hpa` only after checking that SGI boot tests can fetch `sash` and `fx`.

## Recommended Follow-Up Documentation Files

- `docs/user-guide.md`
  - End-to-end workflow for preparing media, configuring clients, testing `sash`, running `fx`, booting miniroot, and opening distributions.

- `docs/troubleshooting.md`
  - BOOTP/TFTP/RSH diagnostics, container checks, SGI PROM checks, and common path/IP mistakes.

- `docs/media-layout.md`
  - Expected `/DIST` structure and examples using the current staged directories `6.5`, `6.5.22`, `6.5.30`, `onc3nfs`, and `patch`.

## Open Questions for Runtime Testing

- What exact `inst from` path convention should we document for this container when using `guest` and `/DIST`?
- Should the maintained image keep only `guest`, or also add an `irix` account for compatibility with common third-party guides?
- Should the entrypoint generate `.rhosts` entries as hostnames only, IP addresses only, or both? Official docs emphasize hostnames; the Spinlock guide notes IP-specific entries can be used.

## Verified Hardware Result

On 2026-06-13, an SGI Octane2 successfully booted `sash64` from the maintained Bookworm-based container using:

```text
bootp():6.5.30/stand/sash64 -x
```

The SGI reported standalone shell `Version 6.5 ARCS Apr 30, 1998 (64 Bit)`, and basic `sash` commands such as `ls` and `help` worked. This confirms the new image's BOOTP/TFTP path works with real SGI hardware for the initial network boot stage.
