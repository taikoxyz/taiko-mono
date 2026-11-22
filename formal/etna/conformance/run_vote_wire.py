"""Run the selected unsigned vote serialization cases with pinned local inputs."""

import argparse
from contextlib import contextmanager
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import stat
import sys


ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[2]
DRAFT = ROOT.parent / "draft_rules"
PACKAGE = "example.org/etna-vote-wire"
PARENT = "TestEtnaVoteWire"
SMOKE = "zero32-hash-only"
PROFILE = DRAFT / "vote_wire_sources.json"
CORPUS = DRAFT / "vote_wire_vectors.json"
EXPECTATIONS = DRAFT / "vote_wire_native_expectations.json"
ADAPTER = DRAFT / "comet_vote_wire_test.go.txt"
FLAGS = ("timestampAccepted", "marshalAttempted", "panicked", "blockIdIsZero", "blockIdComplete")
ROW_KEYS = {"id", "wireHex", *FLAGS}
HEX = re.compile(r"(?:[a-f0-9]{2})+")
DOMAIN = re.compile(r"etna-[A-Za-z0-9_-]{43}")
HELPERS = ("run_comet_signed.py", "run_comet_bootstrap.py", "run_comet.py", "run_baseline.py",
           "leased_execution.py", "comet_boundary_common.py", "run_isolated.py",
           "boundary_scope.py", "current_spec.py")
