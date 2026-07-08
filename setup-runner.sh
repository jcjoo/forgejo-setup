#!/usr/bin/env bash
# Gera o token de registro do runner e grava em .env (RUNNER_REGISTRATION_TOKEN).
# Rode uma vez, com o Forgejo já no ar e o admin criado.
# Uso: ./setup-runner.sh
set -euo pipefail
cd "$(dirname "$0")"

echo "Gerando token de registro do runner…"
TOKEN=$(docker compose exec -u 1000 forgejo forgejo actions generate-runner-token | tr -d '[:space:]')

if grep -q '^RUNNER_REGISTRATION_TOKEN=' .env 2>/dev/null; then
  sed -i "s/^RUNNER_REGISTRATION_TOKEN=.*/RUNNER_REGISTRATION_TOKEN=$TOKEN/" .env
else
  echo "RUNNER_REGISTRATION_TOKEN=$TOKEN" >> .env
fi

echo "Token gravado em .env — suba o resto com: docker compose up -d"
echo "(no Portainer: cole o mesmo valor na variável RUNNER_REGISTRATION_TOKEN do stack e faça o redeploy)"