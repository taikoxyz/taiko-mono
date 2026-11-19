#!/usr/bin/env python3
"""Collect bounded offline stock signer transport evidence using public cached votes."""
import argparse
from contextlib import contextmanager
import copy
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import shutil
import stat
import sys

ROOT = Path(__file__).resolve().parent
PROFILE = ROOT / "comet_transport"
PACKAGE = "command-line-arguments"
PARENT = "TestCometTransport"
SMOKE = "nil-exact"
EPISODES = (
    SMOKE, "nil-time", "prevote-exact", "wrong-chain-retry", "prevote-conflict-retry",
    "wrong-union", "wrong-union-retry", "truncated-retry", "transport-exhausted", "cancel",
)
STOCK = tuple("privval/" + name + ".go" for name in (
    "file", "errors", "msgs", "retry_signer_client", "signer_client", "signer_dialer_endpoint",
    "signer_endpoint", "signer_listener_endpoint", "signer_requestHandler", "signer_server",
    "socket_dialers", "socket_listeners",
))
NATIVE = {
    "go.mod": "comet_transport/go.mod",
    "go.sum": "comet_transport/go.sum",
    "transport_test.go": "comet_transport/transport_test.go",
    "filepv_test.go": "comet_filepv/filepv_test.go",
    "public-votes.json": "comet_signed/public-votes.json",
}
PINNED = (
    *NATIVE.values(), "comet_filepv/pins.json", "run_comet_transport.py",
    "COMET_TRANSPORT.md", "../tests/test_comet_transport.py",
)
FAULTS = {
    "refusal-branch": (
        "privval/retry_signer_client.go",
        b"func (sc *RetrySignerClient) SignVote(",
        b"\t\tif _, ok := err.(*RemoteSignerError); ok {\n\t\t\treturn err\n\t\t}\n",
        b"",
    ),
    "client-assignment": (
        "privval/signer_client.go",
        b"func (sc *SignerClient) SignVote(",
        b"\t*vote = resp.Vote\n",
        b"\tvote.Timestamp = resp.Vote.Timestamp\n",
    ),
}
RECEIPT_LIMIT = 128 * 1024
DURATION = r"[0-9]+(?:\.[0-9]+)?s"


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


FILEPV = load_module("etna_transport_filepv", ROOT / "run_comet_filepv.py")
SIGNED = FILEPV.SIGNED
COMET = SIGNED.COMET
CURRENT = SIGNED.CURRENT_SPEC


def compare_receipt(observed, expected, path="$"):
    """Require exact values, keys, sequence lengths, order and scalar types."""
    def mismatch():
        raise ValueError("receipt value mismatch at " + path)

    if type(observed) is not type(expected):
        mismatch()
    if type(expected) is dict:
        if set(observed) != set(expected):
            mismatch()
        for key in sorted(expected):
            compare_receipt(observed[key], expected[key], path + "." + str(key))
    elif type(expected) is list:
        if len(observed) != len(expected):
            mismatch()
        for index, (actual, model) in enumerate(zip(observed, expected)):
            compare_receipt(actual, model, f"{path}[{index}]")
    elif observed != expected:
        mismatch()


def framed(wire):
    data = bytes.fromhex(wire)
    return (FILEPV.varint(len(data)) + data).hex()


