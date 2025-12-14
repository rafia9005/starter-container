#!/bin/bash

# --- Configuration ---
VERSION="3.8.0"
ARCH="linux-amd64"
FILENAME="prometheus-${VERSION}.${ARCH}.tar.gz"
DOWNLOAD_URL="https://github.com/prometheus/prometheus/releases/download/v${VERSION}/${FILENAME}"
TEMP_DIR="/tmp/prometheus_install"

# --- Pre-Check ---
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo (e.g., sudo ./install_prometheus.sh)"
  exit 1
fi

echo "--- Starting Prometheus v${VERSION} Installation ---"

# Create temp directory
mkdir -p ${TEMP_DIR}
cd ${TEMP_DIR}

# --- 1. Setup User and Directories ---
echo "1. Setting up 'prometheus' user and directories..."
useradd --no-create-home --shell /bin/false prometheus
mkdir -p /etc/prometheus
mkdir -p /var/lib/prometheus

# --- 2. Download and Extract ---
echo "2. Downloading and extracting Prometheus binary..."
wget ${DOWNLOAD_URL}
tar xvf ${FILENAME}

# Get the extracted directory name
EXTRACTED_DIR=$(find . -maxdepth 1 -type d -name "prometheus-*" | head -n 1)

if [ -z "$EXTRACTED_DIR" ]; then
    echo "Error: Extraction failed. Exiting."
    exit 1
fi

# --- 3. Move Binaries and Configuration ---
echo "3. Moving binaries and configuration files..."

# Move binaries
cp ${EXTRACTED_DIR}/prometheus /usr/local/bin/
cp ${EXTRACTED_DIR}/promtool /usr/local/bin/

# Set ownership for binaries
chown prometheus:prometheus /usr/local/bin/prometheus
chown prometheus:prometheus /usr/local/bin/promtool

# Move default configuration file
cp ${EXTRACTED_DIR}/prometheus.yml /etc/prometheus/

# Set ownership for configuration and data directories
chown -R prometheus:prometheus /etc/prometheus
chown -R prometheus:prometheus /var/lib/prometheus

# --- 4. Create Systemd Service File ---
echo "4. Creating systemd service file (prometheus.service)..."
tee /etc/systemd/system/prometheus.service > /dev/null <<EOF
[Unit]
Description=Prometheus Time-Series Monitoring Server
Documentation=https://prometheus.io/docs/
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
Restart=on-failure
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus \
    --web.listen-address=0.0.0.0:9090

[Install]
WantedBy=multi-user.target
EOF

# --- 5. Clean Up and Start Service ---
echo "5. Reloading systemd, starting, and enabling service..."

# Clean up
rm -rf ${TEMP_DIR}

# Reload daemon
systemctl daemon-reload

# Start and enable
systemctl start prometheus
systemctl enable prometheus

echo "--- Installation Complete ---"
echo "Status:"
systemctl status prometheus | grep "Active:"
echo "Access Prometheus at: http://<Your-Server-IP>:9090"
