# --- Dockerfile: packages the Python backend microservice into an image ---
# The BUILD pipeline builds this image and pushes it to AWS ECR.
# The DEPLOY pipeline tells EC2 to pull and run it.

FROM python:3.12-slim

# Don't write .pyc files; flush logs immediately (nicer in container logs).
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Install deps first so Docker can cache this layer when only code changes.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application code.
COPY . .

# Build-time version stamp (passed via --build-arg in the pipeline).
ARG APP_VERSION=dev
ENV APP_VERSION=$APP_VERSION

# Run as a non-root user.
RUN useradd --create-home --uid 10001 appuser
USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health').status==200 else 1)"

# gunicorn = production WSGI server. "app:app" = module app.py, object `app`.
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "app:app"]
