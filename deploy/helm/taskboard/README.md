# taskboard Helm chart
Deploys the FastAPI backend (Deployment + Service) and PostgreSQL (StatefulSet + headless Service + PVC).

```bash
helm lint . -f values-local.yaml && helm lint . -f values-prod.yaml
helm template taskboard . -f values-local.yaml
helm upgrade --install taskboard . -n taskboard --create-namespace -f values-local.yaml --wait
helm test taskboard -n taskboard --logs
```
Key values: `backend.replicas`, `backend.image.*`, `postgres.storage.*`,
`secret.mode` (plain|external), `targetGroupBinding.*`.
Local and prod differ only in values files; the templates are identical.
