"""Select one fixed source scope for the exact current Etna document bundle."""

import json
from pathlib import Path

import current_spec


def reviewed_boundary(workspace_root: Path, fixed_claim_id: str) -> dict:
    """Classify and select against the same metadata bytes without reporting execution."""
    manifest = json.loads(current_spec.MANIFEST_PATH.read_bytes(),
                          object_pairs_hook=current_spec._unique_object)
    documents = {path: (workspace_root / path).read_bytes() for path in current_spec.DOCUMENT_PATHS}
    workspace = current_spec.classify_workspace_documents(documents, manifest)
    claim = current_spec._select_claim(workspace["bundleId"], "boundary-products", fixed_claim_id, manifest)
    if workspace["bundleId"] != current_spec.CURRENT_BUNDLE:
        raise ValueError("boundary product requires the current reviewed workspace")
    return {"workspace": workspace, "claim": claim}
