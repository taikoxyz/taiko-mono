#!/usr/bin/env python3
"""Collect pinned stock FilePV persistence and cached public-vote replay evidence."""
import argparse
import base64
from contextlib import contextmanager
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
FIXTURE = ROOT / "comet_filepv"

_spec = importlib.util.spec_from_file_location("etna_filepv_signed", ROOT / "run_comet_signed.py")
SIGNED = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(SIGNED)
COMET = SIGNED.COMET
require_stable = SIGNED.require_stable
write_json = SIGNED.write_json

PACKAGE = "command-line-arguments"
WRITER = "TestFilePVWrite"
READER = "TestFilePVRead"
SEEDS = {"precommit_nil": (1000, 0, 3), "prevote_a_r1": (1000, 1, 2)}
SMOKE = "nil-exact"
FAULT_PATH = "privval/file.go"
FAULT_BEFORE = (
    b"\tpv.LastSignState.SignBytes = signBytes\n"
    b"\tpv.LastSignState.Save()\n"
    b"}\n"
)
FAULT_AFTER = b"\tpv.LastSignState.SignBytes = signBytes\n}\n"
FAULT_FUNCTION = b"func (pv *FilePV) saveSigned("
BUILD_FILES = ("go.mod", "go.sum", "filepv_test.go", "public-votes.json")
MISSING_STATE = "O01 persistence id={}: state file missing after saveSigned"


def state_path(seed):
    return f"/tmp/output/state/{seed}.json"


def varint(value):
    encoded = bytearray()
    while value >= 128:
        encoded.append((value & 127) | 128)
        value >>= 7
    encoded.append(value)
    return bytes(encoded)


def number(tag, value):
    return bytes((tag,)) + varint(value) if value else b""


def field(tag, data):
    return bytes((tag,)) + varint(len(data)) + data


def vote_observation(vote, chain, address, signature=b""):
    """Encode the selected public vote and its canonical sign bytes independently."""
    kind, height, round_ = (int(vote[key]) for key in ("voteType", "height", "round"))
    seconds, nanos = (int(vote[key]) for key in ("timestampSeconds", "timestampNanos"))
    block, parts = (SIGNED.hex_field(vote[key], 32) for key in ("blockHash", "partsHash"))
    total = int(vote["partsTotal"])
    timestamp = number(0x08, seconds) + number(0x10, nanos)
    partset = number(0x08, total) + (field(0x12, parts) if any(parts) else b"")
    block_id = (field(0x0A, block) if any(block) else b"") + field(0x12, partset)
    wire = (number(0x08, kind) + number(0x10, height) + number(0x18, round_)
            + field(0x22, block_id) + field(0x2A, timestamp) + field(0x32, address))
    if signature:
        wire += field(0x42, signature)
    canonical = number(0x08, kind) + b"\x11" + height.to_bytes(8, "little")
    if round_:
        canonical += b"\x19" + round_.to_bytes(8, "little")
    if any(block):
        canonical += field(0x22, block_id)
    canonical += field(0x2A, timestamp) + field(0x32, chain.encode())
    return dict(wire=wire.hex(), signBytes=(varint(len(canonical)) + canonical).hex(),
                seconds=seconds, nanos=nanos, signature=signature.hex(), extensionSignature="")


def disk_observation(seed, expected):
    raw = json.dumps(expected, indent=2).encode()
    return dict(path=state_path(seed), sha256=COMET.digest(raw), bytes=len(raw), mode="0600")


