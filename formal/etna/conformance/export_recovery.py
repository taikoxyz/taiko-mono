#!/usr/bin/env python3
"""Export actual frozen M08 PublicAttempt receipts; no Python acceptance guards."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent
BASE = ROOT.parent / "EtnaSettlement.tla"
MODEL = ROOT.parent / "EtnaRecoveryTransaction.tla"
CONFIG = ROOT.parent / "configs/recovery-tx-held.cfg"
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
KINDS = {"Mixed", "Empty", "Unheld", "DuplicateIds", "LateWrongKey", "LateUnissued",
         "FutureFI", "ConsumedFI", "DuplicateFI"}
FAILURES = {"None", "SecondRegistry"}


def digest(value):
    return hashlib.sha256(value).hexdigest()


def content_digest(value):
    return digest(json.dumps({k: v for k, v in value.items() if k != "content_sha256"},
                             sort_keys=True, separators=(",", ":")).encode())


def derived_config(raw):
    text = raw.decode().replace("SPECIFICATION RecoveryTransactionSpec", "SPECIFICATION ExportSpec")
    text = text.replace('RequestKinds = {"Mixed",', 'RequestKinds = {"Unheld", "Mixed",')
    return text.replace('CallbackModes = {"None", "Registry"}', 'CallbackModes = {"None"}')


class ValueParser:
    """Constrained parser for TLC values, never eval/exec of printed input."""
    token = re.compile(r'\s*(<<|>>|\|->|:>|@@|[\[\](),]|TRUE|FALSE|\d+|"(?:\\.|[^"\\])*"|[A-Za-z_][A-Za-z_0-9]*)')

    def __init__(self, text):
        self.text, self.pos = text, 0

    def take(self, want=None):
        match = self.token.match(self.text, self.pos)
        if not match:
            raise ValueError("invalid TLC value")
        token = match.group(1)
        if want is not None and token != want:
            raise ValueError("unexpected TLC token")
        self.pos = match.end()
        return token

    def peek(self):
        match = self.token.match(self.text, self.pos)
        return match.group(1) if match else None

    def value(self):
        token = self.take()
        if token == "<<":
            result = []
            if self.peek() != ">>":
                while True:
                    result.append(self.value())
                    if self.peek() != ",":
                        break
                    self.take(",")
            self.take(">>")
            return result
        if token in {"[", "("}:
            close, arrow, separator = ("]", "|->", ",") if token == "[" else (")", ":>", "@@")
            result = {}
            while True:
                key = self.take()
                if key.startswith('"'):
                    key = json.loads(key)
                self.take(arrow)
                if key in result:
                    raise ValueError("duplicate TLC map key")
                result[key] = self.value()
                if self.peek() != separator:
                    break
                self.take(separator)
            self.take(close)
            return result
        if token in {"TRUE", "FALSE"}:
            return token == "TRUE"
        if token.isdecimal():
            return int(token)
        if token.startswith('"'):
            return json.loads(token)
        raise ValueError("unsupported TLC value")


def parse_receipts(log):
    if "Model checking completed. No error has been found." not in log or "0 states left on queue." not in log:
        raise ValueError("TLC did not exhaust")
    cases = {}
    for match in re.finditer(r'<<\s*"ETNA_RECOVERY"\s*,', log):
        row = ValueParser(log[match.start():]).value()
        if len(row) != 3 or row[0] != "ETNA_RECOVERY":
            raise ValueError("wrong receipt envelope")
        _, kind, attempt = row
        failure = attempt["injection"]["failure"]
        key = kind + "/" + failure
        if key in cases:
            raise ValueError("duplicate receipt")
        cases[key] = dict(id=key, kind=kind, attempt=attempt)
    required = {kind + "/" + failure for kind in KINDS for failure in FAILURES}
    if set(cases) != required:
        raise ValueError("missing/unexpected public attempts")
    return [cases[key] for key in sorted(cases)]


def provenance(inputs):
    return {"base_sha256": digest(inputs[BASE]), "model_sha256": digest(inputs[MODEL]),
            "source_config_sha256": digest(inputs[CONFIG]),
            "export_config_sha256": digest(derived_config(inputs[CONFIG]).encode()),
            "wrapper_sha256": digest(WRAPPER.encode()), "tlc_sha256": TLC_SHA}


def validate(data):
    if data.get("schema") != "etna-recovery-replay-1" or data.get("grid") != 6:
        raise ValueError("wrong schema/grid")
    if data.get("provenance") != provenance({p: p.read_bytes() for p in [BASE, MODEL, CONFIG]}):
        raise ValueError("wrong frozen model/config/tool provenance")
    if data.get("content_sha256") != content_digest(data):
        raise ValueError("changed expectations")
    cases = data.get("cases", [])
    required = {kind + "/" + failure for kind in KINDS for failure in FAILURES}
    if len(cases) != 18 or {case["id"] for case in cases} != required:
        raise ValueError("missing/duplicate cases")
    for case in cases:
        attempt = case["attempt"]
        if attempt["schemaVersion"] != 1 or not attempt["present"]:
            raise ValueError("missing public attempt")
        if attempt["injection"]["callback"] != "None":
            raise ValueError("unsupported callback is a GAP")
        for side in ["before", "after"]:
            if set(attempt[side]["state"]["bonds"]) != {"0", "1", "2"}:
                raise ValueError("missing canonical bond")


def generate(java, jar):
    inputs = {p: p.read_bytes() for p in [BASE, MODEL, CONFIG]}
    if digest(Path(jar).read_bytes()) != TLC_SHA:
        raise ValueError("wrong TLC binary")
    with tempfile.TemporaryDirectory(prefix="etna-recovery-replay-") as directory:
        work = Path(directory)
        for source in [BASE, MODEL]:
            (work / source.name).write_bytes(inputs[source])
        (work / "EtnaRecoveryExport.tla").write_text(WRAPPER)
        (work / "Export.cfg").write_text(derived_config(inputs[CONFIG]))
        result = subprocess.run([str(Path(java).resolve()), "-Xmx256m", "-XX:+UseParallelGC", "-cp",
                                 str(Path(jar).resolve()), "tlc2.TLC", "-workers", "1", "-config",
                                 "Export.cfg", "-metadir", "states", "EtnaRecoveryExport"],
                                cwd=work, capture_output=True, text=True, timeout=45,
                                env={"PATH": "/usr/bin:/bin", "LANG": "C.UTF-8"})
        if result.returncode:
            raise ValueError("TLC failed: " + result.stdout[-3000:] + result.stderr[-1000:])
        if any(p.read_bytes() != value for p, value in inputs.items()) or digest(Path(jar).read_bytes()) != TLC_SHA:
            raise ValueError("TLC inputs changed")
        cases = parse_receipts(result.stdout)
    data = dict(schema="etna-recovery-replay-1", grid=6, provenance=provenance(inputs), cases=cases,
                gaps=["Literal confirmed95 displaced fixture", "Withdrawn profile", "Registry callback class"],
                extra_real_scenarios=["Public paid displacement and unconfirmed issued/unheld exclusion"])
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
    parser.add_argument("--output", type=Path, default=ROOT / "recovery_cases.json")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    data = generate(args.java, args.jar)
    if args.check:
        compare_fixture(data, json.loads(args.output.read_text()))
    else:
        args.output.write_text(json.dumps(data, sort_keys=True, indent=2) + "\n")
    print("18 actual M08 public attempts; three explicit GAP classes")


if __name__ == "__main__":
    main()
