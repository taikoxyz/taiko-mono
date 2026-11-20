"""Offline, pinned execution shared by the two public Comet boundary consumers.

This module stages an explicit allowlist. It neither discovers tests nor fetches
modules. Source selection and actual native outcomes remain separate receipts.
"""
import argparse
from contextlib import contextmanager
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import stat
import sys
from typing import NamedTuple

import run_comet_signed as SIGNED
import leased_execution as LEASED
from boundary_scope import require_healthy_native, reviewed_boundary

ROOT = Path(__file__).resolve().parent
COMET = SIGNED.COMET
PUBLIC = ROOT / "comet_signed/public-votes.json"
PUBLIC_SHA = "34932f8ddf991ae41eb1be94c873e99524f51cf96d427faed4a1bfc443dc960e"
SHARED_READER = ROOT / "comet_boundary/public_input.go.txt"
REPLACEMENT = b"\nreplace github.com/cometbft/cometbft => /tmp/upstream\n"


class BoundaryProfile(NamedTuple):
    claim: str
    fixture: str
    package: str
    parent: str
    smoke: str
    cases: tuple
    staged: tuple
    audit: object
    fault_path: str
    fault_before: bytes
    fault_after: bytes
    fault_case: str
    fault_diagnostics: tuple


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def same(actual, expected, label):
    """Keep integer/bool identity throughout raw and metadata comparisons."""
    if type(actual) is not type(expected):
        raise ValueError("wrong type in " + label)
    if type(expected) is dict:
        if actual.keys() != expected.keys():
            raise ValueError("wrong fields in " + label)
        for key, value in expected.items():
            same(actual[key], value, label + "." + key)
    elif type(expected) in (list, tuple):
        if len(actual) != len(expected):
            raise ValueError("wrong length in " + label)
        for i, value in enumerate(expected):
            same(actual[i], value, label + "[" + str(i) + "]")
    elif actual != expected:
        raise ValueError("wrong value in " + label)


def metadata_json(raw):
    """Operational elapsed times may be finite floats; protocol receipts may not."""
    if type(raw) is not bytes:
        raise ValueError("metadata requires original bytes")
    def finite(value):
        number = float(value)
        if not math.isfinite(number):
            raise ValueError("non-finite operational number")
        return number
    return json.loads(raw.decode("utf-8"), object_pairs_hook=COMET.EXECUTION.unique_object,
                      parse_float=finite, parse_constant=SIGNED.reject_number)


def identity(path, directory=False):
    value = Path(path).lstat()
    expected = stat.S_ISDIR if directory else stat.S_ISREG
    if not expected(value.st_mode) or (not directory and value.st_nlink != 1):
        raise ValueError("substituted filesystem input: " + str(path))
    return dict(device=value.st_dev, inode=value.st_ino, mode=stat.S_IMODE(value.st_mode),
                links=value.st_nlink)


def inventory(paths):
    return {str(path): dict(sha256=digest(path.read_bytes()), **identity(path)) for path in paths}


def require_inventory(paths, expected, label):
    same(inventory(paths), expected, label)


def load_inputs(profile):
    # Reuse the existing authoritative public-provenance/source validator.
    signed_pins, manifest, watched, _ = SIGNED.native_inputs()
    fixture = ROOT / profile.fixture
    pins_path = fixture / "pins.json"
    pins = SIGNED.strict_json(pins_path.read_bytes())
    if set(pins) != {"schema", "claim", "package", "parent", "cases", "source",
                     "goToolSha256", "inputsSha256", "sourceFault"}:
        raise ValueError("wrong boundary pins fields")
    same(pins["schema"], "etna-comet-boundary-pins-1", "pins schema")
    for field, expected in (("claim", profile.claim), ("package", profile.package),
                            ("parent", profile.parent), ("cases", list(profile.cases)),
                            ("source", signed_pins["source"]),
                            ("goToolSha256", signed_pins["goToolSha256"])):
        same(pins[field], expected, "pins " + field)
    sources = {target: ROOT / source for source, target in profile.staged}
    if len(sources) != len(profile.staged) or len(set(sources.values())) != len(sources):
        raise ValueError("duplicate staged source or destination")
    if sources.get("public_input.go") != SHARED_READER or sources.get("public-votes.json") != PUBLIC:
        raise ValueError("shared reader and public input must be explicitly staged")
    if any(Path(target).name != target for target in sources):
        raise ValueError("unsafe staged filename")
    same(set(pins["inputsSha256"]), set(sources), "staged pin names")
    for target, source in sources.items():
        if source.is_symlink() or digest(source.read_bytes()) != pins["inputsSha256"][target]:
            raise ValueError("wrong staged input: " + target)
        watched[source] = pins["inputsSha256"][target]
    if pins["inputsSha256"]["public-votes.json"] != PUBLIC_SHA:
        raise ValueError("wrong public projection")
    fault = pins["sourceFault"]
    original = manifest["files"][profile.fault_path]["sha256"]
    same(fault, dict(path=profile.fault_path, originalSha256=original,
                     beforeSha256=digest(profile.fault_before),
                     afterSha256=digest(profile.fault_after), mutantSha256=fault.get("mutantSha256")),
         "source fault pins")
    SIGNED.match(r"[0-9a-f]{64}", fault["mutantSha256"], "mutant source digest")
    for path in (Path(__file__), LEASED.PATH, ROOT / "boundary_scope.py", ROOT / "current_spec.py",
                 ROOT / "current_spec_boundaries.json", ROOT / "run_comet_apphash.py", pins_path,
                 ROOT / ("run_comet_terminal.py" if profile.claim == "terminal-seen-commit" else "run_comet_evidence.py")):
        watched[path] = digest(path.read_bytes())
    return pins, manifest, sources, watched


