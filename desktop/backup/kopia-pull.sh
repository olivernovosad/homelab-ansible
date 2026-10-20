#!/usr/bin/env bash
set -euo pipefail

# Pulls a read-only mirror of the Kopia repository from gaia-server via
# SFTP, using rclone with an inline ("on the fly") remote — no rclone.conf,
# no credentials stored outside this script and the SSH key file.
#
# Uses SFTP, not rsync: the kopia-offsite account on gaia-server is locked
# to `ForceCommand internal-sftp` (no shell, no arbitrary commands), which
# rsync's protocol cannot work with — rsync needs to exec `rsync --server`
# remotely, which a shell-less forced command refuses. shell_type=none
# tells rclone's SFTP backend not to attempt shell-based detection/hashing
# against that account.
#
# The kopia-offsite account only has group READ access to the repository
# (0750, no write) — this script never writes to the remote side, only
# reads, matching that restriction by design.

GAIA_HOST="192.168.x.x"
GAIA_PORT="22"
REMOTE_USER="kopia-offsite"
SSH_KEY="$HOME/.ssh/kopia-pull"
KNOWN_HOSTS="$HOME/.ssh/known_hosts"
DEST="$HOME/kopia-offsite"
LOG="$HOME/kopia-pull.log"

mkdir -p "$DEST"

log() { echo "$(date -Iseconds): $*" >> "$LOG"; }

# Never sync during the nightly backup window on gaia-server (DB dump at
# 01:45, Kopia snapshot at 02:00). Pulling mid-write just mirrors a
# repository that's still changing — wasted bandwidth, not a corruption
# risk (Kopia writes blobs atomically: temp file + rename), but no reason
# to do it anyway.
current_hour="$(date +%H)"
if [[ "$current_hour" == "01" || "$current_hour" == "02" ]]; then
  log "preskakujem, v backup okne na gaia-server (01:00-03:00)"
  exit 0
fi

if ! nc -z -w3 "$GAIA_HOST" "$GAIA_PORT" 2>/dev/null; then
  log "gaia-server nedostupný, preskakujem"
  exit 0
fi

RCLONE_REMOTE=":sftp,host=${GAIA_HOST},port=${GAIA_PORT},user=${REMOTE_USER},key_file=${SSH_KEY},known_hosts_file=${KNOWN_HOSTS},shell_type=none:"

if rclone sync "$RCLONE_REMOTE" "$DEST" \
    --sftp-disable-hashcheck \
    --retries 3 \
    --low-level-retries 10 \
    --log-file "$LOG" \
    --log-level INFO; then
  log "sync OK"
else
  log "sync ZLYHAL"
  exit 1
fi
