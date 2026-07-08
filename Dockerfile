# ─────────────────────────────────────────────────────────
# KadianAI LABS — static site container (nginx, non-root)
# ─────────────────────────────────────────────────────────
FROM nginxinc/nginx-unprivileged:1.27-alpine

# nginx-unprivileged runs as UID 101 and listens on 8080 by default.
USER root

# Replace default config with our hardened, header-preserving config.
RUN rm -f /etc/nginx/conf.d/default.conf
COPY nginx/nginx.conf        /etc/nginx/nginx.conf
COPY nginx/default.conf      /etc/nginx/conf.d/default.conf

# Copy the static site content.
COPY --chown=101:101 index.html 404.html favicon.svg robots.txt sitemap.xml kadianai-website.html /usr/share/nginx/html/

USER 101
EXPOSE 8080

# Basic container-level healthcheck (k8s probes are the real gate).
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/bin/sh", "-c", "wget -q -O /dev/null http://127.0.0.1:8080/ || exit 1"]

STOPSIGNAL SIGQUIT
CMD ["nginx", "-g", "daemon off;"]
