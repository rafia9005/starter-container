# Set the latest version variable
VERSION="3.8.0"
ARCH="linux-amd64"
FILENAME="prometheus-${VERSION}.${ARCH}.tar.gz"
DOWNLOAD_URL="https://github.com/prometheus/prometheus/releases/download/v${VERSION}/${FILENAME}"

echo "Downloading Prometheus v${VERSION}..."
wget ${DOWNLOAD_URL}

# Create Prometheus user, group, and directories
sudo useradd --no-create-home --shell /bin/false prometheus
sudo mkdir /etc/prometheus
sudo mkdir /var/lib/prometheus

# Extract the archive
tar xvf ${FILENAME}

# Move binaries and set ownership
sudo cp prometheus-${VERSION}.${ARCH}/prometheus /usr/local/bin/
sudo cp prometheus-${VERSION}.${ARCH}/promtool /usr/local/bin/
sudo chown prometheus:prometheus /usr/local/bin/prometheus
sudo chown prometheus:prometheus /usr/local/bin/promtool

# Move config and console files, then set ownership
sudo cp -r prometheus-${VERSION}.${ARCH}/consoles /etc/prometheus
sudo cp -r prometheus-${VERSION}.${ARCH}/console_libraries /etc/prometheus
sudo cp prometheus-${VERSION}.${ARCH}/prometheus.yml /etc/prometheus/
sudo chown -R prometheus:prometheus /etc/prometheus
sudo chown -R prometheus:prometheus /var/lib/prometheus

# Clean up downloaded files
rm -rf prometheus-${VERSION}.${ARCH} ${FILENAME}

sudo tee /etc/systemd/system/prometheus.service > /dev/null <<EOF
[Unit]
Description=Prometheus Server
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
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries \
    --web.listen-address=0.0.0.0:9090

[Install]
WantedBy=multi-user.target
EOF
