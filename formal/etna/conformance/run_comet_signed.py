#!/usr/bin/env python3
"""Exercise pinned stock Comet signed admission with public inputs and offline isolation."""
import argparse
import base64
from contextlib import contextmanager
import importlib.util
import json
import math
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
FIXTURE = ROOT / "comet_signed"
spec = importlib.util.spec_from_file_location("etna_signed_bootstrap", ROOT / "run_comet_bootstrap.py")
BOOT = importlib.util.module_from_spec(spec)
spec.loader.exec_module(BOOT)
COMET = BOOT.COMET
require_stable = BOOT.require_stable
CURRENT_SPEC = COMET.load_module("etna_current_spec", ROOT / "current_spec.py")

PACKAGE = "example.org/etna-comet-signed"
PARENT = "TestCometSigned"
SMOKE = "precommit_a"
FAULT_LEAF = "commit-exact-two-thirds"
FAULT_DIAGNOSTIC = (
    "signed-commit-threshold id=commit-exact-two-thirds "
    "expected=insufficient-power got=accept wantGot=2 wantNeeded=2"
)
FAULT_PATH = "types/validation.go"
GO_OUTPUT_BUFFER = 1024
FAULT_FUNCTION = b"func verifyCommitSingle("
FAULT_BEFORE = (
    b"\tif got, needed := talliedVotingPower, votingPowerNeeded; got <= needed {\n"
    b"\t\treturn ErrNotEnoughVotingPowerSigned{Got: got, Needed: needed}\n"
    b"\t}\n\n\treturn nil\n}\n\nfunc verifyBasicValsAndCommit("
)
FAULT_AFTER = FAULT_BEFORE.replace(b"got <= needed", b"got < needed")
BUILD_FILES = ("go.mod", "go.sum", "public-votes.json", "signed_test.go")
GO_MOD_REPLACEMENT = b"\nreplace github.com/cometbft/cometbft => /tmp/upstream\n"
PROVENANCE = {
    "commit": "89f419915de4b73bb57c53bf970f6dea9e8e8c8c",
    "path": "testdata/etna_vectors/vectors.json",
    "gitBlob": "e069e2930143cbaf126d46532a96179764ec0ab6",
    "sha256": "85d9df59bbc1709950be8cd8b248a3871523229afabd3d4e65b8027d6e4529de",
}
DEPLOYMENT = {"l1_chain_id": "1", "l2_chain_id": "167001", "inbox": "0x" + "11" * 20,
              "registry": "0x" + "22" * 20}
CASES = (
    "precommit_a", "precommit_nil", "precommit_b", "precommit_a_late", "prevote_a_r1",
    "prevote_b_r1", "prevote_b_r2", "precommit_b_r1", "gen1_precommit_a",
    "gen1_precommit_b", "gen2_precommit_a", "gen2_precommit_b", "other_inbox_precommit_b",
    "partial_block_id", "max_values", "precommit_b_h1001", "hash_only_block_id",
    "zero_timestamp", "negative_timestamp", "min_timestamp", "max_timestamp_seconds",
    "precommit_a_backdated", "precommit_b_backdated",
)
PAIRS = (
    "precommit_conflict", "precommit_vs_nil", "prevote_conflict_round_1", "same_block_later_time",
    "different_round", "different_type", "generation_1_conflict", "historical_generation_conflict",
    "future_generation", "other_deployment", "different_round_conflicting_blocks",
    "different_generation", "different_height", "backdated_conflict",
)
VOTE_BOUNDS = {
    "voteType": (1, 2), "height": (1, (1 << 63) - 1), "round": (0, (1 << 31) - 1),
    "partsTotal": (0, (1 << 32) - 1), "timestampSeconds": (-62135596800, 253402300799),
    "timestampSecondsU64": (0, (1 << 64) - 1), "timestampNanos": (0, 999999999),
    "generation": (0, (1 << 48) - 1),
}


def reject_number(_):
    raise ValueError("unexpected float or non-finite JSON value")


def strict_json(raw):
    return json.loads(raw.decode("utf-8"), object_pairs_hook=COMET.EXECUTION.unique_object,
                      parse_float=reject_number, parse_constant=reject_number)


