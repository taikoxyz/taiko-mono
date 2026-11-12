#!/usr/bin/env bash
# Exercise the selection gate with a fake Cargo process; no Rust compilation is needed.
set -euo pipefail

VECTOR_SCRIPT_ROOT="$(cd "$(dirname "$0")" && pwd)"
VECTOR_GUARD_TMP="$(mktemp -d)"
trap 'rm -rf "$VECTOR_GUARD_TMP"' EXIT
mkdir "$VECTOR_GUARD_TMP/bin"
cat > "$VECTOR_GUARD_TMP/bin/cargo" <<'CARGO'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$VECTOR_GUARD_CALLS"
if [[ "$*" == *' -- --list' ]]; then
    cat "$VECTOR_GUARD_LIST"
fi
CARGO
chmod +x "$VECTOR_GUARD_TMP/bin/cargo"
export PATH="$VECTOR_GUARD_TMP/bin:$PATH"
export VECTOR_GUARD_CALLS="$VECTOR_GUARD_TMP/calls"
export VECTOR_GUARD_LIST="$VECTOR_GUARD_TMP/list"
VECTOR_TEST_PREFIX='derivation::pipeline::shasta::pipeline::payload::boundary_vectors::'

write_valid_list() {
    printf '%s%s: test\n' "$VECTOR_TEST_PREFIX" unzen_boundary_vectors \
        "$VECTOR_TEST_PREFIX" unzen_boundary_vectors_client_fork_selection \
        "$VECTOR_TEST_PREFIX" unzen_boundary_vectors_reject_mutated_expectations > "$VECTOR_GUARD_LIST"
}

expect_refusal() {
    local scenario="$1"
    : > "$VECTOR_GUARD_CALLS"
    if bash "$VECTOR_SCRIPT_ROOT/test_derivation_vectors.sh" > "$VECTOR_GUARD_TMP/output" 2>&1; then
        echo "selection guard accepted $scenario" >&2
        exit 1
    fi
    if [[ "$(wc -l < "$VECTOR_GUARD_CALLS" | tr -d ' ')" != 1 ]] ||
        [[ "$(cat "$VECTOR_GUARD_CALLS")" != *' -- --list' ]]; then
        echo "selection guard executed tests after $scenario" >&2
        cat "$VECTOR_GUARD_CALLS" >&2
        exit 1
    fi
    if ! grep -q 'expected exactly 3 derivation vector tests' "$VECTOR_GUARD_TMP/output"; then
        cat "$VECTOR_GUARD_TMP/output" >&2
        exit 1
    fi
}

: > "$VECTOR_GUARD_LIST"
expect_refusal 'zero matching tests'
write_valid_list
sed 's/unzen_boundary_vectors_client_fork_selection/unzen_boundary_vectors_renamed/' \
    "$VECTOR_GUARD_LIST" > "$VECTOR_GUARD_TMP/renamed"
mv "$VECTOR_GUARD_TMP/renamed" "$VECTOR_GUARD_LIST"
expect_refusal 'a renamed required test'
write_valid_list
printf '%sextra: test\n' "$VECTOR_TEST_PREFIX" >> "$VECTOR_GUARD_LIST"
expect_refusal 'an unexpected fourth test'
write_valid_list
printf '%sunzen_boundary_vectors: test\n' "$VECTOR_TEST_PREFIX" >> "$VECTOR_GUARD_LIST"
expect_refusal 'a duplicate matching test'
write_valid_list
: > "$VECTOR_GUARD_CALLS"
bash "$VECTOR_SCRIPT_ROOT/test_derivation_vectors.sh" > "$VECTOR_GUARD_TMP/output" 2>&1
if [[ "$(wc -l < "$VECTOR_GUARD_CALLS" | tr -d ' ')" != 2 ]] ||
    [[ "$(tail -n 1 "$VECTOR_GUARD_CALLS")" != 'test --locked -p driver --lib unzen_boundary_vectors -- --include-ignored' ]]; then
    echo 'selection guard did not execute the required tests after a valid listing' >&2
    cat "$VECTOR_GUARD_CALLS" >&2
    exit 1
fi
echo 'derivation vector selection guard: all controls passed'
