#!/bin/bash

# Generate rust contract bindings.
# ref: https://getfoundry.sh/forge/reference/bind/

set -euo pipefail

ALLOY_VERSION=1.0.36

forge bind \
  --root ../protocol \
  --select '^IInbox$' \
  --select '^CodecOptimized$' \
  --bindings-path crates/bindings \
  --crate-name bindings \
  --overwrite \
  --alloy-version ${ALLOY_VERSION}

CARGO_TOML="crates/bindings/Cargo.toml"
SNIPPET=$'\n\n[lib]\ndoctest = false\n\n[lints]\nrust.warnings = "allow"\n'

if ! grep -q 'rust.warnings' "$CARGO_TOML"; then
  printf "%s" "$SNIPPET" >> "$CARGO_TOML"
fi
