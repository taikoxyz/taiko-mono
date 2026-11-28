"""Emit a source-bound receipt for one of the two current recovery products."""
import argparse
import hashlib
import json
import re
from pathlib import Path

from current_spec import (
    CURRENT_BUNDLE, DOCUMENT_PATHS, MANIFEST_PATH, classify_workspace_documents, select_claim,
)
from proving_recovery import FOOTER


def emit(product, workspace_root, case, raw, *, expected_claim=None):
    if product == "proving":
        from proving_recovery import audit
        consumer, claim = "proof-progress-model", "arbitrary-height-landing"
    elif product == "timestamp":
        from timestamp_recovery import audit_named as audit
        consumer, claim = "rules-schedule-model", "timestamp-stop"
    else:
        raise ValueError("unknown recovery product")
    if expected_claim is not None and expected_claim != claim:
        raise ValueError("expected claim differs from the selected recovery product")
    documents = {path: (workspace_root / path).read_bytes() for path in DOCUMENT_PATHS}
    workspace = classify_workspace_documents(documents, json.loads(MANIFEST_PATH.read_bytes()))
    if workspace["bundleId"] != CURRENT_BUNDLE:
        raise ValueError("recovery product requires the current reviewed workspace")
    scope = select_claim(workspace["bundleId"], consumer, claim)
    text = raw.decode("utf-8")
    errors = re.findall(r"^Error:[^\n]*$", text, re.M)
    if (len(errors) != 2 or not re.fullmatch(r"Error: Invariant \w+ is violated\.", errors[0])
            or errors[1] != "Error: The behavior up to this point is:" or not FOOTER.search(text)):
        raise ValueError("incomplete native witness or unexpected engine diagnostics")
    transitions = audit(text, case)
    return dict(workspace=workspace, claim=scope, case=case,
                rawSha256=hashlib.sha256(raw).hexdigest(), transitions=len(transitions))


def command(emitter, description):
    parser = argparse.ArgumentParser(description=description)
    parser.add_argument("case")
    parser.add_argument("log", type=Path)
    parser.add_argument("--workspace-root", type=Path, default=Path(__file__).resolve().parents[3])
    parser.add_argument("--expect-claim")
    args = parser.parse_args()
    try:
        receipt = emitter(args.workspace_root, args.case, args.log.read_bytes(), expected_claim=args.expect_claim)
    except (OSError, ValueError) as error:
        parser.exit(1, f"recovery claim rejected: {error}\n")
    print(json.dumps(receipt, sort_keys=True))
