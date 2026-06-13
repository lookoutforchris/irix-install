#!/bin/sh
set -eu

BOOTPTAB="${BOOTPTAB:-/etc/bootptab}"
RHOSTS_USERS="${RHOSTS_USERS:-root guest}"

tmp_rhosts="$(mktemp)"
trap 'rm -f "$tmp_rhosts"' EXIT

if [ -r "$BOOTPTAB" ]; then
    awk '
        /^[[:space:]]*(#|$)/ { next }
        {
            line = $0
            sub(/[[:space:]]+#.*/, "", line)
            sub(/^[[:space:]]+/, "", line)
            sub(/[[:space:]]+$/, "", line)
            if (line == "") next

            split(line, fields, ":")
            host = fields[1]
            gsub(/[[:space:]]/, "", host)

            if (host != "" && host !~ /^\./) {
                print host " root"
            }
        }
    ' "$BOOTPTAB" | sort -u > "$tmp_rhosts"
fi

for user in $RHOSTS_USERS; do
    home="$(getent passwd "$user" | cut -d: -f6 || true)"
    if [ -n "$home" ] && [ -d "$home" ]; then
        cp "$tmp_rhosts" "$home/.rhosts"
        chmod 0644 "$home/.rhosts"
        chown "$user:$user" "$home/.rhosts"
    fi
done

exec /usr/sbin/xinetd -dontfork
