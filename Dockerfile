# Render the current frontend at build time, then ship only static files.
FROM node:22-alpine AS build
WORKDIR /app
COPY src/Node/package*.json ./
RUN npm ci
COPY src/Node/build.js ./
COPY src/Node/views ./views
COPY src/Node/public ./public
ARG APP_VERSION=dev
ARG API_BASE_URL=
RUN APP_VERSION="$APP_VERSION" API_BASE_URL="$API_BASE_URL" npm run build

FROM nginxinc/nginx-unprivileged:stable-alpine
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --from=build --chown=101:101 /app/dist/ /usr/share/nginx/html/
USER 101
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1
STOPSIGNAL SIGQUIT
CMD ["nginx", "-g", "daemon off;"]
