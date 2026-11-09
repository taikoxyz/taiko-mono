#!/usr/bin/env bash
# Full reproducible package validation. Requires Python >=3.11 and the pinned Lean toolchain.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/check.py
python3 -m unittest discover -s scripts/tests -v
lake build
mkdir -p .lake/audit
lake env lean -o .lake/audit/Audit.olean scripts/Audit.lean
LEAN_PATH="$(pwd)/.lake/audit${LEAN_PATH:+:$LEAN_PATH}" lake env lean scripts/AuditTests.lean
LEAN_PATH="$(pwd)/.lake/audit${LEAN_PATH:+:$LEAN_PATH}" lake env lean --run scripts/RunAudit.lean
for library in DerivationModel DerivationStatements DerivationProofs DerivationWitnesses DerivationVectors; do
  lake env leanchecker "$library"
done
lake exe vectors ../../testdata/derivation_vectors/manifest_cases.json
