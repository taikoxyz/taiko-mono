"""Checks a launcher makes before every start of stock CometBFT.

The official executable only (CONS-3.1-1): the deployment manifest (comet-manifest.json beside
script/, or ETNA_COMET_MANIFEST) pins the executable's sha256 for each supported platform, and a
reported version string alone does not identify the build. A launcher hashes the executable it
is about to exec and refuses any other.

An empty pending-evidence store at every start (CONS-3.1-10, LIMIT-12-22): no block commits
evidence, so the stock pool is bounded only by expiry, and neither age limit advances while no
block commits. With CometBFT stopped, the launcher deletes <db_dir>/evidence.db and nothing
else; the WAL, block, state, app/EL and signer stores stay.

start_etna_full_node.py loads this module by path; the validator supervisor keeps its own copy
of the same checks.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import sys

# The engine every node runs (CONS-3.1-1): the deployment manifest names its official executable
# per platform by digest.
COMET_MANIFEST_SCHEMA = 1
COMET_RELEASE = "v0.40.0"
COMET_SOURCE_COMMIT = "0880b4d378f347ab16e54ec677ff50d803f37d62"
# Database backends whose stores live at <db_dir>/<name>.db in stock cometbft-db v0.14.1 and
# that the official executable supports.
COMET_DB_BACKENDS = ("goleveldb", "pebbledb")
# Settings read here, by Viper path, with their stock defaults.
READ_SETTINGS = {"db_dir": "data", "db_backend": "goleveldb"}


def comet_platform():
    """This host's platform as the deployment manifest names it, such as linux/amd64."""
    machine = os.uname().machine.lower()
    return f"{sys.platform}/{dict(x86_64='amd64', aarch64='arm64').get(machine, machine)}"


def sha256_file(path):
    digest = hashlib.sha256()
    with open(path, "rb") as source:
        for block in iter(lambda: source.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def load_manifest():
    """The deployment manifest: ETNA_COMET_MANIFEST, or the comet-manifest.json shipped beside
    script/. Only a manifest for CometBFT v0.40.0 at its source commit is used."""
    path = Path(os.environ.get("ETNA_COMET_MANIFEST", str(Path(__file__).resolve().parents[1] / "comet-manifest.json")))
    try:
        manifest = json.loads(path.read_bytes())
    except (OSError, ValueError) as error:
        raise ValueError(f"CometBFT deployment manifest {path}: {error}") from error
    if (not isinstance(manifest, dict) or manifest.get("schema") != COMET_MANIFEST_SCHEMA
            or manifest.get("release") != COMET_RELEASE or manifest.get("source_commit") != COMET_SOURCE_COMMIT
            or not isinstance(manifest.get("platforms"), dict)):
        raise ValueError(f"{path} is not a schema {COMET_MANIFEST_SCHEMA} manifest for CometBFT {COMET_RELEASE} {COMET_SOURCE_COMMIT}")
    return manifest


def check_comet_executable(manifest, name):
    """The resolved path of executable `name` (a path, or a name looked up on PATH) when its
    digest is the one the manifest pins for this platform; anything else is refused. The caller
    execs exactly the returned path, so the file hashed is the file started."""
    platform = comet_platform()
    entry = manifest["platforms"].get(platform)
    if not isinstance(entry, dict) or not isinstance(entry.get("sha256"), str) or len(entry["sha256"]) != 64:
        reason = manifest.get("unsupported_platforms", {}).get(platform, "the manifest names no executable for it")
        raise ValueError(f"no official CometBFT {COMET_RELEASE} executable for {platform}: {reason} (CONS-3.1-1)")
    found = name if os.sep in name else shutil.which(name)
    if found is None:
        raise ValueError(f"CometBFT executable {name} not found")
    executable = Path(found).resolve(strict=True)
    digest = sha256_file(executable)
    if digest != entry["sha256"]:
        raise ValueError(f"CometBFT executable {executable} has sha256 {digest}, not the {platform} digest "
                         f"{entry['sha256']} the deployment manifest pins (CONS-3.1-1)")
    return executable


def config_values(config):
    """Every value config.toml gives each Viper path. Viper folds key case and also reads a
    literal dotted key, so one path can have several spellings."""
    found = {}

    def walk(table, prefix=""):
        for key, value in table.items():
            path = prefix + key.lower()
            found.setdefault(path, []).append(value)
            if isinstance(value, dict):
                walk(value, path + ".")
    walk(config)
    return found


def env_values(path):
    """Every nonempty CMT_* override of a string setting stock Comet could apply: both
    CMT_DB_DIR and the copied CMTDB_DIR spelling count; an empty value is ignored, as by Viper."""
    suffix = path.upper().replace(".", "_").replace("-", "_")
    return [(name, os.environ[name]) for name in ("CMT_" + suffix, "CMT" + suffix) if os.environ.get(name, "")]


def read_setting(settings, path):
    """The one value stock Comet uses for an unpinned string setting: each config.toml spelling,
    or the stock default when there is none, and each CMT_* override. Candidates that disagree
    are refused, since the launcher could not tell which one Comet applies."""
    values = (settings.get(path) or [READ_SETTINGS[path]]) + [value for _, value in env_values(path)]
    if len({repr(value) for value in values}) != 1 or not all(isinstance(value, str) and value for value in values):
        raise ValueError(f"CometBFT {path} is ambiguous or invalid across config.toml and CMT_* overrides: "
                         f"{sorted({repr(value) for value in values})}")
    return values[0]


def evidence_store(home, settings):
    """Stock cometbft-db's evidence pool store, <db_dir>/evidence.db, with db_dir rooted at the
    Comet home as stock rootify does. Only backends that keep it there are accepted."""
    if read_setting(settings, "db_backend") not in COMET_DB_BACKENDS:
        raise ValueError(f"CometBFT db_backend must be one of {COMET_DB_BACKENDS}")
    db_dir = read_setting(settings, "db_dir")
    return (Path(db_dir) if os.path.isabs(db_dir) else Path(home) / db_dir) / "evidence.db"


def remove_pending_evidence(store, label):
    """Delete the pending-evidence store `store`, and only it, then make the removal durable. The
    caller has CometBFT stopped; a symlinked store is refused rather than followed. Prints
    `<label>_pending_evidence_removed: <store>` when something was removed."""
    try:
        metadata = os.lstat(store)
    except FileNotFoundError:
        return
    if stat.S_ISLNK(metadata.st_mode):
        raise ValueError(f"pending-evidence store {store} must not be a symlink")
    if stat.S_ISDIR(metadata.st_mode):
        shutil.rmtree(store)
    else:
        os.unlink(store)
    directory = os.open(Path(store).parent, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(directory)
    finally:
        os.close(directory)
    print(f"{label}_pending_evidence_removed: {store}", flush=True)
