#!/usr/bin/env bash
# Provide exactly the EL revision already pinned in this client's Cargo graph for native tests.
# On Linux, copy it out of the default alethia-reth image when it is present locally: it is built
# from the same revision and lockfile (release, `/app/alethia-reth`), and this saves a second
# ~17 min source build. Other hosts, another ALETHIA_RETH_IMAGE, a missing default image or a Docker
# daemon of another architecture build the pinned source instead.
set -euo pipefail
CLIENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$CLIENT_DIR"
if [[ -n "${ETNA_EL_BIN:-}" ]]; then
  test -x "$ETNA_EL_BIN"
  exit 0
fi
TASK_PINNED_REVISION=20a9282a24b14567ebad82c427f8ceeeaf40aab4
linux_arch() {
  case "$1" in
    x86_64|amd64) echo amd64 ;;
    aarch64|arm64) echo arm64 ;;
  esac
}
if [[ "$(uname -s)" == Linux ]]; then
  # tests/entrypoint.sh builds this default image from the production Dockerfile's
  # execution-runtime target, which compiles the same revision.
  TASK_PINNED_IMAGE="alethia-reth:etna-$TASK_PINNED_REVISION"
  TASK_ARCH=$(linux_arch "$(uname -m)")
  if [[ "${ALETHIA_RETH_IMAGE:-$TASK_PINNED_IMAGE}" == "$TASK_PINNED_IMAGE" && -n "$TASK_ARCH" ]] &&
    [[ "$(linux_arch "$(docker info --format '{{.Architecture}}' 2> /dev/null)")" == "$TASK_ARCH" ]] &&
    docker image inspect "$TASK_PINNED_IMAGE" > /dev/null 2>&1; then
    echo "Copying alethia-reth from $TASK_PINNED_IMAGE (linux/$TASK_ARCH)"
    TASK_OUTPUT="$CLIENT_DIR/target/etna-signer/alethia-reth"
    TASK_CONTAINER=''
    # Whatever step fails, leave neither a partial binary nor the container. The test-run label lets
    # the entrypoint's cleanup remove the container if this script is killed before its trap runs.
    trap 'rm -f "$TASK_OUTPUT.tmp"; if [[ -n "$TASK_CONTAINER" ]]; then docker rm -f "$TASK_CONTAINER" > /dev/null; fi' EXIT
    mkdir -p "$CLIENT_DIR/target/etna-signer"
    TASK_CONTAINER=$(docker create --platform "linux/$TASK_ARCH" \
      ${TAIKO_CLIENT_RS_TEST_RUN:+--label "taiko-client-rs.test-run=$TAIKO_CLIENT_RS_TEST_RUN"} "$TASK_PINNED_IMAGE")
    docker cp "$TASK_CONTAINER:/app/alethia-reth" "$TASK_OUTPUT.tmp"
    "$TASK_OUTPUT.tmp" --version
    mv -f "$TASK_OUTPUT.tmp" "$TASK_OUTPUT"
    exit 0
  fi
fi
TASK_PINNED_SOURCE=$(cargo metadata --locked --format-version=1 | python3 -c '
import json,pathlib,sys
data=json.load(sys.stdin)
matches=[p for p in data["packages"] if p["name"]=="alethia-reth-chainspec" and (p.get("source") or "").endswith("#"+sys.argv[1])]
if len(matches)!=1: raise SystemExit("expected one exact pinned EL source")
print(pathlib.Path(matches[0]["manifest_path"]).parents[2])
' "$TASK_PINNED_REVISION")
test "$(git -C "$TASK_PINNED_SOURCE" rev-parse HEAD)" = "$TASK_PINNED_REVISION"
git -C "$TASK_PINNED_SOURCE" diff --quiet HEAD --
TASK_TARGET_DIR="${CARGO_TARGET_DIR:-$CLIENT_DIR/target}"
if [[ "$TASK_TARGET_DIR" != /* ]]; then TASK_TARGET_DIR="$CLIENT_DIR/$TASK_TARGET_DIR"; fi
CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-2}" cargo build --locked --manifest-path "$TASK_PINNED_SOURCE/Cargo.toml" --target-dir "$TASK_TARGET_DIR" -p alethia-reth-bin
git -C "$TASK_PINNED_SOURCE" diff --quiet HEAD --
mkdir -p "$CLIENT_DIR/target/etna-signer"
cp "$TASK_TARGET_DIR/debug/alethia-reth" "$CLIENT_DIR/target/etna-signer/alethia-reth"
