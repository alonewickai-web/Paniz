#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="$repo_root/.env.server"
compose_file="$repo_root/compose.server.yaml"

if [[ ! -f "$env_file" ]]; then
  echo "Missing .env.server. Run: bash ops/create-server-env.sh"
  exit 1
fi

cd "$repo_root"
compose() {
  docker compose --env-file "$env_file" --file "$compose_file" "$@"
}

compose up -d mysql
docker compose --parallel 1 --env-file "$env_file" --file "$compose_file" build api migrate storefront
compose --profile setup run --rm migrate
compose up -d api storefront

wait_for_health() {
  local service="$1"
  local container_id
  local state
  container_id="$(compose ps -q "$service")"
  if [[ -z "$container_id" ]]; then
    echo "Could not find the $service container."
    return 1
  fi
  for _ in $(seq 1 90); do
    state="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$container_id")"
    if [[ "$state" == "healthy" ]]; then
      echo "$service is healthy."
      return 0
    fi
    if [[ "$state" == "unhealthy" || "$state" == "exited" || "$state" == "dead" ]]; then
      echo "$service failed to become healthy; recent logs follow:"
      compose logs --tail=80 "$service"
      return 1
    fi
    sleep 2
  done
  echo "$service health check timed out; recent logs follow:"
  compose logs --tail=80 "$service"
  return 1
}

wait_for_health api
wait_for_health storefront

cat <<'EOF'
Database migrations, API, and storefront are ready.
After panizstyle.ir, www, and api DNS records point to this server, start HTTPS:
  docker compose --env-file .env.server -f compose.server.yaml up -d caddy
EOF
