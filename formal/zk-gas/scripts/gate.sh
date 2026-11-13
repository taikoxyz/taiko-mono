#!/usr/bin/env bash
# Full reproducible package validation. Requires Python >=3.11 and the pinned Lean toolchain.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/check.py
python3 -m unittest discover -s scripts/tests -v
lake build
python3 scripts/test_meter_generator.py
lake exe generate-meter-vectors --check ../../testdata/zk_gas_vectors/meter-vectors.json
mkdir -p .lake/audit
lake env lean -o .lake/audit/Audit.olean scripts/Audit.lean
LEAN_PATH="$(pwd)/.lake/audit${LEAN_PATH:+:$LEAN_PATH}" lake env lean scripts/AuditTests.lean
LEAN_PATH="$(pwd)/.lake/audit${LEAN_PATH:+:$LEAN_PATH}" lake env lean --run scripts/RunAudit.lean
for library in ZkGasModel ZkGasStatements ZkGasProofs ZkGasWitnesses ZkGasTraces; do
  lake env leanchecker "$library"
done
# Every vector's trace, then the branch coverage gate. check-traces fails when traces/ is missing.
lake exe check-traces ../../testdata/zk_gas_vectors
