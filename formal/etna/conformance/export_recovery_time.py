#!/usr/bin/env python3
"""Export actual TLC first-header observations; no Python header constructor."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent
MODEL = ROOT.parent / "EtnaRecoveryTime.tla"
CONFIG = ROOT.parent / "configs/recovery-time-normal.cfg"
PARSER_SOURCE = ROOT / "export_recovery.py"
PINS = ROOT / "pins.json"
EXPORTER = Path(__file__).resolve()
INPUTS = (MODEL, CONFIG, PARSER_SOURCE, PINS, EXPORTER)
_spec = importlib.util.spec_from_file_location("etna_time_parser", PARSER_SOURCE)
_parser = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_parser)
ValueParser = _parser.ValueParser
REQUIRED = {"equal-times", "parent-dominates", "later-anchor"}
TLC_SHA = "936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88"
WRAPPER = r"""-------------------------- MODULE EtnaRecoveryTimeExport --------------------------
EXTENDS EtnaRecoveryTime
VARIABLE printed
exportVars == <<vars,printed>>
ExportInit == Init /\ printed=FALSE
ExportNext == ((Prepare \/ Construct) /\ UNCHANGED printed) \/
 (/\ observed.present /\ ~printed
  /\ PrintT(<<"ETNA_RECOVERY_TIME",caseId,observed>>)
  /\ printed'=TRUE /\ UNCHANGED vars)
ExportSpec == ExportInit /\ [][ExportNext]_exportVars
=================================================================================
"""


def digest(value):
    return hashlib.sha256(value).hexdigest()


def content_digest(value):
    return digest(json.dumps({k: v for k, v in value.items() if k != "content_sha256"},
                             sort_keys=True, separators=(",", ":")).encode())


def export_config(raw):
    return raw.decode().replace("SPECIFICATION Spec", "SPECIFICATION ExportSpec")


def provenance(inputs):
    return {"sources_sha256": {p.name: digest(inputs[p]) for p in INPUTS},
            "spec": json.loads(inputs[PINS])["spec"], "tlc_sha256": TLC_SHA,
            "wrapper_sha256": digest(WRAPPER.encode()),
            "export_config_sha256": digest(export_config(inputs[CONFIG]).encode())}


def parse_receipts(log):
    if ("Model checking completed. No error has been found." not in log
            or "0 states left on queue." not in log or re.search(r"^Error:", log, re.M)):
        raise ValueError("TLC did not exhaust successfully")
    rows = {}
    for match in re.finditer(r'<<\s*"ETNA_RECOVERY_TIME"\s*,', log):
        row = ValueParser(log[match.start():]).value()
        if len(row) != 3 or row[0] != "ETNA_RECOVERY_TIME":
            raise ValueError("wrong receipt envelope")
        _, name, observation = row
        if name in rows:
            raise ValueError("duplicate receipt")
        rows[name] = dict(id=name, observation=observation)
    if set(rows) != REQUIRED:
        raise ValueError("missing/unexpected receipts")
    return [rows[name] for name in sorted(rows)]


def exact_fields(value, fields):
    if not isinstance(value, dict) or set(value) != set(fields):
        raise ValueError("missing/unexpected observation fields")


def validate(data):
    exact_fields(data, ("schema", "provenance", "cases", "boundaries", "content_sha256"))
    if data["schema"] != "etna-recovery-time-replay-1":
        raise ValueError("wrong schema")
    if data["content_sha256"] != content_digest(data):
        raise ValueError("changed observations")
    if data["provenance"] != provenance({p: p.read_bytes() for p in INPUTS}):
        raise ValueError("wrong source/tool provenance")
    cases = data["cases"]
    if len(cases) != 3 or {c["id"] for c in cases} != REQUIRED:
        raise ValueError("missing/duplicate cases")
    for case in cases:
        exact_fields(case, ("id", "observation"))
        o = case["observation"]
        exact_fields(o, ("present", "raw", "header"))
        if o["present"] is not True:
            raise ValueError("missing actual observation")
        exact_fields(o["raw"], ("generation", "parent", "origin", "anchor"))
        exact_fields(o["raw"]["parent"], ("height", "elTimestamp"))
        exact_fields(o["raw"]["origin"], ("height", "l1Number", "l1Timestamp"))
        exact_fields(o["raw"]["anchor"], ("l1Number", "l1Timestamp"))
        exact_fields(o["header"], ("generation", "height", "parentHeight", "bftTime",
                                  "elTimestamp", "anchor", "lastBlockIDEmpty", "lastCommitEmpty"))
        exact_fields(o["header"]["anchor"], ("l1Number", "l1Timestamp"))


def generate(java, jar, log_output=None):
    inputs = {p: p.read_bytes() for p in INPUTS}
    if digest(Path(jar).read_bytes()) != TLC_SHA:
        raise ValueError("wrong TLC binary")
    with tempfile.TemporaryDirectory(prefix="etna-recovery-time-") as directory:
        work = Path(directory)
        (work / MODEL.name).write_bytes(inputs[MODEL])
        (work / "EtnaRecoveryTimeExport.tla").write_text(WRAPPER)
        (work / "Export.cfg").write_text(export_config(inputs[CONFIG]))
        result = subprocess.run([str(Path(java).resolve()), "-Xmx256m", "-XX:+UseParallelGC", "-cp",
            str(Path(jar).resolve()), "tlc2.TLC", "-workers", "1", "-seed", "1", "-config",
            "Export.cfg", "-metadir", "states", "EtnaRecoveryTimeExport"], cwd=work,
            capture_output=True, text=True, timeout=45,
            env={"PATH": "/usr/bin:/bin", "LANG": "C.UTF-8"})
        if any(p.read_bytes() != value for p, value in inputs.items()) or digest(Path(jar).read_bytes()) != TLC_SHA:
            raise ValueError("TLC inputs changed")
        if result.returncode:
            raise ValueError("TLC failed: " + result.stdout[-4000:] + result.stderr[-1000:])
        cases = parse_receipts(result.stdout)
    data = dict(schema="etna-recovery-time-replay-1", provenance=provenance(inputs), cases=cases,
        boundaries=["Authenticated retained parent, fixed origin and finalized anchor are trusted inputs",
                    "Integer seconds; no subsecond BFT-time rounding exercised",
                    "Deterministic first-header construction, not STF history or consensus execution"])
    data["content_sha256"] = content_digest(data)
    validate(data)
    if log_output is not None:
        Path(log_output).write_text(result.stdout + result.stderr)
    return data


def compare_fixture(actual, current):
    validate(actual)
    validate(current)
    if actual != current:
        raise ValueError("fixture differs from actual model execution")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--java", required=True)
    parser.add_argument("--jar", required=True)
    parser.add_argument("--output", type=Path, default=ROOT / "recovery_time_cases.json")
    parser.add_argument("--log", type=Path)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    data = generate(args.java, args.jar, args.log)
    if args.check:
        compare_fixture(data, json.loads(args.output.read_text()))
    else:
        args.output.write_text(json.dumps(data, sort_keys=True, indent=2) + "\n")
    print("3 actual recovery first-header observations; distinct BFT/EL clocks")


if __name__ == "__main__":
    main()
