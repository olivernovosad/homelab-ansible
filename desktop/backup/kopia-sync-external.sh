#!/usr/bin/env bash
set -euo pipefail

EXTERNAL_MOUNT="/run/media/anthropos/Extreme SSD"
SOURCE="$HOME/kopia-offsite/"
DEST="$EXTERNAL_MOUNT/kopia-backup/"

if ! mountpoint -q "$EXTERNAL_MOUNT"; then
  echo "Externý disk nie je pripojený na $EXTERNAL_MOUNT — koniec."
  exit 1
fi

mkdir -p "$DEST"
rsync -az --delete "$SOURCE" "$DEST"
echo "Hotovo: $(date)"