def effective_go_mod(profile, pins):
    original = (ROOT / profile.fixture / "go.mod").read_bytes()
    if digest(original) != pins["inputsSha256"]["go.mod"]:
        raise ValueError("original boundary module changed")
    return original + REPLACEMENT


def expected_inputs(profile, pins):
    return {"inputs/" + name: sha for name, sha in pins["inputsSha256"].items()} | {
        "modfiles/go.mod": digest(effective_go_mod(profile, pins)),
        "modfiles/go.sum": pins["inputsSha256"]["go.sum"],
    }


def isolation_command(profile, trial, source, args, selected):
    # Reset inherited signal dispositions before the authoritative supervisor's
    # namespace child. No shell or inherited credential environment is involved.
    command = ["/usr/bin/env", "-i", "--default-signal=INT,QUIT,TERM,HUP,PIPE",
               "PATH=/usr/bin:/bin", "LANG=C.UTF-8", "LC_ALL=C.UTF-8",
               sys.executable, "-I", "-S", "-B", str(ROOT / "run_isolated.py")]
    for path, target in ((trial / "inputs", "replay"), (source, "upstream"),
                         (trial / "modfiles", "modfiles"), (args.go_root, "go"),
                         (args.module_cache, "gomodcache")):
        command += ["--read-bind", str(path) + "=/tmp/" + target]
    for path, target in ((args.build_cache, "gocache"), (trial / "work", "output")):
        command += ["--write-bind", str(path) + "=/tmp/" + target]
    command += ["--cwd", "/tmp/replay", "--timeout", "100"]
    environment = dict(GOROOT="/tmp/go", GOMODCACHE="/tmp/gomodcache", GOCACHE="/tmp/gocache",
                       GOPATH="/tmp/gopath", GOTMPDIR="/tmp/output/build", GOENV="off",
                       GOTOOLCHAIN="local", GOPROXY="off", GOSUMDB="off", GOVCS="*:off",
                       GOWORK="off", CGO_ENABLED="0", GOTELEMETRY="off", GOMAXPROCS="2")
    for name, value in environment.items():
        command += ["--env", name + "=" + value]
    command += ["--", "/tmp/go/bin/go", "test", "-json", "-count=1", "-parallel=1", "-p=2",
                "-mod=readonly", "-modfile=/tmp/modfiles/go.mod", "-timeout=90s",
                "-run=" + selected, "."]
    return command