def fields(value, wanted, label):
    if type(value) is not dict or set(value) != set(wanted):
        raise ValueError("wrong fields in " + label)


def match(pattern, value, label):
    if type(value) is not str or not re.fullmatch(pattern, value):
        raise ValueError("wrong " + label)


def decimal(value, lower, upper):
    match(r"0|-?[1-9][0-9]{0,19}", value, "canonical decimal string")
    if not lower <= int(value) <= upper:
        raise ValueError("decimal value outside its bounds")
    return int(value)


def hex_field(value, size=None):
    allowed = r"0x(?:[0-9a-f]{2})+" if size is None else r"0x[0-9a-f]{" + str(size * 2) + "}"
    match(allowed, value, "public hex field")
    return bytes.fromhex(value[2:])


def named_rows(value, names, label):
    if type(value) is not list or any(type(item) is not dict for item in value):
        raise ValueError("wrong " + label + " records")
    if tuple(item.get("name") for item in value) != tuple(names):
        raise ValueError("missing, duplicate, reordered or unexpected " + label + " identity")


def load_projection(raw):
    data = strict_json(raw)
    fields(data, ("schema", "provenance", "deployment", "voteKey", "voteCases",
                  "votePairs", "chainDomains", "spectators"), "projection")
    if (data["schema"] != "etna-public-votes-1" or data["provenance"] != PROVENANCE
            or data["deployment"] != DEPLOYMENT):
        raise ValueError("unexpected public provenance or deployment")
    fields(data["voteKey"], ("public_key", "signer"), "vote key")
    match(r"0x0[23][0-9a-f]{64}", data["voteKey"]["public_key"], "compressed SEC1 vote key")
    hex_field(data["voteKey"]["signer"], 20)
    named_rows(data["spectators"], ("a2", "a3", "a4"), "spectator")
    points = {data["voteKey"]["public_key"]}
    addresses = {data["voteKey"]["signer"]}
    for spectator in data["spectators"]:
        fields(spectator, ("name", "public_key", "ck_addr"), "spectator")
        match(r"0x0[23][0-9a-f]{64}", spectator["public_key"], "compressed SEC1 spectator key")
        hex_field(spectator["ck_addr"], 20)
        points.add(spectator["public_key"])
        addresses.add(spectator["ck_addr"])
    if len(points) != 4 or len(addresses) != 4:
        raise ValueError("duplicate vote/spectator point or address")

    domains = data["chainDomains"]
    if type(domains) is not list or len(domains) != 5:
        raise ValueError("five domain records are required")
    expected_domains = [(DEPLOYMENT["inbox"], value) for value in ("0", "1", "2", "281474976710655")]
    expected_domains.append(("0x" + "33" * 20, "0"))
    domain_generations = {}
    for item, identity in zip(domains, expected_domains):
        fields(item, ("l1_chain_id", "l2_chain_id", "inbox", "generation", "preimage",
                      "chain_domain", "chain_id"), "domain")
        if ((item["inbox"], item["generation"]) != identity
                or any(item[chain] != DEPLOYMENT[chain] for chain in ("l1_chain_id", "l2_chain_id"))):
            raise ValueError("unexpected domain identity")
        digest = hex_field(item["chain_domain"], 32)
        if item["chain_id"] != "etna-" + base64.urlsafe_b64encode(digest).decode().rstrip("="):
            raise ValueError("domain digest and chain ID disagree")
        preimage = hex_field(item["preimage"], 160)
        expected_preimage = b"ETNA_COMET_DOMAIN_V1".ljust(32, b"\0")
        expected_preimage += int(item["l1_chain_id"]).to_bytes(32, "big")
        expected_preimage += int(item["l2_chain_id"]).to_bytes(32, "big")
        expected_preimage += hex_field(item["inbox"], 20).rjust(32, b"\0")
        expected_preimage += int(item["generation"]).to_bytes(32, "big")
        if preimage != expected_preimage or item["chain_id"] in domain_generations:
            raise ValueError("wrong domain preimage or duplicate chain ID")
        domain_generations[item["chain_id"]] = item["generation"]

    named_rows(data["voteCases"], CASES, "signed vote")
    for row in data["voteCases"]:
        fields(row, ("name", "chain_id", "sign_bytes", "signature", "vote"), "vote case")
        hex_field(row["sign_bytes"])
        signature = hex_field(row["signature"], 65)
        if signature[64] not in (0, 1):
            raise ValueError("signature recovery byte must remain 0 or 1")
        vote = row["vote"]
        fields(vote, (*VOTE_BOUNDS, "blockHash", "partsHash"), "vote")
        hex_field(vote["blockHash"], 32)
        hex_field(vote["partsHash"], 32)
        numbers = {name: decimal(vote[name], *bounds) for name, bounds in VOTE_BOUNDS.items()}
        if numbers["timestampSeconds"] % (1 << 64) != numbers["timestampSecondsU64"]:
            raise ValueError("signed timestamp and uint64 bit pattern disagree")
        match(r"etna-[A-Za-z0-9_-]{43}", row["chain_id"], "vote chain ID")
        if domain_generations.get(row["chain_id"]) != vote["generation"]:
            raise ValueError("vote generation and chain ID disagree")
    named_rows(data["votePairs"], PAIRS, "vote pair")
    for pair in data["votePairs"]:
        fields(pair, ("name", "a", "b", "double_sign", "reason", "current_generation"), "vote pair")
        if (pair["a"] not in CASES or pair["b"] not in CASES or pair["a"] == pair["b"]
                or type(pair["double_sign"]) is not bool):
            raise ValueError("wrong pair reference or result shape")
        match(r"[a-z]+(?:_[a-z]+)*", pair["reason"], "vote pair reason")
        decimal(pair["current_generation"], *VOTE_BOUNDS["generation"])
    return data


