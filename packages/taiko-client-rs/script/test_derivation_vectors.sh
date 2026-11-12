#!/usr/bin/env bash
# Fail closed if Cargo's substring filter no longer selects the complete vector suite.
set -euo pipefail

VECTOR_RS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$VECTOR_RS_ROOT"
VECTOR_LIST_TMP="$(mktemp -d)"
trap 'rm -rf "$VECTOR_LIST_TMP"' EXIT
VECTOR_TEST_PREFIX='derivation::pipeline::shasta::pipeline::payload::boundary_vectors::'
printf '%s%s\n' "$VECTOR_TEST_PREFIX" unzen_boundary_vectors \
    "$VECTOR_TEST_PREFIX" unzen_boundary_vectors_client_fork_selection \
    "$VECTOR_TEST_PREFIX" unzen_boundary_vectors_reject_mutated_expectations |
    LC_ALL=C sort > "$VECTOR_LIST_TMP/expected"
cargo test --locked -p driver --lib unzen_boundary_vectors -- --list > "$VECTOR_LIST_TMP/list"
awk '/: test$/ { sub(/: test$/, ""); print }' "$VECTOR_LIST_TMP/list" |
    LC_ALL=C sort > "$VECTOR_LIST_TMP/actual"
if ! cmp -s "$VECTOR_LIST_TMP/expected" "$VECTOR_LIST_TMP/actual"; then
    echo 'expected exactly 3 derivation vector tests with the required names; refusing to run' >&2
    diff -u "$VECTOR_LIST_TMP/expected" "$VECTOR_LIST_TMP/actual" >&2 || true
    exit 1
fi
# Required conformance tests must execute even if someone later adds an ignore attribute.
cargo test --locked -p driver --lib unzen_boundary_vectors -- --include-ignored
