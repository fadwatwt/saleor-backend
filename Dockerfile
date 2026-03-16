### Build and install packages
FROM python:3.12 AS build-python

RUN apt-get -y update \
  && apt-get install -y gettext \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=ghcr.io/astral-sh/uv:0.8 /uv /uvx /bin/
ENV UV_COMPILE_BYTECODE=1 UV_SYSTEM_PYTHON=1 UV_PROJECT_ENVIRONMENT=/usr/local
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project --no-editable

### Final image
FROM python:3.12-slim

RUN groupadd -r saleor && useradd -r -g saleor saleor

RUN apt-get update \
  && apt-get install -y \
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
  media-types \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /app/media /app/static \
  && chown -R saleor:saleor /app/

COPY --from=build-python /usr/local/lib/python3.12/site-packages/ /usr/local/lib/python3.12/site-packages/
COPY --from=build-python /usr/local/bin/ /usr/local/bin/
COPY . /app
WORKDIR /app

ARG STATIC_URL
ENV STATIC_URL=${STATIC_URL:-/static/}
RUN SECRET_KEY=dummy STATIC_URL=${STATIC_URL} python3 manage.py collectstatic --no-input

EXPOSE 10000
ENV PYTHONUNBUFFERED=1

# --- التعديلات الجوهرية لتقليل الرام على Render ---

# 1. تقليل عدد العمال (Workers) إلى 1 وهو الأهم لتقليل استهلاك الذاكرة للنصف تقريباً.
# 2. تعطيل عمليات الـ Migrate التلقائية عند بدء التشغيل إذا كنت قد أجريتها سابقاً لتوفير الرام أثناء الإقلاع.
# 3. استخدام سطر أوامر محسن لـ uvicorn.

CMD ["sh", "-c", "uvicorn saleor.asgi:application --host=0.0.0.0 --port=${PORT:-10000} --workers=1 --lifespan=off --timeout-keep-alive=30"]