MANIFEST = ROOT / "manifests/comet.json"
GOGO_MANIFEST = DRAFT / "vote_wire_gogoproto_manifest.json"
GOGO = "github.com/cosmos/gogoproto"
VERSION = "v1.7.2"
SIGNED_MOD = ROOT / "comet_signed/go.mod"
SIGNED_SUM = ROOT / "comet_signed/go.sum"
SIGNED_PINS = ROOT / "comet_signed/pins.json"
COMET_PINS = ROOT / "comet-pins.json"


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def encoded(data):
    return (json.dumps(data, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n").encode()


def parse_json(raw):
    def unique(pairs):
        out = {}
        for key, value in pairs:
            if key in out:
                raise ValueError("duplicate JSON key: " + key)
            out[key] = value
        return out

    def reject(value):
        raise ValueError("non-finite number: " + value)

    return json.loads(raw.decode("utf-8"), object_pairs_hook=unique, parse_constant=reject)


def same(actual, expected, label):
    # Canonical JSON retains bool/int/float distinctions, including in nested rows.
    if encoded(actual) != encoded(expected):
        raise ValueError("mismatch in " + label)


def selected_indices(corpus, ids):
    names = [v["id"] for v in corpus["vectors"]]
    if (not names or any(type(n) is not str or not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", n)
                         for n in names) or len(names) != len(set(names))):
        raise ValueError("invalid or repeated vector id")
    if ids is None:
        return list(range(len(names)))
    if type(ids) not in (list, tuple) or not ids:
        raise ValueError("expected a nonempty id selection")
    selected = [i for i, name in enumerate(names) if name in ids]
    if [names[i] for i in selected] != list(ids):
        raise ValueError("unknown, duplicate or out-of-order id selection")
    return selected


def _public_input(row):
    data = {}
    for key, low, high in (("type", -(1 << 31), 1 << 31), ("round", -(1 << 31), 1 << 31),
                           ("total", 0, 1 << 32), ("nanos", -(1 << 31), 1 << 31)):
        value = row.get(key)
        if type(value) is not int or not low <= value < high:
            raise ValueError("wrong raw integer: " + key)
        data[key] = value
    for key in ("height", "seconds"):
        value = row.get(key)
        if (type(value) is not str or not re.fullmatch(r"(?:0|-?[1-9][0-9]{0,18})", value)
                or not -(1 << 63) <= int(value) < (1 << 63)):
            raise ValueError("wrong raw int64 string: " + key)
        data[key] = value
    for key, backing in (("hashHex", "hashBacking"), ("partsHashHex", "partsHashBacking")):
        value = row.get(key)
        if type(value) is not str or not re.fullmatch(r"(?:[0-9a-f]{64})?", value):
            raise ValueError("wrong raw hash: " + key)
        data[key] = value
        if backing in row:
            if value or row[backing] != "nonnil-empty":
                raise ValueError("invalid empty slice representation")
            data[backing] = "nonnil-empty"
    return data


def project_inputs(corpus, ids=None) -> dict:
    """Build the complete and exclusive JSON input made available to Go."""
    if type(corpus["chainId"]) is not str or not DOMAIN.fullmatch(corpus["chainId"]):
        raise ValueError("invalid vote domain")
    rows = []
    for i in selected_indices(corpus, ids):
        vector = corpus["vectors"][i]
        rows.append({"id": vector["id"], "input": _public_input(vector["input"])})
    return {"schema": "etna-vote-wire-inputs-1", "chainId": corpus["chainId"], "rows": rows}


def validate_observations(corpus, expectations, rows, ids=None) -> dict:
    indices = selected_indices(corpus, ids)
    vectors, expected = corpus["vectors"], expectations["rows"]
    if (type(expected) is not list or len(expected) != len(vectors)
            or type(rows) is not list or len(rows) != len(indices)):
        raise ValueError("wrong native row count")
    for i, row in zip(indices, rows):
        vector, oracle = vectors[i], expected[i]
        if (type(row) is not dict or set(row) != ROW_KEYS or type(row["id"]) is not str
                or any(type(row[key]) is not bool for key in FLAGS)
                or not (row["wireHex"] is None or type(row["wireHex"]) is str)):
            raise ValueError("wrong native observation fields or types")
        if type(oracle) is not dict or set(oracle) != ROW_KEYS or oracle["id"] != vector["id"]:
            raise ValueError("misbound native expectation")
        if any(type(oracle[key]) is not bool for key in FLAGS):
            raise ValueError("invalid native expectation flags")
        literal = oracle["wireHex"]
        if literal is not None:
            if literal != f"/vectors/{i}/wireHex":
                raise ValueError("wire pointer must refer to its own vector")
            literal = vector["wireHex"]
            if type(literal) is not str or not HEX.fullmatch(literal):
                raise ValueError("invalid literal wire bytes")
        same(row, oracle | {"wireHex": literal}, "actual native observation " + vector["id"])
    return {"observations": rows}


def collect_native(raw, returncode, corpus, expectations, ids=None) -> dict:
    """Consume the exact ordered Go 1.27 test2json stream, including terminals."""
    if type(raw) is not bytes or type(returncode) is not int or returncode != 0 or not raw.endswith(b"\n"):
        raise ValueError("wrong native capture or return code")
    lines = iter(raw[:-1].split(b"\n"))

    def event(action, test=None, *, output=False, frame=False):
        raw_line = next(lines, None)
        if raw_line is None:
            raise ValueError("missing Go event")
        row = parse_json(raw_line)
        keys = {"Time", "Action", "Package"}
        if test is not None:
            keys.add("Test")
        if output:
            keys.add("Output")
        if frame:
            keys.add("OutputType")
        if action == "pass":
            keys.add("Elapsed")
        if (type(row) is not dict or set(row) != keys or row["Action"] != action
                or row["Package"] != PACKAGE or row.get("Test") != test
                or type(row["Time"]) is not str
                or not re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{1,9})?(?:Z|[+-]\d\d:\d\d)", row["Time"])
                or (frame and row["OutputType"] != "frame")):
            raise ValueError("unexpected or misordered Go event for " + str(test))
        if action == "pass" and (type(row["Elapsed"]) not in (int, float)
                                 or not math.isfinite(row["Elapsed"]) or row["Elapsed"] < 0):
            raise ValueError("invalid Go elapsed time")
        if output:
            if type(row["Output"]) is not str or len(row["Output"].encode()) > 1024:
                raise ValueError("unexpected Go output fragment")
            return row["Output"]

    def frame_line(test, pattern):
        if not re.fullmatch(pattern, event("output", test, output=True, frame=True)):
            raise ValueError("wrong Go output frame")

    def begin(test):
        event("run", test)
        frame_line(test, re.escape("=== RUN   " + test + "\n"))

    def finish(test):
        frame_line(test, re.escape("--- PASS: " + test) + r" \([0-9]+(?:\.[0-9]+)?s\)\n")
        event("pass", test)

    rows = []
    event("start")
    begin(PARENT)
    for i in selected_indices(corpus, ids):
        test = PARENT + "/" + corpus["vectors"][i]["id"]
        begin(test)
        text = event("output", test, output=True)
        match = re.fullmatch(r"    vote_wire_test\.go:[1-9][0-9]*: receipt=(\{[^\r\n]+\})\n", text)
        if not match:
            raise ValueError("missing native observation for " + test)
        rows.append(parse_json(match[1].encode()))
        finish(test)
    finish(PARENT)
    frame_line(None, "PASS\n")
    if not re.fullmatch(re.escape("ok  \t" + PACKAGE + "\t") + r"[0-9]+(?:\.[0-9]+)?s\n",
                        event("output", output=True)):
        raise ValueError("invalid Go package status")
    event("pass")
    if next(lines, None) is not None:
        raise ValueError("trailing event or data")
    return validate_observations(corpus, expectations, rows, ids)


def native_helpers():
    # Import native machinery only for an explicit CLI run. Pure receipt consumers
    # have no dependency on a Go SDK, a local source tree or historical fixtures.
    sys.path.insert(0, str(ROOT))
    try:
        import comet_boundary_common
        return comet_boundary_common
    finally:
        sys.path.pop(0)


class StockInputs:
    """Authoritative immutable data used by staging, execution and readback."""

    def __init__(self, common):
        self.profile = parse_json(PROFILE.read_bytes())
        pinned_files = (DRAFT / "quorum_source.json", CORPUS, EXPECTATIONS, MANIFEST,
                        COMET_PINS, SIGNED_PINS, SIGNED_MOD, SIGNED_SUM, GOGO_MANIFEST)
        pins = self.profile["files"]
        same(sorted(pins), sorted(str(p.relative_to(REPO)) for p in pinned_files), "profile file set")
        self.watched = (*pinned_files, PROFILE, ADAPTER, DRAFT / "vote_wire.py", Path(__file__).resolve(),
                        *(ROOT / name for name in HELPERS), common.COMET.EXECUTION_PATH)
        self.initial = common.inventory(self.watched)
        for p in pinned_files:
            same(self.initial[str(p)]["sha256"], pins[str(p.relative_to(REPO))], "profile hash " + p.name)

        self.manifest = parse_json(MANIFEST.read_bytes())
        self.gogo = parse_json(GOGO_MANIFEST.read_bytes())
        self.corpus = parse_json(CORPUS.read_bytes())
        self.expectations = parse_json(EXPECTATIONS.read_bytes())
        signed = parse_json(SIGNED_PINS.read_bytes())
        comet = parse_json(COMET_PINS.read_bytes())["source"]
        self.tools = signed["goToolSha256"]
        self.commit = self.profile["upstream"]
        same(signed["source"], comet, "stock source pins")
        same(comet["commit"], self.commit, "stock source commit")
        same(comet["manifestSha256"], self.initial[str(MANIFEST)]["sha256"], "stock manifest hash")
        same(self.corpus["design"], self.profile["design"], "corpus source")
        same(self.expectations["design"], self.profile["design"], "native expectation source")
        same(self.corpus["comet"], self.commit, "corpus stock version")
        same(self.expectations["comet"], self.commit, "native expectation stock version")
        same(self.profile["expectedVectors"], len(self.corpus["vectors"]), "vector count")
        same(len(self.corpus["vectors"]), 29, "selected corpus")
        same(comet["files"], len(self.manifest["files"]), "stock manifest count")
        same(comet["files"], self.profile["sourceFiles"], "stock source file count")
        same(sorted(self.tools), sorted(["VERSION", "bin/go", *("pkg/tool/linux_amd64/" + name
             for name in ("asm", "compile", "link", "vet"))]), "stock SDK file set")
        gogo = self.profile["gogoproto"]
        for key in ("module", "version", "h1", "archiveSha256", "fileCount"):
            same(self.gogo[key], gogo[key], "dependency manifest " + key)
        same([gogo["module"], gogo["version"], gogo["fileCount"]], [GOGO, VERSION, 787], "dependency profile")
        same(len(self.gogo["files"]), 787, "dependency manifest count")
        self.adapter = ADAPTER.read_bytes()
        original = SIGNED_MOD.read_bytes()
        replacement = b"module example.org/etna-comet-signed\n"
        if not original.startswith(replacement) or original.count(replacement) != 1:
            raise ValueError("unexpected dependency module declaration")
        self.module = b"module " + PACKAGE.encode() + b"\n" + original[len(replacement):]
        self.sums = SIGNED_SUM.read_bytes()
        if f"{GOGO} {VERSION} {gogo['h1']}".encode() not in self.sums.splitlines():
            raise ValueError("gogoproto h1 missing from pinned go.sum")
        common.require_inventory(self.watched, self.initial, "loaded vote wire inputs")

    def stage_files(self, ids):
        return {
            "inputs/inputs.json": encoded(project_inputs(self.corpus, ids)),
            "inputs/vote_wire_test.go": self.adapter,
            "inputs/go.mod": self.module,
            "inputs/go.sum": self.sums,
            "modfiles/go.mod": self.module + b"\nreplace github.com/cometbft/cometbft => /tmp/upstream\n",
            "modfiles/go.sum": self.sums,
        }


def _tree(common, root, files, *, verify_content):
    """Fingerprint every regular file's physical identity against the exact manifest set."""
    seen = {}
    for path in root.rglob("*"):
        info = path.lstat()
        if stat.S_ISDIR(info.st_mode):
            continue
        name = path.relative_to(root).as_posix()
        if name not in files:
            raise ValueError("unexpected snapshot file: " + name)
        seen[name] = common.identity(path)
        if verify_content:
            data = path.read_bytes()
            same({"bytes": len(data), "sha256": digest(data)}, files[name], "dependency file " + name)
    if seen.keys() != files.keys():
        raise ValueError("snapshot missing files")
    return digest(encoded(seen))


def custody(common, args, inputs, lock_id):
    """Re-read source manifests, tool bytes, code, and physical inputs under the lease."""
    common.require_inventory(inputs.watched, inputs.initial, "frozen inputs and runner dependencies")
    tools = common.inventory(args.go_root / name for name in inputs.tools)
    for name, expected in inputs.tools.items():
        same(tools[str(args.go_root / name)]["sha256"], expected, "Go tool " + name)
    source = common.COMET.verify_snapshot(args.source, inputs.manifest, inputs.commit)
    comet_ids = _tree(common, args.source, inputs.manifest["files"], verify_content=False)
    gogo_dir = args.module_cache / (GOGO + "@" + VERSION)
    cached_mod = args.module_cache / "cache/download" / GOGO / "@v" / (VERSION + ".mod")
    if gogo_dir.resolve(strict=True) != gogo_dir or cached_mod.resolve(strict=True) != cached_mod:
        raise ValueError("gogoproto cache path is aliased")
    gogo_ids = _tree(common, gogo_dir, inputs.gogo["files"], verify_content=True)
    cached = common.inventory([cached_mod])[str(cached_mod)]
    same(cached["sha256"], inputs.gogo["files"]["go.mod"]["sha256"], "cached gogoproto .mod")
    same(common.identity(args.build_lock), lock_id, "shared cache lock")
    directories = {str(path): common.identity(path, directory=True)
                   for path in (args.source, args.go_root, args.module_cache, args.build_cache, gogo_dir)}
    # New content in the writable cache can alter its subdirectory link count.
    del directories[str(args.build_cache)]["links"]
    return dict(source=source, cometFileIdentitiesSha256=comet_ids,
                gogoproto=dict(module=GOGO, version=VERSION, h1=inputs.gogo["h1"],
                               files=inputs.gogo["fileCount"], fileIdentitiesSha256=gogo_ids,
                               cachedModule={str(cached_mod): cached}),
                directories=directories, sharedCacheLock={str(args.build_lock): lock_id},
                tools=tools, watched=inputs.initial)


def stage_inventory(common, directory, files):
    identities = {}
    for folder in ("inputs", "modfiles"):
        current = directory / folder
        common.identity(current, directory=True)
        expected = {Path(name).name for name in files if Path(name).parent.name == folder}
        if {p.name for p in current.iterdir()} != expected:
            raise ValueError("unexpected or missing staged input in " + folder)
    for name, data in files.items():
        path = directory / name
        identities[name] = common.inventory([path])[str(path)]
        same(identities[name]["sha256"], digest(data), "staged input " + name)
    return identities


def _filter(smoke):
    return "^" + PARENT + "$" + ("/^" + SMOKE + "$" if smoke else "")


def read_record(common, path):
    common.identity(path)
    return parse_json(path.read_bytes())


def verify_capture(common, args, inputs, directory, smoke, current):
    """Reconstruct both the execution metadata and the actual observations from retained files."""
    common.identity(directory, directory=True)
    record = read_record(common, directory / "execution.json")
    common.identity(directory / "combined.log")
    raw = (directory / "combined.log").read_bytes()
    ids = [SMOKE] if smoke else None
    command = common.isolation_command(None, directory, args.source, args, _filter(smoke))
    supervisor = record.get("supervisorCommand")
    if (type(supervisor) is not list or len(supervisor) != 8 + len(command)
            or supervisor[:4] != [sys.executable, "-B", str(common.LEASED.PATH), "--_supervise_leased"]
            or any(type(s) is not str or not re.fullmatch(r"[1-9][0-9]*", s) for s in supervisor[4:6])
            or int(supervisor[4]) < 3 or supervisor[6:] != ["110", str(ROOT), *command]):
        raise ValueError("wrong leased supervisor invocation")
    seconds = record.get("seconds")
    if type(seconds) not in (int, float) or not math.isfinite(seconds) or seconds < 0:
        raise ValueError("invalid elapsed time")
    observed = collect_native(raw, record.get("returncode"), inputs.corpus, inputs.expectations, ids)
    staged = stage_inventory(common, directory, inputs.stage_files(ids))
    expected = dict(schema="etna-vote-wire-execution-1", phase="smoke" if smoke else "full",
                    package=PACKAGE, parent=PARENT, filter=_filter(smoke), command=command,
                    supervisorCommand=supervisor, supervisorReturncode=common.LEASED.LEASED_EXIT_CODES[0],
                    returncode=0, timedOut=False, seconds=seconds, streamsCombined=True,
                    outputDecoding="utf-8-errors-replace", combinedOutputSha256=digest(raw),
                    before=current, after=current, stagedBefore=staged, stagedAfter=staged,
                    observations=observed["observations"])
    same(record, expected, "retained unsigned execution")
    return dict(schema="etna-vote-wire-result-1", phase=expected["phase"], status="PASS",
                executionSha256=digest((directory / "execution.json").read_bytes()),
                combinedOutputSha256=digest(raw), cases=len(observed["observations"]))


def require_smoke(common, args, inputs, current):
    directory = args.smoke_output
    checked = verify_capture(common, args, inputs, directory, True, current)
    same(read_record(common, directory / "summary.json"), checked, "retained smoke summary")
    return dict(path=str(directory), **checked)


@contextmanager
def build_lease(common, path):
    identity = common.identity(path)
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC)
    try:
        if fd < 3:
            duplicate = fcntl.fcntl(fd, fcntl.F_DUPFD_CLOEXEC, 3)
            os.close(fd)
            fd = duplicate
        info = os.fstat(fd)
        opened = dict(device=info.st_dev, inode=info.st_ino, mode=stat.S_IMODE(info.st_mode),
                      links=info.st_nlink)
        same(opened, identity, "opened cache lease")
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        same(common.identity(path), identity, "leased physical file")
        yield fd, identity
    finally:
        os.close(fd)


