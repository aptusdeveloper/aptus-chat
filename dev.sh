#!/usr/bin/env bash
# Inicia (ou reinicia) o aptus-chat localmente e expõe via ngrok.
# Uso: ./dev.sh [--no-ngrok]

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SOCK="$REPO_DIR/.overmind.sock"

# PATH completo necessário: rbenv + NVM (onde fica o pnpm)
export PATH="$HOME/.nvm/versions/node/v24.14.0/bin:/opt/homebrew/bin:/opt/homebrew/opt/postgresql@16/bin:$HOME/.rbenv/bin:$HOME/.rbenv/shims:/usr/local/bin:$PATH"
eval "$(rbenv init -)" 2>/dev/null || true

cd "$REPO_DIR"

# ── helpers ──────────────────────────────────────────────────────────────────
log()  { echo "[aptus-chat] $*"; }
wait_for_port() {
  local port=$1 tries=30
  while (( tries-- > 0 )); do
    curl -s -o /dev/null "http://localhost:$port" && return 0
    sleep 1
  done
  echo "[aptus-chat] ERRO: porta $port não respondeu em 30s" >&2
  return 1
}

# ── matar sock morto sem processo dono ───────────────────────────────────────
if [[ -S "$SOCK" ]]; then
  if overmind ps &>/dev/null; then
    log "Overmind rodando — reiniciando backend e worker..."
    overmind restart backend worker
  else
    log "Sock stale encontrado — removendo..."
    rm -f "$SOCK"
  fi
fi

# ── iniciar overmind se não estiver de pé ────────────────────────────────────
if [[ ! -S "$SOCK" ]]; then
  log "Iniciando servidores (Rails + Sidekiq + Vite)..."
  pkill -f "puma.*3000" 2>/dev/null || true
  overmind start -f Procfile.dev > /tmp/overmind-aptus.log 2>&1 &
  OVERMIND_PID=$!
  log "Overmind PID=$OVERMIND_PID — aguardando Rails..."
  wait_for_port 3000
fi

log "✓ Rails respondendo em http://localhost:3000"

# ── ngrok ────────────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--no-ngrok" ]]; then
  log "ngrok ignorado (--no-ngrok)"
  exit 0
fi

# Matar ngrok anterior na porta 3000
pkill -f "ngrok http 3000" 2>/dev/null || true
sleep 1

log "Iniciando ngrok..."
ngrok http 3000 > /tmp/ngrok-aptus.log 2>&1 &
sleep 3

PUBLIC_URL=$(curl -s http://localhost:4040/api/tunnels \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(next((t['public_url'] for t in d.get('tunnels',[]) if t['proto']=='https'), 'N/A'))" 2>/dev/null || echo "N/A")

if [[ "$PUBLIC_URL" == "N/A" ]]; then
  log "⚠️  ngrok não retornou URL — verifique /tmp/ngrok-aptus.log"
else
  log "✓ Exposto publicamente: $PUBLIC_URL"
fi

echo ""
echo "  Local:  http://localhost:3000"
echo "  Ngrok:  $PUBLIC_URL"
echo "  Logs:   tail -f /tmp/overmind-aptus.log"
echo ""
