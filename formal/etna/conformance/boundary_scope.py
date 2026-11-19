"""Resolve reviewed Etna boundary scopes and validate native TLC invocation metadata."""

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


def require_tlc_argv(argv: list[str], config: str, module: str) -> None:
    """Check the complete invocation in the guarded, stable TLC namespace."""
    expected = ["/tmp/etna-jre/bin/java", "-Xmx1024m", "-XX:+UseParallelGC", "-cp",
                "/tmp/etna-tools/tla2tools.jar", "tlc2.TLC", "-workers", "1", "-seed", "1",
                "-deadlock", "-metadir", "/tmp/etna-out/states", "-config", config, module]
    if type(argv) is not list or argv != expected:
        raise ValueError("actual TLC invocation differs from the selected profile")
