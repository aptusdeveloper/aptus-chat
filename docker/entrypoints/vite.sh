#!/bin/sh
set -x

rm -rf /app/tmp/pids/server.pid
rm -rf /app/tmp/cache/*

LOCK_HASH_FILE="/app/node_modules/.pnpm-lock.hash"
CURRENT_HASH=$(md5sum pnpm-lock.yaml | awk '{print $1}')

if [ -f "$LOCK_HASH_FILE" ] && [ "$(cat "$LOCK_HASH_FILE")" = "$CURRENT_HASH" ]; then
  echo "pnpm-lock.yaml unchanged, skipping pnpm install."
else
  pnpm store prune
  pnpm install --force
  echo "$CURRENT_HASH" > "$LOCK_HASH_FILE"
fi

echo "Ready to run Vite development server."

exec "$@"
