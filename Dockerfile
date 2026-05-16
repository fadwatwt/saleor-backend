FROM python:3.12 AS build-python

RUN apt-get update && apt-get install -y gettext \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=ghcr.io/astral-sh/uv:0.8 /uv /uvx /bin/
COPY pyproject.toml uv.lock ./

ENV UV_COMPILE_BYTECODE=1 \
    UV_SYSTEM_PYTHON=1 \
    UV_PROJECT_ENVIRONMENT=/usr/local

RUN uv sync --locked --no-install-project --no-editable

FROM python:3.12-slim

RUN groupadd -r saleor && useradd -r -g saleor saleor

RUN apt-get update && apt-get install -y \
    libffi8 \
    libgdk-pixbuf-2.0-0 \
    liblcms2-2 \
    libopenjp2-7 \
    libssl3 \
    libtiff6 \
    libwebp7 \
    libpq5 \
    libmagic1 \
    libcurl4 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=build-python /usr/local /usr/local
COPY . .

ENV PYTHONUNBUFFERED=1
ENV STATIC_URL=/static/

RUN SECRET_KEY=dummy python3 manage.py collectstatic --no-input

EXPOSE 10000

CMD ["sh", "-c", "uvicorn saleor.wsgi:application --host=0.0.0.0 --port=${PORT:-10000} --workers=${WEB_CONCURRENCY:-4}"]
