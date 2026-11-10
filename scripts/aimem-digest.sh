#!/usr/bin/env bash
#
# aimem-digest.sh — gera o digest diario cruzando projetos.
#
# Chamado pelo aimem-digest.service (timer systemd). Fala com o servico local
# pela tailnet usando token bearer lido de arquivo protegido.
#
# Placeholders (<...>) e $(cat ...) nunca guardam valor real no repo.

set -euo pipefail

# URL do servico na tailnet (passada pela unit via Environment).
AIMEM_URL="${AIMEM_URL:-http://<TAILNET_IP>:<SERVICE_PORT>}"

# Token lido de arquivo fora do controle de versao (modo 600).
# A unit injeta AIMEM_TOKEN via EnvironmentFile; o fallback mostra o padrao.
TOKEN="${AIMEM_TOKEN:-$(cat /etc/ai-memory/token)}"

OUT_DIR="/var/lib/ai-memory/digests"
STAMP="$(date +%Y-%m-%d)"
OUT_FILE="${OUT_DIR}/digest-${STAMP}.md"

mkdir -p "$OUT_DIR"

echo "Gerando digest ${STAMP} ..."

# Healthcheck (rota sem token).
if ! curl -fsS "${AIMEM_URL}/health" >/dev/null; then
  echo "ERRO: servico ai-memory nao respondeu em ${AIMEM_URL}" >&2
  exit 1
fi

# Chamada autenticada que gera o resumo cruzando projetos.
curl -fsS \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -X POST "${AIMEM_URL}/digest" \
  -d '{"scope":"all","period":"1d"}' \
  -o "$OUT_FILE"

echo "Digest salvo em ${OUT_FILE}"
