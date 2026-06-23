# Runtime Configuration

Only these files are mounted into the container during normal deployment:

- `bootptab`: BOOTP client definitions for SGI systems.
- `hosts`: host name mappings visible inside the container.

The xinetd service definitions are baked into the image from `docker/xinetd.d/`.
Do not add or edit `config/xinetd.d/` for normal use; it is not mounted by
`docker-compose.yml`.

IRIX install media is mounted separately from `./irix` to `/home/guest/irix`.
