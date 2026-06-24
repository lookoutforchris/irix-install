FROM debian:bookworm-slim

LABEL org.opencontainers.image.source="https://github.com/lookoutforchris/irix-install"
LABEL org.opencontainers.image.description="Docker-based SGI IRIX network install server"
LABEL org.opencontainers.image.licenses="MIT"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bootp \
        mksh \
        rsh-redone-server \
        tftpd-hpa \
        xinetd \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -c "Guest User" -d /home/guest -m -s /bin/mksh guest \
    && chsh -s /bin/mksh root \
    && passwd -d root \
    && passwd -d guest \
    && mkdir -p /home/guest/irix

COPY docker/xinetd.d/bootps /etc/xinetd.d/bootps
COPY docker/xinetd.d/tftp /etc/xinetd.d/tftp
COPY docker/xinetd.d/rsh /etc/xinetd.d/rsh
COPY docker/xinetd.conf /etc/xinetd.conf
COPY docker/entrypoint.sh /usr/local/sbin/irix-install-entrypoint

RUN chmod 0644 /etc/xinetd.d/bootps /etc/xinetd.d/tftp /etc/xinetd.d/rsh \
    && chmod 0644 /etc/xinetd.conf \
    && chmod 0755 /usr/local/sbin/irix-install-entrypoint

VOLUME ["/home/guest/irix"]

EXPOSE 67/udp 69/udp 514/tcp

ENTRYPOINT ["/usr/local/sbin/irix-install-entrypoint"]