def collect(profile, raw, returncode, phase):
    """Consume the exact ordered Go1.27 test2json stream and full receipts."""
    fault = phase == "mutant"
    if phase not in ("smoke", "normal", "mutant", "restored"):
        raise ValueError("unknown native phase")
    if type(raw) is not bytes or type(returncode) is not int or returncode != int(fault):
        raise ValueError("INCONCLUSIVE: wrong native status or raw bytes")
    rows = []
    for line in raw.splitlines():
        row = json.loads(line.decode("utf-8"), object_pairs_hook=COMET.EXECUTION.unique_object,
                         parse_constant=SIGNED.reject_number)
        if (type(row) is not dict or row.get("Package") != profile.package
                or set(row) - {"Time", "Action", "Package", "Test", "Elapsed", "Output", "OutputType"}):
            raise ValueError("unexpected native package or event fields")
        if "Elapsed" in row and (type(row["Elapsed"]) not in (int, float)
                                 or not math.isfinite(row["Elapsed"]) or row["Elapsed"] < 0):
            raise ValueError("wrong native elapsed value")
        if "Time" in row and type(row["Time"]) is not str:
            raise ValueError("wrong native event time")
        rows.append(row)
    events = iter(rows)
    def event(action, test=None, kind=None, output=False):
        row = next(events, {})
        if (row.get("Action") != action or ("Test" in row) != (test is not None)
                or row.get("Test") != test or ("Output" in row) != output
                or ("OutputType" in row) != (kind is not None) or row.get("OutputType") != kind):
            raise ValueError("missing, extra or misordered native event: " + str(test))
        if output:
            text = row["Output"]
            if type(text) is not str or len(text.encode()) > 1024:
                raise ValueError("wrong native output fragment")
            require_healthy_native(text)
            return text
    def line(test, pattern, kind=None, receipt=False):
        text = event("output", test, kind, True)
        if receipt:
            chunks = [text]
            while not chunks[-1].endswith("\n"):
                if len(chunks[-1].encode()) != 1024 or len(chunks) >= 1024:
                    raise ValueError("truncated or excessive native receipt")
                chunks.append(event("output", test, kind, True))
            text = "".join(chunks)
            require_healthy_native(text)
        match = re.fullmatch(pattern, text)
        if match is None:
            raise ValueError("unexpected native output: " + str(test))
        return match
    def begin(test):
        event("run", test)
        line(test, re.escape("=== RUN   " + test + "\n"), "frame")
    def finish(test, outcome):
        line(test, re.escape("--- " + outcome.upper() + ": " + test) + r" \([0-9]+(?:\.[0-9]+)?s\)\n", "frame")
        event(outcome, test)
    names = (profile.smoke,) if phase == "smoke" else profile.cases
    outcomes = {}
    event("start")
    begin(profile.parent)
    for name in names:
        test = profile.parent + "/" + name
        begin(test)
        # The frozen Go producer reports both validation errors before logging its receipt.
        if fault and name == profile.fault_case:
            for message in profile.fault_diagnostics:
                line(test, r"\s+[A-Za-z0-9_]+_test\.go:[1-9][0-9]*: " + re.escape(message + "\n"), "error")
        match = line(test, r"\s+[A-Za-z0-9_]+_test\.go:[1-9][0-9]*: receipt=(.+)\n", receipt=True)
        encoded = match[1].encode()
        audited = profile.audit(encoded, source_fault=fault)
        same(audited["case"], name, "native receipt/test identity")
        outcomes[name] = dict(sha256=digest(encoded), audit=audited)
        finish(test, "fail" if fault and name == profile.fault_case else "pass")
    overall = "fail" if fault else "pass"
    finish(profile.parent, overall)
    line(None, re.escape(overall.upper() + "\n"), "frame")
    prefix = ("FAIL\t" if fault else "ok  \t") + profile.package + "\t"
    line(None, re.escape(prefix) + r"[0-9]+(?:\.[0-9]+)?s\n", "frame" if fault else None)
    event(overall)
    if next(events, None) is not None:
        raise ValueError("extra native event")
    return outcomes


@contextmanager
def source_fault(profile, source, manifest, pins, restoration):
    path = source / profile.fault_path
    original, initial = path.read_bytes(), identity(path)
    if COMET.file_entry(original) != manifest["files"][profile.fault_path] or original.count(profile.fault_before) != 1:
        raise ValueError("source fault must select one original source hunk")
    mutant = original.replace(profile.fault_before, profile.fault_after, 1)
    if digest(mutant) != pins["sourceFault"]["mutantSha256"]:
        raise ValueError("private source mutation differs from pin")
    changed = manifest | {"files": manifest["files"] | {profile.fault_path: COMET.file_entry(mutant)}}
    try:
        path.chmod(initial["mode"] | stat.S_IWUSR)
        path.write_bytes(mutant)
        path.chmod(initial["mode"])
        COMET.verify_snapshot(source, changed, manifest["commit"])
        yield changed
    finally:
        path.chmod(initial["mode"] | stat.S_IWUSR)
        try:
            path.write_bytes(original)
        finally:
            path.chmod(initial["mode"])
        same(identity(path), initial, "same-copy source restoration")
        restored = COMET.verify_snapshot(source, manifest, manifest["commit"])
        SIGNED.write_json(restoration, dict(source=restored, file=identity(path), sha256=digest(path.read_bytes())))