def frozen_expectations(projection, pins):
    """Build wire receipts from published literals, and non-wire receipts from the pins."""
    expected = {}
    for case in projection["voteCases"]:
        name = case["name"]
        oracle = pins["wire"][name]
        fields(oracle, ("bytes", "validateBasic"), "wire oracle")
        if type(oracle["bytes"]) is not int or len(hex_field(case["sign_bytes"])) != oracle["bytes"]:
            raise ValueError("incorrect wire oracle byte count for " + name)
        vote = case["vote"]
        expected[name] = dict(address=projection["voteKey"]["signer"], key=projection["voteKey"]["public_key"],
                              height=int(vote["height"]), round=int(vote["round"]),
                              type=int(vote["voteType"]), index=0,
                              chain=case["chain_id"], signBytes=case["sign_bytes"], signature=case["signature"],
                              validateBasic=oracle["validateBasic"], verify="accept")
    if set(expected) != set(pins["wire"]) or set(expected) & pins["native"].keys():
        raise ValueError("missing or duplicate frozen outcome identity")
    expected.update(pins["native"])
    if tuple(expected) != tuple(pins["expectedLeaves"]):
        raise ValueError("frozen execution identity/order mismatch")
    return expected


def parse_events(raw):
    rows = []
    for line in raw.splitlines():
        # Go reports fractional Elapsed values. Allow them on lifecycle metadata.
        try:
            value = json.loads(line.decode("utf-8"), object_pairs_hook=COMET.EXECUTION.unique_object,
                               parse_constant=reject_number)
        except (ValueError, UnicodeError) as error:
            raise ValueError("invalid Go JSON stream") from error
        if (type(value) is not dict or value.get("Package") != PACKAGE
                or set(value) - {"Time", "Elapsed", "Action", "Package", "Test", "Output", "OutputType"}
                or ("Time" in value and type(value["Time"]) is not str)):
            raise ValueError("unexpected Go event fields or package")
        if "Elapsed" in value:
            elapsed = value["Elapsed"]
            if (value.get("Action") not in ("pass", "fail") or type(elapsed) not in (int, float)
                    or elapsed < 0 or (type(elapsed) is float and not math.isfinite(elapsed))):
                raise ValueError("invalid native Elapsed metadata")
        rows.append(value)
    return iter(rows)


