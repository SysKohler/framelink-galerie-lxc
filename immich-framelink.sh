#!/usr/bin/env bash
# Framelink-Immich Setup mit Branding-Overlay
...
cp -a web/build "$APP_DIR"/www
# Branding Overlay: Framelink-Galerie
mkdir -p "$APP_DIR"/www/assets
curl -fsSL https://raw.githubusercontent.com/SysKohler/framelink-galerie-lxc/main/branding/logo.png -o "$APP_DIR"/www/assets/logo.png
curl -fsSL https://raw.githubusercontent.com/SysKohler/framelink-galerie-lxc/main/branding/index.html -o "$APP_DIR"/www/index.html
# Weitere Schritte...