def frozen_expectations(projection, disk_oracle):
    rows = {row["name"]: row for row in projection["voteCases"]}
    address = SIGNED.hex_field(projection["voteKey"]["signer"], 20)
    chain = rows["precommit_nil"]["chain_id"]
    disk, state, writers = {}, {}, {}
    for name, (height, round_, step) in SEEDS.items():
        row = rows[name]
        vote = row["vote"]
        if (tuple(int(vote[k]) for k in ("height", "round", "voteType", "timestampSeconds",
                                        "timestampNanos")) != (height, round_, step - 1, 1700000000, 123)
                or row["chain_id"] != chain):
            raise ValueError("public FilePV seed context differs")
        sig = SIGNED.hex_field(row["signature"], 65)
        signbytes = SIGNED.hex_field(row["sign_bytes"])
        expected = dict(height=str(height), round=round_, step=step,
                        signature=base64.b64encode(sig).decode(), signbytes=signbytes.hex().upper())
        state[name] = dict(height=height, round=round_, step=step,
                           signature=sig.hex(), signBytes=signbytes.hex())
        if vote_observation(vote, chain, address, sig)["signBytes"] != signbytes.hex():
            raise ValueError("public FilePV canonical vote bytes differ")
        disk[name] = expected
        writers[name] = dict(schema="etna-comet-filepv-writer-1", seed=name, path=state_path(name),
                             attempt=state[name], stateAfter=state[name], diskAfter=disk_observation(name, expected))
    if json.dumps(disk, sort_keys=True) != json.dumps(disk_oracle, sort_keys=True):
        raise ValueError("frozen FilePV disk oracle differs from public bytes")

    def reader(seed, request_name=None, *, changes=None, request_chain=chain, error="", drop=(),
               check=None, panic=""):
        before = state[seed] | dict.fromkeys(drop, "")
        observed_disk = disk_observation(seed, disk[seed])
        if check is None:
            vote = rows[request_name or seed]["vote"] | (changes or {})
            attempt = dict(chain=request_chain, vote=vote_observation(vote, request_chain, address))
            signature = b"" if error else bytes.fromhex(state[seed]["signature"])
            if signature:
                vote = vote | {"timestampNanos": "123"}
            reply = dict(error=error, vote=vote_observation(vote, request_chain, address, signature),
                         verified=bool(signature))
            operation = "SignVote"
        else:
            attempt = dict(zip(("height", "round", "step"), check))
            reply = dict(reuse=False, error=error, panic=panic)
            operation = "CheckHRS"
        return dict(schema="etna-comet-filepv-reader-1", seed=seed, path=state_path(seed),
                    operation=operation, attempt=attempt, reply=reply, stateBefore=before,
                    stateAfter=before, diskBefore=observed_disk, diskAfter=observed_disk)

    nil, prevote = SEEDS
    conflict = "error signing vote: conflicting data"
    readers = {
        SMOKE: reader(nil),
        "nil-time": reader(nil, changes={"timestampNanos": "124"}),
        "prevote-exact": reader(prevote),
        "prevote-conflict": reader(prevote, "prevote_b_r1", error=conflict),
        "wrong-chain": reader(nil, request_chain=rows["gen1_precommit_a"]["chain_id"], error=conflict),
        "height-regression": reader(nil, changes={"height": "999", "round": "2"},
                                    error="error signing vote: height regression. Got 999, last height 1000"),
        "round-regression": reader(prevote, nil,
                                    error="error signing vote: round regression at height 1000. Got 0, last round 1"),
        "step-regression": reader(nil, prevote, changes={"round": "0"},
                                   error="error signing vote: step regression at height 1000 round 0. Got 2, last step 3"),
        "missing-sign-bytes": reader(nil, drop=("signature", "signBytes"),
                                     error="error signing vote: no SignBytes found"),
        "missing-signature": reader(nil, drop=("signature",), check=SEEDS[nil],
                                    panic="pv: Signature is nil but SignBytes is not!"),
        "advance-check": reader(nil, check=(1000, 1, 2)),
    }
    return disk, writers, readers


