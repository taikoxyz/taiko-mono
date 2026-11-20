#!/usr/bin/env python3
"""Start stock Comet as a full node (sentries included), retaining its writer lease across exec.

An imported store starts like any other. Before every start, holding the writer lease and so
with no Comet running on the home, the launcher checks the executable's digest against the
deployment manifest (CONS-3.1-1) and deletes the pending-evidence store, and nothing else
(CONS-3.1-10, LIMIT-12-22), as the validator supervisor does (etna_comet_guard.py).
"""
import fcntl
import importlib.util
import os
from pathlib import Path
import stat
import sys
import tomllib


def comet_guard():
    """The shared pre-start checks beside this script, loaded by path so that isolated
    interpreters (python3 -I, PYTHONSAFEPATH) find them too."""
    spec = importlib.util.spec_from_file_location("etna_comet_guard", Path(__file__).resolve().with_name("etna_comet_guard.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def comet_identity():
    """The Comet OS identity the validator supervisor also uses: ETNA_COMET_UID and
    ETNA_COMET_GID together, else the caller's own. The operator owns the home for it."""
    uid, gid = os.environ.get("ETNA_COMET_UID"), os.environ.get("ETNA_COMET_GID")
    if uid is None and gid is None:
        return os.geteuid(), os.getegid()
    if uid is None or gid is None:
        raise ValueError("ETNA_COMET_UID and ETNA_COMET_GID must be set together")
    return int(uid), int(gid)


def assume_comet_identity(uid, gid):
    """Drop a privileged launcher to the Comet identity without supplementary groups. A
    same-identity caller keeps its own; an unprivileged one cannot become another."""
    if (uid, gid) == (os.geteuid(), os.getegid()):
        return
    if os.geteuid() != 0:
        raise ValueError("stock full node cannot assume its configured OS identity")
    os.setgroups([])
    os.setgid(gid)
    os.setuid(uid)


def main():
    guard = comet_guard()
    identity = comet_identity()
    home = Path(os.environ["ETNA_COMET_HOME"]).resolve(strict=True)
    config = tomllib.loads((home / "config/config.toml").read_text())
    if config.get("priv_validator_laddr", ""):
        raise ValueError("full-node startup refuses validator configuration")
    evidence = guard.evidence_store(home, guard.config_values(config))
    manifest = guard.load_manifest()
    parent = home.parent.stat()
    if parent.st_mode & 0o022 or parent.st_uid not in (0, os.geteuid()):
        raise ValueError("unprotected full-node owner directory")
    path = home.parent / ("." + home.name + ".etna-owner.lock")
    fd = os.open(path, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW | os.O_CLOEXEC, 0o600)
    m = os.fstat(fd)
    if (not stat.S_ISREG(m.st_mode) or m.st_nlink != 1 or m.st_mode & 0o077 or
            m.st_uid != os.geteuid() or not os.path.samestat(m, path.lstat())):
        raise ValueError("invalid full-node writer lease")
    fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    os.set_inheritable(fd, True)
    # The lease is held: no Comet this launcher started runs on the home.
    binary = os.environ.get("ETNA_COMET_BIN", "cometbft")
    executable = guard.check_comet_executable(manifest, binary)
    guard.remove_pending_evidence(evidence, "etna_full_node")
    assume_comet_identity(*identity)
    os.chdir(home)
    os.execv(executable, [binary, "start", "--home", str(home)])


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError) as error:
        print(f"etna full node: {error}", file=sys.stderr)
        sys.exit(1)