def require_go_outcomes(raw, returncode, phase, expected):
    """Require ordered exact lifecycle, independent observations and one designated fault."""
    if phase not in ("smoke", "normal", "mutant", "restored"):
        raise ValueError("unknown signed execution phase")
    fault = phase == "mutant"
    outcome = "fail" if fault else "pass"
    if returncode != int(fault):
        raise ValueError("wrong native return code")
    rows = parse_events(raw)

    def event(action, identity, has_output, kind):
        row = next(rows, {})
        if (row.get("Action") != action or ("Test" in row) != (identity is not None)
                or row.get("Test") != identity or ("Output" in row) != has_output):
            raise ValueError("missing, extra or wrongly ordered native event: " + str(identity))
        if ("OutputType" in row) != (kind is not None) or row.get("OutputType") != kind:
            raise ValueError("wrong native OutputType")
        if has_output:
            output = row["Output"]
            if type(output) is not str:
                raise ValueError("wrong native output type")
            if kind is None and len(output.encode("utf-8")) > GO_OUTPUT_BUFFER:
                raise ValueError("ordinary native output exceeds the Go buffer")
        return row.get("Output")

    def require_event(action, identity=None, pattern=None, kind=None, exact=None):
        payload = event(action, identity, pattern is not None, kind)
        if pattern is None:
            return
        if exact is not None:
            # The pinned test2json splits long ASCII output lines at 1024 bytes.
            # Only the expected receipt may span consecutive same-leaf output events.
            fragments = [payload]
            while not fragments[-1].endswith("\n"):
                if len(fragments[-1].encode()) != GO_OUTPUT_BUFFER or len(fragments) == 4:
                    raise ValueError("truncated or excessive native receipt: " + str(identity))
                fragments.append(event("output", identity, True, kind))
            payload = "".join(fragments)
        actual = re.fullmatch(pattern, payload)
        if actual is None:
            raise ValueError("unexpected native output for " + str(identity))
        if exact is not None:
            receipt = strict_json(actual[1].encode())
            # Canonical JSON comparison distinguishes true from 1 and checks extra fields.
            if json.dumps(receipt, sort_keys=True) != json.dumps(exact, sort_keys=True):
                raise ValueError("wrong native observation for " + str(identity))

    typed_line = r"[ \t]+signed_test\.go:[1-9][0-9]*: "
    duration = r"[0-9]+(?:\.[0-9]+)?s"
    results = {}

    def frames_start(identity):
        require_event("run", identity)
        require_event("output", identity, re.escape("=== RUN   " + identity + "\n"), "frame")

    def frames_end(identity, result):
        require_event("output", identity, re.escape(f"--- {result.upper()}: {identity}") +
                      r" \(" + duration + r"\)\n", "frame")
        require_event(result, identity)

    require_event("start")
    frames_start(PARENT)
    for name, receipt in expected.items():
        identity = PARENT + "/" + name
        frames_start(identity)
        require_event("output", identity, typed_line + r"receipt=(.+)\n", exact=receipt)
        result = "pass"
        if fault and name == FAULT_LEAF:
            require_event("output", identity, typed_line + re.escape(FAULT_DIAGNOSTIC + "\n"), "error")
            result = "fail"
        frames_end(identity, result)
        results[identity] = result
    frames_end(PARENT, outcome)
    require_event("output", pattern=outcome.upper() + r"\n", kind="frame")
    prefix = ("FAIL\t" if fault else "ok  \t") + PACKAGE + "\t"
    require_event("output", pattern=re.escape(prefix) + duration + r"\n", kind="frame" if fault else None)
    require_event(outcome)
    if next(rows, None) is not None or list(results.values()).count("fail") != int(fault) or not results:
        raise ValueError("missing fault or extra native events")
    return results


