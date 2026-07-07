#!/bin/bash

# Pindah ke direktori utama Pterodactyl
cd /home/container

# 1. Konversi variabel startup panel
MODIFIED_STARTUP=$(echo -e "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g')

echo "====== PERSIAPAN STRUKTUR FILE POWERDNS ======"

# Buat folder-folder penting di /home/container jika belum ada
mkdir -p /home/container/bin
mkdir -p /home/container/modules
mkdir -p /home/container/etc
mkdir -p /home/container/run

# Mengambil informasi versi aktual yang terpasang di sistem container
INSTALLED_VERSION=$(pdns_server --version 2>&1 | head -n 1 | awk '{print $2}')
echo "[INFO] Versi PowerDNS aktif di sistem: $INSTALLED_VERSION"

# Selalu perbarui file eksekusi dan modul di File Manager agar sesuai dengan versi image terbaru
echo "[INFO] Menyinkronkan file eksekusi PowerDNS ke /home/container/bin/..."
cp /usr/sbin/pdns_server /home/container/bin/
chmod +x /home/container/bin/pdns_server

echo "[INFO] Menyinkronkan modul backend database ke /home/container/modules/..."
rm -f /home/container/modules/*.so  # Bersihkan modul lama agar tidak bentrok versi
cp -r /usr/lib/pdns/pdns/*.so /home/container/modules/ 2>/dev/null

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
TABLE_CHECK=$(mysql -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -D "${MYSQL_DB}" --skip-ssl -e "SHOW TABLES LIKE 'domains';" -s -N 2>/dev/null)

if [ "$TABLE_CHECK" = "domains" ]; then
    echo "[INFO] Tabel PowerDNS sudah ditemukan di MySQL. SKIP import."
else
    echo "[WARNING] Tabel PowerDNS kosong! Mengunduh skema otomatis..."
    
    curl -sSL https://raw.githubusercontent.com/PowerDNS/pdns/master/modules/gmysqlbackend/schema.mysql.sql -o /tmp/schema.sql

    mysql -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -D "${MYSQL_DB}" --skip-ssl < /tmp/schema.sql
    
    if [ $? -eq 0 ]; then
        echo "[SUCCESS] Skema database berhasil dipasang!"
    else
        echo "[ERROR] Gagal memasang skema database. Cek izin user MySQL Anda."
        exit 1
    fi
fi

echo "====== MENJALANKAN POWERDNS & INTERAKTIF KONSOL ======"

# Buat Named Pipe (FIFO) untuk menangkap input konsol
PIPE_INPUT="/home/container/run/console.pipe"
rm -f "$PIPE_INPUT"
mkfifo "$PIPE_INPUT"

# Jalankan PowerDNS di background menggunakan tanda & (Fixed background process)
/home/container/bin/pdns_server --daemon=no --config-dir=/home/container/etc &
PDNS_PID=$!

# Fungsi untuk membersihkan proses jika server dimatikan panel
cleanup() {
    echo "[INFO] Menghentikan PowerDNS..."
    kill -TERM "$PDNS_PID" 2>/dev/null
    rm -f "$PIPE_INPUT"
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT

echo "[SUCCESS] PowerDNS berhasil berjalan di background."
echo "[TIPS] Anda bisa mengetik langsung di konsol ini!"
echo "[TIPS] Ketik 'help' atau 'menu' untuk melihat daftar perintah."
echo "--------------------------------------------------------"

# Loop interaktif membaca input konsol secara langsung tanpa interupsi servis
cat <> "$PIPE_INPUT" | while read -r cmd; do
    cmd=$(echo "$cmd" | xargs)
    [ -z "$cmd" ] && continue

    case "$cmd" in
        pdnsutil*)
            echo -e "\n\e[33m[KONSOL] Mengeksekusi Utilitas DNS...\e[0m"
            ARGS=${cmd#pdnsutil}
            /usr/bin/pdnsutil --config-dir=/etc/pdns $ARGS
            echo -e "\e[32m[KONSOL] Selesai.\e[0m\n"
            ;;

        pdns-control*)
            echo -e "\n\e[33m[KONSOL] Mengeksekusi Kontrol Internal...\e[0m"
            ARGS=${cmd#pdns-control}
            /usr/bin/pdns_control --socket-dir=/home/container/run $ARGS
            echo -e "\e[32m[KONSOL] Selesai.\e[0m\n"
            ;;

        "mysql-check")
            echo -e "\n\e[34m[KONSOL] Memeriksa Konektivitas Database Backend...\e[0m"
            TABLE_COUNT=$(mysql -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -D "${MYSQL_DB}" -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${MYSQL_DB}';" -s -N 2>/dev/null)
            if [ $? -eq 0 ]; then
                echo -e "\e[32m[SUKSES] Koneksi lancar! Ditemukan $TABLE_COUNT tabel di database '${MYSQL_DB}'.\e[0m\n"
            else
                echo -e "\e[31m[ERROR] Gagal terhubung ke MySQL. Periksa kembali variabel database Anda.\e[0m\n"
            fi
            ;;

        "help" | "menu")
            echo -e "\n\e[36m=================== MENU KONSOL POWERDNS ==================="
            echo "Berikut daftar perintah kustom yang bisa Anda gunakan:"
            echo "------------------------------------------------------------"
            echo "1. pdnsutil <perintah>   -> Kelola zona, rekam (record), & DNSSEC."
            echo "                            Contoh: pdnsutil create-zone test.com"
            echo "2. pdns-control <opsi>   -> Kontrol servis & bersihkan cache."
            echo "                            Contoh: pdns-control purge test.com"
            echo "3. mysql-check           -> Tes koneksi instan ke DB MySQL."
            echo "4. help / menu           -> Menampilkan pesan bantuan ini."
            echo "============================================================\e[0m\n"
            ;;

        *)
            echo -e "\e[31m[KONSOL] Perintah '$cmd' tidak dikenali.\e[0m"
            echo "Ketik 'help' atau 'menu' untuk melihat daftar perintah yang tersedia."
            ;;
    esac
done
