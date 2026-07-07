FROM alpine:3.20

# Variabel untuk menentukan versi PowerDNS (default ke terbaru di repositori edge)
# Contoh nilai saat build: "4.9", "4.8", atau dikosongkan "" untuk versi paling baru
ARG PDNS_VERSION=""

# 1. Tambahkan repositori edge untuk mendapatkan versi terbaru & install dependensi
RUN echo "https://dl-cdn.alpinelinux.org/alpine/latest-stable/main" >> /etc/apk/repositories && \
    apk update && \
    # Jika PDNS_VERSION diisi, pasang versi spesifik. Jika kosong, pasang versi terbaru.
    if [ -z "$PDNS_VERSION" ]; then \
        apk add --no-cache pdns pdns-backend-mysql; \
    else \
        apk add --no-cache pdns~=${PDNS_VERSION} pdns-backend-mysql~=${PDNS_VERSION}; \
    fi && \
    apk add --no-cache mariadb-client bash curl

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

# 5. Eksekusi entrypoint kustom
COPY ./entrypoint.sh /entrypoint.sh
CMD ["/bin/bash", "/entrypoint.sh"]