def require_go_outcomes(raw, returncode, parent, expected, faults):
    """Admit only the exact named Go lifecycle, observations and designated failures."""
    if not expected or set(faults) - set(expected) or returncode != int(bool(faults)):
        raise ValueError("wrong native return code or selected leaves")
    rows = iter(raw.splitlines())
    results, process = {}, None

    def event(action, test=None, *, output=False, kind=None):
        line = next(rows, None)
        if line is None:
            raise ValueError("missing native output for " + str(test))
        row = json.loads(line, object_pairs_hook=COMET.EXECUTION.unique_object,
                         parse_constant=SIGNED.reject_number)
        required = {"Package", "Action"}
        if test is not None:
            required.add("Test")
        if output:
            required.add("Output")
        if kind is not None:
            required.add("OutputType")
        if (type(row) is not dict or set(row) - {"Time", "Elapsed"} != required
                or row["Package"] != PACKAGE or row["Action"] != action
                or row.get("Test") != test or row.get("OutputType") != kind
                or ("Time" in row and type(row["Time"]) is not str)):
            raise ValueError("wrong native event for " + str(test))
        if "Elapsed" in row:
            elapsed = row["Elapsed"]
            if (action not in ("pass", "fail") or type(elapsed) not in (int, float)
                    or elapsed < 0 or (type(elapsed) is float and not math.isfinite(elapsed))):
                raise ValueError("wrong native elapsed value")
        if output:
            text = row["Output"]
            if type(text) is not str or len(text.encode()) > SIGNED.GO_OUTPUT_BUFFER:
                raise ValueError("wrong native output fragment")
            return text

    def output(test, pattern, kind):
        if not re.fullmatch(pattern, event("output", test, output=True, kind=kind)):
            raise ValueError("unexpected native output for " + str(test))

    def start(test):
        event("run", test)
        output(test, re.escape(f"=== RUN   {test}\n"), "frame")

    def end(test, outcome):
        output(test, re.escape(f"--- {outcome.upper()}: {test}") + r" \([0-9]+(?:\.[0-9]+)?s\)\n",
               "frame")
        event(outcome, test)

    event("start")
    start(parent)
    log_prefix = r"[ \t]+filepv_test\.go:[1-9][0-9]*: "
    for name, oracle in expected.items():
        test = f"{parent}/{name}"
        start(test)
        parts = [event("output", test, output=True)]
        while not parts[-1].endswith("\n"):
            if len(parts[-1].encode()) != SIGNED.GO_OUTPUT_BUFFER or len(parts) == 8:
                raise ValueError("truncated or excessive native receipt for " + test)
            parts.append(event("output", test, output=True))
        match = re.fullmatch(log_prefix + r"receipt=(.+)\n", "".join(parts))
        if match is None:
            raise ValueError("missing native receipt for " + test)
        actual = SIGNED.strict_json(match[1].encode())
        if type(actual) is not dict:
            raise ValueError("wrong native receipt for " + test)
        token = actual.pop("process", None)
        SIGNED.fields(token, ("pid", "namespace", "startTicks"), "native process")
        if type(token["pid"]) is not int or token["pid"] <= 0:
            raise ValueError("wrong native process PID")
        SIGNED.match(r"pid:\[[1-9][0-9]*\]", token["namespace"], "native process namespace")
        SIGNED.match(r"[1-9][0-9]*", token["startTicks"], "native process start tick")
        if process is not None and token != process:
            raise ValueError("native process identity changed between leaves")
        process = token
        if json.dumps(actual, sort_keys=True) != json.dumps(oracle, sort_keys=True):
            raise ValueError("wrong native observation for " + test)
        outcome = "fail" if name in faults else "pass"
        if outcome == "fail":
            output(test, log_prefix + re.escape(faults[name] + "\n"), "error")
        end(test, outcome)
        results[test] = outcome
    outcome = "fail" if faults else "pass"
    end(parent, outcome)
    output(None, outcome.upper() + r"\n", "frame")
    prefix = "FAIL\t" if faults else "ok  \t"
    output(None, re.escape(prefix + PACKAGE + "\t") + r"[0-9]+(?:\.[0-9]+)?s\n",
           "frame" if faults else None)
    event(outcome)
    if next(rows, None) is not None:
        raise ValueError("extra native events")
    return dict(process=process, outcomes=results)