def native_inputs():
    """Load stock inputs without choosing a workspace claim for dependent runners."""
    pins_path = FIXTURE / "pins.json"
    pins_raw = pins_path.read_bytes()
    pins = strict_json(pins_raw)
    manifest_path = ROOT / "manifests/comet.json"
    manifest_raw = manifest_path.read_bytes()
    source_pins = ROOT / "comet-pins.json"
    source = strict_json(source_pins.read_bytes())["source"]
    if (pins["schema"] != "etna-comet-signed-pins-1" or pins["source"] != source
            or COMET.digest(manifest_raw) != source["manifestSha256"]):
        raise ValueError("incorrect stock source pin or manifest identity")
    if set(pins["inputsSha256"]) != set(BUILD_FILES):
        raise ValueError("missing or extra native input pin")
    pinned = {FIXTURE / name: digest for name, digest in pins["inputsSha256"].items()}
    pinned[ROOT / "registry_public/registration.json"] = pins["registrationSha256"]
    pinned[ROOT / "spec_correspondence.json"] = pins["specCorrespondenceSha256"]
    require_stable(pinned, "pinned public/build/authority inputs")
    projection = load_projection((FIXTURE / "public-votes.json").read_bytes())
    registration = strict_json((ROOT / "registry_public/registration.json").read_bytes())
    matching = [row["key"] for row in registration["register_digests"] if row["name"] == "a1_owner_aa"]
    if matching != [projection["voteKey"]["public_key"]]:
        raise ValueError("vote key differs from frozen public registration")
    if {name: registration["source" + name[0].upper() + name[1:]]
            for name in ("commit", "path", "gitBlob", "sha256")} != PROVENANCE:
        raise ValueError("vote and registration source provenance differs")

    manifest = strict_json(manifest_raw)
    if len(manifest["files"]) != source["files"]:
        raise ValueError("source manifest count differs")
    watched = {path: COMET.digest(path.read_bytes()) for path in [
        Path(__file__), ROOT / "run_comet.py", ROOT / "run_comet_bootstrap.py",
        ROOT / "run_isolated.py", ROOT / "run_baseline.py", COMET.EXECUTION_PATH,
        ROOT / "COMET_SIGNED.md", ROOT.parent / "tests/test_comet_signed.py",
        manifest_path, source_pins,
    ]} | pinned | {pins_path: COMET.digest(pins_raw)}
    return pins, manifest, watched, frozen_expectations(projection, pins)


def inputs():
    """Retain the legacy single-SPEC interface for historical callers."""
    pins, manifest, watched, expected = native_inputs()
    authority_path = ROOT / "spec_authority.py"
    authority = COMET.load_module("etna_signed_spec", authority_path)
    ledger = authority.load_spec_correspondence(ROOT / "spec_correspondence.json")
    workspace_spec = ROOT.parents[2] / ledger["path"]
    raw = workspace_spec.read_bytes()
    correspondence = authority.verify_workspace_spec(raw, pins["specAuthority"], ledger)
    watched.update({authority_path: COMET.digest(authority_path.read_bytes()), workspace_spec: COMET.digest(raw)})
    return pins, manifest, watched, expected, correspondence


def campaign_inputs():
    pins, manifest, watched, expected = native_inputs()
    boundary, boundary_watch = CURRENT_SPEC.historical_workspace_receipt(
        ROOT.parents[2], "comet-signed", "public-votes", spec_commit=pins["specAuthority"]["commit"],
        implementation_commit=pins["source"]["commit"], manifest_sha256=pins["source"]["manifestSha256"],
        input_pins_sha256={"comet_signed/pins.json": watched[FIXTURE / "pins.json"]},
    )
    return pins, manifest, watched | boundary_watch, expected, boundary


