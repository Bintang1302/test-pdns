FROM alpine:3.20

# 1. Install PowerDNS, MySQL backend, dan MariaDB client
RUN apk add --no-cache pdns pdns-backend-mysql mariadb-client bash curl

# 2. Buat grup/user dengan toleransi ID 999 jika sudah terpakai oleh sistem bawaan
RUN (addgroup -g 999 container || true) && \
    (adduser -D -u 999 -G container -h /home/container container || adduser -D -u 999 -G $(getent group 999 | cut -d: -f1) -h /home/container container)

# 3. Buat folder yang diperlukan dan berikan hak akses
RUN mkdir -p /home/container /var/run/pdns /etc/pdns && \
    chown -R 999:999 /home/container /var/run/pdns /etc/pdns

# 4. Atur lingkungan kerja sesuai standar Pterodactyl Wings
USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container

# 5. Eksekusi entrypoint kustom Anda
COPY ./entrypoint.sh /entrypoint.sh
CMD ["/bin/bash", "/entrypoint.sh"]
