# --- Dockerfile: packages the Node.js SSR frontend into a runnable image ---
# The BUILD pipeline builds this image and pushes it to AWS ECR.
# The DEPLOY pipeline tells EC2 to pull and run it.

FROM node:20-alpine

# Don't run as root in the container.
ENV NODE_ENV=production
WORKDIR /app

# Install deps first so Docker caches this layer when only code changes.
COPY package*.json ./
RUN npm ci --omit=dev

# Copy the application code.
COPY . .

# Build-time version stamp (passed via --build-arg in the pipeline).
ARG APP_VERSION=dev
ENV APP_VERSION=$APP_VERSION
ENV PORT=3000

# node:alpine ships an unprivileged "node" user.
USER node

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:3000/health || exit 1

CMD ["node", "server.js"]
