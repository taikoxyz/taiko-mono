#!/usr/bin/env bash
# Rejects proof escape hatches in the spec sources (TaikoSpec.lean and TaikoSpec/):
#   sorry, admit                    unproved goals
#   native_decide                   trusts the compiler instead of the kernel
#   axiom                           adds an assumption
#   implemented_by, extern, unsafe  run code other than the definition the proofs are about
#   partial                         a function the kernel cannot unfold
#   debug.skipKernelTC              skips kernel checking
# `lake exe checkaxioms` backs this up by checking what each declaration actually depends on.
set -euo pipefail
cd "$(dirname "$0")/.."

forbidden='sorry|admit|native_decide|axiom|implemented_by|extern|unsafe|partial|debug\.skipKernelTC'
if grep -rnwE "$forbidden" TaikoSpec.lean TaikoSpec; then
  echo "gate: the spec sources above use a forbidden construct" >&2
  exit 1
fi
echo "gate: ok"
