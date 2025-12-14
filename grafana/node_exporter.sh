#!/bin/bash

# --- Configuration ---
NE_VERSION="1.7.0"  # Versi Node Exporter (ganti jika ada yang lebih baru)
NE_ARCH="linux-amd64"
NE_FILENAME="node_exporter-${NE_VERSION}.${NE_ARCH}.tar.gz"
NE_DOWNLOAD_URL="https://github.com/prometheus/node_exporter/releases/download/v${NE_VERSION}/${NE_FILENAME}"
TEMP_DIR="/tmp/node_exporter_install"
PROMETHEUS_CONFIG="/etc/prometheus/prometheus.yml"

# --- Pre-Check ---
if [ "$EUID" -ne 0 ]; then
  echo "Harap jalankan script ini dengan sudo (contoh: sudo ./install_node_exporter.sh)"
  exit 1
fi

echo "--- Memulai Instalasi Node Exporter v${NE_VERSION} ---"

# Buat direktori sementara
mkdir -p ${TEMP_DIR}
cd ${TEMP_DIR}

# --- 1. Setup User dan Direktori ---
echo "1. Menyiapkan user 'node_exporter'..."
# Pastikan user belum ada sebelum dibuat
id -u node_exporter &>/dev/null || useradd --no-create-home --shell /bin/false node_exporter

# --- 2. Download dan Ekstrak ---
echo "2. Mendownload dan mengekstrak Node Exporter binary..."
wget ${NE_DOWNLOAD_URL}
tar xvf ${NE_FILENAME}

# Dapatkan nama direktori hasil ekstrak
EXTRACTED_DIR=$(find . -maxdepth 1 -type d -name "node_exporter-*" | head -n 1)

if [ -z "$EXTRACTED_DIR" ]; then
    echo "Error: Ekstraksi gagal. Keluar."
    exit 1
fi

# --- 3. Pindahkan Binary ---
echo "3. Memindahkan binary Node Exporter..."
cp ${EXTRACTED_DIR}/node_exporter /usr/local/bin/
chown node_exporter:node_exporter /usr/local/bin/node_exporter

# --- 4. Buat Systemd Service File ---
echo "4. Membuat systemd service file (node_exporter.service)..."
tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
Restart=on-failure
ExecStart=/usr/local/bin/node_exporter \
    --web.listen-address=":9100"

[Install]
WantedBy=multi-user.target
EOF

# --- 5. Start dan Enable Service ---
echo "5. Reload systemd, memulai, dan mengaktifkan service..."

# Reload daemon
systemctl daemon-reload

# Start dan enable
systemctl start node_exporter
systemctl enable node_exporter

echo "Node Exporter Status:"
systemctl status node_exporter | grep "Active:"

# --- 6. Konfigurasi Prometheus untuk Scrape ---
echo "6. Mengkonfigurasi Prometheus (${PROMETHEUS_CONFIG}) untuk scraping Node Exporter (port 9100)..."

# Cek apakah job Node Exporter sudah ada
if grep -q "job_name: \"node_exporter\"" "$PROMETHEUS_CONFIG"; then
    echo "Job 'node_exporter' sudah ada di konfigurasi Prometheus. Melewati penambahan."
else
    # Tambahkan job baru ke scrape_configs
    cat <<EOT >> ${PROMETHEUS_CONFIG}

  - job_name: "node_exporter"
    static_configs:
      - targets: ["localhost:9100"]
EOT
    echo "Job 'node_exporter' berhasil ditambahkan ke konfigurasi."
fi

# --- 7. Restart Prometheus ---
echo "7. Me-restart Prometheus untuk memuat konfigurasi baru..."
systemctl restart prometheus

echo "Prometheus Status (setelah restart):"
systemctl status prometheus | grep "Active:"

# --- Cleanup ---
rm -rf ${TEMP_DIR}

echo ""
echo "--- Instalasi Node Exporter Selesai ---"
echo "Node Exporter berjalan di: http://<Server-IP>:9100/metrics"
echo "Cek target di Prometheus UI (Port 9001): http://<Server-IP>:9001/targets"
