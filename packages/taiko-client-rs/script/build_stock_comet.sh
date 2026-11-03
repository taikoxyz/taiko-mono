#!/usr/bin/env bash
# Build unmodified stock Comet v0.40.0 for native foreground recovery tests.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
package_root="$PWD"
export GOTOOLCHAIN=go1.27.2
test "$(go env GOVERSION)" = go1.27.2
mkdir -p target/etna-signer
metadata=$(go mod download -json github.com/cometbft/cometbft@v0.40.0)
source_dir=$(printf '%s' "$metadata" | python3 -c 'import json,sys; print(json.load(sys.stdin)["Dir"])')
info_file=$(printf '%s' "$metadata" | python3 -c 'import json,sys; print(json.load(sys.stdin)["Info"])')
python3 - "$info_file" <<'PY'
import json, sys
with open(sys.argv[1]) as source:
    metadata = json.load(source)
assert metadata["Version"] == "v0.40.0", metadata
assert metadata["Origin"]["Hash"] == "0880b4d378f347ab16e54ec677ff50d803f37d62", metadata
PY
# The upstream CLI reports 0.39.0+hash even at the verified v0.40.0 source tag.
cd "$source_dir"
CGO_ENABLED=0 go build -mod=readonly -tags=cometbft -trimpath -buildvcs=false \
  -ldflags='-s -w -buildid= -X github.com/cometbft/cometbft/version.TMGitCommitHash=0880b4d378f347ab16e54ec677ff50d803f37d62' \
  -o "$package_root/target/etna-signer/cometbft" ./cmd/cometbft
cp "$info_file" "$package_root/target/etna-signer/comet-source.json"
