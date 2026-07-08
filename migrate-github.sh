#!/usr/bin/env bash
# Migra repos do GitHub (org psoengenhariaeletrica) para o Forgejo, protege a
# branch padrão e configura push mirror de volta ao GitHub (backup off-site).
#
# Pré-requisitos:
#   - Forgejo no ar com uma organização criada (padrão: pso)
#   - Token de admin do Forgejo: UI → Configurações → Aplicações → token
#     (escopos: write:repository, write:organization)
#   - gh CLI autenticado (o token do GitHub sai de `gh auth token`)
#
# Uso:
#   FORGEJO_TOKEN=xxx ./migrate-github.sh repo1 repo2 …   # repos específicos
#   FORGEJO_TOKEN=xxx ./migrate-github.sh --all           # todos os privados
#
# Flags por env:
#   FORGEJO_URL   (padrão http://localhost:3300)
#   FORGEJO_ORG   (padrão pso)
#   GITHUB_ORG    (padrão psoengenhariaeletrica)
#   APPROVALS     (padrão 1 — aprovações obrigatórias na branch padrão)
#   MIRROR=0      (desliga o push mirror de volta ao GitHub)
set -euo pipefail

FORGEJO_URL=${FORGEJO_URL:-http://localhost:3300}
FORGEJO_ORG=${FORGEJO_ORG:-pso}
GITHUB_ORG=${GITHUB_ORG:-psoengenhariaeletrica}
APPROVALS=${APPROVALS:-1}
MIRROR=${MIRROR:-1}
: "${FORGEJO_TOKEN:?defina FORGEJO_TOKEN (token de admin do Forgejo)}"
GITHUB_TOKEN=$(gh auth token)

fj() { # método path [json]
  local method=$1 path=$2 body=${3:-}
  curl -sf -X "$method" "$FORGEJO_URL/api/v1$path" \
    -H "Authorization: token $FORGEJO_TOKEN" \
    -H 'Content-Type: application/json' \
    ${body:+-d "$body"}
}

if [[ ${1:-} == "--all" ]]; then
  mapfile -t REPOS < <(gh api "/orgs/$GITHUB_ORG/repos?per_page=100" --paginate \
    -q '.[] | select(.private) | .name')
else
  REPOS=("$@")
fi
[[ ${#REPOS[@]} -gt 0 ]] || { echo "nenhum repo informado (use --all ou liste nomes)"; exit 1; }

echo "Migrando ${#REPOS[@]} repo(s) de $GITHUB_ORG para $FORGEJO_URL/$FORGEJO_ORG"

for repo in "${REPOS[@]}"; do
  echo "== $repo =="

  # 1) Migração (código + issues + PRs + releases + labels + milestones)
  if fj GET "/repos/$FORGEJO_ORG/$repo" >/dev/null 2>&1; then
    echo "   já existe no Forgejo — pulando migração"
  else
    fj POST /repos/migrate "$(jq -n \
      --arg addr "https://github.com/$GITHUB_ORG/$repo.git" \
      --arg tok "$GITHUB_TOKEN" --arg name "$repo" --arg org "$FORGEJO_ORG" \
      '{clone_addr:$addr, auth_token:$tok, repo_name:$name, repo_owner:$org,
        service:"github", private:true, issues:true, pull_requests:true,
        releases:true, labels:true, milestones:true, wiki:true}')" >/dev/null
    echo "   migrado"
  fi

  # 2) Proteção da branch padrão (merge só via PR + aprovações obrigatórias)
  default=$(fj GET "/repos/$FORGEJO_ORG/$repo" | jq -r .default_branch)
  if fj GET "/repos/$FORGEJO_ORG/$repo/branch_protections/$default" >/dev/null 2>&1; then
    echo "   proteção de '$default' já existe"
  else
    fj POST "/repos/$FORGEJO_ORG/$repo/branch_protections" "$(jq -n \
      --arg b "$default" --argjson n "$APPROVALS" \
      '{branch_name:$b, enable_push:false, required_approvals:$n,
        block_on_rejected_reviews:true, dismiss_stale_approvals:true,
        block_on_outdated_branch:false}')" >/dev/null
    echo "   branch '$default' protegida ($APPROVALS aprovação(ões))"
  fi

  # 3) Push mirror de volta ao GitHub (backup off-site a cada push)
  if [[ $MIRROR == 1 ]]; then
    if fj GET "/repos/$FORGEJO_ORG/$repo/push_mirrors" | jq -e 'length > 0' >/dev/null; then
      echo "   push mirror já configurado"
    else
      fj POST "/repos/$FORGEJO_ORG/$repo/push_mirrors" "$(jq -n \
        --arg addr "https://github.com/$GITHUB_ORG/$repo.git" \
        --arg user "$GITHUB_ORG" --arg pass "$GITHUB_TOKEN" \
        '{remote_address:$addr, remote_username:$user, remote_password:$pass,
          interval:"8h0m0s", sync_on_commit:true}')" >/dev/null
      echo "   push mirror → github.com/$GITHUB_ORG/$repo"
    fi
  fi
done

echo "Concluído."
