#!/usr/bin/env python3
"""Extract the actual shared production core with pinned Charon/Aeneas; reject unknown externs."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
WORKSPACE = REPO / "packages/taiko-client-rs"
CORE = WORKSPACE / "crates/etna-consensus-core"
OUTPUT = ROOT / "Etna/Refinement/Rust"
ROOTS = [
    "etna_consensus_core::has_strict_quorum",
    "etna_consensus_core::positive_unsettled_cap",
    "etna_consensus_core::committee_size_bounded",
    *["etna_consensus_core::forced::" + name for name in
      ["pending_entry", "check_preimage", "is_due", "classify_forced", "resolve_forced", "advance_cursor"]],
    *["etna_consensus_core::schedule::Schedule::" + name for name in
      ["validate", "epoch_of", "h_first", "h_last", "checked_l1_first", "derivation_parent_height",
       "epoch_starting_at", "switch_target", "next_switch_target", "check_anchor_progress", "force_epoch"]],
    "etna_consensus_core::transition::transition_committee",
]


def run(command, **kwargs):
    """Run a real tool and preserve a failed tool's nonzero exit status."""
    return subprocess.run(command, check=True, text=True, **kwargs)


def digest(path):
    """SHA256 of actual bytes, without location or code normalization."""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--work", type=Path)
    parser.add_argument("--compile", action="store_true", help="Build the actual generated Lean with pinned backend imports")
    args = parser.parse_args()
    aeneas_root = Path(os.environ["AENEAS_ROOT"])
    charon_root = Path(os.environ["CHARON_ROOT"])
    charon = os.environ.get("CHARON_EXE", str(charon_root / "charon/target/release/charon"))
    aeneas = os.environ.get("AENEAS_EXE", str(aeneas_root / "bin/aeneas"))
    run(["python3", str(ROOT / "scripts/check_toolchain.py"), "--aeneas", str(aeneas_root), "--charon", str(charon_root)])
    work = args.work or Path(tempfile.mkdtemp(prefix="etna-core-extraction-"))
    work.mkdir(parents=True, exist_ok=True)
    generated = work / "generated"
    generated.mkdir(exist_ok=True)
    llbc = work / "etna_consensus_core.llbc"
    command = [charon, "cargo", "--preset=aeneas", "--dest-file", str(llbc)]
    for symbol in ROOTS:
        command.extend(["--start-from", symbol])
    command.extend(["--", "-p", "etna-consensus-core", "--locked"])
    env = dict(os.environ, CARGO_TARGET_DIR=str(work / "target"))
    with (work / "charon.log").open("w") as log:
        run(command, cwd=WORKSPACE, env=env, stdout=log, stderr=subprocess.STDOUT)
    with (work / "aeneas.log").open("w") as log:
        run([aeneas, "-backend", "lean", "-all-computable", "-dest", str(generated), str(llbc)], stdout=log, stderr=subprocess.STDOUT)
    llbc_data = json.loads(llbc.read_text())
    if llbc_data["has_errors"]:
        raise ValueError("Charon marked production extraction as containing errors")
    files = sorted(generated.glob("*.lean"))
    if len(files) != 1:
        raise ValueError("expected one complete generated production module")
    source = files[0].read_text()
    if re.search(r"(?m)^\s*(?:axiom|opaque)\b|\bsorry(?:Ax)?\b", source):
        raise ValueError("generated production source contains an unresolved axiom/opaque/stub")
    definitions = []
    for match in re.finditer(r"/-- \[([^]\n]+)\]:?\n(?:(?!-/)[\s\S])*?-/\n(?:@\[[^\]]*\]\s*)*def ([^\s(]+)", source):
        rust, lean = match.groups()
        definitions.append({"rust_symbol": rust, "lean_definition": "etna_consensus_core." + lean})
    # Constants and types are documented directly in generated source; every production function must appear.
    constants = {
        "etna_consensus_core.forced.MAX_FORCED_TX_BYTES": "etna_consensus_core::forced::MAX_FORCED_TX_BYTES",
        "etna_consensus_core.schedule.UINT48_MAX": "etna_consensus_core::schedule::UINT48_MAX",
        "etna_consensus_core.MAX_N_MAX": "etna_consensus_core::MAX_N_MAX",
    }
    constant_definitions = [item for item in definitions if item["lean_definition"] in constants]
    if {item["lean_definition"]: item["rust_symbol"] for item in constant_definitions} != constants:
        raise ValueError("generated constants differ from the exact allowlisted initializers")
    function_definitions = [item for item in definitions if item["lean_definition"] not in constants]
    if len(function_definitions) != len(ROOTS):
        raise ValueError(f"missing production definitions: {len(function_definitions)} generated for {len(ROOTS)} roots")
    normalized_roots = {item["rust_symbol"].replace("::{etna_consensus_core::schedule::Schedule}", "::Schedule") for item in function_definitions}
    if normalized_roots != set(ROOTS):
        raise ValueError(f"generated Rust symbol set differs from explicit roots: {normalized_roots ^ set(ROOTS)}")
    declarations = [{"kind": "function", **item} for item in function_definitions]
    declarations.extend({"kind": "constant", "rust_symbol": rust, "lean_definition": lean} for lean, rust in constants.items())
    for match in re.finditer(r"/-- \[([^]\n]+)\]\n(?:(?!-/)[\s\S])*?-/\n(?:@\[[^\]]*\]\n)*(inductive|structure) ([^\s]+)", source):
        rust, kind, lean = match.groups()
        declarations.append({"kind": kind, "rust_symbol": rust, "lean_definition": "etna_consensus_core." + lean})
    log = (work / "aeneas.log").read_text()
    log = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", log)
    counts = {}
    for label in ["transparent", "opaque"]:
        matches = re.findall(r"Translated " + label + r" functions:[^\r\n]*?(\d+)/(\d+)", log)
        if not matches:
            raise ValueError("missing real Aeneas translation counts")
        counts[label] = int(matches[-1][1])
    if counts["transparent"] != len(ROOTS) + len(constants):
        raise ValueError("transparent body count differs from function roots plus constant initializers")
    # Opaque LLBC stdlib declarations are resolved by the pinned Aeneas standard library models.
    # Any unresolved declaration emits an axiom above and is rejected, rather than accepted as a stub.
    if args.compile:
        (work / "lean-toolchain").write_bytes((ROOT / "lean-toolchain").read_bytes())
        (work / "lakefile.toml").write_text(
            'name = "etna_core_extraction"\n[[require]]\nname = "aeneas"\npath = ' + json.dumps(str(aeneas_root / "backends/lean")) +
            '\n[[lean_lib]]\nname = "EtnaConsensusCore"\nsrcDir = "generated"\n')
        run(["lake", "update"], cwd=work)
        run(["lake", "build", "EtnaConsensusCore"], cwd=work)
        run(["lake", "env", "lean", str(files[0])], cwd=work)
    args.output.mkdir(parents=True, exist_ok=True)
    for path in files:
        (args.output / path.name).write_bytes(path.read_bytes())
    lock = json.loads((ROOT / "tools.lock.json").read_text())
    provenance = {
        "schema_version": 1,
        "status": "actual-production-source-extracted; refinement-theorems-pending",
        "crate": "packages/taiko-client-rs/crates/etna-consensus-core",
        "tools": {key: lock[key] for key in ["charon", "aeneas", "extractor_rust", "production_rust", "lean", "mathlib"]},
        "source_sha256": {str(path.relative_to(REPO)): digest(path) for path in sorted(CORE.glob("src/*.rs")) if path.name != "tests.rs"},
        "cargo_sha256": {str(path.relative_to(REPO)): digest(path) for path in [WORKSPACE / "Cargo.toml", WORKSPACE / "Cargo.lock", CORE / "Cargo.toml"]},
        "generated_sha256": {path.name: digest(path) for path in files},
        "generated_definitions": definitions,
        "generated_declarations": declarations,
        "charon_llbc_version": llbc_data["charon_version"],
        "root_symbols": ROOTS,
        "counts": {"production_function_roots": len(ROOTS), "transparent_constant_initializers": len(constants), "transparent_functions": counts["transparent"], "opaque_llbc_stdlib_functions_resolved_by_backend_models": counts["opaque"], "unresolved_generated_axioms": 0, "opaque_stubs": 0},
        "source_normalization": "none; generated bytes are copied unchanged",
        "authentication_boundary": {
            "forced": "ABCI checks presence/index via core before exact MPT proof; adapter authenticates entry and computes size/hash/canonical-first facts. Preimage canonicality is required/computed only after inclusion fails for a due hash-matching entry; its unused input is false. NeedsSkip retains rich bytes in runtime cache equality.",
            "singleton": "Engine adapter only supplies Empty/Retained after canonical tx decoding, exact committed-parent singleton build completion and all existing expected-header checks. Transport, timeout and history failures never supply Empty.",
            "committee": "ABCI establishes DerivedRelation with full CommitteeState equality; pre-insertion presence comes from the complete map. Core overlays derived epoch and checks conflict/outgoing/incoming order. Adapter retains sorted validator union and pruning.",
            "quorum": "Lander verifies ordered distinct committee addresses, ZIP215 signatures and authenticated bounded member powers before applying shared strict quorum arithmetic.",
            "schedule": "ABCI retains all four serialized fields and panic diagnostics; arithmetic and checked overflow decisions delegate to core.",
        },
        "trust_boundary": "Pinned compiler/Charon/Aeneas translation and Aeneas standard scalar/Result library models; adapter-established authentication facts; no generated-source refinement theorem is claimed by extraction alone.",
    }
    (args.output / "provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")
    print(json.dumps(provenance["counts"], indent=2))
    print("Generated production definitions; refinement remains pending")


if __name__ == "__main__":
    main()
