#!/usr/bin/env bash
# Reviewed immutable compilers; dependencies belong to this runner, never a developer machine.
set -euo pipefail
mode="${1:?lean|extract|native|protocol}"
etna_repo="$(git rev-parse --show-toplevel)"
etna_tools="${RUNNER_TEMP:?}/etna-tools"
mkdir -p "$etna_tools/bin"
export PATH="$etna_tools/bin:$HOME/.elan/bin:$PATH"
checksum() { echo "$1  $2" | sha256sum --check --strict; }
resource() { date -u; uname -a; df -h; free -h; }
resource
if [[ "${GITHUB_ACTIONS:-}" == true && "${RUNNER_ENVIRONMENT:-}" == github-hosted && "${RUNNER_OS:-}" == Linux ]]; then
  # Only disposable image-preinstalled SDKs unrelated to these jobs; never source/tool caches.
  sudo rm -rf /usr/local/lib/android /usr/share/dotnet /opt/ghc
  df -h
fi
case "$mode" in
  lean|extract)
    if ! command -v elan >/dev/null; then
      gh release download v4.1.2 --repo leanprover/elan --pattern elan-x86_64-unknown-linux-gnu.tar.gz --dir "$etna_tools"
      checksum f81c2e48c1588d4612cd2c8851947898a45ac8d72748a07dff3a5694f1cf589b "$etna_tools/elan-x86_64-unknown-linux-gnu.tar.gz"
      tar -xzf "$etna_tools/elan-x86_64-unknown-linux-gnu.tar.gz" -C "$etna_tools/bin"
      "$etna_tools/bin/elan-init" -y --no-modify-path --default-toolchain none
    fi
    elan toolchain install leanprover/lean4:v4.35.0-rc4
    echo "$HOME/.elan/bin" >> "$GITHUB_PATH"
    # Materialize the exact lock and retrieve matching Mathlib artifacts; never float pins.
    (cd "$etna_repo/formal/etna"; lake exe cache get)
    ;;
  native|protocol) ;;
  *) echo "unknown bootstrap scope: $mode" >&2; exit 1;;
esac
if [[ "$mode" == native || "$mode" == extract ]]; then
  rustup toolchain install 1.95 --profile minimal
  rustc +1.95 -vV
fi
if [[ "$mode" == native ]]; then
  sudo apt-get update
  sudo apt-get install -y build-essential pkg-config clang libclang-dev llvm-dev cmake protobuf-compiler
  echo "LIBCLANG_PATH=$(llvm-config --libdir)" >> "$GITHUB_ENV"
fi
if [[ "$mode" == protocol ]]; then
  : "${ETNA_PROTOCOL:?immutable protocol repository root}"
  # Install both root formatting tools and protocol compile dependencies before Foundry.
  npm install --global pnpm@9.15.9
  (cd "$etna_repo"; pnpm install --frozen-lockfile --filter . --filter @taiko/protocol)
  (cd "$ETNA_PROTOCOL"; pnpm install --frozen-lockfile --filter . --filter @taiko/protocol)
  echo "$etna_repo/node_modules/.bin" >> "$GITHUB_PATH"
  gh release download v1.5.1 --repo foundry-rs/foundry --pattern foundry_v1.5.1_linux_amd64.tar.gz --dir "$etna_tools"
  checksum 73640b01bd9ed29fdb4965085099371f8cf0dbbec3e2086cf54564efc4dcfe88 "$etna_tools/foundry_v1.5.1_linux_amd64.tar.gz"
  tar -xzf "$etna_tools/foundry_v1.5.1_linux_amd64.tar.gz" -C "$etna_tools/bin"
  echo "$etna_tools/bin" >> "$GITHUB_PATH"
  "$etna_tools/bin/forge" --version
fi
if [[ "$mode" == extract ]]; then
  sudo apt-get update
  sudo apt-get install -y build-essential git ca-certificates rsync unzip bzip2 pkg-config libgmp-dev bubblewrap
  gh release download 2.6.1 --repo ocaml/opam --pattern opam-2.6.1-x86_64-linux --dir "$etna_tools/bin"
  checksum b533d393a6967150d6ef41cb3d71e147e93ecbabeb59e921aa412c0ae79ebe3d "$etna_tools/bin/opam-2.6.1-x86_64-linux"
  install -m755 "$etna_tools/bin/opam-2.6.1-x86_64-linux" "$etna_tools/bin/opam"
  checksum 41f6795a5e2659db139296b0d9d708c9d1b699e5ac0604edebbff64df685ab51 "$etna_repo/formal/etna/tools/opam-environment.export"
  git clone https://github.com/AeneasVerif/aeneas.git "$etna_tools/aeneas"
  git -C "$etna_tools/aeneas" checkout --detach 673f9e30e1e2a81b355df9a9550168e672a10d4e
  git clone https://github.com/AeneasVerif/charon.git "$etna_tools/aeneas/charon"
  git -C "$etna_tools/aeneas/charon" checkout --detach a5276d59516b6e7dc519441e244399ab8d429107
  git -C "$etna_tools/aeneas/charon" submodule update --init --recursive
  rustup toolchain install nightly-2026-09-17 --profile minimal --component rustc-dev,llvm-tools,rust-src,miri
  # Do not accidentally reuse the production Cargo target or compiler flags.
  env -u CARGO_TARGET_DIR -u RUSTFLAGS -u CARGO_ENCODED_RUSTFLAGS cargo +nightly-2026-09-17 build --manifest-path "$etna_tools/aeneas/charon/charon/Cargo.toml" --release --locked --bin charon --bin charon-driver
  mkdir -p "$etna_tools/aeneas/charon/bin"
  install -m755 "$etna_tools/aeneas/charon/charon/target/release/charon" "$etna_tools/aeneas/charon/charon/target/release/charon-driver" "$etna_tools/aeneas/charon/bin/"
  opam --root="$etna_tools/opam-root" init --bare --no-setup -y
  opam --root="$etna_tools/opam-root" switch import "$etna_repo/formal/etna/tools/opam-environment.export" --switch="$etna_tools/ocaml" -y
  (cd "$etna_tools/aeneas"; opam --root="$etna_tools/opam-root" exec --switch="$etna_tools/ocaml" -- make build-bin)
  {
    echo "AENEAS_ROOT=$etna_tools/aeneas"
    echo "CHARON_ROOT=$etna_tools/aeneas/charon"
    echo "AENEAS_EXE=$etna_tools/aeneas/src/_build/default/main.exe"
    echo "CHARON_EXE=$etna_tools/aeneas/charon/bin/charon"
    echo "CHARON_CACHE_DIR=$etna_tools/charon-cache"
  } >> "$GITHUB_ENV"
fi
resource