def expected_receipts(projection, disk):
    """Compose public O02 wire/disk expectations with the fixed transport contract."""
    _, _, handler = FILEPV.frozen_expectations(projection, disk, "handler")
    nil = handler[SMOKE]["calls"][0]

    def attempt(call, pipe=1, change=""):
        req, response = call["request"], call["response"]
        request_frame = framed(req["wire"])
        server_frame = framed(response["wire"])
        read_error = ""
        delivered = server_frame
        wire_response = response
        if change == "wrong-union":
            delivered = "024200"
            wire_response = {"union": "PingResponse", "wire": "4200"}
        elif change in ("truncate", "silent"):
            delivered = server_frame[:-2] if change == "truncate" else ""
            wire_response = None
            read_error = "read pipe: i/o timeout"
        return {
            "pipe": pipe, "requestWrite": request_frame, "requestRead": request_frame,
            "request": {"chain": req["requestedChain"], "configuredChain": req["configuredChain"],
                        "wire": req["wire"], "vote": req["vote"]},
            "stockResponse": response, "handlerError": call["goError"] or "",
            "serverFrame": server_frame, "wireSent": delivered, "wireRead": delivered,
            "wireResponse": wire_response, "clientReadError": read_error,
            "clientDeadline": True, "clientDrop": bool(read_error), "peerOpenAtError": bool(read_error),
        }

    def call_report(call, attempts=None, failure=None):
        request, response = call["request"], call["response"]
        remote = response["error"]
        error_class, error_message = "ok", ""
        if remote is not None:
            error_class = "remote"
            error_message = f"signerEndpoint returned error #{remote['code']}: {remote['description']}"
        if failure == "required":
            error_class = "exhausted-required-response"
            error_message = "exhausted all attempts to sign vote: response is required"
        elif failure in ("exhausted", "aborted"):
            error_class = failure + "-timeout"
            prefix = "exhausted all attempts to sign vote" if failure == "exhausted" else "aborted signing vote"
            error_message = prefix + ": read pipe: i/o timeout: endpoint read timed out"
        return {
            "requestedChain": request["requestedChain"], "before": request["vote"],
            "after": call["voteAfter"] if error_class == "ok" else request["vote"],
            "result": {"class": error_class, "message": error_message, "remote": remote},
            "verified": error_class == "ok", "attempts": attempts or [attempt(call)],
            **{key: call[key] for key in ("stateBefore", "stateAfter", "diskBefore", "diskAfter")},
        }

    def report(name, seed, calls, retries=1, pipes=1, cancel=False):
        owned = list(range(1, pipes + 1))
        return {
            "schema": "etna-comet-transport-receipt-1", "episode": name, "seed": seed,
            "path": FILEPV.state_path(seed), "configuredChain": nil["request"]["configuredChain"],
            "loadedDisk": FILEPV.disk_observation(seed, disk[seed]), "calls": calls,
            "profile": {"readMillis": 200, "serverMillis": 3000, "acceptMillis": 200,
                        "retryMillis": 2000 if cancel else 20, "pingMillis": 3_600_000,
                        "retries": retries},
            "cleanup": {"accepted": owned, "dialed": owned, "closedPipes": owned,
                        "retryWaitObserved": cancel, "joined": True, "retryClosed": True,
                        "listenerClosed": True, "servicesStopped": True},
        }

    reports = {}
    for name in EPISODES[:5]:
        source = handler[name]
        reports[name] = report(name, source["seed"], [call_report(call) for call in source["calls"]],
                               retries=2 if len(source["calls"]) == 2 else 1)
    seed = handler[SMOKE]["seed"]
    reports["wrong-union"] = report("wrong-union", seed, [
        call_report(nil, [attempt(nil, change="wrong-union")], "required"),
    ])
    reports["wrong-union-retry"] = report("wrong-union-retry", seed, [
        call_report(nil, [attempt(nil, change="wrong-union"), attempt(nil)]),
    ], retries=2)
    reports["truncated-retry"] = report("truncated-retry", seed, [
        call_report(nil, [attempt(nil, change="truncate"), attempt(nil, pipe=2)]),
    ], retries=2, pipes=2)
    reports["transport-exhausted"] = report("transport-exhausted", seed, [
        call_report(nil, [attempt(nil, pipe=pipe, change="silent") for pipe in (1, 2, 3)], "exhausted"),
    ], retries=3, pipes=3)
    reports["cancel"] = report("cancel", seed, [
        call_report(nil, [attempt(nil, change="silent")], "aborted"),
    ], retries=3, cancel=True)
    return reports


def changed_expectations(phase, expected):
    changed = copy.deepcopy(expected)
    reasons = {}
    if phase == "refusal-branch":
        for name in ("wrong-chain-retry", "prevote-conflict-retry"):
            call = changed[name]["calls"][0]
            call["attempts"].append(copy.deepcopy(call["attempts"][0]))
            call["result"]["class"] = "exhausted-remote"
            call["result"]["message"] = "exhausted all attempts to sign vote: " + call["result"]["message"]
            reasons[name] = "$.calls[0].attempts"
    elif phase == "client-assignment":
        for name, report in changed.items():
            for index, call in enumerate(report["calls"]):
                if call["result"]["class"] != "ok":
                    continue
                vote = call["after"]
                signature = FILEPV.field(0x42, bytes.fromhex(vote["signature"])).hex()
                if not vote["wire"].endswith(signature):
                    raise ValueError("fault oracle cannot remove the final signature field")
                call["after"] = vote | {"wire": vote["wire"].removesuffix(signature), "signature": ""}
                call["verified"] = False
                reasons.setdefault(name, f"$.calls[{index}].after.signature")
    return changed, reasons


