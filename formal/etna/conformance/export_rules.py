#!/usr/bin/env python3
"""Export actual M11 public calls; Python validates structure, never L1 acceptance."""
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
MODEL = ROOT.parent / "EtnaRulesSchedule.tla"
CONFIG = ROOT.parent / "configs/rules-public.cfg"
STOP_CONFIG = ROOT.parent / "configs/rules-stop-handoff-public.cfg"
PARSER_SOURCE = ROOT / "export_recovery.py"
PINS = ROOT / "pins.json"
CONTRACT_MANIFEST = ROOT / "manifests/contracts.json"
TLC_SHA = "936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88"
CONTRACT_COMMIT = "89f419915de4b73bb57c53bf970f6dea9e8e8c8c"
COUNTS = dict(Earliest=2, Reschedule=4, RulesLock=2, RuleNumber=1, Promote=2,
              PromotionRevert=2, StopCancel=2, StopLock=2, StopReached=1, BadStop=1,
              BadZeroStop=1, TooEarly=1, NotOwner=1, Uninitialized=1, RecoveryZero=3,
              RecoveryNew=3, RecoveryNumber=2, RecoveryExpired=1, RecoveryNonce=1,
              RecoveryCheckpoint=1, RecoveryGeneration=1, RecoveryStop=2, RecoveryNoStart=1)
REQUIRED = {f"{program}/{i}" for program, count in COUNTS.items() for i in range(1, count + 1)}
STOP_COUNTS = dict(StopDueRecovery=3, StopFutureRecovery=3, StopOffGridRecovery=3)
MAPPING = dict(timestamp_base=100000, timestamp_scale=1152, cancellation_sentinel=99,
               cancellation_uint48=2**48 - 1, etna_start=6, grid_interval=6)
WRAPPER = r'''------------------------ MODULE EtnaRulesExport ------------------------
EXTENDS EtnaRulesSchedule
VARIABLE printed
ExportVars == <<RulesVars, printed>>
ExportInit == RulesInit /\ printed = 0
ExportNext == IF receipt.present /\ printed < index
 THEN /\ PrintT(<<"ETNA_RULES", PublicAttempt>>)
      /\ printed' = index /\ UNCHANGED RulesVars
 ELSE RulesNext /\ UNCHANGED printed
ExportSpec == ExportInit /\ [][ExportNext]_ExportVars
=============================================================================
'''
_spec = importlib.util.spec_from_file_location("etna_rules_parser", PARSER_SOURCE)
_parser = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_parser)
ValueParser = _parser.ValueParser


def digest(value):
    return hashlib.sha256(value).hexdigest()


def content_digest(value):
    return digest(json.dumps({k: v for k, v in value.items() if k != "content_sha256"},
                             sort_keys=True, separators=(",", ":")).encode())


def profile_config(profile):
    if profile == "rules":
        return CONFIG
    if profile == "stop-handoff":
        return STOP_CONFIG
    raise ValueError("unknown replay profile")


def profile_counts(profile):
    profile_config(profile)
    return COUNTS if profile == "rules" else STOP_COUNTS


def sources(profile="rules"):
    return [BASE, MODEL, profile_config(profile), PARSER_SOURCE, PINS, CONTRACT_MANIFEST]


def derived_config(raw):
    return raw.decode().replace("SPECIFICATION RulesSpec", "SPECIFICATION ExportSpec")


def provenance(inputs, profile="rules"):
    config = profile_config(profile)
    return dict(base_sha256=digest(inputs[BASE]), model_sha256=digest(inputs[MODEL]),
                source_config_sha256=digest(inputs[config]),
                export_config_sha256=digest(derived_config(inputs[config]).encode()),
                parser_sha256=digest(inputs[PARSER_SOURCE]), pins_sha256=digest(inputs[PINS]),
                contracts_manifest_sha256=digest(inputs[CONTRACT_MANIFEST]),
                wrapper_sha256=digest(WRAPPER.encode()), tlc_sha256=TLC_SHA,
                contracts_commit=CONTRACT_COMMIT)


def parse_receipts(log, profile="rules"):
    counts = profile_counts(profile)
    required = {f"{program}/{i}" for program, count in counts.items() for i in range(1, count + 1)}
    if ("Model checking completed. No error has been found." not in log
            or "0 states left on queue." not in log or re.search(r"^Error:", log, re.M)):
        raise ValueError("TLC did not exhaust")
    rows = {}
    for match in re.finditer(r'<<\s*"ETNA_RULES"\s*,', log):
        row = ValueParser(log[match.start():]).value()
        if len(row) != 2 or row[0] != "ETNA_RULES":
            raise ValueError("wrong receipt envelope")
        attempt = row[1]
        key = f"{attempt['program']}/{attempt['index']}"
        if key in rows:
            raise ValueError("duplicate public attempt")
        rows[key] = dict(id=key, attempt=attempt)
    if set(rows) != required:
        raise ValueError("missing/unexpected public attempts")
    return [rows[key] for key in sorted(rows)]


