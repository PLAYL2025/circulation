# ---- Build stage ----
FROM python:3.11-slim AS build

ENV PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    POETRY_VERSION=1.8.3

# System deps needed to build Python packages (e.g., psycopg2)
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    curl \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Only copy dependency files first to leverage Docker layer caching
COPY pyproject.toml poetry.lock ./

# Install Poetry and project dependencies (no virtualenv, install into system site-packages)
RUN pip install --no-cache-dir "poetry==${POETRY_VERSION}" \
 && poetry config virtualenvs.create false \
 && poetry install --without dev --no-interaction --no-ansi \
 && pip install --no-cache-dir gunicorn

# Copy the rest of the application source
COPY . .

# ---- Runtime stage ----
FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Runtime libs (e.g., libpq for psycopg2)
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    libpq5 \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Bring in installed packages and application code from build stage
COPY --from=build /usr/local /usr/local
COPY --from=build /app /app

EXPOSE 80

# WSGI app factory detected: palace.manager.api.app:initialize_application()
CMD ["gunicorn", "--workers", "3", "--threads", "4", "--timeout", "120", "-b", "0.0.0.0:80", "palace.manager.api.app:initialize_application()"]