def native_outcomes(raw, returncode, selected):
    """Read the ordered Go lifecycle and each native producer's digest."""
    if type(returncode) is not int or returncode != 0 or not raw or len(raw) > 128 * 1024:
        raise ValueError("native transport execution failed or produced invalid output length")

    def invalid(token):
        raise ValueError("invalid native floating point token: " + token)

    events = iter(json.loads(line, object_pairs_hook=COMET.EXECUTION.unique_object, parse_constant=invalid)
                  for line in raw.splitlines())

    def event(action, name=None, output=None, *, frame=False):
        row = next(events, None)
        fields = {"Time", "Action", "Package"}
        if name is not None:
            fields.add("Test")
        if output is not None:
            fields.add("Output")
            if frame:
                fields.add("OutputType")
        if action == "pass":
            fields.add("Elapsed")
        SIGNED.fields(row, fields, "ordered native event")
        if (row["Package"] != PACKAGE or row["Action"] != action or row.get("Test") != name
                or type(row["Time"]) is not str
                or re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d+)?Z", row["Time"]) is None):
            raise ValueError("wrong ordered native event")
        if action == "pass":
            elapsed = row["Elapsed"]
            if type(elapsed) not in (int, float) or not math.isfinite(elapsed) or elapsed < 0:
                raise ValueError("wrong native elapsed time")
        if output is not None:
            if frame and row["OutputType"] != "frame":
                raise ValueError("wrong native frame type")
            message = row["Output"]
            match = re.fullmatch(output, message) if type(message) is str else None
            if not match:
                raise ValueError("wrong native diagnostic for " + str(name))
            return match
        return None

    def started(name):
        event("run", name)
        event("output", name, re.escape("=== RUN   " + name + "\n"), frame=True)

    def passed(name):
        event("output", name, r"\s*--- PASS: " + re.escape(name) + r" \(" + DURATION + r"\)\n", frame=True)
        event("pass", name)

    event("start")
    started(PARENT)
    process = event("output", PARENT,
                    r" +transport_test.go:[1-9][0-9]*: transport process ([1-9][0-9]*) "
                    r"(pid:\[[1-9][0-9]*\]) ([1-9][0-9]*)\n")
    pid, namespace, start = process.groups()
    traces = {}
    for episode in selected:
        name = PARENT + "/" + episode
        started(name)
        receipt = event("output", name,
                        r" +transport_test.go:[1-9][0-9]*: receipt " + episode
                        + r" ([1-9][0-9]*) ([0-9a-f]{64})\n")
        size, digest = receipt.groups()
        traces[episode] = {"bytes": int(size), "sha256": digest}
        passed(name)
    passed(PARENT)
    event("output", output="PASS\n", frame=True)
    event("output", output=re.escape("ok  \t" + PACKAGE + "\t") + DURATION + "\n")
    event("pass")
    for _ in events:
        raise ValueError("additional native events after package pass")
    return {"process": {"pid": int(pid), "namespace": namespace, "startTicks": start}, "receipts": traces}


def physical(info):
    return f"{info.st_dev}:{info.st_ino}"


def mode(info):
    return stat.S_IMODE(info.st_mode)


def file_record(path):
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode):
        raise ValueError("non-regular guarded input: " + str(path))
    return {"mode": mode(info), "bytes": info.st_size, "sha256": COMET.digest(path.read_bytes())}


def inventory(root):
    result = {}
    for path in (root, *root.rglob("*")):
        info = path.lstat()
        name = path.relative_to(root).as_posix()
        if stat.S_ISDIR(info.st_mode):
            result[name] = {"kind": "directory", "mode": mode(info)}
        elif stat.S_ISREG(info.st_mode):
            result[name] = {"kind": "file", **file_record(path)}
        else:
            raise ValueError("non-regular inventory path: " + name)
    return result


def require_stable(actual, expected, label):
    try:
        compare_receipt(actual, expected)
    except ValueError as error:
        raise ValueError(label + " changed") from error


def directory_descriptor(path):
    return os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)


def stable_file_identity(info):
    return (info.st_dev, info.st_ino, info.st_uid, info.st_mode, info.st_nlink,
            info.st_size, info.st_mtime_ns, info.st_ctime_ns)


