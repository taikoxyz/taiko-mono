#!/usr/bin/env python3
"""Check the 19 Etna archive dispositions using local source files only."""

from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import re
import sys


MANIFEST = "archived_disposition.json"
ARCHIVE = Path("experiments")
SIGNER_NOTE = ARCHIVE / "signer-wide-progress.txt"
FAMILIES = {
    "EtnaSignerCrash": (2, "C01"),
    "EtnaRegistry": (4, "R01"),
    "EtnaForcedInclusion": (9, "F01"),
    "EtnaProvingProgress": (3, "P01"),
    "EtnaVerifierRollback": (1, "Q02"),
}
STANDARD_MODULES = {"Naturals", "Integers", "FiniteSets", "Sequences", "TLC"}
REQUIRED_EVIDENCE = {
    "C01": {
        "CRASH_RECOVERY.md#checked-signer-profiles-and-incomplete-wider-experiments",
        "REPORT.md#coverage-closure-batch--g05-actual-signer-composition",
        "SIGNER_NIL_REPLAY.md#frozen-profiles-and-record-identities",
        "conformance/COMET_SIGNED.md#expected-native-behavior",
        "REPORT.md#n01-feedback-repair-bind-actual-native-inputs",
    },
    "R01": {
        "REGISTRY.md",
        "REGISTRY_RETIREMENT_PRODUCT.md#literal-program-and-expected-operational-observations",
        "conformance/REGISTRY_PUBLIC.md#literal-execution-ledgers",
        "conformance/REGISTRY_CASES.md#internal-solidity-fixture",
        "conformance/REGISTRY_CASES.md#ordinary-exit-withdrawal-and-slot-reuse",
        "conformance/REGISTRY_CASES.md#late-token-refusal-and-identical-calldata-retry",
        "REPORT.md#n02-actual-signed-evidence-and-input-binding",
        "REPORT.md#n03-actual-exit-withdrawal-and-slot-reuse",
        "REPORT.md#n04-actual-late-token-failures-and-identical-retries",
    },
    "F01": {
        "FORCED_INCLUSION.md#finite-workloads-and-observation-projections",
        "FI_SUFFIX_RECOVERY.md#omitted-chronology-and-finite-program",
        "REPORT.md#coverage-closure-batch--g04-positive-stop-old-proof-handoff",
    },
    "P01": {
        "PROVING_PROGRESS.md#exhaustive-workload-profiles",
        "PROVING_ARRIVAL_OVERLAP.md#finite-product-and-frozen-literal-calls",
        "PROOF_RECAPTURE.md#previously-omitted-chronology",
        "PROVING_RECOVERY.md",
        "REPORT.md#f05--nonzero-recovery-and-proving-resource-scenarios",
    },
    "Q02": {
        "VERIFIER_ROLLBACK.md#checked-behavior-and-independent-observations",
        "ROLLBACK_PAYMENTS.md",
        "REPORT.md#adversarial-coverage-batch--h05-pre-correction-payments-and-fresh-retry",
    },
}
ROW_FIELDS = {
    "config", "config_sha256", "status", "run_source", "sources", "observation",
    "version_hazard", "omitted_dimension", "selected_scope", "obligation", "remaining",
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, f"duplicate JSON member: {key}")
        result[key] = value
    return result


def require_keys(value, keys, label):
    require(isinstance(value, dict), f"expected object in {label}")
    extra = value.keys() - keys
    missing = keys - value.keys()
    require(not extra, f"unexpected keys in {label}: {', '.join(sorted(extra))}")
    require(not missing, f"missing keys in {label}: {', '.join(sorted(missing))}")


def require_string(value, label):
    require(isinstance(value, str) and bool(value.strip()), f"expected text in {label}")


def local_file(root, name):
    require_string(name, "local path")
    path = Path(name)
    require(
        not path.is_absolute()
        and path.as_posix() == name
        and ".." not in path.parts
        and not re.search(r"[\\:\x00-\x1f]", name),
        f"invalid local path: {name}",
    )
    target = root / path
    require(target.resolve() == target and target.is_file(), f"missing or nonlocal file: {name}")
    return target


def fail_walk(error):
    raise error


def discover_configs(root):
    archive = root / ARCHIVE
    require(archive.is_dir() and not archive.is_symlink(), "missing local experiments directory")
    configs = set()
    for directory, dirs, files in os.walk(archive, onerror=fail_walk):
        for name in dirs + files:
            path = Path(directory) / name
            require(not path.is_symlink(), f"symlink in experiments: {path.relative_to(root)}")
        for name in files:
            if name.endswith(".cfg"):
                configs.add((Path(directory) / name).relative_to(root).as_posix())
    return configs


