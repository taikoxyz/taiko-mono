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
FI_BASE_NOTE = ARCHIVE / "fi-base" / "OBSERVATION.md"
GUIDE = "ARCHIVED_DISPOSITION.md"
# These notes are frozen historical evidence, including labels and per-case results.
HISTORICAL_NOTE_SHA256 = {
    "experiments/fi-base/OBSERVATION.md":
        "ecfe1e820be00ceb03d1124e99f87a48ff3222ce3becd89c0f3d25d7307be9ac",
    "experiments/fi-budget/OBSERVATION.md":
        "a897cb8fed2d5214e3721e69f70227decb72ac4d4f3765028771064e7cf07231",
    "experiments/fi-prefix/OBSERVATION.md":
        "05364f08de66572f8bbea8b5ac5dbbc199a04af6eebc2bb271eee7c235b082dc",
    "experiments/fi-projected/OBSERVATION.md":
        "ad8d023cc7354404cb010da68b23ee864d92720286205add1310876f91fdcd92",
    "experiments/fi-raw/OBSERVATION.md":
        "df81ac8f5a2f5e902352b9e476c382572b5fbe1f43fc4f5701f16855cdec347f",
    "experiments/m09-wide-runtime/README.md":
        "0126c7d8ee33aa9783cf87e67b419c4e10cc16971b50c18b893d7b818f181723",
    "experiments/progress-initial/OBSERVATION.md":
        "442d5a354056c06222d73d288cf3011a3d91ffb0d927fa7cab24b60f2f106b38",
    "experiments/registry-fixed-init/OBSERVATION.md":
        "ba668fd91d4be71495adc4fbdcd43b6a3619dbf61a2583912f52c7802754fae3",
    "experiments/registry-raw-init/OBSERVATION.md":
        "9fe443d0bf113f82c07f99e909e5fe85811368ab21d0c47079c746f2d14f2e1d",
    "experiments/registry-rich-receipt/OBSERVATION.md":
        "43ed687240e67c75eba8cf80de2b0e52b90db89ea187ff090ff6233a2b62742e",
    "experiments/registry-two-slot-raw/OBSERVATION.md":
        "98a72051ada5efb08420e7701638d388ee5d5866c40a72331b5288fc31786c35",
    "experiments/signer-wide-progress.txt":
        "9bb0af21a47e39d3bea768aeb88c80e7afe2289136f15a03e68ffef94f101a94",
}
# The historical notes for these three configs omit config digests. Pin the
# retained files from the audited checkout without attributing them to the runs.
RETAINED_CONFIG_SHA256 = {
    "experiments/m09-wide-runtime/configs/rollback-replay.cfg":
        "a4644485aedfd476690e56909a96bf42598fa2c447fde3947e395145a77fea41",
    "experiments/signer-wide-three-payloads.cfg":
        "26f0b6ab643a5582ffce7bfc81c83a732c308fd377f6f3fbf256e7d5e3fd89bd",
    "experiments/signer-wide-two-payloads.cfg":
        "60b54f2e551a277d2123ec9d754a47d2674fd8a3fa9cf22b124ef7f05dbb3adc",
}
REMAINING_STATUS = re.compile(
    r"(?:OPEN|WAITING)(?:,?[ \t]+(?!(?:OPEN|WAITING|COMPLETE|CLOSED)\b)[A-Za-z0-9].*)?"
)
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
        require(path.parent == ARCHIVE, f"unexpected config layout: {config}")
        return Path(module + ".tla"), SIGNER_NOTE

    directory = path.parent
    if module != "EtnaRegistry":
        require(directory.name == "configs", f"unexpected config layout: {config}")
        directory = directory.parent
    require(directory.parent == ARCHIVE, f"unexpected config layout: {config}")
    note = directory / ("README.md" if module == "EtnaVerifierRollback" else "OBSERVATION.md")
    require(note.as_posix() in HISTORICAL_NOTE_SHA256, f"unreviewed archive for config: {config}")
    return directory / (module + ".tla"), note


def read_observation(root, observation):
    name = observation.as_posix()
    return checked_bytes(root, name, HISTORICAL_NOTE_SHA256[name], "historical observation")


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
    text = read_observation(root, observation)
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
    if observation.name != "README.md":
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


def check_guide(root, configs):
    guide = local_file(root, GUIDE).read_text(encoding="utf-8")
    links = re.findall(r"\]\((experiments/[^()\s]+\.cfg)\)", guide)
    require(
        len(links) == len(configs) and set(links) == configs,
        f"guide config links must match the {len(configs)} archived configs",
    )


def check_obligations(root):
    worklist = local_file(root, "WORKLIST.md").read_text(encoding="utf-8")
    for _, obligation in FAMILIES.values():
        statuses = re.findall(rf"^\| {obligation} \| ([^|\r\n]+)\|", worklist, re.MULTILINE)
        status = statuses[0].partition(" / ")[2].strip() if len(statuses) == 1 else ""
        require(
            " / " not in status and REMAINING_STATUS.fullmatch(status),
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
    used_observations = {FI_BASE_NOTE.as_posix()}
    counts = Counter()
    for name, row in sorted(rows.items()):
        config = checked_bytes(root, name, row["config_sha256"], "config")
        modules = re.findall(r"^\\\* MODULE: (\w+)$", config, re.MULTILINE)
        require(len(modules) == 1 and modules[0] in FAMILIES, f"unexpected archive MODULE: {name}")
        module = modules[0]
        counts[module] += 1
        source, observation = archive_layout(name, module)
        if module in {"EtnaSignerCrash", "EtnaVerifierRollback"}:
            require(name in RETAINED_CONFIG_SHA256, f"unreviewed retained config: {name}")
            require(
                row["config_sha256"] == RETAINED_CONFIG_SHA256[name],
                f"retained config SHA-256 mismatch: {name}",
            )
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
        used_observations.add(observation.as_posix())
    require(counts == expected_counts, f"unexpected archive family counts: {dict(counts)}")
    require_keys(pins, used_sources, "source_sha256")
    require_keys(HISTORICAL_NOTE_SHA256, used_observations, "historical observation coverage")
    fi_base = (FI_BASE_NOTE.parent / "EtnaSettlement.tla").as_posix()
    require(
        pins[fi_base] in read_observation(root, FI_BASE_NOTE),
        f"historical observation disagrees with SHA-256: {fi_base}",
    )
    check_guide(root, configs)
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
