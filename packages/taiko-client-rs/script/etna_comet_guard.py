"""Checks a launcher makes before every start of stock CometBFT.

The official executable only (CONS-3.1-1): the deployment manifest (comet-manifest.json beside
script/, or ETNA_COMET_MANIFEST) pins the executable's sha256 for each supported platform, and a
reported version string alone does not identify the build. A launcher copies the executable into
a sealed memfd, hashing the bytes it copies, refuses any other digest and execs that memfd, so the
bytes it hashed are the bytes that start: no rename over the path or write to the file in between
reaches them.

An empty pending-evidence store at every start (CONS-3.1-10, LIMIT-12-22): no block commits
evidence, so the stock pool is bounded only by expiry, and neither age limit advances while no
block commits. With CometBFT stopped, the launcher deletes <db_dir>/evidence.db and nothing
else; the WAL, block, state, app/EL and signer stores stay.

start_etna_full_node.py and the validator supervisor (etna_validator.py) load this module by
path.
"""
import errno
import fcntl
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
# memfd_create's MFD_EXEC (Linux 6.3), which keeps a memfd executable under vm.memfd_noexec = 1;
# older kernels refuse the flag, and their memfds are executable.
MFD_EXEC = getattr(os, "MFD_EXEC", 0x10)
# The seals that freeze a memfd's contents for good.
EXECUTABLE_SEALS = (getattr(fcntl, "F_SEAL_SEAL", 0) | getattr(fcntl, "F_SEAL_SHRINK", 0)
                    | getattr(fcntl, "F_SEAL_GROW", 0) | getattr(fcntl, "F_SEAL_WRITE", 0))


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


def executable_path(descriptor):
    """The path that execs the open file `descriptor` itself, never a name resolved again."""
    return f"/proc/self/fd/{descriptor}"


def sealed_memfd():
    """A fresh close-on-exec memfd that can be sealed and executed."""
    flags = os.MFD_CLOEXEC | os.MFD_ALLOW_SEALING
    try:
        return os.memfd_create("cometbft", flags | MFD_EXEC)
    except OSError as error:
        if error.errno != errno.EINVAL:
            raise
        return os.memfd_create("cometbft", flags)


def sealed_comet_executable(manifest, name):
    """An open, sealed in-memory copy of executable `name` (a path, or a name looked up on PATH)
    whose digest is the one the manifest pins for this platform; anything else is refused. The
    copy is hashed as it is written and sealed against writes, shrinking and growth before the
    digest is compared, and the caller execs it through executable_path, passing the descriptor
    to the child: the bytes hashed are exactly the bytes started. Needs Linux memfd_create, the
    only platform the manifest supports, and an executable memfd (vm.memfd_noexec below 2)."""
    platform = comet_platform()
    entry = manifest["platforms"].get(platform)
    if not isinstance(entry, dict) or not isinstance(entry.get("sha256"), str) or len(entry["sha256"]) != 64:
        reason = manifest.get("unsupported_platforms", {}).get(platform, "the manifest names no executable for it")
        raise ValueError(f"no official CometBFT {COMET_RELEASE} executable for {platform}: {reason} (CONS-3.1-1)")
    found = name if os.sep in name else shutil.which(name)
    if found is None:
        raise ValueError(f"CometBFT executable {name} not found")
    executable = Path(found).resolve(strict=True)
    if not hasattr(os, "memfd_create") or not EXECUTABLE_SEALS:
        raise ValueError(f"starting exactly the hashed CometBFT executable needs Linux memfd_create and sealing, "
                         f"not available on {platform} (CONS-3.1-1)")
    source = os.open(executable, os.O_RDONLY | os.O_CLOEXEC)
    try:
        if not stat.S_ISREG(os.fstat(source).st_mode):
            raise ValueError(f"CometBFT executable {executable} is not a regular file")
        sealed = sealed_memfd()
        try:
            digest = hashlib.sha256()
            while chunk := os.read(source, 1 << 20):
                digest.update(chunk)
                view = memoryview(chunk)
                while view:
                    view = view[os.write(sealed, view):]
            fcntl.fcntl(sealed, fcntl.F_ADD_SEALS, EXECUTABLE_SEALS)
        except BaseException:
            os.close(sealed)
            raise
    finally:
        os.close(source)
    if digest.hexdigest() != entry["sha256"]:
        os.close(sealed)
        raise ValueError(f"CometBFT executable {executable} has sha256 {digest.hexdigest()}, not the {platform} "
                         f"digest {entry['sha256']} the deployment manifest pins (CONS-3.1-1)")
    return sealed


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