def verify_receipts(directory, producer, expected, variant, reasons):
    """Bind producer metadata to the same one-read bytes consumed by the oracle."""
    receipts, rejections = {}, {}
    dirfd = directory_descriptor(directory)
    try:
        info = os.fstat(dirfd)
        if mode(info) != 0o700 or info.st_uid != os.geteuid():
            raise ValueError("transport receipt directory ownership or mode differs")
        if set(os.listdir(dirfd)) != {name + ".json" for name in expected} or set(producer) != set(expected):
            raise ValueError("wrong native transport receipt inventory")
        for name, model in expected.items():
            filename = name + ".json"
            fd = os.open(filename, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=dirfd)
            with os.fdopen(fd, "rb") as stream:
                info = os.fstat(fd)
                if not (stat.S_ISREG(info.st_mode) and mode(info) == 0o600
                        and info.st_uid == os.geteuid() and info.st_nlink == 1
                        and 0 < info.st_size <= RECEIPT_LIMIT):
                    raise ValueError("invalid native transport receipt file: " + name)
                raw = stream.read(RECEIPT_LIMIT + 1)
                identity = stable_file_identity(info)
                require_stable(stable_file_identity(os.fstat(fd)), identity, "receipt descriptor")
                named = os.stat(filename, dir_fd=dirfd, follow_symlinks=False)
                require_stable(stable_file_identity(named), identity, "receipt pathname")
            received = {"bytes": len(raw), "sha256": COMET.digest(raw)}
            if len(raw) != info.st_size or received != producer[name]:
                raise ValueError("native producer and consumed receipt bytes differ: " + name)
            observed = SIGNED.strict_json(raw)
            try:
                compare_receipt(observed, model)
            except ValueError as error:
                if name not in reasons or str(error) != "receipt value mismatch at " + reasons[name]:
                    raise
                compare_receipt(observed, variant[name])
                rejections[name] = str(error)
            else:
                if name in reasons:
                    raise ValueError("source variation escaped the ordinary observer: " + name)
            receipts[name] = received
        if set(os.listdir(dirfd)) != {name + ".json" for name in expected}:
            raise ValueError("transport receipt directory changed while reading")
        require_stable(physical(directory.lstat()), physical(os.fstat(dirfd)), "receipt directory pathname")
    finally:
        os.close(dirfd)
    return {"verifiedReceipts": receipts, "expectedRejections": rejections}


def load_inputs(workspace):
    signed_pins, manifest, inherited, _ = SIGNED.native_inputs()
    pins_path = PROFILE / "pins.json"
    pins = SIGNED.strict_json(pins_path.read_bytes())
    SIGNED.fields(pins, ("schema", "inputsSha256"), "transport pins")
    if pins["schema"] != "etna-comet-transport-pins-1" or set(pins["inputsSha256"]) != set(PINNED):
        raise ValueError("wrong or omitted transport profile inputs")
    pinned = {ROOT / name: digest for name, digest in pins["inputsSha256"].items()}
    file_pins = SIGNED.strict_json((FILEPV.FIXTURE / "pins.json").read_bytes())
    if (pins["inputsSha256"][NATIVE["public-votes.json"]] != signed_pins["inputsSha256"]["public-votes.json"]
            or pins["inputsSha256"][NATIVE["filepv_test.go"]] != file_pins["inputsSha256"]["filepv_test.go"]):
        raise ValueError("transport build differs from the existing public FilePV evidence pins")
    record = {path: file_record(path) for path in inherited | pinned}
    for path, digest in (inherited | pinned).items():
        if record[path]["sha256"] != digest:
            raise ValueError("transport input pin mismatch: " + str(path))
    extra = [pins_path, Path(FILEPV.__file__), Path(CURRENT.__file__), CURRENT.MANIFEST_PATH]
    docs = {name: workspace / name for name in CURRENT.DOCUMENT_PATHS}
    record.update({path: file_record(path) for path in (*extra, *docs.values())})
    metadata = SIGNED.strict_json(CURRENT.MANIFEST_PATH.read_bytes())
    bundle = CURRENT.classify_workspace_documents({name: path.read_bytes() for name, path in docs.items()}, metadata)
    claim = CURRENT.select_claim(bundle["bundleId"], "comet-signer-transport", "cached-replies")
    projection = SIGNED.load_projection((ROOT / NATIVE["public-votes.json"]).read_bytes())
    expected = expected_receipts(projection, file_pins["disk"])
    return signed_pins, manifest, record, expected, file_pins["disk"], bundle, claim


def signed_tools(go_root, expected):
    actual = {relative: file_record(go_root / relative) for relative in expected}
    if {path: entry["sha256"] for path, entry in actual.items()} != expected or len(actual) != 6:
        raise ValueError("Go SDK differs from the six independently pinned tools")
    return actual