@contextmanager
def private_source_fault(private, manifest, restoration):
    """Apply the threshold fault only while guarded by same-copy restoration."""
    path = private / FAULT_PATH
    original_mode = stat.S_IMODE(path.stat().st_mode)
    original = path.read_bytes()
    if (COMET.file_entry(original) != manifest["files"][FAULT_PATH]
            or original.count(FAULT_FUNCTION) != 1 or original.count(FAULT_BEFORE) != 1
            or original.index(FAULT_BEFORE) <= original.index(FAULT_FUNCTION)):
        raise ValueError("single verifier fault selector or original source differs")
    mutant = original.replace(FAULT_BEFORE, FAULT_AFTER, 1)
    changed = dict(manifest)
    changed["files"] = dict(manifest["files"])
    changed["files"][FAULT_PATH] = COMET.file_entry(mutant)

    applied = False
    writable = original_mode | stat.S_IWUSR
    try:
        path.chmod(writable)
        if path.write_bytes(mutant) != len(mutant):
            raise OSError("incomplete private source fault write")
        applied = True
        yield changed
    finally:
        try:
            if applied and path.read_bytes() != mutant:
                raise ValueError("private fault bytes drifted before restoration")
        finally:
            # Attempt to recover the original bytes and mode even when application
            # or the pre-restore readback raised an exception.
            try:
                path.chmod(writable)
                if path.write_bytes(original) != len(original):
                    raise OSError("incomplete private source restoration")
            finally:
                path.chmod(original_mode)
            restored = COMET.verify_snapshot(private, manifest, manifest["commit"])
            restored_mode = stat.S_IMODE(path.stat().st_mode)
            if restored_mode != original_mode:
                raise ValueError("private source mode drifted during restoration")
            write_json(restoration, restored | {"mode": format(restored_mode, "04o")})


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")


def isolation_command(trial, private, args, parent_filter):
    command = [sys.executable, "-B", str(ROOT / "run_isolated.py")]
    for source, target in ((trial / "inputs", "replay"), (private, "upstream"),
                           (trial / "modfiles", "modfiles"), (args.go_root, "go"),
                           (args.module_cache, "gomodcache")):
        command += ["--read-bind", f"{source}=/tmp/{target}"]
    for source, target in ((args.build_cache, "gocache"), (trial / "work", "output")):
        command += ["--write-bind", f"{source}=/tmp/{target}"]
    command += ["--cwd", "/tmp/replay", "--timeout", str(args.timeout)]
    environment = dict(GOROOT="/tmp/go", GOMODCACHE="/tmp/gomodcache", GOCACHE="/tmp/gocache",
                       GOPATH="/tmp/gopath", GOTMPDIR="/tmp/output/build", GOENV="off",
                       GOTOOLCHAIN="local", GOPROXY="off", GOSUMDB="off", GOVCS="*:off",
                       GOWORK="off", CGO_ENABLED="0", GOTELEMETRY="off", GOMAXPROCS="2")
    for name, value in environment.items():
        command += ["--env", f"{name}={value}"]
    command += ["--", "/tmp/go/bin/go", "test", "-json", "-count=1", "-parallel=1", "-p=2",
                "-mod=readonly", "-modfile=/tmp/modfiles/go.mod", "-timeout=90s",
                "-run=" + parent_filter, "."]
    return command


def effective_go_mod(pins):
    original = (FIXTURE / "go.mod").read_bytes()
    if COMET.digest(original) != pins["inputsSha256"]["go.mod"]:
        raise ValueError("original Go module input changed")
    return original + GO_MOD_REPLACEMENT


def expected_executed_inputs(pins):
    original = pins["inputsSha256"]
    return {f"inputs/{name}": original[name] for name in BUILD_FILES} | {
        "modfiles/go.mod": COMET.digest(effective_go_mod(pins)),
        "modfiles/go.sum": original["go.sum"],
    }


def require_executed_inputs(record, pins):
    expected = expected_executed_inputs(pins)
    if record.get("executedInputsBefore") != expected or record.get("executedInputsAfter") != expected:
        raise ValueError("wrong executed Go input hashes")


