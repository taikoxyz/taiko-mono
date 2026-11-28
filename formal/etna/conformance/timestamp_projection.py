"""Attribute ordinary timestamp safety for a verified projected TLC invocation."""

from hashlib import sha256
import json
from pathlib import Path
import re

from boundary_scope import require_healthy_native, require_tlc_argv, reviewed_boundary
from current_spec import _unique_object
from proving_recovery import FOOTER

CLAIM = "timestamp-projection"
EXECUTION_SCHEMA = "etna-timestamp-projection-execution-1"
EXECUTION_FIELDS = frozenset({"schema", "case", "argv", "cwd", "returncode", "timedOut",
                              "rawSha256", "inputSha256"})
PRODUCT = "EtnaTimestampRecoveryProduct.tla"
WRAPPER = "EtnaTimestampSafety.tla"
SCHEDULE = "EtnaTimestampSchedule.tla"
PRODUCT_SHA256 = "d1f46b2ef4543620f7777882c3190bfc4f5e4c4b4f74fd4ec02ee86e741a2e59"
WRAPPER_SHA256 = "e5071ca484c4d2aa2d92b57b4e2eb190d8c1d0b9a9f1de1db8db2991a8bdebee"
SCHEDULE_SHA256 = "cb164fdfedf957ecad468deff00affedd2e106e87d56b5b659edfed9765b76bb"

ORIGINAL_CONFIGS = {
    "small-safety": "433270463ea707b911b7fc850888564c7cd9cda18337b4a1a5b9bae6ffc775e2",
    "reset-safety": "f05bd380abe9a4c077e823756bf92993ec092d27b583c2de5ac3adac6bc12fb8",
    "structural-safety": "ebf4d60a01dc4ac2885e8ceb51223a0f04bf01ac612083231799e04c4f698387",
}
REPLAY_SOURCES = {
    "timestamp_recovery.py": "ca22c4a559b36203c14e865da97d45b23c2b64ea6c3e64e4a74f4d1d56b78e31",
    "proving_recovery.py": "84af36278bb123f001cf28b6e77809a4ceb233b2d6eed59c1569710d2db46c75",
}

TLC_BANNER = "TLC2 Version 2.19 of 08 August 2024 (rev: 5a47802)"
COMPLETED = "Model checking completed. No error has been found."


def _digest(raw):
    return sha256(raw).hexdigest()


def _require_hash(raw, expected, label):
    if type(raw) is not bytes or _digest(raw) != expected:
        raise ValueError(f"{label} differs from the reviewed projection input")


def audit_projection_source(product_bytes: bytes, wrapper_bytes: bytes) -> dict:
    """Bind the product and wrapper to the read-footprint proof in the guide."""
    _require_hash(product_bytes, PRODUCT_SHA256, PRODUCT)
    _require_hash(wrapper_bytes, WRAPPER_SHA256, WRAPPER)
    return {
        "productSha256": PRODUCT_SHA256,
        "wrapperSha256": WRAPPER_SHA256,
        "requiredScheduleSha256": SCHEDULE_SHA256,
        "view": ["s", "bad"],
    }


def _audit_completion(raw, cwd):
    text = raw.decode("utf-8")
    require_healthy_native(text)
    lines = text.splitlines()
    banner = [line for line in lines if line.startswith("TLC2 Version ")]
    if lines[:1] != [TLC_BANNER] or banner != [TLC_BANNER]:
        raise ValueError("missing pinned TLC version in native output")
    modules = (WRAPPER, PRODUCT, SCHEDULE)
    parsed = [line.removeprefix("Parsing file ") for line in lines if line.startswith("Parsing file ")]
    locations = [path for path in parsed if Path(path).name in modules]
    if (len(locations) != 3 or locations[0] != str(cwd / WRAPPER)
            or set(locations) != {str(cwd / module) for module in modules}
            or lines.count("Semantic processing of module EtnaTimestampSafety") != 1):
        raise ValueError("native output does not identify the projected model and dependencies")
    if (lines.count(COMPLETED) != 1
            or sum(line.startswith("Finished in ") for line in lines) != 1
            or any(line.startswith(("Error:", "State ")) for line in lines)):
        raise ValueError("unexpected native safety diagnostics")
    footer = FOOTER.search(text)
    if footer is None or text.index(COMPLETED) >= footer.start():
        raise ValueError("missing completed native graph footer")
    count = re.fullmatch(r"([\d,]+) states generated, ([\d,]+) distinct states found, 0 states left on queue\.",
                         footer[0].splitlines()[0])
    if count is None:
        raise ValueError("native graph still has outstanding states")
    generated, distinct = (int(value.replace(",", "")) for value in count.groups())
    if not 1 <= distinct <= generated:
        raise ValueError("invalid native graph counts")
    return {"generated": generated, "distinct": distinct, "queued": 0}