@contextmanager
def shared_build_guard(args):
    lockfd = os.open(args.build_lock, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(lockfd, "rb") as lock:
        cachefd = directory_descriptor(args.build_cache)
        try:
            lockinfo, cacheinfo = os.fstat(lockfd), os.fstat(cachefd)
            if not stat.S_ISREG(lockinfo.st_mode) or lockinfo.st_nlink != 1:
                raise ValueError("shared build lock is not a regular one-link file")

            def verify():
                identities = {
                    "lock": physical(os.fstat(lockfd)), "cache": physical(os.fstat(cachefd)),
                }
                if identities != {"lock": args.expected_lock_identity, "cache": args.expected_cache_identity}:
                    raise ValueError("unexpected physical shared build cache or lock")
                for path, opened in ((args.build_lock, lockinfo), (args.build_cache, cacheinfo)):
                    named = path.lstat()
                    if physical(named) != physical(opened) or named.st_mode != opened.st_mode:
                        raise ValueError("physical shared build resource changed: " + str(path))
                return identities

            verify()
            COMET.EXECUTION.acquire_lock(lock, 30)
            verify()
            try:
                yield verify
            finally:
                verify()
        finally:
            os.close(cachefd)


def source_variation(private, manifest, phase):
    relative, anchor, before, after = FAULTS[phase]
    path = private / relative
    original = path.read_bytes()
    if original.count(anchor) != 1 or COMET.file_entry(original) != manifest["files"][relative]:
        raise ValueError("source variation target mismatch")
    start = original.index(anchor)
    end = original.find(b"\nfunc ", start + len(anchor))
    body = original[start:] if end < 0 else original[start:end]
    if body.count(before) != 1:
        raise ValueError("source variation selector is not unique in the target function")
    offset = start + body.index(before)
    changed = original[:offset] + after + original[offset + len(before):]
    first = path.lstat()
    entries = manifest["files"] | {relative: COMET.file_entry(changed)}
    mutation = {"path": relative, "identity": physical(first), "original": manifest["files"][relative],
                "changed": entries[relative], "mode": mode(first)}
    return path, original, changed, manifest | {"files": entries}, mutation


@contextmanager
def phase_source(private, manifest, phase):
    if phase not in FAULTS:
        yield manifest, None
        return
    path, original, changed, updated, mutation = source_variation(private, manifest, phase)

    def set_body(data):
        path.chmod(mutation["mode"] | stat.S_IWUSR)
        try:
            path.write_bytes(data)
        finally:
            path.chmod(mutation["mode"])
        if physical(path.lstat()) != mutation["identity"] or path.read_bytes() != data:
            raise ValueError("source variation did not preserve the exact target file")

    try:
        set_body(changed)
        yield updated, mutation
    finally:
        set_body(original)


def make_stage(trial, private, manifest, selected_models, disk, watched):
    inputs, mods, work = (trial / name for name in ("inputs", "modfiles", "work"))
    for path in (inputs, mods, work, trial / "jails"):
        path.mkdir(mode=0o700)
    for name, relative in NATIVE.items():
        shutil.copyfile(ROOT / relative, inputs / name)
        if file_record(inputs / name)["sha256"] != watched[ROOT / relative]["sha256"]:
            raise ValueError("staged fixture differs from its guarded input: " + name)
    for relative in STOCK:
        raw = (private / relative).read_bytes()
        if COMET.file_entry(raw) != manifest["files"][relative]:
            raise ValueError("staged source differs from the exact phase source: " + relative)
        (inputs / Path(relative).name).write_bytes(raw)
    (mods / "go.mod").write_bytes((inputs / "go.mod").read_bytes() + SIGNED.GO_MOD_REPLACEMENT)
    shutil.copyfile(inputs / "go.sum", mods / "go.sum")
    for directory in (inputs, mods):
        for path in directory.iterdir():
            path.chmod(0o444)
        directory.chmod(0o555)
    for name in ("build", "receipts", "state", "tmp"):
        (work / name).mkdir(mode=0o700)
    selected_disk = {report["seed"]: disk[report["seed"]] for report in selected_models.values()}
    for seed, value in selected_disk.items():
        path = work / "state" / (seed + ".json")
        data = json.dumps(value, indent=2).encode()
        with os.fdopen(os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), "wb") as stream:
            stream.write(data)
    return inputs, mods, work, selected_disk