def trial(phase, private, manifest, args, pins, watched, tools, expected):
    require_stable(watched | tools, "runner, public inputs or Go toolchain")
    commit = pins["source"]["commit"]
    source_before = COMET.verify_snapshot(private, manifest, commit)
    directory = args.output / phase
    (directory / "work/build").mkdir(parents=True)
    (directory / "modfiles").mkdir()
    (directory / "inputs").mkdir()
    for name in BUILD_FILES:
        shutil.copyfile(FIXTURE / name, directory / "inputs" / name)
    (directory / "modfiles/go.mod").write_bytes(effective_go_mod(pins))
    shutil.copyfile(directory / "inputs/go.sum", directory / "modfiles/go.sum")
    expected_inputs = expected_executed_inputs(pins)
    executed = {directory / path: digest for path, digest in expected_inputs.items()}
    require_stable(executed, "executed inputs")
    parent_filter = "^" + PARENT + "$"
    if phase == "smoke":
        parent_filter += "/^" + SMOKE + "$"
    command = isolation_command(directory, private, args, parent_filter)
    result = COMET.EXECUTION.execute(command, ROOT, args.timeout + 10)
    raw = result["output"].encode("utf-8")
    raw_file = directory / "combined.log"
    raw_file.write_bytes(raw)
    execution = dict(phase=phase, sourceRoot=str(private), command=command,
                     supervisorCommand=result["supervisor_argv"], returncode=result["returncode"],
                     timedOut=result["timeout"], seconds=result["seconds"],
                     combinedOutputFile=raw_file.name, combinedOutputSha256=COMET.digest(raw),
                     streamsCombined=True, outputDecoding="utf-8-errors-replace", sourceBefore=source_before,
                     toolsSha256=pins["goToolSha256"], selectedFilter=parent_filter,
                     executedInputsBefore=expected_inputs)
    record = directory / "execution.json"
    write_json(record, execution)
    require_stable(watched | tools | executed, "runner, toolchain or executed inputs")
    execution["sourceAfter"] = COMET.verify_snapshot(private, manifest, commit)
    execution["executedInputsAfter"] = expected_inputs
    write_json(record, execution)
    if result["timeout"] or result["returncode"] == 125:
        raise ValueError("native timeout or supervisor failure")
    execution["outcomes"] = require_go_outcomes(raw, result["returncode"], phase, expected)
    write_json(record, execution)
    return execution


def _verified_smoke(path, expected, pins):
    if path is None:
        raise ValueError("full campaign requires --smoke-output from the reviewed genuine smoke")
    root = path.resolve(strict=True) / "smoke"
    record = json.loads((root / "execution.json").read_bytes(), object_pairs_hook=COMET.EXECUTION.unique_object)
    raw = (root / "combined.log").read_bytes()
    if (record["phase"] != "smoke" or record["timedOut"] is not False
            or record["combinedOutputSha256"] != COMET.digest(raw) or record["toolsSha256"] != pins["goToolSha256"]
            or record["selectedFilter"] != f"^{PARENT}$/^{SMOKE}$"):
        raise ValueError("invalid or stale genuine smoke record")
    require_executed_inputs(record, pins)
    source = dict(commit=pins["source"]["commit"], files=pins["source"]["files"], status="INPUTS_VERIFIED")
    if record["sourceBefore"] != source or record["sourceAfter"] != source:
        raise ValueError("smoke source identity differs")
    outcome = require_go_outcomes(raw, record["returncode"], "smoke", {SMOKE: expected[SMOKE]})
    if record["outcomes"] != outcome:
        raise ValueError("smoke receipt outcomes differ")
    return {"record": str(root / "execution.json"), "rawSha256": COMET.digest(raw)}, record


def validate_smoke(path, expected, pins):
    """Recheck the historical native phase record and raw bytes."""
    return _verified_smoke(path, expected, pins)[0]


