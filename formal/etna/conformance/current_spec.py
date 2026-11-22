"""Review exact workspace documents and select a separately pinned evidence scope."""
import hashlib
import json
from pathlib import Path

MANIFEST_PATH = Path(__file__).resolve().with_name("current_spec_boundaries.json")
# Compatibility name: fixed product-review revision, not the latest source.
CURRENT_BUNDLE = "2e6763e21bc236cfcda6011d164b32040f9e0c8d"
LATEST_SOURCE_BUNDLE = "3602629758beb653423a23608fd1960810efcfac"
# Explicit reviewed source-only scopes; product qualification is separate.
SOURCE_REVIEW_BUNDLES = ("f556fa94186b0ab604573e8d3a4c4d4fa835dc84", LATEST_SOURCE_BUNDLE)
SOURCE_REVISION_PATH = Path(__file__).resolve().with_name("source_revision_obligations.json")
SOURCE_REVISION_SHA256 = "186c78c1b6d20b3e4adff7eddcaef06993d16d1637bfdee5450960ce54a6db5d"
DOCUMENT_PATHS = tuple("packages/protocol/docs/etna/" + name
                       for name in ("SPEC.md", "ACCEPTANCE.md", "SWITCH.md"))

# Independent pins for canonical JSON of the two reviewed inventories. Changing
# document pins cannot grant a claim, and changing a claim cannot admit new bytes.
BUNDLE_INVENTORY_SHA256 = "b2c51886f72feac0ba6d40e326f81b574b7020ec301cebb7a25820a508bea95f"
CLAIM_INVENTORY_SHA256 = "d127d53a73905b701d950d75c1021433f05de6c6dfc3e21a0b96394ab79ef958"


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


def select_source_revision(bundle_id: str) -> dict:
    """Select source-review metadata only; actual workspace needs three raw documents.

    This never grants an older product claim or reports runtime conformance.
    """
    manifest = json.loads(MANIFEST_PATH.read_bytes(), object_pairs_hook=_unique_object)
    bundles = _inventory(manifest, "bundles", BUNDLE_INVENTORY_SHA256)
    raw = SOURCE_REVISION_PATH.read_bytes()
    if _sha(raw) != SOURCE_REVISION_SHA256:
        raise ValueError("source revision ledger differs from the reviewed pin")
    ledger = json.loads(raw, object_pairs_hook=_unique_object)
    if (type(ledger) is not dict or set(ledger) != {"schema", "bundles"}
            or ledger["schema"] != "etna-source-revision-obligations-1"
            or type(bundle_id) is not str or bundle_id not in SOURCE_REVIEW_BUNDLES
            or bundle_id not in bundles or type(ledger["bundles"]) is not dict
            or set(ledger["bundles"]) != set(SOURCE_REVIEW_BUNDLES)):
        raise ValueError("unreviewed source-only revision")
    # Check every separately reviewed scope at the inner selection boundary.
    # A valid latest scope cannot conceal a promoted or malformed frozen scope.
    for scope in ledger["bundles"].values():
        if (type(scope) is not dict
                or set(scope) != {"disposition", "execution", "supersedes", "evidence", "obligations"}
                or scope["disposition"] != "source-review-only"
                or scope["execution"] != "NOT_EVALUATED" or scope["supersedes"] != CURRENT_BUNDLE
                or scope["evidence"] is not None or type(scope["obligations"]) is not list
                or not scope["obligations"]):
            raise ValueError("source review cannot grant execution credit")
        identifiers = set()
        for item in scope["obligations"]:
            if (type(item) is not dict or set(item) != {"id", "ruleIds", "scope", "status"}
                    or type(item["id"]) is not str or not item["id"] or item["id"] in identifiers
                    or item["status"] != "WAITING" or type(item["scope"]) is not str
                    or not item["scope"].strip() or type(item["ruleIds"]) is not list
                    or not item["ruleIds"] or any(type(rule) is not str or not rule
                                                for rule in item["ruleIds"])
                    or len(set(item["ruleIds"])) != len(item["ruleIds"])):
                raise ValueError("invalid waiting source obligation")
            identifiers.add(item["id"])
    scope = ledger["bundles"][bundle_id]
    return {"bundleId": bundle_id, "status": "SOURCE_REVIEWED", **scope}


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
