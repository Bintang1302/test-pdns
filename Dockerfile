FROM alpine:3.20

# 1. Install PowerDNS, MySQL backend, dan MariaDB client untuk cek database otomatis
RUN apk add --no-cache pdns pdns-backend-mysql mariadb-client bash curl

# 2. Buat langsung user 'container' dengan GID & UID 999 (Sangat Aman di Alpine 3.20)
RUN addgroup -g 999 container && \
    adduser -D -u 999 -G container -h /home/container container

# 3. Buat folder yang diperlukan dan berikan hak akses ke user container
RUN mkdir -p /home/container /var/run/pdns /etc/pdns && \
    chown -R container:container /home/container /var/run/pdns /etc/pdns

# 4. Atur lingkungan kerja sesuai standar Pterodactyl Wings
USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container

# 5. Eksekusi entrypoint kustom Anda
COPY ./entrypoint.sh /entrypoint.sh
CMD ["/bin/bash", "/entrypoint.sh"]
