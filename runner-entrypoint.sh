#!/bin/sh
# Entrypoint do serviço runner: registra na primeira subida (usa
# RUNNER_REGISTRATION_TOKEN) e sobe o daemon. Idempotente — se /data/.runner
# já existe (subidas seguintes), pula direto pro daemon. É o que permite um
# "docker compose up -d" simples (Portainer inclusive) deixar o runner
# pronto, sem rodar setup-runner.sh à parte.
set -eu

if [ ! -f /data/.runner ]; then
  : "${RUNNER_REGISTRATION_TOKEN:?defina RUNNER_REGISTRATION_TOKEN no .env — gere com: docker compose exec -u 1000 forgejo forgejo actions generate-runner-token}"

  echo "Aguardando o Forgejo em ${FORGEJO_ROOT_URL}..."
  until wget -q -O /dev/null "${FORGEJO_ROOT_URL}api/healthz"; do
    sleep 2
  done

  echo "Registrando runner..."
  forgejo-runner register --no-interactive \
    --instance "$FORGEJO_ROOT_URL" \
    --token "$RUNNER_REGISTRATION_TOKEN" \
    --name "${RUNNER_NAME:-pso-runner}" \
    --labels "$RUNNER_LABELS"
fi

exec forgejo-runner daemon --config /data/config.yml
