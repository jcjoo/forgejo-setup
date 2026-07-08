# Imagem dos jobs do Forgejo Actions (labels do runner apontam para ela).
# Motivos de existir, em cima do node:22-bookworm puro:
#   1. /var/run como diretório real — o symlink absoluto /var/run -> /run das
#      imagens Debian/Ubuntu faz o Docker 29+ (Go 1.24, os.Root) rejeitar a
#      cópia do runtime do runner ("mkdirat var/run/act: path escapes from
#      parent").
#   2. docker CLI + buildx, para workflows que buildam/públicam imagens
#      (o socket do host é montado pelo runner via container.options).
FROM docker:cli AS dockercli

FROM node:22-bookworm
RUN rm /var/run && mkdir -m 0755 /var/run
COPY --from=dockercli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=dockercli /usr/local/libexec/docker/cli-plugins/docker-buildx \
    /usr/local/libexec/docker/cli-plugins/docker-buildx
