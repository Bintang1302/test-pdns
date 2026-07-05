#!/bin/bash
cd /home/container

# 1. Mengonversi variabel startup dari panel Pterodactyl
MODIFIED_STARTUP=$(echo -e -e "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g')

echo "====== MEMERIKSA DATABASE ======"

# 2. Cek apakah tabel 'domains' sudah ada di database MySQL target
TABLE_CHECK=$(mysql -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -D "${MYSQL_DB}" -e "SHOW TABLES LIKE 'domains';" -s -N 2>/dev/null)

if [ "$TABLE_CHECK" = "domains" ]; then
    echo "[INFO] Tabel PowerDNS sudah ditemukan. Melewati proses import (SKIP)."
else
    echo "[WARNING] Tabel PowerDNS belum ada! Memulai pemasangan skema otomatis..."
    
    # Download skema resmi PowerDNS terbaru dari official repository
    curl -sSL https://raw.githubusercontent.com/PowerDNS/pdns/master/modules/gmysqlbackend/schema.mysql.sql -o /tmp/schema.sql
    
    # Import skema ke MySQL user
    mysql -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -D "${MYSQL_DB}" < /tmp/schema.sql
    
    if [ $? -eq 0 ]; then
        echo "[SUCCESS] Skema database PowerDNS berhasil dipasang!"
    else
        echo "[ERROR] Gagal memasang skema database! Periksa kembali hak akses user MySQL Anda."
        exit 1
    fi
fi

echo "====== MENJALANKAN POWERDNS ======"
# 3. Jalankan perintah utama PowerDNS
eval ${MODIFIED_STARTUP}
