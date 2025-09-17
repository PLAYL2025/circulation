# ---------- build ----------
FROM python:3.11-slim AS build

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# deps de sistema para compilar libs python (uwsgi, xmlsec, lxml, pillow, psycopg2 etc.)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential python3-dev libpq-dev curl ca-certificates git \
    pkg-config libffi-dev zlib1g-dev \
    libxml2-dev libxslt1-dev libxmlsec1-dev libxmlsec1-openssl \
    libjpeg62-turbo-dev libpcre3-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# copie manifestos primeiro para cache de deps
COPY pyproject.toml poetry.lock* ./

# instalar Poetry sem venv e atualizar pip toolchain
RUN pip install --no-cache-dir --upgrade pip setuptools wheel poetry && \
    poetry config virtualenvs.create false

# instale deps (sem dev)
RUN poetry install -vvv --no-interaction --no-ansi --without dev

# copie o código
COPY . .

# ---------- runtime ----------
FROM python:3.11-slim AS runtime

# libs de runtime necessárias
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 ca-certificates \
    libxml2 libxslt1.1 libxmlsec1 libxmlsec1-openssl libffi8 libpcre3 && \
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
