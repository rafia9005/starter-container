#!/bin/bash

check_port() {
  netstat -tuln | grep ":$1 " > /dev/null
  return $?
}

get_random_unused_port() {
  local port
  for i in {1..5}; do
    port=$((RANDOM % 10000 + 8000))
    if ! check_port $port; then
      echo $port
      return 0
    fi
  done
  echo "No available port found. Please try again later."
  exit 1
}

echo "Enter hosting name (e.g., rafi):"
read HOST_NAME

echo "Enter network name (e.g., ${HOST_NAME}_network):"
read NETWORK_NAME

echo "Enter MySQL username:"
read MYSQL_USER

echo "Enter MySQL password:"
read -s MYSQL_PASSWORD

NGINX_PORT=$(get_random_unused_port)
PHPMYADMIN_PORT=$(get_random_unused_port)
FILEBROWSER_PORT=$(get_random_unused_port)

cat > docker-compose.yml <<EOF
version: '3.8'

services:
  nginx:
    image: nginx:latest
    container_name: ${HOST_NAME}_nginx
    ports:
      - "${NGINX_PORT}:80"
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf
      - /var/www/${HOST_NAME}/web:/var/www/html
    depends_on:
      - php
    networks:
      - ${NETWORK_NAME}

  php:
    build:
      context: ./php
    container_name: ${HOST_NAME}_php
    volumes:
      - /var/www/${HOST_NAME}/web:/var/www/html
    networks:
      - ${NETWORK_NAME}

  mysql:
    image: mysql:5.7
    container_name: ${HOST_NAME}_mysql
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_PASSWORD}
      MYSQL_DATABASE: ${HOST_NAME}_db
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    volumes:
      - db-data:/var/lib/mysql
    networks:
      - ${NETWORK_NAME}

  phpmyadmin:
    image: phpmyadmin/phpmyadmin
    container_name: ${HOST_NAME}_phpmyadmin
    environment:
      PMA_HOST: ${HOST_NAME}_mysql
      MYSQL_ROOT_PASSWORD: ${MYSQL_PASSWORD}
    ports:
      - "${PHPMYADMIN_PORT}:80"
    depends_on:
      - mysql
    networks:
      - ${NETWORK_NAME}

  filebrowser:
    image: hurlenko/filebrowser
    container_name: ${HOST_NAME}_filebrowser
    ports:
      - "${FILEBROWSER_PORT}:8080"
    volumes:
      - /var/www/${HOST_NAME}/web:/data
      - /var/www/${HOST_NAME}/filebrowser.db:/config
    environment:
      - FB_BASEURL=/filebrowser
    networks:
      - ${NETWORK_NAME}
    restart: unless-stopped

volumes:
  db-data:

networks:
  ${NETWORK_NAME}:
    driver: bridge
EOF

cp ./web/index.html /var/www/${HOST_NAME}/web/index.html

echo "Docker Compose file has been generated as docker-compose.yml"
echo "NGINX port: $NGINX_PORT"
echo "PHPMyAdmin port: $PHPMYADMIN_PORT"
echo "FileBrowser port: $FILEBROWSER_PORT"

echo "Setup complete!"