def check_cancelled(cancelled):
    if cancelled():
        raise ValueError("unsigned native execution cancelled")


def run_trial(common, args, inputs, fd, lock_id, cancelled):
    before = custody(common, args, inputs, lock_id)
    check_cancelled(cancelled)
    smoke_receipt = None if args.smoke else require_smoke(common, args, inputs, before)
    ids = [SMOKE] if args.smoke else None
    files = inputs.stage_files(ids)
    for name in ("inputs", "modfiles", "work/build"):
        (args.output / name).mkdir(parents=True)
    for name, data in files.items():
        (args.output / name).write_bytes(data)
    staged = stage_inventory(common, args.output, files)
    command = common.isolation_command(None, args.output, args.source, args, _filter(args.smoke))
    check_cancelled(cancelled)
    result = common.LEASED.execute(command, ROOT, 110, lease_fd=fd, cancellation=cancelled)
    raw = result["output"].encode("utf-8")
    (args.output / "combined.log").write_bytes(raw)
    record = dict(schema="etna-vote-wire-execution-1", phase="smoke" if args.smoke else "full",
                  package=PACKAGE, parent=PARENT, filter=_filter(args.smoke), command=result["argv"],
                  supervisorCommand=result["supervisor_argv"], supervisorReturncode=result["supervisor_returncode"],
                  returncode=result["returncode"], timedOut=result["timeout"], seconds=result["seconds"],
                  streamsCombined=True, outputDecoding="utf-8-errors-replace", combinedOutputSha256=digest(raw),
                  before=before, stagedBefore=staged)
    capture = args.output / "execution.json"
    capture.write_bytes(encoded(record))
    after = custody(common, args, inputs, lock_id)
    record.update(after=after, stagedAfter=stage_inventory(common, args.output, files))
    capture.write_bytes(encoded(record))
    same(before, after, "physical dependencies before/after")
    same(staged, record["stagedAfter"], "staged inputs before/after")
    check_cancelled(cancelled)
    if result["timeout"] is not False or result["supervisor_returncode"] != common.LEASED.LEASED_EXIT_CODES[0]:
        raise ValueError("isolated execution or descendant supervision failed")
    record.update(collect_native(raw, record["returncode"], inputs.corpus, inputs.expectations, ids))
    capture.write_bytes(encoded(record))
    summary = verify_capture(common, args, inputs, args.output, args.smoke, after)
    if smoke_receipt is not None:
        same(require_smoke(common, args, inputs, after), smoke_receipt, "actual smoke capture before/after")
        summary["smoke"] = smoke_receipt
    check_cancelled(cancelled)
    (args.output / "summary.json").write_bytes(encoded(summary))
    same(read_record(common, args.output / "summary.json"), summary, "written native summary")
    check_cancelled(cancelled)
    return summary


