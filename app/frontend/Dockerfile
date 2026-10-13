# syntax=docker/dockerfile:1
# ---------- stage 1: build the static site ----------
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
ARG NEXT_PUBLIC_APP_VERSION=local
ENV NEXT_PUBLIC_APP_VERSION=${NEXT_PUBLIC_APP_VERSION}
RUN npm run build            # produces ./out

# ---------- stage 2: unprivileged nginx ----------
FROM nginxinc/nginx-unprivileged:1.27-alpine
# *.template files are rendered with envsubst at container start
COPY nginx.conf /etc/nginx/templates/default.conf.template
COPY --from=build /app/out /usr/share/nginx/html
ENV BACKEND_URL=http://backend:8000
EXPOSE 8080