def _require_not_cancelled(cancelled):
    if cancelled():
        raise ValueError("INCONCLUSIVE: campaign cancellation requested")


def run_trial(profile, phase, source, manifest, args, pins, sources, watched, tools, *, lease_fd, cancelled):
    _require_not_cancelled(cancelled)
    SIGNED.require_stable(watched | tools, "boundary campaign inputs")
    before = COMET.verify_snapshot(source, manifest, pins["source"]["commit"])
    native_modes = inventory(source / name for name in manifest["files"])
    trial = args.output / phase
    (trial / "inputs").mkdir(parents=True)
    (trial / "modfiles").mkdir()
    (trial / "work/build").mkdir(parents=True)
    for target, origin in sources.items():
        shutil.copyfile(origin, trial / "inputs" / target)
    (trial / "modfiles/go.mod").write_bytes(effective_go_mod(profile, pins))
    shutil.copyfile(trial / "inputs/go.sum", trial / "modfiles/go.sum")
    executed = {trial / name: sha for name, sha in expected_inputs(profile, pins).items()}
    SIGNED.require_stable(executed, "staged native inputs")
    executed_before = inventory(executed)
    selected = "^" + profile.parent + "$" + ("/^" + profile.smoke + "$" if phase == "smoke" else "")
    command = isolation_command(profile, trial, source, args, selected)
    _require_not_cancelled(cancelled)
    result = LEASED.execute(command, ROOT, 110, lease_fd=lease_fd, cancellation=cancelled)
    raw = result["output"].encode("utf-8")
    (trial / "combined.log").write_bytes(raw)
    record = dict(schema="etna-comet-boundary-trial-2", claim=profile.claim, phase=phase,
                  package=profile.package, parent=profile.parent, selectedFilter=selected,
                  command=command, supervisorCommand=result["supervisor_argv"],
                  supervisorReturncode=result["supervisor_returncode"],
                  returncode=result["returncode"], timedOut=result["timeout"], seconds=result["seconds"],
                  streamsCombined=True, outputDecoding="utf-8-errors-replace", combinedOutputFile="combined.log",
                  combinedOutputSha256=digest(raw), sourceBefore=before,
                  sourceManifestSha256=digest(json.dumps(manifest, sort_keys=True, separators=(",", ":")).encode()),
                  toolsSha256=pins["goToolSha256"], executedInputsBefore=expected_inputs(profile, pins),
                  executedFileIdentityBefore={str(path.relative_to(trial)): item for path, item in
                                              ((Path(name), value) for name, value in executed_before.items())})
    SIGNED.write_json(trial / "execution.json", record)
    SIGNED.require_stable(watched | tools | executed, "native runner, tool or staged input")
    require_inventory(executed, executed_before, "staged native input identities")
    require_inventory((source / name for name in manifest["files"]), native_modes, "native source identities")
    record.update(sourceAfter=COMET.verify_snapshot(source, manifest, pins["source"]["commit"]),
                  executedInputsAfter=expected_inputs(profile, pins),
                  executedFileIdentityAfter=record["executedFileIdentityBefore"])
    SIGNED.write_json(trial / "execution.json", record)
    _require_not_cancelled(cancelled)
    if result["timeout"] is not False or result["returncode"] == 125:
        raise ValueError("INCONCLUSIVE: native deadline or supervisor failure")
    record["outcomes"] = collect(profile, raw, result["returncode"], phase)
    _require_not_cancelled(cancelled)
    SIGNED.write_json(trial / "execution.json", record)
    return record


