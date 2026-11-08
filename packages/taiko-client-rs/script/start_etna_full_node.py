#!/usr/bin/env python3
"""Retain the stock full-node writer lease across exec; an imported store starts like any other."""
import fcntl
import os
from pathlib import Path
import stat
import sys
import tomllib


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
    identity = comet_identity()
    home = Path(os.environ["ETNA_COMET_HOME"]).resolve(strict=True)
    config = tomllib.loads((home / "config/config.toml").read_text())
    if config.get("priv_validator_laddr", ""):
        raise ValueError("full-node startup refuses validator configuration")
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
    binary = os.environ.get("ETNA_COMET_BIN", "cometbft")
    assume_comet_identity(*identity)
    os.chdir(home)
    os.execvp(binary, [binary, "start", "--home", str(home)])


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError) as error:
        print(f"etna full node: {error}", file=sys.stderr)
        sys.exit(1)
