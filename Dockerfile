# -------- Stage 1: Builder --------
FROM python:3.10-slim as builder

WORKDIR /app

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    default-libmysqlclient-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

# Installing mysqlclient explicitly as a safety net in case it's
# missing from requirements.txt — make sure it's actually listed there too
RUN pip install --no-cache-dir --target=/install mysqlclient && \
    pip install --no-cache-dir --target=/install -r requirements.txt && \
    ls /install/bin

# -------- Stage 2: Final Image --------
FROM python:3.10-slim

ENV DEBIAN_FRONTEND=noninteractive

# libmariadb3 = runtime client library mysqlclient needs to actually
# connect to MySQL/MariaDB. Without this, you get "Error loading MySQLdb
# module" at runtime even if the package installed fine during build.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libmariadb3 \
    && rm -rf /var/lib/apt/lists/*

RUN adduser --disabled-password --gecos '' appuser

WORKDIR /app

ENV PYTHONUNBUFFERED=1 \
    PYTHONPATH="/install" \
    PATH="/install/bin:$PATH"

COPY --from=builder /install /install
COPY . .

RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 8000

CMD ["gunicorn", "notesapp.wsgi:application", "--bind", "0.0.0.0:8000"]
