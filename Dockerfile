FROM node:20-alpine as build

WORKDIR /app

RUN apk add --no-cache git

# Immich-Repo klonen
RUN git clone https://github.com/immich-app/immich.git .

# In das Web-Frontend wechseln
WORKDIR /app/apps/web

# Logo einfügen (angepasster Pfad)
COPY logo.png ./src/assets/logo.png

# Branding ersetzen – nur wenn Dateien vorhanden sind
RUN [ -f ./src/index.html ] && sed -i 's/<title>Immich/<title>Framelink-Galerie/' ./src/index.html || true
RUN find ./src -type f -exec sed -i 's/Immich/Framelink-Galerie/g' {} + || true
RUN sed -i 's/appName: "Immich"/appName: "Framelink-Galerie"/' ./src/app/constants.ts || true
RUN sed -i 's/"name": "Immich"/"name": "Framelink-Galerie"/' ./src/manifest.webmanifest || true
RUN sed -i 's/"short_name": "Immich"/"short_name": "Framelink"/' ./src/manifest.webmanifest || true

# Build starten
RUN npm install && npm run build

# Output-Stage
FROM nginx:alpine
COPY --from=build /app/apps/web/dist/immich /usr/share/nginx/html