def validate(data, profile="rules"):
    counts = profile_counts(profile)
    required = {f"{program}/{i}" for program, count in counts.items() for i in range(1, count + 1)}
    schema = "etna-rules-replay-1" if profile == "rules" else "etna-stop-handoff-replay-1"
    if data.get("schema") != schema or data.get("mapping") != MAPPING:
        raise ValueError("wrong schema/time mapping")
    inputs = {p: p.read_bytes() for p in sources(profile)}
    if data.get("provenance") != provenance(inputs, profile):
        raise ValueError("wrong model/config/parser/contract provenance")
    pins = json.loads(inputs[PINS])
    if pins["contracts"]["commit"] != CONTRACT_COMMIT or pins["contracts"]["manifestSha256"] != digest(inputs[CONTRACT_MANIFEST]):
        raise ValueError("wrong contract source inventory")
    if data.get("content_sha256") != content_digest(data):
        raise ValueError("changed expectations")
    cases = data.get("cases", [])
    if len(cases) != sum(counts.values()) or {case["id"] for case in cases} != required:
        raise ValueError("missing/duplicate cases")
    schedule_fields = {"activeRules", "nextRules", "rulesTime", "stopTime", "stopGrid"}
    for case in cases:
        a = case["attempt"]
        if a["schemaVersion"] != 1 or a["present"] is not True:
            raise ValueError("missing actual public attempt")
        if case["id"] != f"{a['program']}/{a['index']}":
            raise ValueError("original call identity mismatch")
        if a["operation"] not in {"Rules", "Stop", "Recover"}:
            raise ValueError("unknown operation")
        if type(a["accepted"]) is not bool or a["scheduleEvent"]["present"] != a["accepted"]:
            raise ValueError("invalid actual outcome/event")
        if a["context"]["registryUnlocked"] is not True:
            raise ValueError("registry callback context is outside this replay")
        if a["setup"]["etnaStart"] != 6 or a["setup"]["gridInterval"] != 6 or a["setup"]["maxAnchorAge"] != 1 or a["setup"]["cancellationSentinel"] != 99:
            raise ValueError("wrong public setup mapping")
        if len(a["scheduleEvent"]["limbs"]) != 5 or a["scheduleEvent"]["reserved16"] != 0:
            raise ValueError("invalid raw event limbs")
        for side in ("before", "after"):
            if set(a[side]["schedule"]) != schedule_fields:
                raise ValueError("incomplete five-field schedule")
            if set(a[side]["origin"]) != {"present", "height", "l1Block", "timestamp"}:
                raise ValueError("incomplete origin")
    # Validate ordering/continuity, not whether a call should be accepted.
    by_id = {case["id"]: case["attempt"] for case in cases}
    for program, count in counts.items():
        for i in range(2, count + 1):
            previous, current = by_id[f"{program}/{i-1}"], by_id[f"{program}/{i}"]
            if previous["after"] != current["before"] or previous["setup"] != current["setup"]:
                raise ValueError("broken executed program continuity")
            if previous["context"]["timestamp"] > current["context"]["timestamp"]:
                raise ValueError("non-monotone call clock")


def generate(java, jar, log_path=None, profile="rules"):
    inputs = {p: p.read_bytes() for p in sources(profile)}
    if digest(Path(jar).read_bytes()) != TLC_SHA:
        raise ValueError("wrong TLC binary")
    with tempfile.TemporaryDirectory(prefix="etna-rules-replay-") as directory:
        work = Path(directory)
        for source in (BASE, MODEL):
            (work / source.name).write_bytes(inputs[source])
        (work / "EtnaRulesExport.tla").write_text(WRAPPER)
        (work / "Export.cfg").write_text(derived_config(inputs[profile_config(profile)]))
        result = subprocess.run([str(Path(java).resolve()), "-Xmx256m", "-XX:+UseParallelGC", "-cp",
                                 str(Path(jar).resolve()), "tlc2.TLC", "-workers", "1", "-seed", "1",
                                 "-deadlock", "-config", "Export.cfg", "-metadir", "states", "EtnaRulesExport"],
                                cwd=work, capture_output=True, text=True, timeout=45,
                                env={"PATH": "/usr/bin:/bin", "LANG": "C.UTF-8"})
        if result.returncode:
            raise ValueError("TLC failed: " + result.stdout[-3000:] + result.stderr[-1000:])
        if any(p.read_bytes() != value for p, value in inputs.items()) or digest(Path(jar).read_bytes()) != TLC_SHA:
            raise ValueError("TLC inputs changed")
        cases = parse_receipts(result.stdout, profile)
    data = dict(schema="etna-rules-replay-1" if profile == "rules" else "etna-stop-handoff-replay-1",
                mapping=MAPPING, provenance=provenance(inputs, profile), cases=cases,
                boundaries=["Authenticated resolved L2 anchor and actual node/image rules are model-only",
                            "Unzen finalization and first-landing proof are explicit setup premises",
                            "Registry callback lock and structural K upgrade are not replayed"],
                supplemental=["Concrete uint48 scheduling boundary and ABI range rejection"])
    data["content_sha256"] = content_digest(data)
    validate(data, profile)
    if log_path is not None:
        Path(log_path).write_text(result.stdout)
    return data


def compare_fixture(actual, current, profile="rules"):
    validate(actual, profile)
    validate(current, profile)
    if actual != current:
        raise ValueError("fixture differs from actual M11 execution")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--java", required=True)
    parser.add_argument("--jar", required=True)
    parser.add_argument("--profile", choices=("rules", "stop-handoff"), default="rules")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--log", type=Path)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    output = args.output or ROOT / ("rules_cases.json" if args.profile == "rules" else "stop_handoff_cases.json")
    data = generate(args.java, args.jar, args.log, args.profile)
    if args.check:
        compare_fixture(data, json.loads(output.read_text()), args.profile)
    else:
        output.write_text(json.dumps(data, sort_keys=True, indent=2) + "\n")
    print(f"{len(data['cases'])} actual M11 public calls across {len(profile_counts(args.profile))} programs; scale1152 and raw event limbs")


if __name__ == "__main__":
    main()
