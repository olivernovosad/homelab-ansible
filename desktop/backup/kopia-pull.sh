#!/usr/bin/env bash
set -euo pipefail

OPTIPLEX_HOST="192.168.x.x"
DEST="$HOME/kopia-offsite"
LOG="$HOME/kopia-pull.log"

mkdir -p "$DEST"

if ! nc -z -w3 "$OPTIPLEX_HOST" 22 2>/dev/null; then
  echo "$(date): optiplex nedostupný, preskakujem" >> "$LOG"
  exit 0
fi

rsync -az --delete \
  -e "ssh -i $HOME/.ssh/kopia-pull -o StrictHostKeyChecking=accept-new" \
  backuppull@"$OPTIPLEX_HOST":/ "$DEST"/ \
  && echo "$(date): sync OK" >> "$LOG" \
  || echo "$(date): sync ZLYHAL" >> "$LOG"
