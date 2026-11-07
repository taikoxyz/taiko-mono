"""Select the native stock executable from a completed checkpoint before opening signer files."""
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess


def _protected_json(path):
    meta = path.lstat()
    if (not stat.S_ISREG(meta.st_mode) or meta.st_nlink != 1 or meta.st_mode & 0o077
            or meta.st_uid != os.geteuid() or meta.st_size > 2**20):
        raise ValueError("unprotected checkpoint control file")
    return json.loads(path.read_bytes())


def selected(app, home):
    """Recognize an incomplete or detached import as well as a published pair."""
    for path in (app, home):
        if (os.path.lexists(path / ".etna-checkpoint.json")
                or os.path.lexists(path.parent / ".etna-checkpoint-completed.json")
                or (path.parent.name in ("ready", ".checkpoint-work")
                    and os.path.lexists(path.parent.parent / "intent.json"))):
            return True
    state = app / "abci-state.json"
    try:
        descriptor = os.open(state, os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW)
    except FileNotFoundError:
        return False
    limit = 16 * 1024 * 1024
    with os.fdopen(descriptor, "rb") as stream:
        meta = os.fstat(stream.fileno())
        if not stat.S_ISREG(meta.st_mode) or meta.st_nlink != 1 or meta.st_size > limit:
            raise ValueError("unsafe app journal")
        raw = stream.read(limit + 1)
    if len(raw) > limit:
        raise ValueError("app journal exceeds capacity")
    def unique(fields):
        result = dict(fields)
        if len(result) != len(fields):
            raise ValueError("duplicate app journal key")
        return result
    journal = json.loads(raw, object_pairs_hook=unique)
    if not isinstance(journal, dict):
        raise ValueError("unknown app journal format")
    if "installation_id" in journal:
        return True
    # Only the established top-level ordinary state layout may take the legacy launch
    # path. App::new independently validates its complete typed contents.
    required = {"schema_version", "app_version", "chain_id", "generation", "inbox", "genesis",
                "last_height", "last_comet_hash", "parent", "anchor", "forced_cursor",
                "committees", "val_state"}
    if (set(journal) - {"recovery"} != required or journal["schema_version"] not in (17, 18)
            or type(journal["schema_version"]) is not int
            or (journal["schema_version"] == 17 and journal.get("recovery") is not None)
            or (journal["schema_version"] == 18 and not isinstance(journal.get("recovery"), dict))):
        raise ValueError("unknown app journal format")
    return False


def launch_info(app, home):
    """Use the controller-owned manifest to select the guard itself and stock's exact program."""
    if not selected(app, home):
        return None
    if app.name != "app" or home.name != "comet" or app.parent != home.parent or app.parent.name != "ready":
        raise ValueError("incomplete or mixed import paths")
    ready = app.parent
    for path in (ready, ready.parent):
        meta = path.lstat()
        if not stat.S_ISDIR(meta.st_mode) or meta.st_mode & 0o022 or meta.st_uid != os.geteuid():
            raise ValueError("unprotected import publication directory")
    descriptor = _protected_json(ready / ".etna-checkpoint-completed.json")
    intent = _protected_json(ready.parent / "intent.json")
    client = Path(descriptor["client_binary"])
    if client.resolve(strict=True) != client or not client.is_file():
        raise ValueError("invalid native launch guard")
    supplied = os.environ.get("ETNA_CLIENT_BIN")
    if supplied and Path(supplied) != client:
        raise ValueError("imported node refuses a different guard executable")
    with client.open("rb") as binary:
        digest = hashlib.file_digest(binary, "sha256").hexdigest()
    if "0x" + digest != intent["inputs"]["client_binary"]:
        raise ValueError("native launch guard differs from installation")
    for variable in ("ETNA_COMET_COMMAND_JSON", "ETNA_COMET_ENV_JSON",
                     "ETNA_SIGNER_COMMAND_JSON", "ETNA_SIGNER_ENV_JSON"):
        if variable in os.environ:
            raise ValueError("imported node refuses launch override " + variable)
    guard = subprocess.run([str(client), "abci-import", "check-runtime", "--live",
                            "--app-dir", str(app), "--comet-home", str(home)],
                           check=True, stdout=subprocess.PIPE, env={"PATH": os.defpath})
    info = json.loads(guard.stdout)
    if os.environ.get("ETNA_COMET_BIN", info["comet_binary"]) != info["comet_binary"]:
        raise ValueError("imported node refuses a different native Comet program")
    return info


def stock_env(home):
    """Pinned stock reads legacy Viper aliases even with --home. Start from an allowlist."""
    return {"PATH": os.defpath, "HOME": str(home), "CMTHOME": str(home), "TMHOME": str(home)}
