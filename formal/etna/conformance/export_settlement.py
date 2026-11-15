#!/usr/bin/env python3
"""Export receipts produced by TLC executing the unchanged settlement actions.

Python parses observations and validates completeness; it contains no protocol guards.
"""
import argparse
import hashlib
import json
import re
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BASE = ROOT.parent / "EtnaSettlement.tla"
MODEL = ROOT / "EtnaSettlementReplay.tla"
CONFIG = """SPECIFICATION ReplaySpec
CONSTANTS
MaxHeight = 4
MaxGeneration = 2
MaxNonce = 4
MaxTime = 4
CheckCheckpoint = TRUE
CheckNonce = TRUE
CheckDeadline = TRUE
CheckProofGeneration = TRUE
CHECK_DEADLOCK FALSE
INVARIANT TypeOK
"""
LENGTHS = [4, 4, 4, 5, 6, 7, 8, 7]
CASE_NAMES = ["compatible-overlap", "stale-checkpoint", "stale-nonce",
              "inclusive-deadline-and-replay", "expired-then-fresh",
              "old-proof-genesis-origin", "old-proof-retained-origin",
              "two-recoveries-same-checkpoint"]
TLC_SHA256 = "936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88"


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def content_digest(data):
    value = {k: v for k, v in data.items() if k != "content_sha256"}
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def parse_receipts(log):
    if "Model checking completed. No error has been found." not in log or "0 states left on queue." not in log:
        raise ValueError("TLC did not exhaust successfully")
    rows = {}
    for start in re.finditer(r'<<\s*"ETNA_SETTLEMENT"\s*,', log):
        tokens = []
        depth = 0
        pos = start.start()
        while pos < len(log):
            token = re.match(r'\s*(<<|>>|,|TRUE|FALSE|\d+|"ETNA_SETTLEMENT")', log[pos:])
            if not token:
                raise ValueError("invalid receipt token")
            word = token.group(1)
            pos += token.end()
            if word == "<<":
                depth += 1
                tokens.append("[")
            elif word == ">>":
                depth -= 1
                tokens.append("]")
                if depth == 0:
                    break
            else:
                tokens.append({"TRUE": "true", "FALSE": "false"}.get(word, word))
        if depth:
            raise ValueError("truncated receipt")
        row = json.loads("".join(tokens))
        key = tuple(row[1:3])
        if key in rows:
            raise ValueError("duplicate receipt")
        rows[key] = row
    cases = []
    for case_id, length in enumerate(LENGTHS, 1):
        steps = []
        for step in range(length):
            row = rows.pop((case_id, step), None)
            if row is None or len(row) != 15:
                raise ValueError("missing or malformed receipt")
            _, _, _, op, arg, accepted, c, gen, nonce, origin, now, auth, proof, records, origins = row
            steps.append(dict(op=op, arg=arg, accepted=accepted, checkpoint=c,
                              generation=gen, nonce=nonce, origin=origin, now=now,
                              authorization=auth, proof=proof, landings=records, origins=origins))
        cases.append(dict(id=CASE_NAMES[case_id-1], steps=steps))
    if rows:
        raise ValueError("unexpected receipts")
    return cases


def validate(data):
    if data.get("schema") != "etna-settlement-replay-1" or data.get("grid") != 6:
        raise ValueError("wrong schema/grid")
    if data.get("content_sha256") != content_digest(data):
        raise ValueError("expectation content changed")
    provenance = data.get("provenance", {})
    if provenance != dict(base_sha256=sha(BASE), replay_sha256=sha(MODEL),
                          config_sha256=hashlib.sha256(CONFIG.encode()).hexdigest(),
                          tlc_sha256=TLC_SHA256):
        raise ValueError("wrong source/tool provenance")
    cases = data.get("cases", [])
    if len(cases) != len(LENGTHS):
        raise ValueError("wrong case count")
    for case, name, length in zip(cases, CASE_NAMES, LENGTHS):
        if case.get("id") != name or len(case.get("steps", [])) != length:
            raise ValueError("wrong case or skipped steps")
        for row in case["steps"]:
            if len(row.get("landings", [])) != 5 or len(row.get("origins", [])) != 3:
                raise ValueError("missing retained records")


def generate(java, jar):
    inputs = {BASE: BASE.read_bytes(), MODEL: MODEL.read_bytes()}
    if sha(jar) != TLC_SHA256:
        raise ValueError("unexpected TLC binary")
    with tempfile.TemporaryDirectory(prefix="etna-settlement-replay-") as directory:
        work = Path(directory)
        for source, content in inputs.items():
            (work / source.name).write_bytes(content)
        (work / "Replay.cfg").write_text(CONFIG)
        command = [str(Path(java).resolve()), "-Xmx256m", "-XX:+UseParallelGC", "-cp",
                   str(Path(jar).resolve()), "tlc2.TLC", "-workers", "1", "-config",
                   "Replay.cfg", "-metadir", "states", "EtnaSettlementReplay"]
        result = subprocess.run(command, cwd=work, env={"PATH": "/usr/bin:/bin", "LANG": "C.UTF-8"},
                                capture_output=True, text=True, timeout=45, check=False)
        if result.returncode:
            raise ValueError("TLC failed: " + result.stdout[-3000:] + result.stderr[-1000:])
        if any(source.read_bytes() != content for source, content in inputs.items()) or sha(jar) != TLC_SHA256:
            raise ValueError("TLC inputs changed during execution")
        cases = parse_receipts(result.stdout)
    data = dict(schema="etna-settlement-replay-1", grid=6,
                provenance=dict(base_sha256=hashlib.sha256(inputs[BASE]).hexdigest(),
                                replay_sha256=hashlib.sha256(inputs[MODEL]).hexdigest(),
                                config_sha256=hashlib.sha256(CONFIG.encode()).hexdigest(),
                                tlc_sha256=TLC_SHA256), cases=cases)
    data["content_sha256"] = content_digest(data)
    validate(data)
    return data


def compare_fixture(generated, current):
    validate(generated)
    validate(current)
    if generated != current:
        raise ValueError("fixture differs from actual TLC execution")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--java", required=True)
    parser.add_argument("--jar", required=True)
    parser.add_argument("--output", type=Path, default=ROOT / "settlement_cases.json")
    parser.add_argument("--check", action="store_true", help="regenerate and require identical expectations")
    args = parser.parse_args()
    generated = generate(args.java, args.jar)
    if args.check:
        current = json.loads(args.output.read_text())
        compare_fixture(generated, current)
    else:
        args.output.write_text(json.dumps(generated, indent=2) + "\n")
    print(f"8 cases / {sum(LENGTHS)} receipts from actual TLC actions")


if __name__ == "__main__":
    main()