def _audit_execution(execution, case, raw):
    if type(execution) is not bytes or type(raw) is not bytes:
        raise ValueError("native output and execution record must be raw bytes")
    record = json.loads(execution.decode("utf-8"), object_pairs_hook=_unique_object)
    if (type(record) is not dict or set(record) != EXECUTION_FIELDS
            or record["schema"] != EXECUTION_SCHEMA or record["case"] != case):
        raise ValueError("native execution record differs from the selected profile or schema")
    if type(record["returncode"]) is not int or record["returncode"] != 0 or record["timedOut"] is not False:
        raise ValueError("native timestamp projection did not exit normally")
    if record["rawSha256"] != _digest(raw):
        raise ValueError("raw TLC transcript differs from the captured execution")
    cwd_text = record["cwd"]
    if type(cwd_text) is not str or "\0" in cwd_text:
        raise ValueError("invalid native model working directory")
    cwd = Path(cwd_text)
    if cwd.anchor != "/" or str(cwd) != cwd_text or ".." in cwd.parts:
        raise ValueError("invalid native model working directory")
    require_tlc_argv(record["argv"], case + ".cfg", WRAPPER)
    return record, cwd


def projection_receipt(workspace_root: Path, case: str, raw: bytes, *,
                       execution: bytes, staged_model: Path, expected_claim=None) -> dict:
    """Verify the exact RO staged model and a trusted same-run execution record.

    The collector captures the actual argv, cwd, staged input digests, raw
    output digest and exit status together. It guards input and tool identities
    across the native run. Staged files can be read back from a different host
    path when they match the captured digests.
    """
    if expected_claim is not None and expected_claim != CLAIM:
        raise ValueError("expected claim differs from the timestamp safety projection")
    if type(case) is not str or case not in ORIGINAL_CONFIGS:
        raise ValueError("unknown ordinary timestamp projection profile")
    record, cwd = _audit_execution(execution, case, raw)
    config = case + ".cfg"
    graph = _audit_completion(raw, cwd)

    workspace_model = workspace_root / "formal/etna"
    original = (workspace_model / "products/timestamp-recovery" / config).read_bytes()
    _require_hash(original, ORIGINAL_CONFIGS[case], config + " original")
    expected = original.replace(b"EtnaTimestampRecoveryProduct", b"EtnaTimestampSafety").replace(
        b"CHECK_DEADLOCK FALSE\n", b"CHECK_DEADLOCK FALSE\nVIEW SafetyView\n")
    staged = {name: (staged_model / name).read_bytes() for name in (config, PRODUCT, WRAPPER, SCHEDULE)}
    inputs = {name: _digest(data) for name, data in staged.items()}
    if record["inputSha256"] != inputs:
        raise ValueError("staged TLC inputs differ from the captured execution")
    if staged[config] != expected:
        raise ValueError("actual TLC config differs from the original safety profile plus view")
    source = audit_projection_source(staged[PRODUCT], staged[WRAPPER])
    _require_hash(staged[SCHEDULE], SCHEDULE_SHA256, SCHEDULE)
    for name, digest in REPLAY_SOURCES.items():
        _require_hash((workspace_model / "conformance" / name).read_bytes(), digest, name)

    scope = reviewed_boundary(workspace_root, CLAIM)
    return dict(scope, case=case, outcome="FINITE_SAFETY_EXHAUSTED", graph=graph,
                returncode=record["returncode"], timedOut=record["timedOut"], argv=record["argv"], cwd=str(cwd),
                rawSha256=record["rawSha256"], executionSha256=_digest(execution),
                configSha256=inputs[config], originalConfigSha256=_digest(original), source=source)
