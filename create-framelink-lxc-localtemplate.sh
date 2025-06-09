#!/bin/bash

set -e

# 🧠 Nutzerabfragen
read -p "LXC Container ID (z. B. 201): " CT_ID
read -p "Hostname (z. B. framelink-galerie): " HOSTNAME
read -p "Storage-Name (z. B. local, local-lvm): " STORAGE
read -p "Größe Root-FS in GB (z. B. 8): " DISK_SIZE
read -p "RAM in MB (z. B. 2048): " RAM
read -p "Anzahl CPU-Kerne (z. B. 2): " CPU

# Vorlage auswählen
TEMPLATE_PATH="/var/lib/vz/template/cache/debian-12-standard_12.7-1_amd64.tar.zst"

if [ ! -f "$TEMPLATE_PATH" ]; then
  echo "❌ Template $TEMPLATE_PATH nicht gefunden. Abbruch."
  exit 1
fi

echo "📦 Erstelle LXC Container $CT_ID..."
pct create $CT_ID \
  $TEMPLATE_PATH \
  --ostype debian \
  --hostname $HOSTNAME \
  --storage $STORAGE \
  --rootfs ${STORAGE}:${DISK_SIZE} \
  --memory $RAM \
  --cores $CPU \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --unprivileged 1 \
  --features nesting=1 \
  --start 1

echo "🕒 Warte 10 Sekunden, bis Container hochfährt..."
sleep 10

echo "🚀 Setup von Framelink-Galerie im Container $CT_ID..."

pct exec $CT_ID -- bash -c '
  apt update && apt install -y curl git docker.io docker-compose nodejs npm
  mkdir -p /opt/framelink-galerie/web
  cd /opt/framelink-galerie

  echo "⬇️ Lade Logo herunter..."
  curl -L https://cloud.systemcamp.org/s/ADFWRxrja8yRYat/download -o web/logo.png

  echo "📦 Erstelle Dockerfile..."
  cat <<EOD > web/Dockerfile
FROM node:20-alpine as build
WORKDIR /app
RUN apk add --no-cache git
RUN git clone https://github.com/immich-app/immich.git .
WORKDIR /app/web
COPY logo.png ./src/assets/logo.png
RUN find ./src -type f -exec sed -i "s/Immich/Framelink-Galerie/g" {} + \
 && sed -i "s/<title>Immich/<title>Framelink-Galerie/" ./src/index.html \
 && sed -i "s/appName: \"Immich\"/appName: \"Framelink-Galerie\"/" ./src/app/constants.ts \
 && sed -i "s/\"name\": \"Immich\"/\"name\": \"Framelink-Galerie\"/" ./src/manifest.webmanifest \
 && sed -i "s/\"short_name\": \"Immich\"/\"short_name\": \"Framelink\"/" ./src/manifest.webmanifest
RUN npm install && npm run build
FROM nginx:alpine
COPY --from=build /app/web/dist/immich /usr/share/nginx/html
EOD

  echo "🧱 Erstelle docker-compose.yml..."
  cat <<EOF > docker-compose.yml
version: "3.8"
services:
  postgres:
    image: postgres:14
    restart: always
    environment:
      POSTGRES_USER: immich
      POSTGRES_PASSWORD: password
      POSTGRES_DB: immich
    volumes:
      - pgdata:/var/lib/postgresql/data

  redis:
    image: redis:alpine
    restart: always

  immich-server:
    image: ghcr.io/immich-app/immich-server:release
    depends_on:
      - redis
      - postgres
    environment:
      DB_URL: postgres://immich:password@postgres:5432/immich
      REDIS_HOSTNAME: redis
    volumes:
      - ./uploads:/usr/src/app/upload

  immich-machine-learning:
    image: ghcr.io/immich-app/immich-machine-learning:release
    depends_on:
      - immich-server
    volumes:
      - ./ml-cache:/cache

  framelink-web:
    build:
      context: ./web
    ports:
      - "80:80"
    depends_on:
      - immich-server

volumes:
  pgdata:
EOF

  docker-compose up -d --build
'

echo "✅ Framelink-Galerie Container ($CT_ID) ist eingerichtet und läuft!"