def checked_bytes(root, name, digest, kind):
    require(
        isinstance(digest, str) and re.fullmatch(r"[0-9a-f]{64}", digest),
        f"invalid {kind} SHA-256: {name}",
    )
    content = local_file(root, name).read_bytes()
    require(hashlib.sha256(content).hexdigest() == digest, f"{kind} SHA-256 mismatch: {name}")
    return content.decode("utf-8")


def archive_layout(config, module):
    path = Path(config)
    if module == "EtnaSignerCrash":
        require(path.parent == ARCHIVE, f"unexpected signer archive layout: {config}")
        return Path(module + ".tla"), SIGNER_NOTE

    directory = path.parent.parent if path.parent.name == "configs" else path.parent
    require(directory.parent == ARCHIVE, f"unexpected archive layout: {config}")
    observation = "README.md" if module == "EtnaVerifierRollback" else "OBSERVATION.md"
    return directory / (module + ".tla"), directory / observation


def check_model(root, source, module, pins, used):
    name = source.as_posix()
    require(name in pins, f"missing source pin: {name}")
    text = checked_bytes(root, name, pins[name], "source")
    require(
        re.findall(r"^-+ MODULE (\w+) -+[ \t]*$", text, re.MULTILINE) == [module],
        f"unexpected TLA+ module identity: {name}",
    )
    used.add(name)
    return text


def verify_sources(root, source, module, pins, used):
    text = check_model(root, source, module, pins, used)
    dependencies = []
    # These archived modules use one-line EXTENDS. They have no INSTANCE imports.
    imports = re.findall(r"^EXTENDS ([\w, ]+)$", text, re.MULTILINE)
    require(
        len(imports) == 1 and not re.search(r"\bINSTANCE\b", text),
        f"unexpected archive import syntax: {source}",
    )
    local_imports = {name.strip() for name in imports[0].split(",")} - STANDARD_MODULES
    if module in {"EtnaForcedInclusion", "EtnaVerifierRollback"}:
        require(local_imports == {"EtnaSettlement"}, f"unexpected archive imports: {source}")
        base = ARCHIVE / "fi-base" if module == "EtnaForcedInclusion" else source.parent
        dependency = base / "EtnaSettlement.tla"
        dependencies = verify_sources(root, dependency, "EtnaSettlement", pins, used)
    else:
        require(not local_imports, f"unexpected archive imports: {source}")
    return [source.as_posix(), *dependencies]


def verify_observation(root, row, observation, sources, pins, predecessor):
    text = local_file(root, observation.as_posix()).read_text(encoding="utf-8")
    if observation == SIGNER_NOTE:
        for label, digest in (
            ("Old module SHA-256", predecessor),
            ("Current parameterized module SHA-256", pins[sources[0]]),
        ):
            require(
                re.findall(rf"^{label}: ([0-9a-f]{{64}})$", text, re.MULTILINE) == [digest],
                "signer predecessor attestation mismatch" if label.startswith("Old")
                else "signer parameterized source attestation mismatch",
            )
        require(predecessor != pins[sources[0]], "signer source identities must differ")
        return

    require("INCONCLUSIVE" in text, f"missing archive result in {observation}")
    for source in sources:
        require(
            pins[source] in text,
            f"historical observation disagrees with SHA-256: {source}",
        )
    config = Path(row["config"])
    if observation.name == "README.md":
        # The rollback note names the exact config without recording its digest.
        require(config.relative_to(observation.parent).as_posix() in text,
                f"historical observation omits config: {config}")
    else:
        # Registry uses filenames; FI and proving use configuration stems.
        require(
            any(
                (line.startswith(f"- `{config.name}`:") or line.startswith(f"- `{config.stem}`:"))
                and row["config_sha256"] in line
                for line in text.splitlines()
            ),
            f"historical observation disagrees with config SHA-256: {config}",
        )


def heading_anchors(markdown):
    fence = None
    for line in markdown.splitlines():
        marker = re.match(r"^ {0,3}(`{3,}|~{3,})(.*)$", line)
        if marker:
            if fence is None:
                fence = marker[1]
            elif marker[1].startswith(fence) and not marker[2].strip():
                fence = None
        elif fence is None:
            heading = re.match(r"^ {0,3}#{1,6}\s+(.+?)\s*#*\s*$", line)
            if heading:
                yield re.sub(r"[^\w -]", "", heading[1].lower()).replace(" ", "-")


