#!/usr/bin/env bash
set -euo pipefail

# 1. Running in CI or the env var is already set: use it
if [ -n "${ANSIBLE_VAULT_PASSWORD:-}" ]; then
  echo "$ANSIBLE_VAULT_PASSWORD"
  exit 0
fi

# 2. Local development: read from the OS keyring
if command -v secret-tool &> /dev/null; then
  secret-tool lookup ansible vault
  exit 0
fi

echo "Error: Vault password not found (neither ANSIBLE_VAULT_PASSWORD nor secret-tool standard path)." >&2
exit 1
