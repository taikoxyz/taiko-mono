#!/usr/bin/env bash
# Provide stock Comet v0.40.0 for native foreground tests at target/etna-signer/cometbft.
#
# On linux/amd64 with a Docker daemon of that architecture, copy the official executable out of
# the official image and check it against comet-manifest.json, the digest the validator
# supervisor requires (CONS-3.1-1). Upstream published no executable for any other platform, so
# elsewhere build the exact unmodified source instead. That build is not the official executable
# and the supervisor refuses it by default; for local tests this script writes
# target/etna-signer/comet-manifest.test.json pinning it, which ETNA_COMET_MANIFEST may name.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
package_root="$PWD"
output="$package_root/target/etna-signer/cometbft"
test_manifest="$package_root/target/etna-signer/comet-manifest.test.json"
mkdir -p target/etna-signer
rm -f "$test_manifest"
official_digest=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["platforms"]["linux/amd64"]["sha256"])' comet-manifest.json)
official_image="cometbft/cometbft:v0.40.0@sha256:0703fb881dac0987c8e41a5810cc09dbcb503bb59ac91705f6936c4b972ac798"
if [[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] &&
  [[ "$(docker info --format '{{.Architecture}}' 2> /dev/null)" == x86_64 ]]; then
  echo "Copying the official CometBFT v0.40.0 executable from $official_image (linux/amd64)"
  container=''
  # Whatever step fails, leave neither a partial binary nor the container. The test-run label lets
  # the entrypoint's cleanup remove the container if this script is killed before its trap runs.
  trap 'rm -f "$output.tmp"; if [[ -n "$container" ]]; then docker rm -f "$container" > /dev/null; fi' EXIT
  container=$(docker create --platform linux/amd64 \
    ${TAIKO_CLIENT_RS_TEST_RUN:+--label "taiko-client-rs.test-run=$TAIKO_CLIENT_RS_TEST_RUN"} "$official_image")
  docker cp "$container:/usr/bin/cometbft" "$output.tmp"
  echo "$official_digest  $output.tmp" | sha256sum -c -
  mv -f "$output.tmp" "$output"
  exit 0
fi
export GOTOOLCHAIN=go1.27.2
test "$(go env GOVERSION)" = go1.27.2
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
(
  cd "$source_dir"
  CGO_ENABLED=0 go build -mod=readonly -tags=cometbft -trimpath -buildvcs=false \
    -ldflags='-s -w -buildid= -X github.com/cometbft/cometbft/version.TMGitCommitHash=0880b4d378f347ab16e54ec677ff50d803f37d62' \
    -o "$output" ./cmd/cometbft
)
cp "$info_file" "$package_root/target/etna-signer/comet-source.json"
python3 - "$package_root/comet-manifest.json" "$output" "$test_manifest" <<'PY'
import hashlib, json, os, sys
manifest = json.load(open(sys.argv[1]))
machine = os.uname().machine.lower()
platform = f"{sys.platform}/{dict(x86_64='amd64', aarch64='arm64').get(machine, machine)}"
digest = hashlib.sha256(open(sys.argv[2], "rb").read()).hexdigest()
test = dict(manifest, platforms={platform: dict(sha256=digest, artifact="local unmodified source build for tests; not the official executable")})
test.pop("unsupported_platforms", None)
with open(sys.argv[3], "w") as out:
    json.dump(test, out, indent=2)
PY
echo "Built a non-official CometBFT for tests; the supervisor accepts it only with ETNA_COMET_MANIFEST=$test_manifest" >&2
