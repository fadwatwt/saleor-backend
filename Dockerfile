FROM python:3.12-slim

RUN apt-get update && apt-get install -y \
    gettext \
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
    build-essential \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=ghcr.io/astral-sh/uv:0.8 /uv /uvx /bin/

COPY pyproject.toml uv.lock ./

ENV UV_SYSTEM_PYTHON=1
RUN uv sync --locked --no-install-project --no-editable

COPY . .

ENV STATIC_URL=/static/
ENV PYTHONUNBUFFERED=1

RUN SECRET_KEY=dummy python3 manage.py collectstatic --no-input

EXPOSE 10000

CMD ["sh", "-c", "uvicorn saleor.asgi:application --host=0.0.0.0 --port=${PORT:-10000} --workers=1"]
