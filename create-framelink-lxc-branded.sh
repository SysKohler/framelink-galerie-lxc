#!/bin/bash

set -e

# 🧠 Nutzerabfragen
read -p "LXC Container ID (z. B. 201): " CT_ID
read -p "Hostname (z. B. framelink-galerie): " HOSTNAME
read -p "Storage-Name (z. B. local, local-lvm): " STORAGE
read -p "Größe Root-FS in GB (z. B. 8): " DISK_SIZE
read -p "RAM in MB (z. B. 2048): " RAM
read -p "Anzahl CPU-Kerne (z. B. 2): " CPU

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
  apt update && apt install -y curl git docker.io docker-compose unzip

  mkdir -p /opt/framelink-galerie
  cd /opt/framelink-galerie

  echo "⬇️ Lade Branding-Paket..."
  curl -L https://raw.githubusercontent.com/SysKohler/framelink-galerie-lxc/main/framelink-galerie-branding.zip -o branding.zip
  unzip branding.zip
  rm branding.zip

  echo "📄 Erstelle docker-compose.yml..."
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

volumes:
  pgdata:
EOF

  echo "📦 Starte Immich + Framelink-Web Branding..."
  docker-compose up -d
'

echo "✅ Framelink-Galerie LXC-Container $CT_ID wurde erfolgreich eingerichtet!"
