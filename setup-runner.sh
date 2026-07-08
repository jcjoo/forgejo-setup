#!/usr/bin/env bash
# Registra o runner de CI no Forgejo e sobe o daemon.
# Uso: ./setup-runner.sh   (depois do Forgejo estar no ar e o admin criado)
set -euo pipefail
cd "$(dirname "$0")"

echo "Gerando token de registro do runner…"
TOKEN=$(docker compose exec -u 1000 forgejo forgejo actions generate-runner-token | tr -d '[:space:]')

echo "Buildando a imagem dos jobs (pso-ci-node:22)…"
docker build -t pso-ci-node:22 ./ci-image

# Instância via localhost (runner e jobs rodam na rede do host — ver
# runner-config.yml). Os labels efetivos vêm do runner-config.yml.
echo "Registrando runner…"
docker compose run --rm runner forgejo-runner register --no-interactive \
  --instance "${FORGEJO_ROOT_URL:-http://localhost:3300}" \
  --token "$TOKEN" \
  --name pso-runner \
  --labels 'docker:docker://pso-ci-node:22,ubuntu-latest:docker://pso-ci-node:22,ubuntu-22.04:docker://pso-ci-node:22,ubuntu-24.04:docker://pso-ci-node:22'

echo "Subindo o runner…"
docker compose --profile runner up -d runner
echo "Pronto — confira em Administração → Actions → Runners."
