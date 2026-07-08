# Imagem completa do runner (binário oficial + entrypoint + config já
# embutidos). Só pra rodar direto no Portainer sem precisar montar arquivo
# nenhum: image + variáveis de ambiente (FORGEJO_ROOT_URL,
# RUNNER_REGISTRATION_TOKEN, RUNNER_NAME) resolvem tudo.
FROM code.forgejo.org/forgejo/runner:12

COPY runner-entrypoint.sh /entrypoint.sh
COPY runner-config.yml /data/config.yml

ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]