def require_disk(directory, seed, expected):
    """Read one writer-owned state file without following substituted filesystem paths."""
    filename = seed + ".json"
    if seed not in SEEDS:
        raise ValueError("unexpected FilePV state name")
    try:
        dirfd = os.open(directory, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            directory_info = os.fstat(dirfd)
            if directory_info.st_uid != os.geteuid() or stat.S_IMODE(directory_info.st_mode) != 0o700:
                raise ValueError("FilePV state directory is not exclusively owned")
            fd = os.open(filename, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=dirfd)
            with os.fdopen(fd, "rb") as stream:
                first = os.fstat(stream.fileno())
                if (not stat.S_ISREG(first.st_mode) or first.st_nlink != 1 or first.st_uid != os.geteuid()
                        or stat.S_IMODE(first.st_mode) != 0o600):
                    raise ValueError("FilePV state is not a writer-owned regular 0600 file")
                expected_raw = json.dumps(expected, indent=2).encode()
                raw = stream.read(len(expected_raw) + 1)
                current = os.fstat(stream.fileno())
                named = os.stat(filename, dir_fd=dirfd, follow_symlinks=False)
                stable = (first.st_dev, first.st_ino, first.st_mode, first.st_size,
                          first.st_mtime_ns, first.st_ctime_ns, first.st_nlink)
                if any((info.st_dev, info.st_ino, info.st_mode, info.st_size, info.st_mtime_ns,
                        info.st_ctime_ns, info.st_nlink) != stable for info in (current, named)):
                    raise ValueError("FilePV state identity changed during read")
        finally:
            os.close(dirfd)
    except OSError as error:
        raise ValueError("missing or substituted FilePV state path: " + filename) from error
    if raw != expected_raw or SIGNED.strict_json(raw) != expected:
        raise ValueError("wrong FilePV disk JSON: " + filename)
    return dict(path=state_path(seed), sha256=COMET.digest(raw), bytes=len(raw), mode="0600",
                device=first.st_dev, inode=first.st_ino, owner=first.st_uid,
                modifiedNs=first.st_mtime_ns, changedNs=first.st_ctime_ns)


def state_directory_identity(directory):
    info = directory.lstat()
    if (not stat.S_ISDIR(info.st_mode) or stat.S_IMODE(info.st_mode) != 0o700
            or info.st_uid != os.geteuid()):
        raise ValueError("FilePV state directory is not exclusively owned")
    return {"device": info.st_dev, "inode": info.st_ino, "owner": info.st_uid}


def require_disk_set(directory, expected):
    state_directory_identity(directory)
    if set(os.listdir(directory)) != {name + ".json" for name in expected}:
        raise ValueError("wrong FilePV state directory contents")
    return {name: require_disk(directory, name, disk) for name, disk in expected.items()}


def inputs():
    signed_pins, manifest, watched, _, correspondence = SIGNED.inputs()
    pins_path = FIXTURE / "pins.json"
    pins = SIGNED.strict_json(pins_path.read_bytes())
    SIGNED.fields(pins, ("schema", "inputsSha256", "disk"), "FilePV pins")
    if pins["schema"] != "etna-comet-filepv-pins-1" or set(pins["inputsSha256"]) != set(BUILD_FILES):
        raise ValueError("wrong FilePV pin schema or input paths")
    projection_path = SIGNED.FIXTURE / "public-votes.json"
    if pins["inputsSha256"]["public-votes.json"] != signed_pins["inputsSha256"]["public-votes.json"]:
        raise ValueError("FilePV public vote pin differs from reviewed projection")
    native = {name: FIXTURE / name for name in BUILD_FILES} | {"public-votes.json": projection_path}
    native_pins = {path: pins["inputsSha256"][name] for name, path in native.items()}
    require_stable(native_pins, "FilePV native inputs")
    for path in (Path(__file__), pins_path, ROOT / "run_comet_signed.py",
                 ROOT / "COMET_FILEPV.md", ROOT.parent / "tests/test_comet_filepv.py"):
        watched[path] = COMET.digest(path.read_bytes())
    expected = frozen_expectations(SIGNED.load_projection(projection_path.read_bytes()), pins["disk"])
    return signed_pins, pins, manifest, watched | native_pins, native, expected, correspondence


def expected_executed_inputs(pins, manifest):
    originals = pins["inputsSha256"]
    module = (FIXTURE / "go.mod").read_bytes()
    if COMET.digest(module) != originals["go.mod"]:
        raise ValueError("original FilePV Go module changed")
    return {f"inputs/{name}": digest for name, digest in originals.items()} | {
        "inputs/file.go": manifest["files"][FAULT_PATH]["sha256"],
        "modfiles/go.mod": COMET.digest(module + SIGNED.GO_MOD_REPLACEMENT),
        "modfiles/go.sum": originals["go.sum"],
    }


def require_executed_inputs(record, expected):
    if record.get("executedInputsBefore") != expected or record.get("executedInputsAfter") != expected:
        raise ValueError("wrong executed FilePV input hashes")


def stage(directory, private, manifest, pins, native):
    (directory / "work/state").mkdir(mode=0o700, parents=True)
    (directory / "work/build").mkdir()
    (directory / "modfiles").mkdir()
    (directory / "inputs").mkdir()
    for name, source in native.items():
        shutil.copyfile(source, directory / "inputs" / name)
    actual = (private / FAULT_PATH).read_bytes()
    if COMET.file_entry(actual) != manifest["files"][FAULT_PATH]:
        raise ValueError("FilePV staged source differs from current guarded source")
    (directory / "inputs/file.go").write_bytes(actual)
    (directory / "modfiles/go.mod").write_bytes(
        (directory / "inputs/go.mod").read_bytes() + SIGNED.GO_MOD_REPLACEMENT)
    shutil.copyfile(directory / "inputs/go.sum", directory / "modfiles/go.sum")
    return expected_executed_inputs(pins, manifest)


def selector(parent, selected):
    return "^" + parent + "$/^(" + "|".join(map(re.escape, selected)) + ")$"


def isolation_command(directory, private, args, selected_filter):
    command = SIGNED.isolation_command(directory, private, args, selected_filter)
    return command[:-1] + ["file.go", "filepv_test.go"]


@contextmanager
def omit_save(private, manifest, evidence):
    source = private / FAULT_PATH
    original = source.read_bytes()
    mode = stat.S_IMODE(source.stat().st_mode)
    if (COMET.file_entry(original) != manifest["files"][FAULT_PATH]
            or original.count(FAULT_FUNCTION) != 1 or original.count(FAULT_BEFORE) != 1
            or original.index(FAULT_BEFORE) <= original.index(FAULT_FUNCTION)):
        raise ValueError("wrong FilePV original bytes or omit-save anchor")
    mutated = original.replace(FAULT_BEFORE, FAULT_AFTER, 1)
    changed = manifest | {"files": manifest["files"] | {FAULT_PATH: COMET.file_entry(mutated)}}
    applied = False
    try:
        source.chmod(mode | stat.S_IWUSR)
        if source.write_bytes(mutated) != len(mutated):
            raise OSError("incomplete FilePV source fault write")
        applied = True
        (evidence / "mutant-file.go").write_bytes(mutated)
        write_json(evidence / "mutant-manifest.json", changed)
        yield changed
    finally:
        try:
            if applied and source.read_bytes() != mutated:
                raise ValueError("FilePV mutation bytes changed before restoration")
        finally:
            try:
                source.chmod(mode | stat.S_IWUSR)
                if source.write_bytes(original) != len(original):
                    raise OSError("incomplete FilePV source restoration")
            finally:
                source.chmod(mode)
            verified = COMET.verify_snapshot(private, manifest, manifest["commit"])
            restored_mode = stat.S_IMODE(source.stat().st_mode)
            if restored_mode != mode:
                raise ValueError("FilePV restored source mode differs")
            write_json(evidence / "actual-restoration.json",
                       verified | {"file": COMET.file_entry(source.read_bytes()), "mode": f"{mode:04o}"})


def invocation(role, phase, directory, private, manifest, args, expected_inputs, guarded,
               tool_hashes, expected, faults):
    parent = WRITER if role == "writer" else READER
    path = directory / (role + ".json")
    raw_path = directory / (role + ".log")
    staged = {directory / name: digest for name, digest in expected_inputs.items()}
    require_stable(guarded | staged, "FilePV runner, tools and executed inputs")
    source_before = COMET.verify_snapshot(private, manifest, manifest["commit"])
    selected_filter = selector(parent, expected)
    command = isolation_command(directory, private, args, selected_filter)
    result = COMET.EXECUTION.execute(command, ROOT, args.timeout + 10)
    raw = result["output"].encode()
    raw_path.write_bytes(raw)
    record = dict(phase=phase, role=role, selectedFilter=selected_filter, sourceRoot=str(private),
                  command=command, supervisorCommand=result["supervisor_argv"],
                  returncode=result["returncode"], timedOut=result["timeout"], seconds=result["seconds"],
                  combinedOutputSha256=COMET.digest(raw), executedInputsBefore=expected_inputs,
                  sourceBefore=source_before, toolsSha256=tool_hashes)
    write_json(path, record)
    require_stable(guarded | staged, "FilePV runner, tools and executed inputs")
    record["sourceAfter"] = COMET.verify_snapshot(private, manifest, manifest["commit"])
    record["executedInputsAfter"] = expected_inputs
    write_json(path, record)
    if result["timeout"] or result["returncode"] == 125:
        raise ValueError("FilePV native timeout or supervisor failure")
    record.update(require_go_outcomes(raw, result["returncode"], parent, expected, faults))
    write_json(path, record)
    return record


def run_trial(phase, private, manifest, args, pins, native, guarded, tools, expected):
    directory = args.output / phase
    disk, writers, readers = expected
    state = directory / "work/state"
    if phase == "smoke":
        name = next(iter(SEEDS))
        disk, writers, readers = {name: disk[name]}, {name: writers[name]}, {SMOKE: readers[SMOKE]}
    faults = {}
    if phase == "mutant":
        faults = {name: MISSING_STATE.format(name) for name in writers}
        writers = {name: row | {"diskAfter": None} for name, row in writers.items()}
    executed = stage(directory, private, manifest, pins, native)
    state_identity = state_directory_identity(state)
    require_disk_set(state, {})
    writer = invocation("writer", phase, directory, private, manifest, args, executed, guarded,
                        tools, writers, faults)
    before = require_disk_set(state, {} if faults else disk)
    if state_directory_identity(state) != state_identity:
        raise ValueError("writer replaced the FilePV state directory")
    report = dict(phase=phase, writer=writer, stateDirectory=state_identity,
                  diskBeforeReader=before, reader=None, diskAfterReader=None)
    if not faults:
        reader = invocation("reader", phase, directory, private, manifest, args, executed, guarded,
                            tools, readers, {})
        after = require_disk_set(state, disk)
        if (after != before or state_directory_identity(state) != state_identity
                or reader["process"] == writer["process"]):
            raise ValueError("FilePV reader changed disk or did not have a distinct process identity")
        report.update(reader=reader, diskAfterReader=after)
    write_json(directory / "handoff.json", report)
    print(f"{phase}: {len(writer['outcomes'])} exact writer leaves, "
          f"{len(readers) if report['reader'] else 0} exact reader leaves", flush=True)
    return report


def read_record(path):
    return json.loads(path.read_bytes(), object_pairs_hook=COMET.EXECUTION.unique_object,
                      parse_constant=SIGNED.reject_number)


def validate_smoke(path, args, pins, manifest, watched_hashes, tools, expected):
    disk, writers, readers = expected
    name = next(iter(SEEDS))
    smoke_root = path.resolve(strict=True)
    phase = smoke_root / "smoke"
    private = smoke_root / "private-upstream"
    source = COMET.verify_snapshot(private, manifest, manifest["commit"])
    expected_inputs = expected_executed_inputs(pins, manifest)
    require_stable({phase / file: digest for file, digest in expected_inputs.items()},
                   "FilePV smoke executed inputs")
    report = read_record(phase / "handoff.json")
    smoke_args = argparse.Namespace(**vars(args))
    smoke_args.output = smoke_root
    for role, parent, leaves in (("writer", WRITER, {name: writers[name]}),
                                 ("reader", READER, {SMOKE: readers[SMOKE]})):
        record = read_record(phase / (role + ".json"))
        raw = (phase / (role + ".log")).read_bytes()
        selected = selector(parent, leaves)
        command = isolation_command(phase, private, smoke_args, selected)
        supervisor = record["supervisorCommand"]
        admitted = require_go_outcomes(raw, record["returncode"], parent, leaves, {})
        if (record["phase"] != "smoke" or record["role"] != role or record["timedOut"] is not False
                or record["selectedFilter"] != selected or record["command"] != command
                or supervisor[:4] != [sys.executable, "-B", str(COMET.EXECUTION_PATH), "--_supervise"]
                or not re.fullmatch(r"[1-9][0-9]*", supervisor[4])
                or supervisor[5:] != [str(args.timeout + 10), str(ROOT), *command]
                or record["sourceRoot"] != str(private)
                or record["sourceBefore"] != source or record["sourceAfter"] != source
                or record["toolsSha256"] != tools or record["combinedOutputSha256"] != COMET.digest(raw)
                or any(record[key] != value for key, value in admitted.items()) or report[role] != record):
            raise ValueError("invalid or stale FilePV smoke " + role)
        require_executed_inputs(record, expected_inputs)
    current = require_disk_set(phase / "work/state", {name: disk[name]})
    summary = read_record(smoke_root / "summary.json")
    if (report["phase"] != "smoke" or report["diskBeforeReader"] != current
            or report["stateDirectory"] != state_directory_identity(phase / "work/state")
            or report["diskAfterReader"] != current or report["writer"]["process"] == report["reader"]["process"]
            or summary["schema"] != "etna-comet-filepv-execution-1" or summary["status"] != "PASS"
            or summary["reports"] != [report] or summary["inputsSha256"] != watched_hashes
            or summary["physicalBuildLock"] != str(args.build_lock)):
        raise ValueError("invalid or stale FilePV smoke handoff")
    return dict(path=str(smoke_root), writerSha256=report["writer"]["combinedOutputSha256"],
                readerSha256=report["reader"]["combinedOutputSha256"])


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scenario", choices=("persistence",), default="persistence")
    for name in ("source", "go-root", "module-cache", "build-cache", "build-lock", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--timeout", type=int, default=180, help="per-invocation isolation deadline")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--smoke", action="store_true")
    mode.add_argument("--smoke-output", type=Path)
    args = parser.parse_args(argv)
    try:
        signed, pins, manifest, watched, native, expected, correspondence = inputs()
        COMET.validate_layout(args, watched)
        args.build_lock = args.build_lock.resolve(strict=True)
        tool_hashes = signed["goToolSha256"]
        tools = {args.go_root / name: digest for name, digest in tool_hashes.items()}
        require_stable(tools, "pinned Go SDK")
        lock = args.build_lock
        if not lock.is_file() or lock in watched or lock in tools or any(
                lock.is_relative_to(root) for root in (args.source, args.go_root, args.module_cache, args.output)):
            raise ValueError("an existing independent shared cache lock file is required")
        watched_hashes = {str(path.relative_to(ROOT.parents[2])): digest for path, digest in watched.items()}
        guarded = watched | tools
        with lock.open("r") as guard:
            COMET.EXECUTION.acquire_lock(guard, min(args.timeout, 60))
            smoke = None if args.smoke else validate_smoke(
                args.smoke_output, args, pins, manifest, watched_hashes, tool_hashes, expected)
            source_before = COMET.verify_snapshot(args.source, manifest, manifest["commit"])
            args.output.mkdir(mode=0o700, parents=True)
            private = args.output / "private-upstream"
            shutil.copytree(args.source, private)
            phases = ("smoke",) if args.smoke else ("normal", "mutant", "restored")
            reports = []
            for phase in phases:
                if phase == "mutant":
                    with omit_save(private, manifest, args.output) as changed:
                        reports.append(run_trial(phase, private, changed, args, pins, native,
                                                 guarded, tool_hashes, expected))
                else:
                    reports.append(run_trial(phase, private, manifest, args, pins, native,
                                             guarded, tool_hashes, expected))
            require_stable(guarded, "FilePV campaign runner, public inputs and Go tools")
            source_after = COMET.verify_snapshot(args.source, manifest, manifest["commit"])
            summary = dict(schema="etna-comet-filepv-execution-1", status="PASS", scenario=args.scenario,
                           reports=reports, smoke=smoke, originalSourceBefore=source_before,
                           originalSourceAfter=source_after, specCorrespondence=correspondence,
                           inputsSha256=watched_hashes, physicalBuildLock=str(lock))
            if not args.smoke:
                summary["fault"] = dict(path=FAULT_PATH, original=manifest["files"][FAULT_PATH],
                                        mutant=changed["files"][FAULT_PATH],
                                        restored=read_record(args.output / "actual-restoration.json"))
            write_json(args.output / "summary.json", summary)
            print("PASS: pinned FilePV writer and consumer evidence verified")
    except (OSError, ValueError, KeyError, IndexError, TypeError, subprocess.SubprocessError) as error:
        print("Comet FilePV runner: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
