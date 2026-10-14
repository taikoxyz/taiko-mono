#!/usr/bin/env bash
set -euo pipefail
fixture_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
fixture_tmp="$(mktemp -d)"
trap 'rm -rf "$fixture_tmp"' EXIT
cp "$fixture_dir/generate.go" "$fixture_tmp/main.go"
cat > "$fixture_tmp/go.mod" <<'EOF'
module lander-comet-fixture

go 1.25.0

require github.com/cometbft/cometbft v0.40.0
EOF
go -C "$fixture_tmp" run -mod=mod . "$fixture_dir/envelope.base64" "$fixture_dir/vectors.json"
