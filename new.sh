#!/usr/bin/env bash
# Copy a template into your own project and create its .env.
#
# Usage: ./new.sh <template> <target-dir> [--force]
#   ./new.sh postgres ~/code/my-app/infra/db
#
# The copied folder is self-contained: compose.yaml, .env, Makefile and the
# smoke test all work without this repository.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  echo "Usage: ./new.sh <template> <target-dir> [--force]"
  echo
  echo "Templates:"
  for d in "$ROOT"/*/compose.yaml; do printf '  %s\n' "$(basename "$(dirname "$d")")"; done
  exit "${1:-2}"
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage 0
[[ $# -lt 2 ]] && usage

TEMPLATE="${1%/}"
TARGET="$2"
FORCE="${3:-}"
SRC="$ROOT/$TEMPLATE"

[[ -f "$SRC/compose.yaml" ]] || { echo "error: unknown template '$TEMPLATE'" >&2; usage; }
if [[ -e "$TARGET/compose.yaml" && "$FORCE" != "--force" ]]; then
  echo "error: $TARGET/compose.yaml already exists (use --force to overwrite)" >&2
  exit 1
fi

mkdir -p "$TARGET"
tar -C "$SRC" --exclude=.env --exclude=node_modules --exclude=.next \
  --exclude=dist --exclude=tmp -cf - . | tar -C "$TARGET" -xf -

if [[ -f "$TARGET/.env" ]]; then
  echo "kept existing $TARGET/.env"
else
  cp "$TARGET/.env.example" "$TARGET/.env"
  echo "created $TARGET/.env from .env.example"
fi

cat <<EOF

Copied '$TEMPLATE' to $TARGET

Next steps:
  cd $TARGET
  \$EDITOR .env        # change every password / secret marked change-me
  make up             # or: docker compose up -d --wait
EOF
