#!/bin/bash

cd gitea && docker compose up -d && cd ..

cd komodo && docker compose -p komodo -f sqlite.compose.yaml --env-file ../compose.env up -d && cd ..

cd nginx-proxy-manager && docker compose up -d && cd ..

cd portainer && docker compose up -d && cd ..

echo "Semua container telah berjalan."
