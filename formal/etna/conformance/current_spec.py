"""Review exact workspace documents and select a separately pinned evidence scope."""
import hashlib
import json
from pathlib import Path

MANIFEST_PATH = Path(__file__).resolve().with_name("current_spec_boundaries.json")
CURRENT_BUNDLE = "2e6763e21bc236cfcda6011d164b32040f9e0c8d"
DOCUMENT_PATHS = tuple("packages/protocol/docs/etna/" + name
                       for name in ("SPEC.md", "ACCEPTANCE.md", "SWITCH.md"))

# Independent pins for canonical JSON of the two reviewed inventories. Changing
# document pins cannot grant a claim, and changing a claim cannot admit new bytes.
BUNDLE_INVENTORY_SHA256 = "69ca7e52249cab3d6490b74e3abf5dc6df97277e44ef37fe41bdaac256d6042e"
CLAIM_INVENTORY_SHA256 = "5f9bd8672e8a183c071609a903ff532adc7da31ed51f8e9cda8efcadca8e8603"


def _sha(raw):
    return hashlib.sha256(raw).hexdigest()


def _unique_object(pairs):
    result = {}
    for name, value in pairs:
        if name in result:
            raise ValueError("duplicate workspace boundary key: " + name)
        result[name] = value
    return result


def _inventory(manifest, key, expected):
    if (not isinstance(manifest, dict) or set(manifest) != {"schema", "bundles", "claims"}
            or manifest["schema"] != "etna-workspace-boundaries-1"):
        raise ValueError("invalid workspace boundary manifest")
    section = manifest[key]
    encoded = json.dumps(section, sort_keys=True, separators=(",", ":")).encode()
    if _sha(encoded) != expected:
        raise ValueError(f"{key} inventory differs from the reviewed pin")
    return section


def classify_workspace_documents(raw_by_path: dict[str, bytes], pinned_manifest: dict) -> dict:
    """Match exactly three original byte streams to one reviewed revision."""
    bundles = _inventory(pinned_manifest, "bundles", BUNDLE_INVENTORY_SHA256)
    if (not isinstance(raw_by_path, dict) or set(raw_by_path) != set(DOCUMENT_PATHS)
            or any(not isinstance(raw, bytes) for raw in raw_by_path.values())):
        raise ValueError("workspace requires exact raw SPEC, ACCEPTANCE and SWITCH inputs")
    documents = {path: {"bytes": len(raw), "sha256": _sha(raw),
                        "gitBlob": hashlib.sha1(f"blob {len(raw)}\0".encode() + raw).hexdigest()}
                 for path, raw in raw_by_path.items()}
    for revision, expected in bundles.items():
        if documents == expected:
            return {"status": "SOURCE_REVIEWED", "bundleId": revision, "documents": documents}
    raise ValueError("workspace documents do not match one reviewed revision")


def _select_claim(bundle_id, consumer_id, claim_id, manifest):
    bundles = _inventory(manifest, "bundles", BUNDLE_INVENTORY_SHA256)
    claims = _inventory(manifest, "claims", CLAIM_INVENTORY_SHA256)
    if not all(isinstance(identifier, str) for identifier in (bundle_id, consumer_id, claim_id)):
        raise ValueError("bundle, consumer and claim identities must be strings")
    if bundle_id not in bundles or consumer_id not in claims or claim_id not in claims[consumer_id]:
        raise ValueError("unreviewed workspace, consumer or claim")
    claim = claims[consumer_id][claim_id]
    if bundle_id != CURRENT_BUNDLE and claim["disposition"] != "historical-only":
        raise ValueError("claim requires the current reviewed workspace")
    return {"bundleId": bundle_id, "consumerId": consumer_id, "claimId": claim_id,
            "execution": "NOT_EVALUATED", **claim}


def select_claim(bundle_id: str, consumer_id: str, claim_id: str) -> dict:
    """Select a scope for a classified bundle. Selection conveys no test outcome."""
    manifest = json.loads(MANIFEST_PATH.read_bytes(), object_pairs_hook=_unique_object)
    return _select_claim(bundle_id, consumer_id, claim_id, manifest)


def historical_workspace_receipt(workspace_root, consumer_id, claim_id, *, spec_commit,
                                 implementation_commit, manifest_sha256, input_pins_sha256,
                                 test_sources_sha256=None):
    """Bind a historical runner's pinned inputs and exact workspace bytes in its receipt."""
    evidence = dict(specCommit=spec_commit, implementationCommit=implementation_commit,
                    implementationManifestSha256=manifest_sha256, inputPinsSha256=input_pins_sha256)
    if test_sources_sha256 is not None:
        evidence["testSourcesSha256"] = test_sources_sha256
    metadata = MANIFEST_PATH.read_bytes()
    manifest = json.loads(metadata, object_pairs_hook=_unique_object)
    paths = {name: workspace_root / name for name in DOCUMENT_PATHS}
    raw = {name: path.read_bytes() for name, path in paths.items()}
    workspace = classify_workspace_documents(raw, manifest)
    claim = _select_claim(workspace["bundleId"], consumer_id, claim_id, manifest)
    if claim["disposition"] != "historical-only" or claim.pop("evidence") != evidence:
        raise ValueError("historical runner evidence differs from the selected claim")
    watched = {paths[name]: item["sha256"] for name, item in workspace["documents"].items()}
    watched[MANIFEST_PATH] = _sha(metadata)
    source = Path(__file__).resolve()
    watched[source] = _sha(source.read_bytes())
    return {"workspace": workspace, "claim": claim, "evidence": evidence}, watched
