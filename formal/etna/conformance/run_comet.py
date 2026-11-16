#!/usr/bin/env python3
"""Record exact offline stock-Comet first-block validation and one source fault.

Public dependency fetching is a separate preparation step. This command never
fetches modules, installs tools, signs messages or contacts a live node.
"""
import argparse
from collections import Counter
import hashlib
import importlib.util
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent
PACKAGE = "example.org/etna-comet-first-block"
PARENT = "TestFirstBlockBoundary"
NAMES = ("equal-times", "parent-dominates", "later-anchor", "wrong-bft-time",
         "wrong-initial-height", "retained-last-block-id", "nonempty-last-commit")
IDENTITIES = tuple(PARENT + "/" + name for name in NAMES)
FAULT_PATH = "state/validation.go"
FAULT_BEFORE = '''\t\tgenesisTime := state.LastBlockTime
\t\tif !block.Time.Equal(genesisTime) {
\t\t\treturn fmt.Errorf("block time %v is not equal to genesis time %v",
\t\t\t\tblock.Time,
\t\t\t\tgenesisTime,
\t\t\t)
\t\t}
'''
FAULT_AFTER = "\t\t// Private conformance fault: omit initial genesis-time equality.\n"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# Reuse the existing authoritative scoped supervisor. It owns nested namespace
# cleanup on cancellation, deadlines and caller death; do not duplicate it here.
EXECUTION_PATH = ROOT.parent / "sensitivity/run.py"
EXECUTION = load_module("etna_comet_execution", EXECUTION_PATH)


def require_mutant_time_evidence(rows):
    """Require both real missing-rejection diagnostics, not any test failure.

    Native Go framing is recognized separately; all diagnostic payloads must
    match exactly, in call order. Incidental test source line numbers may vary.
    """
    identity = PARENT + "/wrong-bft-time"
    lines = []
    for row in rows:
        if row.get("Test") == identity and row.get("Action") == "output":
            payload = row.get("Output")
            if not isinstance(payload, str):
                raise ValueError("missing native time diagnostic payload")
            lines.extend(payload.splitlines())
    if (len(lines) != 8 or lines[0].strip() != "=== RUN   " + identity
            or not re.fullmatch(r"--- FAIL: " + re.escape(identity) + r" \([0-9]+(?:\.[0-9]+)?s\)", lines[-1].strip())):
        raise ValueError("missing/duplicate/wrong native time diagnostic frames")
    diagnostics = []
    for line in lines[1:-1]:
        match = re.fullmatch(r"\s*first_block_test\.go:[1-9][0-9]*: (.+)", line)
        if not match:
            raise ValueError("unexpected native time diagnostic payload")
        diagnostics.append(match.group(1))
    expected = [
        "wrong BFT time offset=1s; actual=1970-01-01T00:00:04Z genesis=1970-01-01T00:00:03Z",
        'expected exact rejection "block time 1970-01-01 00:00:04 +0000 UTC is not equal to genesis time 1970-01-01 00:00:03 +0000 UTC", got <nil>',
        "rejected header reached evidence pool 1 times",
        "wrong BFT time offset=1ns; actual=1970-01-01T00:00:03.000000001Z genesis=1970-01-01T00:00:03Z",
        'expected exact rejection "block time 1970-01-01 00:00:03.000000001 +0000 UTC is not equal to genesis time 1970-01-01 00:00:03 +0000 UTC", got <nil>',
        "rejected header reached evidence pool 1 times",
    ]
    if diagnostics != expected:
        raise ValueError("wrong/one-offset/unrelated mutant time semantics")


