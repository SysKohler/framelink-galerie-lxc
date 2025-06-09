FROM node:20-alpine as build

WORKDIR /app

RUN apk add --no-cache git

# Repo klonen
RUN git clone https://github.com/immich-app/immich.git .

# Logo hinzufügen
COPY logo.png ./apps/web/src/assets/logo.png

# Branding – nur bei vorhandenen Dateien
RUN [ -f ./apps/web/src/index.html ] && sed -i 's/<title>Immich/<title>Framelink-Galerie/' ./apps/web/src/index.html || true
RUN find ./apps/web/src -type f -exec sed -i 's/Immich/Framelink-Galerie/g' {} + || true
RUN sed -i 's/appName: "Immich"/appName: "Framelink-Galerie"/' ./apps/web/src/app/constants.ts || true
RUN sed -i 's/"name": "Immich"/"name": "Framelink-Galerie"/' ./apps/web/src/manifest.webmanifest || true
RUN sed -i 's/"short_name": "Immich"/"short_name": "Framelink"/' ./apps/web/src/manifest.webmanifest || true

# Installieren & Build (Monorepo)
RUN npm install
RUN npm run build:web

# Output über NGINX
FROM nginx:alpine
COPY --from=build /app/dist/apps/web /usr/share/nginx/html
