#!/usr/bin/env bash
set -euo pipefail

# 1. Ak beží v CI alebo máš nastavenú premennú, použi ju
if [ -n "${ANSIBLE_VAULT_PASSWORD:-}" ]; then
  echo "$ANSIBLE_VAULT_PASSWORD"
  exit 0
fi

# 2. Lokálny vývoj: načítanie z systémovej kľúčenky
if command -v secret-tool &> /dev/null; then
  secret-tool lookup ansible vault
  exit 0
fi

echo "Error: Vault password not found (neither ANSIBLE_VAULT_PASSWORD nor secret-tool standard path)." >&2
exit 1
