# Imagem única: runner do Forgejo Actions (poller/daemon) + tudo que os
# jobs precisam (node, docker CLI/buildx, fix do /var/run) + entrypoint e
# config já embutidos. A mesma imagem serve duas funções:
#   1. container do runner (entrypoint = runner-entrypoint.sh, registra
#      sozinho e sobe o daemon)
#   2. imagem dos jobs (runs-on: ubuntu-latest etc. — ver runner-config.yml,
#      que aponta os labels pra esta mesma imagem)
# Publicada em ghcr.io — Portainer só troca a imagem + variáveis de
# ambiente, sem build nem checkout de repo no host.
FROM docker:cli AS dockercli

FROM node:22-bookworm
# /var/run como diretório real — o symlink absoluto /var/run -> /run das
# imagens Debian/Ubuntu faz o Docker 29+ (Go 1.24, os.Root) rejeitar a cópia
# do runtime do runner pra dentro do job container ("mkdirat var/run/act:
# path escapes from parent").
RUN rm /var/run && mkdir -m 0755 /var/run
COPY --from=dockercli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=dockercli /usr/local/libexec/docker/cli-plugins/docker-buildx \
    /usr/local/libexec/docker/cli-plugins/docker-buildx
COPY --from=code.forgejo.org/forgejo/runner:12 /bin/forgejo-runner /bin/forgejo-runner

COPY runner-entrypoint.sh /entrypoint.sh
COPY runner-config.yml /data/config.yml

ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]
