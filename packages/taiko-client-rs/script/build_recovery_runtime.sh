#!/usr/bin/env bash
# Build the complete controller/native-role Linux runtime used by the governance_recovery
# LinuxRuntime scenarios. Usage: build_recovery_runtime.sh <host-built taiko-client>
#
# On a Linux host of the Docker daemon's architecture whose os-release ID is ubuntu or debian, the
# image is tests/docker/recovery-runtime.Dockerfile on the host's own distribution, holding the
# host-built client, the Go helpers and stock Comet from target/etna-signer, the runtime scripts and
# the EL from ALETHIA_RETH_IMAGE, so the host-built glibc client runs unchanged. Any other host
# builds the production Dockerfile, which compiles the release binaries.
#
# ETNA_BUILD_TARGET=<stage> builds only that stage of the production Dockerfile on every host and
# takes no client argument; tests/entrypoint.sh uses it for the default execution-runtime image.
# A set CARGO_BUILD_JOBS is passed to every production Dockerfile build as its build argument.
set -euo pipefail
target=${ETNA_BUILD_TARGET:-}
client_bin=''
if [[ -z "$target" ]]; then
  client_bin=${1:?usage: build_recovery_runtime.sh <host-built taiko-client>}
  if [[ "$client_bin" != /* ]]; then client_bin="$PWD/$client_bin"; fi
fi
image=${ETNA_RECOVERY_IMAGE:?ETNA_RECOVERY_IMAGE must name this run image}
run_label="taiko-client-rs.test-run=${TAIKO_CLIENT_RS_TEST_RUN:?owned run label}"
cd "$(dirname "${BASH_SOURCE[0]}")/.."
context=$(mktemp -d)
trap 'rm -rf "$context"' EXIT

linux_arch() {
  case "$1" in
    x86_64|amd64) echo amd64 ;;
    aarch64|arm64) echo arm64 ;;
  esac
}
arch=$(linux_arch "$(docker info --format '{{.Architecture}}')")
if [[ -z "$arch" ]]; then
  echo "unsupported Docker daemon architecture" >&2
  exit 1
fi

base_image=''
os_release=${ETNA_HOST_OS_RELEASE:-/etc/os-release}
if [[ -z "$target" && "$(uname -s)" == Linux && "$(linux_arch "$(uname -m)")" == "$arch" && -r "$os_release" ]]; then
  os_id=$(sed -n 's/^ID=//p' "$os_release" | tr -d "\"'")
  os_version=$(sed -n 's/^VERSION_ID=//p' "$os_release" | tr -d "\"'")
  if [[ "$os_id" =~ ^(ubuntu|debian)$ && -n "$os_version" ]]; then
    base_image="$os_id:$os_version"
  fi
fi

if [[ -n "$base_image" ]]; then
  # Not ${…:?}: after it fails, Bash 3.2 exits through the EXIT trap with status 0.
  if [[ -z "${ALETHIA_RETH_IMAGE:-}" ]]; then
    echo "ALETHIA_RETH_IMAGE must name the alethia-reth image the scenarios run" >&2
    exit 1
  fi
  stage() {
    if [[ ! -f "$1" ]]; then
      echo "missing recovery runtime input: $1" >&2
      exit 1
    fi
    mkdir -p "$context/rootfs/$(dirname "$2")"
    cp "$1" "$context/rootfs/$2"
  }
  # Every input is checked before docker build. The staged set must equal what the production
  # runtime stages COPY, minus /app/etna-el-import (RecoveryImage tests enforce it).
  stage "$client_bin" app/taiko-client
  for helper in etna-signer etna-comet-import; do
    stage "target/etna-signer/$helper" "app/$helper"
  done
  stage target/etna-signer/cometbft usr/bin/cometbft
  for script in etna_validator.py start_etna_validator.sh start_etna_full_node.py; do
    stage "script/$script" "app/script/$script"
  done
  # The Comet UID must read and run what it executes whatever the host umask. The staged files are
  # copies, never links, so this leaves the host's build outputs untouched.
  chmod -R a+rX "$context/rootfs"
  cp tests/docker/recovery-runtime.Dockerfile "$context/Dockerfile"
  echo "Building $image from host binaries on $base_image (linux/$arch)"
  docker build --platform "linux/$arch" --build-arg "BASE_IMAGE=$base_image" \
    --build-arg "ALETHIA_RETH_IMAGE=$ALETHIA_RETH_IMAGE" --label "$run_label" -t "$image" "$context"
  exit 0
fi

cd ../..
# Only this package is copied by its Dockerfile. Exclude caches, .build and unrelated packages.
# Read current worktree bytes so the tested runtime includes uncommitted implementation fixes.
git ls-files -z packages/taiko-client-rs | tar --null -T - -cf - | tar -xf - -C "$context"
# Reuse the positional parameters for the optional target and build jobs: an empty array would
# trip `set -u` in Bash 3.2.
set --
if [[ -n "$target" ]]; then
  set -- --target "$target"
fi
# The Dockerfile's release builds default to 2 jobs; CI runners pass their own count.
if [[ -n "${CARGO_BUILD_JOBS:-}" ]]; then
  set -- "$@" --build-arg "CARGO_BUILD_JOBS=$CARGO_BUILD_JOBS"
fi
docker build --platform "linux/$arch" -f "$context/packages/taiko-client-rs/Dockerfile" \
  "$@" --label "$run_label" -t "$image" "$context"
