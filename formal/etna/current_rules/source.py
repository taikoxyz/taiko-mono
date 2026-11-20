"""Bind these projections to three exact f556 source streams."""

import json

from ..conformance.current_spec import (
    MANIFEST_PATH,
    classify_workspace_documents,
    select_source_revision,
)


SOURCE_REVISION = "f556fa94186b0ab604573e8d3a4c4d4fa835dc84"


def source_identity(raw_by_path: dict[str, bytes]) -> dict:
    """Return the exact source identity and the unchanged execution status."""
    manifest = json.loads(MANIFEST_PATH.read_bytes())
    identity = classify_workspace_documents(raw_by_path, manifest)
    if identity["bundleId"] != SOURCE_REVISION:
        raise ValueError("current-rule models require exact f556 source")
    metadata = select_source_revision(SOURCE_REVISION)
    return {**identity, "execution": metadata["execution"]}
