toolchain := "nightly-2025-09-27"

fmt:
  rustup toolchain install {{toolchain}} && \
  cargo +{{toolchain}} fmt && \
  cargo sort --workspace --grouped

fmt-check:
  rustup toolchain install {{toolchain}} && \
  cargo +{{toolchain}} fmt --check

clippy:
  cargo clippy --workspace --all-features --no-deps -- -D warnings -D missing_docs -D clippy::missing_docs_in_private_items

clippy-fix:
  cargo clippy --fix --workspace --all-features --no-deps --allow-dirty --allow-staged -- -D warnings

udeps:
  cargo +{{toolchain}} udeps --all-targets

test:
  cargo nextest -v run \
    --workspace --all-features
