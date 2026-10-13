#!/usr/bin/env bash
# Phase A3 - run every scanner of the future pipelines locally (from repo root).
set -uo pipefail
cd "$(dirname "$0")/.."
IMG="${1:-taskboard-backend:local}"

docker build --pull -t "$IMG" app/backend

echo "== Gitleaks ==";   docker run --rm -v "$PWD:/src" ghcr.io/gitleaks/gitleaks:v8.30.1 dir /src --redact
echo "== TruffleHog =="; docker run --rm -v "$PWD:/src" trufflesecurity/trufflehog:3.99.2 filesystem /src
echo "== Trivy fs ==";   docker run --rm -v "$PWD:/src" aquasec/trivy:0.75.0 fs /src \
                            --scanners vuln,secret,misconfig --severity HIGH,CRITICAL
echo "== Trivy image =="; docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:0.75.0 \
                            image "$IMG" --severity HIGH,CRITICAL --ignore-unfixed
echo "SonarQube: docker compose --profile sonar up -d, create project+token, then:"
echo '  docker run --rm --network host -v "$PWD/app/backend:/usr/src" -e SONAR_HOST_URL=http://localhost:9000 -e SONAR_TOKEN=<token> sonarsource/sonar-scanner-cli -Dsonar.projectKey=taskboard-backend -Dsonar.qualitygate.wait=true'