def validate_campaign_smoke(path, expected, pins, boundary, watched_hashes, lock_path):
    """Require a smoke produced with this campaign's reviewed workspace and inputs."""
    evidence, record = _verified_smoke(path, expected, pins)
    summary_path = Path(evidence["record"]).parents[1] / "summary.json"
    try:
        raw = summary_path.read_bytes()
    except FileNotFoundError as error:
        raise ValueError("campaign smoke summary is required") from error
    summary = json.loads(raw, object_pairs_hook=COMET.EXECUTION.unique_object, parse_constant=reject_number)
    if (not isinstance(summary, dict) or summary.get("schema") != "etna-comet-signed-execution-2"
            or summary.get("status") != "PASS" or summary.get("specBoundary") != boundary
            or summary.get("inputsSha256") != watched_hashes or summary.get("physicalBuildLock") != str(lock_path)
            or json.dumps(summary.get("reports"), sort_keys=True) != json.dumps([record], sort_keys=True)):
        raise ValueError("invalid or stale campaign smoke summary")
    return evidence | {"summarySha256": COMET.digest(raw)}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    for name, help_text in (
        ("source", "manifest-pinned Comet module source directory (read-only)"),
        ("go-root", "local pinned Go SDK directory (read-only)"),
        ("module-cache", "existing local Go module cache (read-only, no fetch)"),
        ("build-cache", "existing shared writable Go build cache"),
        ("build-lock", "physical lock used by existing runners for that build cache"),
        ("output", "fresh external directory for raw logs, private source and receipts"),
    ):
        parser.add_argument("--" + name, type=Path, required=True, help=help_text)
    parser.add_argument("--timeout", type=int, default=180, help="per-phase isolation deadline in seconds")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--smoke", action="store_true", help="run only the genuine precommit_a leaf")
    mode.add_argument("--smoke-output", type=Path, help="reviewed smoke output required for full campaign")
    args = parser.parse_args(argv)
    try:
        pins, manifest, watched, expected, boundary = campaign_inputs()
        COMET.validate_layout(args, watched)
        tools = {args.go_root / name: digest for name, digest in pins["goToolSha256"].items()}
        require_stable(tools, "pinned Go SDK")
        lock_path = args.build_lock.resolve(strict=True)
        if not lock_path.is_file() or lock_path in watched or lock_path in tools or any(
                lock_path.is_relative_to(root) for root in (args.source, args.go_root, args.module_cache, args.output)):
            raise ValueError("an existing independent shared cache lock file is required")
        watched_hashes = {str(path.relative_to(ROOT.parents[2])): digest for path, digest in watched.items()}
        smoke = None if args.smoke else validate_campaign_smoke(
            args.smoke_output, expected, pins, boundary, watched_hashes, lock_path,
        )
        with lock_path.open("r") as lock:
            COMET.EXECUTION.acquire_lock(lock, min(args.timeout, 60))
            source_before = COMET.verify_snapshot(args.source, manifest, pins["source"]["commit"])
            args.output.mkdir(parents=True)
            private = args.output / "private-upstream"
            shutil.copytree(args.source, private)
            if args.smoke:
                reports = [trial("smoke", private, manifest, args, pins, watched, tools, {SMOKE: expected[SMOKE]})]
            else:
                reports = [trial("normal", private, manifest, args, pins, watched, tools, expected)]
                restoration = args.output / "actual-restoration.json"
                with private_source_fault(private, manifest, restoration) as mutant:
                    write_json(args.output / "mutant-manifest.json", mutant)
                    (args.output / "mutant-validation.go").write_bytes((private / FAULT_PATH).read_bytes())
                    mutant_expected = expected | {FAULT_LEAF: expected[FAULT_LEAF] | {"commit": "accept", "got": 0, "needed": 0}}
                    reports.append(trial("mutant", private, mutant, args, pins, watched, tools, mutant_expected))
                restored = strict_json(restoration.read_bytes())
                reports.append(trial("restored", private, manifest, args, pins, watched, tools, expected))
            require_stable(watched | tools, "campaign runner, public inputs or Go toolchain")
            source_after = COMET.verify_snapshot(args.source, manifest, pins["source"]["commit"])
            summary = dict(schema="etna-comet-signed-execution-2", status="PASS", reports=reports, smoke=smoke,
                           originalSourceBefore=source_before, originalSourceAfter=source_after,
                           specBoundary=boundary,
                           inputsSha256=watched_hashes,
                           physicalBuildLock=str(lock_path))
            if not args.smoke:
                summary["fault"] = dict(path=FAULT_PATH, original=manifest["files"][FAULT_PATH],
                                        mutant=mutant["files"][FAULT_PATH], restored=restored)
            write_json(args.output / "summary.json", summary)
            print("PASS: " + ", ".join(f"{r['phase']} {len(r['outcomes'])} exact leaves" for r in reports))
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print("Comet signed runner: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
