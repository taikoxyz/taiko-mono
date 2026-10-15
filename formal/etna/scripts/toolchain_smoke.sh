#!/usr/bin/env bash
# Real Rust -> LLBC -> Lean smoke using an unmodified upstream safe-Rust test.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
: "${AENEAS_ROOT:?set AENEAS_ROOT to the pinned source checkout}"
: "${CHARON_ROOT:?set CHARON_ROOT to the pinned source checkout}"
charon="${CHARON_EXE:-$CHARON_ROOT/charon/target/release/charon}"
aeneas="${AENEAS_EXE:-$AENEAS_ROOT/bin/aeneas}"
python3 "$root/scripts/check_toolchain.py" --aeneas "$AENEAS_ROOT" --charon "$CHARON_ROOT"
work="${SMOKE_DIR:-$root/.scratch/toolchain-smoke}"
mkdir -p "$work/src" "$work/generated"
cp "$AENEAS_ROOT/tests/src/bool-cmp.rs" "$work/src/lib.rs"
cat > "$work/Cargo.toml" <<'TOML'
[package]
name = "etna_toolchain_smoke"
version = "0.0.0"
edition = "2021"
[workspace]
TOML
# Charon was built against the pinned nightly. It reports the actual embedded version.
"$charon" toolchain-version | tee "$work/charon-toolchain.txt"
(
  cd "$work"
  "$charon" cargo --preset=aeneas
)
# Do not replace this with a manually authored Lean function.
if [[ ! -x "$aeneas" ]]; then
  echo "Aeneas binary unavailable; LLBC generated but Lean smoke and Rust refinement remain pending" >&2
  exit 1
fi
"$aeneas" -backend lean -dest "$work/generated" "$work/etna_toolchain_smoke.llbc"
cp "$root/lean-toolchain" "$work/lean-toolchain"
cat > "$work/lakefile.toml" <<TOML
name = "etna_smoke"
[[require]]
name = "aeneas"
path = "$AENEAS_ROOT/backends/lean"
[[lean_lib]]
name = "EtnaToolchainSmoke"
srcDir = "generated"
TOML
(
  cd "$work"
  lake update
  # Compile generated files explicitly; generated namespace/path is chosen by Aeneas.
  while IFS= read -r file; do lake env lean "$file"; done < <(find generated -name '*.lean' -type f | sort)
)
python3 - "$work" <<'PY'
import hashlib,json,pathlib,sys
work=pathlib.Path(sys.argv[1])
files=list(work.glob('generated/**/*.lean'))
assert files, 'Aeneas produced no Lean files'
print(json.dumps({'tool_health':'passed','etna_rust_refinement':'pending','generated':{str(p.relative_to(work)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}},indent=2))
PY