def isolation_command(args, trial, private, selected):
    inputs, mods, work = (trial / name for name in ("inputs", "modfiles", "work"))
    argv = [sys.executable, "-B", str(ROOT / "run_isolated.py")]
    for source, target in ((inputs, "/tmp/replay"), (private, "/tmp/upstream"), (mods, "/tmp/modfiles"),
                           (args.go_root, "/tmp/go"), (args.module_cache, "/tmp/gomodcache")):
        argv.extend(("--read-bind", f"{source}={target}"))
    for source, target in ((args.build_cache, "/tmp/gocache"), (work, "/tmp/output")):
        argv.extend(("--write-bind", f"{source}={target}"))
    argv.extend(("--cwd", "/tmp/replay", "--timeout", "100", "--jail-parent", str(trial / "jails")))
    env = {
        "GOROOT": "/tmp/go", "GOMODCACHE": "/tmp/gomodcache", "GOCACHE": "/tmp/gocache",
        "GOPATH": "/tmp/gopath", "GOTMPDIR": "/tmp/output/build", "TMPDIR": "/tmp/output/tmp",
        "GOENV": "off", "GOTOOLCHAIN": "local", "GOPROXY": "off", "GOSUMDB": "off",
        "GOVCS": "*:off", "GOWORK": "off", "CGO_ENABLED": "0", "GOTELEMETRY": "off", "GOMAXPROCS": "2",
    }
    for key, value in env.items():
        argv.extend(("--env", key + "=" + value))
    argv.extend(("--", "/tmp/go/bin/go", "test", "-json", "-count=1", "-parallel=1", "-p=2",
                 "-mod=readonly", "-modfile=/tmp/modfiles/go.mod", "-timeout=90s",
                 "-run", "^" + PARENT + "$/^(" + "|".join(map(re.escape, selected)) + ")$",
                 *[Path(name).name for name in STOCK], "filepv_test.go", "transport_test.go"))
    return argv


def stage_inventory(root, watched, manifest):
    expected_inputs = {".": {"kind": "directory", "mode": 0o555}}
    for name, relative in NATIVE.items():
        pin = watched[ROOT / relative]
        expected_inputs[name] = {"kind": "file", "mode": 0o444,
                                 "bytes": pin["bytes"], "sha256": pin["sha256"]}
    for relative in STOCK:
        pin = manifest["files"][relative]
        expected_inputs[Path(relative).name] = {
            "kind": "file", "mode": 0o444, "bytes": pin["bytes"], "sha256": pin["sha256"],
        }
    module = (PROFILE / "go.mod").read_bytes() + SIGNED.GO_MOD_REPLACEMENT
    expected_mods = {
        ".": expected_inputs["."], "go.sum": expected_inputs["go.sum"],
        "go.mod": {"kind": "file", "mode": 0o444, "bytes": len(module), "sha256": COMET.digest(module)},
    }
    actual = {name: inventory(root / name) for name in ("inputs", "modfiles")}
    require_stable(actual, {"inputs": expected_inputs, "modfiles": expected_mods},
                   "exact staged Go source, original module and generated module")
    return actual


def checked_phase(args, trial, private, selected, expected, variant, reasons, disk,
                  watched, phase_manifest, live_source, mutation):
    report = SIGNED.strict_json((trial / "execution.json").read_bytes())
    if (report.get("status") != "VERIFIED" or report.get("phase") != trial.name
            or report.get("timedOut") is not False or report.get("outputDecoding") != "utf-8-errors-replace"):
        raise ValueError("previous phase lacks verified execution: " + trial.name)
    command = isolation_command(args, trial, private, selected)
    require_stable(report.get("command"), command, "previous native command")
    supervisor = report.get("supervisorCommand")
    expected_prefix = [sys.executable, "-B", str(COMET.EXECUTION_PATH), "--_supervise"]
    if (type(supervisor) is not list or supervisor[:4] != expected_prefix or len(supervisor) < 7
            or type(supervisor[4]) is not str or re.fullmatch("[1-9][0-9]*", supervisor[4]) is None
            or supervisor[5:] != ["110", str(ROOT), *command]):
        raise ValueError("previous authoritative supervisor command differs")
    require_stable(report.get("sourceManifest"), phase_manifest["files"], "previous phase manifest")
    require_stable(report.get("mutation"), mutation, "previous phase source variation")
    exec_inputs = stage_inventory(trial, watched, phase_manifest)
    require_stable(report.get("executedInputs"), exec_inputs | {"private": live_source},
                   "previous effective execution snapshot")
    state = trial / "work/state"
    selected_disk = {item["seed"]: disk[item["seed"]] for item in expected.values()}
    require_stable(report.get("stateDirectory"), FILEPV.state_directory_identity(state),
                   "previous durable directory")
    durable = FILEPV.require_disk_set(state, selected_disk)
    for boundary in ("stateBefore", "stateAfter"):
        require_stable(report.get(boundary), durable, "previous durable state")
    if list((trial / "jails").iterdir()):
        raise ValueError("previous owned isolation directory left behind")
    raw = (trial / "combined.log").read_bytes()
    require_stable(COMET.digest(raw), report["combinedOutputSha256"], "previous phase log")
    outcomes = native_outcomes(raw, report["returncode"], selected)
    require_stable(outcomes, report["nativeOutcomes"], "previous native producer")
    verified = verify_receipts(trial / "work/receipts", outcomes["receipts"], expected, variant, reasons)
    require_stable(verified, {key: report[key] for key in verified}, "previous receipt result")
    return report