def check_evidence(root, evidence):
    require_keys(evidence, set(REQUIRED_EVIDENCE), "evidence")
    for obligation, required_links in REQUIRED_EVIDENCE.items():
        group = evidence[obligation]
        require(isinstance(group, dict), f"expected evidence object for {obligation}")
        missing = required_links - group.keys()
        require(not missing, f"required evidence missing: {', '.join(sorted(missing))}")
        require_keys(group, required_links, f"{obligation} evidence")
        for link, scope in group.items():
            require_string(scope, link)
            name, _, anchor = link.partition("#")
            document = local_file(root, name).read_text(encoding="utf-8")
            if anchor:
                require(anchor in heading_anchors(document), f"evidence anchor missing: {link}")


def check_obligations(root):
    worklist = local_file(root, "WORKLIST.md").read_text(encoding="utf-8")
    for _, obligation in FAMILIES.values():
        statuses = re.findall(rf"^\| {obligation} \| ([^|]+)\|", worklist, re.MULTILINE)
        require(
            len(statuses) == 1 and re.match(r"(?:OPEN|WAITING)\b", statuses[0].partition(" / ")[2]),
            f"obligation {obligation} must remain OPEN or WAITING",
        )


def check(root):
    data = json.loads(
        local_file(root, MANIFEST).read_text(encoding="utf-8"),
        object_pairs_hook=unique_object,
    )
    require_keys(data, {"schema_version", "rows", "evidence", "source_sha256",
                        "signer_predecessor_sha256"}, "manifest")
    require(type(data["schema_version"]) is int and data["schema_version"] == 1,
            "unsupported schema_version")
    require(isinstance(data["rows"], list), "rows must be an array")
    pins = data["source_sha256"]
    require(isinstance(pins, dict), "source_sha256 must be an object")
    predecessor = data["signer_predecessor_sha256"]
    require(
        isinstance(predecessor, str) and re.fullmatch(r"[0-9a-f]{64}", predecessor),
        "invalid signer predecessor attestation",
    )

    rows = {}
    for row in data["rows"]:
        require(isinstance(row, dict), "expected disposition row object")
        name = row.get("config")
        require_string(name, "config")
        require_keys(row, ROW_FIELDS, name)
        require(name not in rows, f"duplicate disposition: {name}")
        rows[name] = row

    configs = discover_configs(root)
    missing = configs - rows.keys()
    extra = rows.keys() - configs
    require(
        not missing and not extra,
        "; ".join(
            [f"missing disposition: {name}" for name in sorted(missing)]
            + [f"extra disposition: {name}" for name in sorted(extra)]
        ),
    )
    expected_counts = {module: count for module, (count, _) in FAMILIES.items()}
    expected_total = sum(expected_counts.values())
    require(len(configs) == expected_total, f"expected {expected_total} archived configurations")

    used_sources = set()
    counts = Counter()
    for name, row in sorted(rows.items()):
        config = checked_bytes(root, name, row["config_sha256"], "config")
        modules = re.findall(r"^\\\* MODULE: (\w+)$", config, re.MULTILINE)
        require(len(modules) == 1 and modules[0] in FAMILIES, f"unexpected archive MODULE: {name}")
        module = modules[0]
        counts[module] += 1
        source, observation = archive_layout(name, module)
        historical = "attested_predecessor" if observation == SIGNER_NOTE else "archived_bytes"
        require(row["status"] == "INCONCLUSIVE", f"expected INCONCLUSIVE: {name}")
        require(row["obligation"] == FAMILIES[module][1], f"wrong obligation: {name}")
        require(row["run_source"] == historical, f"historical run source mismatch: {name}")
        require(row["observation"] == observation.as_posix(), f"wrong observation: {name}")
        for field in ("version_hazard", "omitted_dimension", "selected_scope", "remaining"):
            require_string(row[field], f"{name} {field}")
        sources = verify_sources(root, source, module, pins, used_sources)
        require(row["sources"] == sources, f"historical source association mismatch: {name}")
        verify_observation(root, row, observation, sources, pins, predecessor)
    require(counts == expected_counts, f"unexpected archive family counts: {dict(counts)}")
    require_keys(pins, used_sources, "source_sha256")
    check_evidence(root, data["evidence"])
    check_obligations(root)
    return len(configs), len(used_sources)


def main():
    try:
        count, sources = check(Path(__file__).resolve().parent)
    except (ValueError, OSError, RuntimeError) as error:
        print(f"Archived disposition check failed: {error}", file=sys.stderr)
        return 1
    print(f"Archived dispositions verified: {count} INCONCLUSIVE, {sources} local model files.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
