#!/bin/bash

# Generate rust contract bindings.
# ref: https://getfoundry.sh/forge/reference/bind/

set -eou pipefail

ALLOY_VERSION=1.0.36

forge bind \
  --root ../protocol \
  --select '^IInbox$' \
  --select '^CodecOptimized$' \
  --select '^ShastaMainnetInbox$' \
  --bindings-path crates/bindings \
  --crate-name bindings \
  --overwrite \
  --alloy-version ${ALLOY_VERSION}