def record_json(path, value):
    path.write_text(json.dumps(value, sort_keys=True, indent=2) + "\n")


def run_trial(args, trial, private, manifest, expected, disk, guards, common, watched, phase_mutation):
    phase = trial.name
    selected = (SMOKE,) if phase == "smoke" else EPISODES
    expected = {name: expected[name] for name in selected}
    variant, reasons = changed_expectations(phase, expected)
    trial.mkdir(mode=0o700)
    inputs, mods, work, selected_disk = make_stage(trial, private, manifest, expected, disk, watched)
    manifests = stage_inventory(trial, watched, manifest) | {"private": inventory(private)}
    state = work / "state"
    state_identity = FILEPV.state_directory_identity(state)
    durable = FILEPV.require_disk_set(state, selected_disk)
    command = isolation_command(args, trial, private, selected)
    report = {
        **common, "phase": phase, "status": "STARTED", "command": command,
        "mutation": phase_mutation, "sourceManifest": manifest["files"],
        "executedInputs": manifests, "stateBefore": durable, "stateDirectory": state_identity,
    }
    record = trial / "execution.json"
    record_json(record, report)
    try:
        guards()
        native = COMET.EXECUTION.execute(command, ROOT, 110)
        raw = native["output"].encode()
        (trial / "combined.log").write_bytes(raw)
        report.update(supervisorCommand=native["supervisor_argv"], returncode=native["returncode"],
                      timedOut=native["timeout"], combinedOutputSha256=COMET.digest(raw),
                      outputDecoding="utf-8-errors-replace")
        record_json(record, report)
        if native["timeout"] or native["returncode"] == 125:
            raise ValueError("native transport timeout or descendant cleanup failure")
        outcomes = native_outcomes(raw, native["returncode"], selected)
        report["nativeOutcomes"] = outcomes
        report.update(verify_receipts(work / "receipts", outcomes["receipts"], expected, variant, reasons))
        report["status"] = "OBSERVED"
    finally:
        try:
            guards()
            require_stable(inventory(inputs), manifests["inputs"], "staged inputs")
            require_stable(inventory(mods), manifests["modfiles"], "generated module files")
            require_stable(inventory(private), manifests["private"], "private source")
            require_stable(FILEPV.state_directory_identity(state), state_identity, "durable directory")
            durable_after = FILEPV.require_disk_set(state, selected_disk)
            require_stable(durable_after, durable, "durable FilePV state")
            if list((trial / "jails").iterdir()):
                raise ValueError("owned isolation directory left behind")
            report["stateAfter"] = durable_after
            report["phaseInputsStable"] = True
        finally:
            record_json(record, report)
    return report