def require_go_outcomes(raw, returncode, phase):
    """A package PASS or an unrelated failing test is never sufficient evidence."""
    if phase not in ("normal", "mutant", "restored"):
        raise ValueError("unknown execution phase")
    try:
        rows = [json.loads(line) for line in raw.decode().splitlines() if line.strip()]
    except (ValueError, UnicodeError) as error:
        raise ValueError("invalid Go JSON stream") from error
    if not rows or any(not isinstance(row, dict) or row.get("Package") != PACKAGE for row in rows):
        raise ValueError("missing or unexpected Go package")
    wanted = {name: "fail" if phase == "mutant" and name.endswith("/wrong-bft-time") else "pass"
              for name in IDENTITIES}
    parent_action = "fail" if phase == "mutant" else "pass"
    allowed = set(IDENTITIES) | {PARENT}
    runs, endings = Counter(), {}
    package_actions = []
    for row in rows:
        action, identity = row.get("Action"), row.get("Test")
        if action not in ("start", "run", "output", "pass", "fail"):
            raise ValueError("skipped or unexpected Go event")
        if identity:
            if identity not in allowed:
                raise ValueError("unexpected test identity")
            if action == "run":
                runs[identity] += 1
            elif action in ("pass", "fail"):
                if identity in endings:
                    raise ValueError("duplicate terminal test outcome")
                endings[identity] = action
        elif action != "output":
            package_actions.append(action)
    expected = {**wanted, PARENT: parent_action}
    if runs != Counter({name: 1 for name in allowed}) or endings != expected:
        raise ValueError("missing, duplicate or wrong test outcome")
    if package_actions != ["start", parent_action] or returncode != (1 if phase == "mutant" else 0):
        raise ValueError("wrong package outcome or command return code")
    if phase == "mutant":
        require_mutant_time_evidence(rows)
    return wanted


def verify_snapshot(root, manifest, commit):
    root = Path(root).resolve()
    paths = list(root.rglob("*"))
    if any(p.is_symlink() for p in paths):
        raise ValueError("source snapshot symlinks are not allowed")
    actual = {p.relative_to(root).as_posix() for p in paths if p.is_file()}
    if actual != set(manifest.get("files", {})):
        raise ValueError("source snapshot contains missing or extra files")
    baseline = load_module("etna_comet_baseline", ROOT / "run_baseline.py")
    return baseline.verify_source(root, manifest, commit)


def file_entry(data):
    return {"bytes": len(data), "sha256": digest(data),
            "gitBlob": hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()}


def private_fault(source, destination, manifest):
    shutil.copytree(source, destination)
    path = destination / FAULT_PATH
    raw = path.read_text()
    if raw.count(FAULT_BEFORE) != 1:
        raise ValueError("upstream fault selector does not match exactly once")
    path.chmod(0o644)
    path.write_text(raw.replace(FAULT_BEFORE, FAULT_AFTER))
    mutant = json.loads(json.dumps(manifest))
    mutant["files"][FAULT_PATH] = file_entry(path.read_bytes())
    return mutant


def inputs():
    # Exact file pins supplement T01's provenance validation; no receipt is
    # synthesized or regenerated by this adapter.
    pins_raw = (ROOT / "comet-pins.json").read_bytes()
    pins = json.loads(pins_raw)
    manifest_raw = (ROOT / "manifests/comet.json").read_bytes()
    if pins.get("schema") != "etna-comet-conformance-pins-1" or digest(manifest_raw) != pins["source"]["manifestSha256"]:
        raise ValueError("wrong Comet source pin/manifest")
    if pins.get("expectedSubtests") != list(NAMES):
        raise ValueError("pinned and executed test identities differ")
    fixture = (ROOT / "recovery_time_cases.json").read_bytes()
    exporter = (ROOT / "export_recovery_time.py").read_bytes()
    if digest(fixture) != pins["receipt"]["sha256"] or digest(exporter) != pins["receipt"]["exporterSha256"]:
        raise ValueError("wrong T01 receipt/exporter bytes")
    export = load_module("etna_comet_time_receipt", ROOT / "export_recovery_time.py")
    export.validate(json.loads(fixture))
    watched = [ROOT / "run_comet.py", ROOT / "run_isolated.py", ROOT / "run_baseline.py",
               EXECUTION_PATH, ROOT / "tests/test_comet.py", ROOT / "controller_tests/test_comet_lifecycle.py",
               ROOT / "comet-pins.json", ROOT / "manifests/comet.json", ROOT / "recovery_time_cases.json",
               *export.INPUTS, *sorted((ROOT / "comet").glob("*"))]
    watched = {p: digest(p.read_bytes()) for p in watched if p.is_file()}
    return pins, json.loads(manifest_raw), watched