def require_capture(profile, directory, pins, phase, manifest, args):
    """Re-read actual raw bytes and reject metadata aliases before attribution."""
    record = metadata_json((directory / "execution.json").read_bytes())
    raw = (directory / "combined.log").read_bytes()
    expected_keys = {"schema", "claim", "phase", "package", "parent", "selectedFilter", "command",
                     "supervisorCommand", "supervisorReturncode", "returncode", "timedOut", "seconds", "streamsCombined",
                     "outputDecoding", "combinedOutputFile", "combinedOutputSha256", "sourceBefore",
                     "sourceAfter", "sourceManifestSha256", "toolsSha256", "executedInputsBefore",
                     "executedInputsAfter", "executedFileIdentityBefore", "executedFileIdentityAfter", "outcomes"}
    if type(record) is not dict or set(record) != expected_keys:
        raise ValueError("wrong native capture fields")
    if type(record["seconds"]) not in (int, float) or not math.isfinite(record["seconds"]) or record["seconds"] < 0:
        raise ValueError("wrong native capture elapsed time")
    selected = "^" + profile.parent + "$" + ("/^" + profile.smoke + "$" if phase == "smoke" else "")
    private = directory.parent / "private-upstream"
    command = isolation_command(profile, directory, private, args, selected)
    supervisor = record["supervisorCommand"]
    if (type(supervisor) is not list or len(supervisor) != 8 + len(command)
            or supervisor[:4] != [sys.executable, "-B", str(LEASED.PATH), "--_supervise_leased"]
            or type(supervisor[4]) is not str or not re.fullmatch(r"[1-9][0-9]*", supervisor[4])
            or int(supervisor[4]) < 3
            or type(supervisor[5]) is not str or not re.fullmatch(r"[1-9][0-9]*", supervisor[5])
            or supervisor[6:] != ["110", str(ROOT), *command]):
        raise ValueError("wrong native supervisor command")
    expected_source = dict(files=len(manifest["files"]), commit=pins["source"]["commit"], status="INPUTS_VERIFIED")
    native_status = 1 if phase == "mutant" else 0
    for key, expected in (("schema", "etna-comet-boundary-trial-2"), ("claim", profile.claim),
                          ("phase", phase), ("package", profile.package), ("parent", profile.parent),
                          ("selectedFilter", selected), ("command", command),
                          ("timedOut", False), ("returncode", native_status),
                          ("supervisorReturncode", LEASED.LEASED_EXIT_CODES[native_status]),
                          ("streamsCombined", True), ("outputDecoding", "utf-8-errors-replace"),
                          ("combinedOutputFile", "combined.log"), ("combinedOutputSha256", digest(raw)),
                          ("sourceBefore", expected_source), ("sourceAfter", expected_source),
                          ("toolsSha256", pins["goToolSha256"]),
                          ("executedInputsBefore", expected_inputs(profile, pins)),
                          ("executedInputsAfter", expected_inputs(profile, pins)),
                          ("sourceManifestSha256", digest(json.dumps(manifest, sort_keys=True, separators=(",", ":")).encode()))):
        same(record[key], expected, "native capture " + key)
    same(record["executedFileIdentityAfter"], record["executedFileIdentityBefore"], "native staged modes")
    expected = expected_inputs(profile, pins)
    identities = record["executedFileIdentityBefore"]
    if type(identities) is not dict or set(identities) != set(expected):
        raise ValueError("missing native staged identities")
    for name, sha in expected.items():
        value = identities[name]
        if type(value) is not dict or set(value) != {"sha256", "device", "inode", "mode", "links"}:
            raise ValueError("wrong native staged identity fields")
        same(value["sha256"], sha, "staged input hash")
        same(value["links"], 1, "staged single file")
        for field in ("device", "inode", "mode"):
            if type(value[field]) is not int or value[field] < 0:
                raise ValueError("wrong native staged identity number")
    paths = {directory / name: sha for name, sha in expected.items()}
    SIGNED.require_stable(paths, "retained executed inputs")
    actual_ids = {str(path.relative_to(directory)): value for path, value in
                  ((Path(name), value) for name, value in inventory(paths).items())}
    same(actual_ids, identities, "retained executed input identities")
    COMET.verify_snapshot(private, manifest, pins["source"]["commit"])
    outcomes = collect(profile, raw, record["returncode"], phase)
    same(record["outcomes"], outcomes, "native capture outcomes")
    return record