def prior_phase(args, campaign, phase, private, manifest, expected, disk, watched, common):
    selected = (SMOKE,) if phase == "smoke" else EPISODES
    expected = {name: expected[name] for name in selected}
    variant, reasons = changed_expectations(phase, expected)
    live_source = common["sourceInventory"]
    mutation = None
    if phase in FAULTS:
        _, _, _, manifest, mutation = source_variation(private, manifest, phase)
        relative = mutation["path"]
        changed = {key: mutation["changed"][key] for key in ("bytes", "sha256")}
        live_source = live_source | {relative: live_source[relative] | changed}
    report = checked_phase(args, campaign / phase, private, selected, expected, variant,
                           reasons, disk, watched, manifest, live_source, mutation)
    require_stable({key: report[key] for key in common}, common, "prior phase input identity")
    if report.get("phaseInputsStable") is not True or report.get("privateOriginalRestored") is not True:
        raise ValueError("previous phase lacks an exact post-run input guard")
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    for option in ("source", "workspace-root", "go-root", "module-cache", "build-cache", "build-lock", "output"):
        parser.add_argument("--" + option, type=Path, required=True)
    for option in ("expected-cache-identity", "expected-lock-identity"):
        parser.add_argument("--" + option, required=True)
    parser.add_argument("--phase", choices=("smoke", "original", *FAULTS, "restored"), required=True)
    args = parser.parse_args(argv)
    args.timeout = 100
    phase = args.phase
    campaign = args.output.resolve()
    args.output = campaign / phase
    if any(path.is_symlink() for path in (args.build_lock, args.build_cache, args.module_cache, args.source)):
        raise ValueError("prepared resource aliases are forbidden")
    args.build_lock = args.build_lock.absolute()
    workspace = args.workspace_root.resolve(strict=True)
    signed, manifest, watched, expected, disk, bundle, claim = load_inputs(workspace)
    COMET.validate_layout(args, watched)
    if any(campaign == root or campaign in root.parents for root in
           (ROOT.parent, workspace, args.build_cache, args.source, args.go_root, args.module_cache)):
        raise ValueError("campaign output would enclose a prepared input")
    with shared_build_guard(args) as resource_guard:
        identities = resource_guard()
        tools = signed_tools(args.go_root, signed["goToolSha256"])
        modules = args.module_cache.lstat()
        if not stat.S_ISDIR(modules.st_mode):
            raise ValueError("prepared Go module cache must be a directory")
        source_commit = signed["source"]["commit"]
        COMET.verify_snapshot(args.source, manifest, source_commit)
        original = inventory(args.source)
        source_dir = {"path": str(args.source), "identity": physical(args.source.lstat())}
        for name, item in original.items():
            if item["mode"] != (0o555 if item["kind"] == "directory" else 0o444):
                raise ValueError("prepared stock source is not in the original read-only modes: " + name)
        private = campaign / "private-upstream"
        if phase == "smoke":
            campaign.mkdir(mode=0o700)
            shutil.copytree(args.source, private)
        elif not campaign.is_dir() or campaign.is_symlink() or mode(campaign.lstat()) != 0o700:
            raise ValueError("missing exclusive campaign directory")
        require_stable(inventory(private), original, "same-copy original source")
        physical_copy = {name: physical(path.lstat()) for name, path in
                         (("root", private), ("refusal", private / FAULTS["refusal-branch"][0]),
                          ("assignment", private / FAULTS["client-assignment"][0]))}
        common = {
            "schema": "etna-comet-transport-execution-1", "workspace": bundle, "claim": claim,
            "sourceCommit": source_commit, "sourceDirectory": source_dir, "sourceInventory": original,
            "privateCopy": physical_copy, "physicalResources": identities,
            "moduleCache": {"identity": physical(modules), "mode": mode(modules)},
            "tools": tools, "profileInputs": {str(path): record for path, record in watched.items()},
        }

        def guards():
            require_stable(resource_guard(), identities, "shared build resources")
            current_modules = args.module_cache.lstat()
            require_stable((physical(current_modules), current_modules.st_mode),
                           (physical(modules), modules.st_mode), "module cache root")
            require_stable(signed_tools(args.go_root, signed["goToolSha256"]), tools, "Go tools")
            require_stable({path: file_record(path) for path in watched}, watched, "profile inputs")
            require_stable(physical(args.source.lstat()), source_dir["identity"], "original source directory")
            require_stable(inventory(args.source), original, "original stock snapshot")
            actual_copy = {name: physical(path.lstat()) for name, path in
                           (("root", private), ("refusal", private / FAULTS["refusal-branch"][0]),
                            ("assignment", private / FAULTS["client-assignment"][0]))}
            require_stable(actual_copy, physical_copy, "private source physical identity")

        def review_previous(name):
            return prior_phase(args, campaign, name, private, manifest, expected, disk, watched, common)

        history = []
        if phase != "smoke":
            history.append(review_previous("smoke"))
        if phase not in ("smoke", "original"):
            history.append(review_previous("original"))
        if phase == "restored":
            candidates = [name for name in FAULTS if (campaign / name).exists()]
            if len(candidates) != 1:
                raise ValueError("restoration requires exactly one examined source variation")
            history.append(review_previous(candidates[0]))
        trial = campaign / phase
        report = None
        try:
            with phase_source(private, manifest, phase) as (phase_manifest, mutation):
                COMET.verify_snapshot(private, phase_manifest, source_commit)
                report = run_trial(args, trial, private, phase_manifest, expected, disk,
                                   guards, common, watched, mutation)
        finally:
            guards()
            require_stable(inventory(private), original, "exact same-copy restoration")
            if report is not None:
                report["privateOriginalRestored"] = True
                record_json(trial / "execution.json", report)
        previous_processes = [row["nativeOutcomes"]["process"] for row in history]
        if report["nativeOutcomes"]["process"] in previous_processes:
            raise ValueError("native process identity was reused across phases")
        if phase == "restored":
            require_stable(report["verifiedReceipts"], history[1]["verifiedReceipts"],
                           "restored compared with original receipt bytes")
        report["status"] = "VERIFIED"
        record_json(trial / "execution.json", report)
        print(f"{phase}: {len(report['verifiedReceipts'])} receipts, "
              f"{len(report['expectedRejections'])} exact ordinary-observer rejections", flush=True)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError) as error:
        print("transport replay failed: " + str(error), file=sys.stderr)
        raise SystemExit(1)
