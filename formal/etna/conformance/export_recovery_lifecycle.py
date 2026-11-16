#!/usr/bin/env python3
"""Export eight actual frozen M08 lifecycle receipts; no Python protocol oracle."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent
BASE = ROOT.parent / "EtnaSettlement.tla"
MODEL = ROOT.parent / "EtnaRecoveryTransaction.tla"
PROFILES = ("Displaced", "Withdrawn")
CONFIGS = {profile: ROOT.parent / "configs" / ("recovery-tx-" + profile.lower() + ".cfg")
           for profile in PROFILES}
TLC_SHA = "936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88"
WRAPPER = r'''----------------------- MODULE EtnaRecoveryExport -----------------------
EXTENDS EtnaRecoveryTransaction
VARIABLE printed
exportVars == <<allVars,printed>>
ExportInit == TransactionInit /\ printed=FALSE
ExportNext == IF setup<2 THEN TransactionNext /\ UNCHANGED printed
 ELSE IF tx.phase="Idle" /\ now=0 THEN BaseTick /\ UNCHANGED <<setup,printed>>
 ELSE IF tx.phase="Idle" THEN
   (\E kind \in RequestKinds,failure \in FailureModes:
      Begin(kind,Exclusions(kind),FIList(kind),failure,"None")) /\ UNCHANGED <<setup,printed>>
 ELSE IF tx.phase="Done" THEN
   /\ ~printed /\ PrintT(<<"ETNA_RECOVERY",observed.original.kind,PublicAttempt>>)
   /\ printed'=TRUE /\ UNCHANGED allVars
 ELSE AllActions /\ UNCHANGED <<setup,printed>>
ExportSpec == ExportInit /\ [][ExportNext]_exportVars
=============================================================================
'''
# One authoritative constrained TLC-value parser, shared with the existing C03 exporter.
PARSER_SOURCE = ROOT / "export_recovery.py"
_parser_spec = importlib.util.spec_from_file_location("etna_recovery_parser", PARSER_SOURCE)
_parser_module = importlib.util.module_from_spec(_parser_spec)
_parser_spec.loader.exec_module(_parser_module)
ValueParser = _parser_module.ValueParser


KINDS = {"Mixed", "Unheld"}
FAILURES = {"None", "SecondRegistry"}
REQUIRED = {p + "/" + k + "/" + f for p in PROFILES for k in KINDS for f in FAILURES}


def digest(value):
    return hashlib.sha256(value).hexdigest()


def content_digest(value):
    return digest(json.dumps({k: v for k, v in value.items() if k != "content_sha256"},
                             sort_keys=True, separators=(",", ":")).encode())


def derived_config(raw):
    text = raw.decode().replace("SPECIFICATION RecoveryTransactionSpec", "SPECIFICATION ExportSpec")
    return text.replace('CallbackModes = {"None", "Registry"}', 'CallbackModes = {"None"}')


def provenance(inputs):
    return {"base_sha256": digest(inputs[BASE]), "model_sha256": digest(inputs[MODEL]),
            "source_configs_sha256": {p: digest(inputs[CONFIGS[p]]) for p in PROFILES},
            "export_configs_sha256": {p: digest(derived_config(inputs[CONFIGS[p]]).encode())
                                      for p in PROFILES},
            "wrapper_sha256": digest(WRAPPER.encode()), "tlc_sha256": TLC_SHA,
            "parser_source_sha256": digest(inputs[PARSER_SOURCE])}


def parse_receipts(log, profile):
    if "Model checking completed. No error has been found." not in log or "0 states left on queue." not in log:
        raise ValueError("TLC did not exhaust")
    cases = {}
    for match in re.finditer(r'<<\s*"ETNA_RECOVERY"\s*,', log):
        row = ValueParser(log[match.start():]).value()
        if len(row) != 3 or row[0] != "ETNA_RECOVERY":
            raise ValueError("wrong receipt envelope")
        _, kind, attempt = row
        key = profile + "/" + kind + "/" + attempt["injection"]["failure"]
        if key in cases:
            raise ValueError("duplicate receipt")
        cases[key] = dict(id=key, profile=profile, kind=kind, attempt=attempt)
    required = {key for key in REQUIRED if key.startswith(profile + "/")}
    if set(cases) != required:
        raise ValueError("missing/unexpected public attempts")
    return [cases[key] for key in sorted(cases)]


def validate(data):
    if data.get("schema") != "etna-recovery-lifecycle-1" or data.get("grid") != 6:
        raise ValueError("wrong schema/grid")
    sources = [BASE, MODEL, *CONFIGS.values(), PARSER_SOURCE]
    if data.get("provenance") != provenance({p: p.read_bytes() for p in sources}):
        raise ValueError("wrong frozen model/config/tool provenance")
    if data.get("content_sha256") != content_digest(data):
        raise ValueError("changed expectations")
    cases = data.get("cases", [])
    if len(cases) != 8 or {case["id"] for case in cases} != REQUIRED:
        raise ValueError("missing/duplicate cases")
    for case in cases:
        attempt = case["attempt"]
        if case["id"] != case["profile"] + "/" + case["kind"] + "/" + attempt["injection"]["failure"]:
            raise ValueError("case identity mismatch")
        if attempt["schemaVersion"] != 1 or not attempt["present"]:
            raise ValueError("missing public attempt")
        if attempt["injection"]["callback"] != "None":
            raise ValueError("unsupported callback is a GAP")
        for side in ["before", "after"]:
            if set(attempt[side]["state"]["bonds"]) != {"0", "1", "2"}:
                raise ValueError("missing canonical bond")


def generate(java, jar):
    sources = [BASE, MODEL, *CONFIGS.values(), PARSER_SOURCE]
    inputs = {p: p.read_bytes() for p in sources}
    if digest(Path(jar).read_bytes()) != TLC_SHA:
        raise ValueError("wrong TLC binary")
    cases = []
    with tempfile.TemporaryDirectory(prefix="etna-recovery-lifecycle-") as directory:
        work = Path(directory)
        for source in [BASE, MODEL]:
            (work / source.name).write_bytes(inputs[source])
        (work / "EtnaRecoveryExport.tla").write_text(WRAPPER)
        for profile in PROFILES:
            (work / "Export.cfg").write_text(derived_config(inputs[CONFIGS[profile]]))
            result = subprocess.run([str(Path(java).resolve()), "-Xmx256m", "-XX:+UseParallelGC", "-cp",
                                     str(Path(jar).resolve()), "tlc2.TLC", "-workers", "1", "-seed", "1",
                                     "-config", "Export.cfg", "-metadir", "states-" + profile,
                                     "EtnaRecoveryExport"], cwd=work, capture_output=True, text=True,
                                    timeout=45, env={"PATH": "/usr/bin:/bin", "LANG": "C.UTF-8"})
            if result.returncode:
                raise ValueError("TLC failed: " + result.stdout[-3000:] + result.stderr[-1000:])
            if any(p.read_bytes() != value for p, value in inputs.items()) or digest(Path(jar).read_bytes()) != TLC_SHA:
                raise ValueError("TLC inputs changed")
            cases.extend(parse_receipts(result.stdout, profile))
    data = dict(schema="etna-recovery-lifecycle-1", grid=6, provenance=provenance(inputs), cases=cases,
                mapping={"start_height": 6, "token_unit": "MIN_STAKE", "filler_count": 4095,
                         "filler_stake_units": 5, "bond_ids": [0, 4096, 4097], "timestamp_scale": 1200},
                gaps=["Registry callback class", "Actual Unzen finalization proof verification"])
    data["content_sha256"] = content_digest(data)
    validate(data)
    return data


def compare_fixture(actual, current):
    validate(actual)
    validate(current)
    if actual != current:
        raise ValueError("fixture differs from actual M08 execution")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--java", required=True)
    parser.add_argument("--jar", required=True)
    parser.add_argument("--output", type=Path, default=ROOT / "recovery_lifecycle_cases.json")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    data = generate(args.java, args.jar)
    if args.check:
        compare_fixture(data, json.loads(args.output.read_text()))
    else:
        args.output.write_text(json.dumps(data, sort_keys=True, indent=2) + "\n")
    print("8 actual M08 lifecycle public attempts; callback/Unzen-proof boundaries explicit")


if __name__ == "__main__":
    main()
