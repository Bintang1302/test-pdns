#!/bin/bash
# Pindah ke direktori utama Pterodactyl
cd /home/container

# 1. Konversi variabel startup panel
MODIFIED_STARTUP=$(echo -e -e "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g')

echo "====== PERSIAPAN STRUKTUR FILE POWERDNS ======"

# Buat folder-folder penting di /home/container jika belum ada
mkdir -p /home/container/bin
mkdir -p /home/container/modules
mkdir -p /home/container/etc
mkdir -p /home/container/run

# Salin aplikasi utama pdns_server ke folder lokal server jika belum ada
if [ ! -f "/home/container/bin/pdns_server" ]; then
    echo "[INFO] Menyalin file eksekusi PowerDNS ke /home/container/bin/..."
    cp /usr/sbin/pdns_server /home/container/bin/
    chmod +x /home/container/bin/pdns_server
fi

# Salin modul database (MySQL backend .so) ke folder lokal server jika belum ada
if [ -z "$(ls -A /home/container/modules 2>/dev/null)" ]; then
    echo "[INFO] Menyalin modul backend database ke /home/container/modules/..."
    cp -r /usr/lib/pdns/pdns/*.so /home/container/modules/ 2>/dev/null
fi

# Buat file konfigurasi pdns.conf di dalam /home/container/etc/ jika belum ada
if [ ! -f "/home/container/etc/pdns.conf" ]; then
    echo "[INFO] Membuat file konfigurasi utama di /home/container/etc/pdns.conf..."
    cat <<EOF > /home/container/etc/pdns.conf
# File Konfigurasi PowerDNS Pterodactyl
# Anda bebas mengedit file ini langsung dari File Manager Panel!

launch=gmysql
gmysql-host=${MYSQL_HOST}
gmysql-port=${MYSQL_PORT}
gmysql-user=${MYSQL_USER}
gmysql-password=${MYSQL_PASSWORD}
gmysql-dbname=${MYSQL_DB}

local-port=${SERVER_PORT}
local-address=0.0.0.0

# Paksa menggunakan modul yang ada di folder File Manager
module-dir=/home/container/modules

# Hindari error Read-only dengan mematikan socket file eksternal
control-console=yes
socket-dir=/home/container/run
EOF
fi

echo "====== MEMERIKSA DATABASE ======"
TABLE_CHECK=$(mysql -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -D "${MYSQL_DB}" -e "SHOW TABLES LIKE 'domains';" -s -N 2>/dev/null)

if [ "$TABLE_CHECK" = "domains" ]; then
    echo "[INFO] Tabel PowerDNS sudah ditemukan di MySQL. SKIP import."
else
    echo "[WARNING] Tabel PowerDNS kosong! Mengunduh skema otomatis..."
    curl -sSL https://raw.githubusercontent.com/PowerDNS/pdns/master/modules/gmysqlbackend/schema.mysql.sql -o /tmp/schema.sql
    mysql -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -D "${MYSQL_DB}" < /home/container/etc/schema.mysql.sql
    if [ $? -eq 0 ]; then
        echo "[SUCCESS] Skema database berhasil dipasang!"
    else
        echo "[ERROR] Gagal memasang skema database. Cek izin user MySQL Anda."
        exit 1
    fi
fi

echo "====== MENJALANKAN POWERDNS DARI FILE MANAGER ======"
# 2. Jalankan perintah startup kustom
eval ${MODIFIED_STARTUP}
