#!/usr/bin/env bash
# Full reproducible package validation. Requires Python >=3.11 and the pinned Lean toolchain.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/check.py
python3 scripts/check_statements.py
python3 -m unittest discover -s scripts/tests -v
python3 ../../testdata/derivation_vectors/generate_boundaries.py --check
python3 -m unittest discover -s ../../testdata/derivation_vectors -p 'test_boundary_vectors.py' -v
lake build
mkdir -p .lake/audit
lake env lean -o .lake/audit/Audit.olean scripts/Audit.lean
LEAN_PATH="$(pwd)/.lake/audit${LEAN_PATH:+:$LEAN_PATH}" lake env lean scripts/AuditTests.lean
LEAN_PATH="$(pwd)/.lake/audit${LEAN_PATH:+:$LEAN_PATH}" lake env lean --run scripts/RunAudit.lean
for library in DerivationModel DerivationStatements DerivationProofs DerivationWitnesses DerivationVectors; do
  lake env leanchecker "$library"
done
lake exe vectors ../../testdata/derivation_vectors/manifest_cases.json
lake exe vectors --boundaries ../../testdata/derivation_vectors/boundary_cases.json
python3 scripts/test_model_vectors.py -v
mkdir -p .lake/model_vectors
rm -f .lake/model_vectors/inputs.json .lake/model_vectors/expected.json
python3 ../../testdata/derivation_vectors/generate_model_inputs.py --output .lake/model_vectors/inputs.json
lake exe vectors --emit-boundaries .lake/model_vectors/inputs.json .lake/model_vectors/expected.json
