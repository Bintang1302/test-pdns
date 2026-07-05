FROM alpine:3.20

# Tambahkan mariadb-client ke dalam instalasi paket apk
RUN apk add --no-cache pdns pdns-backend-mysql mariadb-client bash curl

# Pengaturan User ID 999 untuk standar Pterodactyl
RUN sed -i 's/^ping:x:999:999:/container:x:999:999:/' /etc/passwd && \
    sed -i 's/^ping:x:999:/container:x:999:/' /etc/group && \
    mkdir -p /home/container /var/run/pdns /etc/pdns && \
    chown -R container:container /home/container /var/run/pdns /etc/pdns

USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container

COPY ./entrypoint.sh /entrypoint.sh
CMD ["/bin/bash", "/entrypoint.sh"]
