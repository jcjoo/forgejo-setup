# Forgejo PSO — Produção

Deploy de **produção** do Forgejo da PSO para o **Portainer**: cola o
`docker-compose.yml`, preenche as variáveis e sobe. Só imagens de registry —
sem `build`, sem bind-mount de arquivo, sem imagem custom.

- **Forgejo** + **Postgres**: imagens oficiais.
- **Runner de CI**: imagem oficial `code.forgejo.org/forgejo/runner:12`. Um
  serviço só, que se registra sozinho e gera o `config.yml` no volume.
- **Imagem de job** (o que roda no `runs-on:`): vem de registry, definida em
  `CI_JOB_IMAGE`. Em Docker 29+ ela precisa ter o `/var/run` real — a do
  ghcr já tem.

## Rodar no Portainer

**1. Criar a stack**
Portainer → **Stacks** → **Add stack** → **Web editor**. Cole o conteúdo do
`docker-compose.yml`.

**2. Variáveis de ambiente**
Em **Environment variables**, adicione (ver `.env.example`):

| Variável | Obrigatória | Exemplo |
|---|---|---|
| `FORGEJO_ROOT_URL` | sim | `https://git.pso.com.br/` |
| `FORGEJO_DOMAIN` | sim | `git.pso.com.br` |
| `POSTGRES_PASSWORD` | sim | *(senha forte)* |
| `FORGEJO_HTTP_PORT` | não | `3000` |
| `FORGEJO_SSH_PORT` | não | `2222` |
| `RUNNER_REGISTRATION_TOKEN` | depois | *(deixe vazio agora)* |
| `CI_JOB_IMAGE` | não | `ghcr.io/jcjoo/pso-forgejo-runner:latest` |

Deixe `RUNNER_REGISTRATION_TOKEN` **vazio** neste primeiro deploy.

**3. Deploy the stack**
Forgejo e Postgres sobem. O `runner` fica reiniciando avisando que falta o
token — **isso é esperado** nesta fase.

**4. Instalar o Forgejo (cria o admin) — pela UI**
Abra a `FORGEJO_ROOT_URL` no navegador. Aparece a tela de instalação com o
banco já preenchido. Só role até o fim, crie a conta de **administrador** e
clique em **Install Forgejo**.

> As Actions (e o token do runner) **só ativam depois** desse install. Antes
> disso o runner erra e o menu de runners não mostra token — normal.

**5. Pegar o token do runner — pela UI**
Logado como admin: **Site Administration → Actions → Runners → Create new
Runner**. Copie o **registration token**.

**6. Registrar o runner**
Na stack no Portainer → **Editor** → em Environment variables, cole o token
em `RUNNER_REGISTRATION_TOKEN` → **Update the stack**.
O runner registra e começa a pollar. Confira em **Actions → Runners** (deve
aparecer `pso-runner` como *idle*).

Pronto. Nos próximos deploys é idempotente: o runner vê que já está
registrado e sobe direto.

## Por que o runner fala interno (importante, atrás de nginx/HTTPS)

O runner registra por `http://forgejo:3000/` (rede interna do compose,
`RUNNER_INSTANCE_URL`), **não** pelo domínio público. Os jobs também rodam
nessa rede interna. Motivo: a URL de registro é a que o runner injeta nos
jobs — dela sai a URL de clone do `checkout`. Se fosse o domínio público,
cada passo sairia pro nginx por HTTPS e voltaria, quebrando por **hairpin
NAT** ou **TLS**. Na mesma máquina, runner↔Forgejo tem que ser interno.

## Precisa entrar no terminal?

Não para subir. O install e o token são pela UI. Terminal só se você quiser
inspecionar (`docker compose logs runner`) ou gerar o token via CLI:

```bash
docker compose exec -u 1000 forgejo forgejo actions generate-runner-token
```

## Registry (docker push nos jobs)

Se o CI faz `docker build/push` pro registry do Forgejo, use a variável de
org `REGISTRY_HOST=git.pso.com.br` (domínio público, TLS do nginx). O push é
feito pelo daemon do host e precisa alcançar esse domínio (hairpin). Se não
funcionar no servidor, me avise.

## Docker ≤ 28

Se o servidor não for Docker 29+, o `/var/run` não é problema: aponte
`CI_JOB_IMAGE` para uma imagem pública pronta (`catthehacker/ubuntu:act-22.04`,
que já tem node + docker + buildx) e nem precisa da imagem do ghcr.

## Backup

Volumes: `forgejo_data` (repos, config, LFS), `forgejo_pg` (banco),
`runner_data` (registro do runner).

```bash
docker compose exec database pg_dump -U forgejo forgejo > backup.sql
```