def run_trial(phase, source, manifest, args, pins, tool_hashes):
    before = verify_snapshot(source, manifest, pins["source"]["commit"])
    trial = args.output / phase
    work = trial / "work"
    work.mkdir(parents=True)
    (work / "build").mkdir()
    (work / "go.mod").write_bytes((ROOT / "comet/go.mod").read_bytes() +
        b"\nreplace github.com/cometbft/cometbft => /tmp/upstream\n")
    (work / "go.sum").write_bytes((ROOT / "comet/go.sum").read_bytes())
    command = [sys.executable, str(ROOT / "run_isolated.py"),
        "--read-bind", str(ROOT / "comet") + "=/tmp/replay",
        "--read-bind", str(ROOT / "recovery_time_cases.json") + "=/tmp/receipt.json",
        "--read-bind", str(source) + "=/tmp/upstream",
        "--read-bind", str(args.go_root) + "=/tmp/go",
        "--read-bind", str(args.module_cache) + "=/tmp/gomodcache",
        "--write-bind", str(args.build_cache) + "=/tmp/gocache",
        "--write-bind", str(work) + "=/tmp/output",
        "--cwd", "/tmp/replay", "--timeout", str(args.timeout)]
    environment = {"GOROOT": "/tmp/go", "GOMODCACHE": "/tmp/gomodcache", "GOCACHE": "/tmp/gocache",
        "GOPATH": "/tmp/gopath", "GOTMPDIR": "/tmp/output/build", "GOENV": "off", "GOTOOLCHAIN": "local",
        "GOPROXY": "off", "GOSUMDB": "off", "GOVCS": "*:off", "GOWORK": "off", "CGO_ENABLED": "0",
        "GOTELEMETRY": "off", "GOMAXPROCS": "2", "ETNA_RECOVERY_TIME_FIXTURE": "/tmp/receipt.json"}
    for name, value in environment.items():
        command.extend(["--env", name + "=" + value])
    command.extend(["--", "/tmp/go/bin/go", "test", "-json", "-count=1", "-parallel=1", "-p=2",
                    "-mod=readonly", "-modfile=/tmp/output/go.mod", "-timeout=90s", "./..."])
    started = time.monotonic()
    result = EXECUTION.execute(command, ROOT, args.timeout + 10)
    # The authoritative supervisor combines stdout/stderr, decodes UTF-8 with
    # replacement, and returns text. Preserve that representation honestly.
    combined = result["output"].encode("utf-8")
    (trial / "combined.log").write_bytes(combined)
    report = {"phase": phase, "command": command, "supervisorCommand": result["supervisor_argv"],
        "returncode": result["returncode"], "timedOut": result["timeout"],
        "elapsedSeconds": round(time.monotonic() - started, 3),
        "combinedOutputFile": "combined.log", "combinedOutputSha256": digest(combined),
        "streamsCombined": True, "outputDecoding": "utf-8-errors-replace", "storedEncoding": "utf-8-reencoded-text",
        "sourceBefore": before, "manifestSha256": digest(json.dumps(manifest,sort_keys=True).encode()),
        "toolsSha256": tool_hashes}
    (trial / "execution.json").write_text(json.dumps(report, sort_keys=True, indent=2) + "\n")
    if result["returncode"] == 125:
        raise ValueError("supervisor initialization or descendant cleanup failed (125)")
    report["outcomes"] = require_go_outcomes(combined, result["returncode"], phase)
    report["mutantTimeSemanticsVerified"] = phase == "mutant"
    report["sourceAfter"] = verify_snapshot(source, manifest, pins["source"]["commit"])
    (trial / "execution.json").write_text(json.dumps(report, sort_keys=True, indent=2) + "\n")
    print(phase + ": seven exact Go test outcomes verified", flush=True)
    return report