def arguments(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("source", "go-root", "module-cache", "build-cache", "build-lock", "output", "workspace-root"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--timeout", type=int, default=100)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--smoke", action="store_true")
    mode.add_argument("--smoke-output", type=Path)
    return parser.parse_args(argv)


def run_profile(profile, args):
    with LEASED.cancellation_scope() as cancelled:
        try:
            return _run_profile(profile, args, cancelled)
        finally:
            # All private finally blocks finish under the recording handler.
            _require_not_cancelled(cancelled)


def _run_profile(profile, args, cancelled):
    pins, manifest, sources, watched = load_inputs(profile)
    boundary = reviewed_boundary(args.workspace_root, profile.claim)
    for name, item in boundary["workspace"]["documents"].items():
        watched[args.workspace_root / name] = item["sha256"]
    COMET.validate_layout(args, watched)
    if args.timeout != 100:
        raise ValueError("boundary native90/isolation100/supervisor110 bounds are fixed")
    tools = {args.go_root / name: sha for name, sha in pins["goToolSha256"].items()}
    SIGNED.require_stable(watched | tools, "boundary source and tools")
    before_files = inventory(watched | tools)
    lock_path = args.build_lock.absolute()
    lock_id = identity(lock_path)
    cache_ids = {name: identity(getattr(args, name), directory=True) for name in ("build_cache", "module_cache", "go_root")}
    if any(lock_path == path or lock_path.is_relative_to(path) for path in
           (args.output, args.source, args.go_root, args.module_cache)):
        raise ValueError("shared lock must be an independent existing physical file")
    _require_not_cancelled(cancelled)
    fd = os.open(lock_path, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC)
    try:
        if fd < 3:
            # The supervisor needs a descriptor distinct from its redirected streams.
            original_fd = fd
            fd = fcntl.fcntl(original_fd, fcntl.F_DUPFD_CLOEXEC, 3)
            os.close(original_fd)
        info = os.fstat(fd)
        same(dict(device=info.st_dev, inode=info.st_ino, mode=stat.S_IMODE(info.st_mode), links=info.st_nlink), lock_id, "opened cache lock")
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        original_before = COMET.verify_snapshot(args.source, manifest, pins["source"]["commit"])
        original_modes = inventory(args.source / name for name in manifest["files"])
        smoke = None
        if not args.smoke:
            smoke_root = args.smoke_output.resolve(strict=True)
            smoke_summary = metadata_json((smoke_root / "summary.json").read_bytes())
            same(smoke_summary["physicalBuildLock"], dict(path=str(lock_path), **lock_id), "smoke physical cache lock")
            same(smoke_summary["specBoundary"], boundary, "smoke source selection")
            smoke = require_capture(profile, smoke_root / "smoke", pins, "smoke", manifest, args)
        args.output.mkdir(parents=True)
        source = args.output / "private-upstream"
        shutil.copytree(args.source, source)
        if args.smoke:
            reports = [run_trial(profile, "smoke", source, manifest, args, pins, sources, watched, tools, lease_fd=fd, cancelled=cancelled)]
        else:
            reports = [run_trial(profile, "normal", source, manifest, args, pins, sources, watched, tools, lease_fd=fd, cancelled=cancelled)]
            restoration = args.output / "actual-restoration.json"
            _require_not_cancelled(cancelled)
            with source_fault(profile, source, manifest, pins, restoration) as mutant:
                _require_not_cancelled(cancelled)
                SIGNED.write_json(args.output / "mutant-manifest.json", mutant)
                (args.output / "mutant-source.go").write_bytes((source / profile.fault_path).read_bytes())
                reports.append(run_trial(profile, "mutant", source, mutant, args, pins, sources, watched, tools, lease_fd=fd, cancelled=cancelled))
            reports.append(run_trial(profile, "restored", source, manifest, args, pins, sources, watched, tools, lease_fd=fd, cancelled=cancelled))
        _require_not_cancelled(cancelled)
        require_inventory(watched | tools, before_files, "boundary source/tool identities")
        require_inventory((args.source / name for name in manifest["files"]), original_modes, "original source identities")
        original_after = COMET.verify_snapshot(args.source, manifest, pins["source"]["commit"])
        same(identity(lock_path), lock_id, "physical cache lock after execution")
        for name, expected in cache_ids.items():
            same(identity(getattr(args, name), directory=True), expected, name + " physical identity")
        summary = dict(schema="etna-comet-boundary-execution-1", claim=profile.claim, status="PASS",
                       reports=reports, smoke=smoke, specBoundary=boundary,
                       originalSourceBefore=original_before, originalSourceAfter=original_after,
                       physicalBuildLock=dict(path=str(lock_path), **lock_id), cacheIdentity=cache_ids,
                       watchedSha256={str(path): sha for path, sha in watched.items()},
                       sourceFault=pins["sourceFault"] if not args.smoke else None)
        _require_not_cancelled(cancelled)
        SIGNED.write_json(args.output / "summary.json", summary)
        if cancelled():
            (args.output / "summary.json").unlink()
            _require_not_cancelled(cancelled)
        return summary
    finally:
        os.close(fd)