def overlaps(first, second):
    return first == second or first in second.parents or second in first.parents


def run(args):
    common = native_helpers()
    inputs = StockInputs(common)
    if args.timeout != 100:
        raise ValueError("expected fixed native 90 / isolation 100 / supervisor 110 second bounds")
    if args.output.is_symlink() or args.build_lock.absolute() != args.build_lock.resolve(strict=True):
        raise ValueError("aliased output or shared cache lock")
    args.build_lock = args.build_lock.resolve(strict=True)
    if args.smoke_output is not None:
        if args.smoke_output.absolute() != args.smoke_output.resolve(strict=True):
            raise ValueError("aliased smoke capture")
        args.smoke_output = args.smoke_output.resolve(strict=True)
    common.COMET.validate_layout(args, inputs.watched)
    if any(path.is_relative_to(mount) for path in inputs.watched
           for mount in (args.source, args.module_cache, args.go_root)):
        raise ValueError("native read mount would expose non-projected campaign inputs")
    if any(overlaps(args.build_lock, path) for path in
           (args.output, args.source, args.go_root, args.module_cache, args.build_cache, ROOT.parent)):
        raise ValueError("shared lock must be a separate physical file")
    if args.smoke_output is not None and any(overlaps(args.smoke_output, path) for path in
           (args.output, args.source, args.go_root, args.module_cache, args.build_cache, args.build_lock)):
        raise ValueError("smoke capture overlaps a build input or output")
    args.output.mkdir(mode=0o700, parents=True)
    with common.LEASED.cancellation_scope() as cancelled:
        try:
            with build_lease(common, args.build_lock) as (fd, lock_id):
                return run_trial(common, args, inputs, fd, lock_id, cancelled)
        except (OSError, ValueError, KeyError, TypeError) as error:
            # A partial or failed execution must never leave a successful summary.
            (args.output / "summary.json").write_bytes(encoded(dict(status="INCONCLUSIVE", error=str(error))))
            raise


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("source", "go-root", "module-cache", "build-cache", "build-lock", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--timeout", type=int, default=100)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--smoke", action="store_true")
    mode.add_argument("--smoke-output", type=Path)
    args = parser.parse_args(argv)
    try:
        result = run(args)
    except (OSError, KeyError, TypeError, ValueError) as error:
        print("INCONCLUSIVE:", error, file=sys.stderr)
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
