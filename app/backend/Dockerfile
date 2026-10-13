# syntax=docker/dockerfile:1
FROM python:3.13-slim

ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION} \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# 1) dependencies first -> cached layer unless requirements.txt changes
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
 && pip uninstall -y pip setuptools wheel

# 2) application code
COPY taskboard ./taskboard

# numeric non-root UID so Kubernetes can verify runAsNonRoot
USER 10001:10001
EXPOSE 8000
CMD ["uvicorn", "taskboard.main:app", "--host", "0.0.0.0", "--port", "8000"]