def validate_layout(args, watched):
    """Canonical preflight for every input and both writable binding roots."""
    for name in ("source", "go_root", "module_cache", "build_cache"):
        setattr(args, name, Path(getattr(args, name)).resolve(strict=True))
    args.output = Path(args.output).resolve()
    writable = (args.build_cache, args.output)
    def overlaps(left, right):
        return left == right or left in right.parents or right in left.parents
    if overlaps(*writable):
        raise ValueError("output and build cache overlap")
    # Private upstream copies live under output. Keeping that tree disjoint
    # from the persistent cache prevents a writable second alias of the copy.
    # Protect the sibling supervisor and each watched path, including any input
    # outside the formal tree, against writable source/cache aliases as well.
    readonly = [args.source, args.go_root, args.module_cache, ROOT.parent.resolve(strict=True),
                *(Path(path).resolve(strict=True) for path in watched)]
    if any(overlaps(left, right) for left in readonly for right in writable):
        raise ValueError("read-only inputs and writable outputs/cache overlap")
    if args.output.exists() or args.timeout <= 0:
        raise ValueError("a fresh output directory and positive timeout are required")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("source", "go-root", "module-cache", "build-cache", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--timeout", type=int, default=600)
    args = parser.parse_args(argv)
    try:
        pins, manifest, watched = inputs()
        validate_layout(args, watched)
        tools = [args.go_root / "bin/go", args.go_root / "VERSION",
                 *sorted((args.go_root / "pkg/tool").glob("*/asm")),
                 *sorted((args.go_root / "pkg/tool").glob("*/compile")),
                 *sorted((args.go_root / "pkg/tool").glob("*/link")), *sorted((args.go_root / "pkg/tool").glob("*/vet"))]
        tool_hashes = {str(p.relative_to(args.go_root)): digest(p.read_bytes()) for p in tools}
        verify_snapshot(args.source, manifest, pins["source"]["commit"])
        args.output.mkdir(parents=True)
        mutant_source = args.output / "private-upstream-fault"
        mutant_manifest = private_fault(args.source, mutant_source, manifest)
        (args.output / "mutant-manifest.json").write_text(json.dumps(mutant_manifest,sort_keys=True,indent=2)+"\n")
        # RED first: the actual missing-check fault must lose only the expected
        # wrong-BFT rejection. Then establish original/restored GREEN.
        (args.output / "mutant-validation.go").write_bytes((mutant_source / FAULT_PATH).read_bytes())
        reports = [run_trial("mutant", mutant_source, mutant_manifest, args, pins, tool_hashes),
                   run_trial("normal", args.source, manifest, args, pins, tool_hashes)]
        # Restore the actual privately faulted source, then validate that full
        # snapshot against the original manifest before the restored trial.
        (mutant_source / FAULT_PATH).write_bytes((args.source / FAULT_PATH).read_bytes())
        verify_snapshot(mutant_source, manifest, pins["source"]["commit"])
        reports.append(run_trial("restored", mutant_source, manifest, args, pins, tool_hashes))
        if any(digest(p.read_bytes()) != value for p,value in watched.items()):
            raise ValueError("adapter/receipt/provenance inputs changed during campaign")
        if any(digest((args.go_root / p).read_bytes()) != value for p,value in tool_hashes.items()):
            raise ValueError("Go toolchain changed during campaign")
        summary = {"schema": "etna-comet-first-block-execution-2", "status": "PASS",
            "goToolchainVersion": (args.go_root / "VERSION").read_text().strip(),
            "sourceCommit": pins["source"]["commit"], "sourceVerifiedAfter": verify_snapshot(args.source,manifest,pins["source"]["commit"]),
            "inputSha256": {str(p.relative_to(ROOT.parent)): value for p,value in watched.items()},
            "reports": reports, "fault": {"path":FAULT_PATH,"originalSha256":manifest["files"][FAULT_PATH]["sha256"],
                "mutantSha256":mutant_manifest["files"][FAULT_PATH]["sha256"]},
            "boundaries": ["Seeded public-only validator and application state; empty evidence",
                "Selected stock header/time admission, no Etna EL/STF or committee/key mapping",
                "No signatures, consensus rounds/locks, network progress or cryptographic verification"]}
        (args.output / "summary.json").write_text(json.dumps(summary,sort_keys=True,indent=2)+"\n")
        print("PASS: actual pinned Comet admission; private fault detected; original source unchanged")
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print("Comet replay failed: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
