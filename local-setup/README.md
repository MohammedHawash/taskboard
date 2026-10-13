# Local setup (Docker Compose)

```bash
cd local-setup
docker compose up --build -d        # db + backend + frontend
docker compose ps                   # all should be "healthy"
open http://localhost:3000          # UI (nginx -> /api -> backend)
open http://localhost:8000/api/docs # API docs
```

Persistence checks
```bash
docker compose restart backend      # tasks survive
docker compose down && docker compose up -d   # tasks survive (volume pgdata)
docker compose down -v              # WARNING: deletes the volume
```

SonarQube (optional)
```bash
docker compose --profile sonar up -d    # http://localhost:9000 (admin/admin)
# Linux: sudo sysctl -w vm.max_map_count=262144
```

Stop: `docker compose down` (add `-v` to wipe data).
Scans: `./scan-local.sh` (Gitleaks, TruffleHog, Trivy fs + image).
Kubernetes: see `minikube/` (`./up.sh`, `./up.sh argocd`, `./down.sh`).
