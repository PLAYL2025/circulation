# ---------- build ----------
FROM python:3.11-slim AS build

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# deps de sistema para compilar libs python (psycopg2 etc.)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libpq-dev curl ca-certificates git && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# copie manifestos primeiro para cache de deps
COPY pyproject.toml poetry.lock* ./
# se o projeto não usa Poetry, troque para requirements*.txt e pip install

# instalar Poetry sem venv
RUN pip install --no-cache-dir poetry && \
    poetry config virtualenvs.create false

# instale deps (sem dev)
RUN poetry install --no-interaction --no-ansi --without dev

# copie o código
COPY . .

# ---------- runtime ----------
FROM python:3.11-slim AS runtime

# libs de runtime (psycopg2 binário precisa do libpq5)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# copie tudo que o build instalou + código
COPY --from=build /usr/local /usr/local
COPY --from=build /app /app

# gunicorn (caso não venha das deps do projeto)
RUN pip install --no-cache-dir gunicorn

EXPOSE 80

# IMPORTANTE: --factory porque o entrypoint é uma factory
# Dica: worker-tmp em tmpfs reduz IO
CMD ["gunicorn", \
     "--workers", "3", "--threads", "4", "--timeout", "120", \
     "--worker-tmp-dir", "/dev/shm", \
     "-b", "0.0.0.0:80", \
     "--factory", "palace.manager.api.app:initialize_application()"]
