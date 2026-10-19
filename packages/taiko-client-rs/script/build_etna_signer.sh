#!/usr/bin/env bash
# Reproducible host helper for Docker devnets; production image cross-builds separately.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
if [[ "$(go env GOVERSION)" != "go1.27.2" ]]; then
  echo "etna-signer requires Go 1.27.2" >&2
  exit 1
fi
mkdir -p target/etna-signer
cd tools/etna-signer
CGO_ENABLED=0 go build -mod=readonly -trimpath -buildvcs=false -ldflags='-s -w -buildid=' -o ../../target/etna-signer/etna-signer .
