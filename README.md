# Forgejo self-hosted — PSO

Forge completa (git + PRs com aprovação obrigatória + registry de containers +
CI compatível com GitHub Actions) a custo zero, rodando no servidor da PSO.
Espelha cada push de volta ao GitHub Free como backup off-site.

## Teste local

```bash
cp .env.example .env            # ajuste a senha do Postgres
docker compose up -d forgejo    # http://localhost:3300
```

1. Abra http://localhost:3300 — a primeira tela cria o **usuário admin**
   (cadastro público já vem desabilitado).
2. Crie a organização `pso` (UI → + → Nova organização).
3. Gere um token de admin: Configurações → Aplicações → Gerar token
   (escopos `write:repository` e `write:organization`).

## Migrar repos do GitHub

```bash
# um ou alguns repos para testar:
FORGEJO_TOKEN=xxx ./migrate-github.sh pso-easynr10 sgi

# todos os 36 privados da org:
FORGEJO_TOKEN=xxx ./migrate-github.sh --all
```

O script, por repo: migra código + issues + PRs + releases + wiki; protege a
branch padrão (merge só via PR, 1 aprovação, aprovação obsoleta descartada);
configura push mirror de volta para `github.com/psoengenhariaeletrica/<repo>`
(sincroniza a cada push + a cada 8 h).

## CI (Forgejo Actions)

O runner se registra sozinho na primeira subida — não precisa de passo manual
separado, funciona igual num `docker compose up -d` local ou num redeploy de
stack no Portainer. Só precisa do token de registro no `.env` antes:

```bash
docker compose up -d forgejo database   # se ainda não estiver no ar
./setup-runner.sh                       # gera o token e grava em RUNNER_REGISTRATION_TOKEN no .env
docker compose up -d                    # builda a ci-image, registra e sobe o runner
```

(No Portainer: gere o token com o comando dentro de `setup-runner.sh` — ou
pela UI, Administração → Actions → Runners → "Create new runner" só pra
copiar o token — e cole em `RUNNER_REGISTRATION_TOKEN` nas variáveis do
stack antes do deploy.)

Os workflows são os mesmos arquivos de `.github/workflows/` — o Forgejo lê
também `.forgejo/workflows/`. Actions `uses:` são baixadas do github.com
normalmente. Nos jobs atuais da PSO, basta trocar o push do Docker Hub pelo
registry embutido:

```yaml
- uses: docker/login-action@v3
  with:
    registry: git.pso.com.br            # o próprio Forgejo
    username: ${{ github.actor }}
    password: ${{ secrets.REGISTRY_TOKEN }}   # token com escopo write:package
```

### Configurar secrets (ex.: `REGISTRY_TOKEN`)

`secrets.*` no workflow **não** são variáveis de ambiente da máquina — são
cadastradas no próprio Forgejo, criptografadas, e só ficam visíveis para os
jobs de Actions:

1. Gere o valor do token: Configurações do usuário → Aplicações → Gerar
   token, escopo `write:package` (é um token pessoal, igual ao de admin
   usado no `migrate-github.sh`, só que com escopo diferente).
2. Cadastre o secret:
   - **Por organização** (visível a todos os repos de `pso` — recomendado
     pro `REGISTRY_TOKEN`): `pso` → Configurações → Actions → Secrets →
     Adicionar Secret → nome `REGISTRY_TOKEN`, valor = token do passo 1.
   - **Por repositório** (se for algo específico de um único repo):
     Repositório → Configurações → Actions → Secrets → mesmo fluxo.
3. O workflow referencia pelo nome (`${{ secrets.REGISTRY_TOKEN }}`) — não
   precisa reiniciar runner nem tocar em `.env` no servidor.

Isso vale para qualquer outro secret que os workflows precisem (ex.: token
de deploy, API key de terceiro): mesmo caminho, só troca o nome e o escopo
do token gerado.

## Registry de containers

```bash
docker login localhost:3300             # usuário + token
docker tag minha-img localhost:3300/pso/minha-img:latest
docker push localhost:3300/pso/minha-img:latest
```

(Em produção com HTTPS no domínio, funciona de qualquer máquina; em HTTP
puro, adicione o host em `insecure-registries` do Docker.)

## Deploy no servidor da PSO

Pré-requisitos no servidor: Docker + plugin do Compose instalados, domínio
(ex.: `git.pso.com.br`) apontando pro IP do servidor, portas 443 e 2222
liberadas no firewall (a 3300 fica só interna, atrás do proxy).

1. **Clonar o repo no servidor.**

   ```bash
   git clone <url-deste-repo> /opt/pso-forgejo && cd /opt/pso-forgejo
   ```

2. **Configurar o `.env` para produção** (copie de `.env.example` e ajuste):

   ```bash
   FORGEJO_ROOT_URL=https://git.pso.com.br/
   POSTGRES_PASSWORD=<senha forte, não a de exemplo>
   ```

3. **Reverse proxy com HTTPS na frente do Forgejo.** Ele continua escutando
   em `127.0.0.1:3300`; o proxy termina TLS e encaminha pra lá. Exemplo com
   Caddy (renova certificado sozinho):

   ```caddyfile
   git.pso.com.br {
       reverse_proxy 127.0.0.1:3300
   }
   ```

4. **Subir forge + banco:**

   ```bash
   docker compose up -d forgejo database
   ```

   Acesse `https://git.pso.com.br`, crie o **usuário admin** na primeira
   tela, depois a organização `pso` e o token de admin — mesmo fluxo do
   teste local (seção acima), só que já no domínio real.

5. **Registrar o runner de CI no próprio servidor** (uma vez só — depois
   disso, `docker compose up -d` sobe tudo, redeploy de stack no Portainer
   incluso):

   ```bash
   ./setup-runner.sh
   docker compose up -d
   ```

6. **Migrar os repos do GitHub** (pode rodar do servidor ou de qualquer
   máquina que enxergue `https://git.pso.com.br`):

   ```bash
   FORGEJO_URL=https://git.pso.com.br FORGEJO_TOKEN=xxx ./migrate-github.sh --all
   ```

### Checklist

- [ ] `FORGEJO_ROOT_URL` com o domínio real + HTTPS (reverse proxy: caddy/nginx)
- [ ] Senha forte no Postgres (`.env`, fora do git)
- [ ] Backup: `docker compose exec database pg_dump -U forgejo forgejo` +
      volume `forgejo_data` → rotina off-site existente da PSO
- [ ] Atualização: trocar a tag da imagem (ex.: `forgejo:13` → `forgejo:14`)
      e `docker compose up -d` — ler as release notes antes de major
- [ ] Runner em máquina separada se os builds pesarem no servidor da forge
