#!/usr/bin/env python3
"""Run inspected validation code in a disposable Linux mount/net/PID namespace.

Bindings are explicit SOURCE=TARGET pairs. Targets stay under private /tmp; only
write bindings persist writes. Tools/dependencies must be bound before chroot,
so no host home, original Git checkout or inherited credentials are exposed.
This is a small validation runner, not a multi-tenant security boundary.
"""
import argparse
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import signal
import subprocess
import sys
import tempfile

SYSTEM_DIRECTORIES = ("/usr", "/bin", "/lib", "/lib64")
DEVICES = ("null", "zero", "random", "urandom")


def parse_binding(value):
    source_text, separator, target_text = value.partition("=")
    source = Path(source_text)
    target = PurePosixPath(target_text)
    if not separator or not source.is_absolute() or not target.is_absolute():
        raise ValueError("binding must be absolute SOURCE=TARGET")
    if ".." in target.parts or len(target.parts) < 3 or target.parts[1] != "tmp":
        raise ValueError("binding target must be a private path below /tmp")
    source = source.resolve(strict=True)
    if ".git" in source.parts or (source.is_dir() and (source / ".git").exists()):
        raise ValueError("original Git metadata must not be bound")
    if source == Path.home() or source in Path.home().parents:
        raise ValueError("host home and its ancestors must not be bound")
    return {"source": str(source), "target": str(target)}


def validate_bindings(read, write):
    bindings = read + write
    targets = [item["target"] for item in bindings]
    if len(targets) != len(set(targets)):
        raise ValueError("duplicate binding target")
    for writable in write:
        target = PurePosixPath(writable["target"])
        for readonly in read:
            other = PurePosixPath(readonly["target"])
            if target in other.parents:
                raise ValueError("a writable binding must not contain a read-only binding")
            if other in target.parents:
                mountpoint = Path(readonly["source"]).joinpath(*target.relative_to(other).parts)
                if not mountpoint.exists() or mountpoint.is_symlink():
                    raise ValueError("nested writable mountpoint must already exist in snapshot")


def clean_environment(values):
    result = {"PATH": "/usr/bin:/bin", "LANG": "C.UTF-8", "LC_ALL": "C.UTF-8"}
    forbidden = {"HOME", "PYTHONPATH", "PYTHONHOME", "BASH_ENV", "ENV", "SHELLOPTS",
                 "GH_TOKEN", "GITHUB_TOKEN", "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY"}
    for value in values:
        name, separator, content = value.partition("=")
        if not separator or not re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*", name):
            raise ValueError("environment entries must be NAME=VALUE")
        if name in forbidden or name.startswith(("LD_", "DYLD_", "GIT_CONFIG")):
            raise ValueError("credential or loader environment override is forbidden")
        result[name] = content
    return result


def _call(*argv):
    subprocess.run(argv, check=True, env=clean_environment([]), stdin=subprocess.DEVNULL)


def _target(root, target):
    path = root.joinpath(*PurePosixPath(target).parts[1:])
    if not path.resolve().is_relative_to(root):
        raise ValueError("binding target escapes disposable root through a symlink")
    return path


def _placeholder(root, binding):
    target = _target(root, binding["target"])
    target.parent.mkdir(parents=True, exist_ok=True)
    if Path(binding["source"]).is_dir():
        target.mkdir(exist_ok=True)
    else:
        target.touch(exist_ok=True)


def _bind(root, binding, readonly):
    target = _target(root, binding["target"])
    _call("/usr/bin/mount", "--bind", binding["source"], str(target))
    if readonly:
        _call("/usr/bin/mount", "-o", "remount,bind,ro,nosuid,nodev", str(target))
    else:
        _call("/usr/bin/mount", "-o", "remount,bind,rw,nosuid,nodev", str(target))


def _inside(spec_path):
    spec = json.loads(Path(spec_path).read_text())
    root = Path(spec["root"])
    _call("/usr/bin/mount", "--make-rprivate", "/")
    _call("/usr/bin/mount", "--bind", str(root), str(root))
    for directory in ("tmp", "dev", "proc", "etc", "nonexistent"):
        (root / directory).mkdir(exist_ok=True)
    _call("/usr/bin/mount", "-t", "tmpfs", "-o", "size=256m,mode=1777,nosuid,nodev", "tmpfs", str(root / "tmp"))
    system = [{"source": str(Path(p).resolve()), "target": p}
              for p in SYSTEM_DIRECTORIES if Path(p).exists()]
    devices = [{"source": "/dev/" + name, "target": "/dev/" + name} for name in DEVICES]
    for binding in system + devices + spec["read"] + spec["write"]:
        _placeholder(root, binding)
    for binding in system:
        _bind(root, binding, True)
    for binding in devices:
        _call("/usr/bin/mount", "--bind", binding["source"], str(_target(root, binding["target"])))
    for binding, readonly in sorted([(b, True) for b in spec["read"]] +
                                    [(b, False) for b in spec["write"]],
                                    key=lambda item: len(PurePosixPath(item[0]["target"]).parts)):
        _bind(root, binding, readonly)
    (root / "etc/passwd").write_text("root:x:0:0:root:/nonexistent:/bin/false\n")
    (root / "etc/group").write_text("root:x:0:\n")
    (root / "etc/nsswitch.conf").write_text("passwd: files\ngroup: files\nhosts: files\n")
    for name, target in {"fd": "/proc/self/fd", "stdin": "/proc/self/fd/0",
                         "stdout": "/proc/self/fd/1", "stderr": "/proc/self/fd/2"}.items():
        (root / "dev" / name).symlink_to(target)
    _call("/usr/bin/mount", "-t", "proc", "-o", "nosuid,nodev,noexec", "proc", str(root / "proc"))
    _call("/usr/bin/mount", "-o", "remount,bind,ro,nosuid,nodev", str(root))
    os.chroot(root)
    os.chdir(spec["cwd"])
    # PID namespace /proc must be mounted before setpriv/libcap reads its state.
    # Dropping all capabilities prevents the inspected program remounting bindings.
    command = ["/usr/bin/setpriv", "--no-new-privs", "--bounding-set=-all",
               "--inh-caps=-all", "--ambient-caps=-all", "--", *spec["command"]]
    os.execve(command[0], command, spec["environment"])


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--read-bind", action="append", default=[], metavar="SOURCE=TARGET")
    parser.add_argument("--write-bind", action="append", default=[], metavar="SOURCE=TARGET")
    parser.add_argument("--env", action="append", default=[], metavar="NAME=VALUE")
    parser.add_argument("--cwd")
    parser.add_argument("--timeout", type=int, default=1200)
    parser.add_argument("--jail-parent", type=Path)
    parser.add_argument("--inside", help=argparse.SUPPRESS)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args(argv)
    if args.inside:
        _inside(args.inside)
        return 125
    try:
        read = [parse_binding(x) for x in args.read_bind]
        write = [parse_binding(x) for x in args.write_bind]
        validate_bindings(read, write)
        environment = clean_environment(args.env)
        command = args.command[1:] if args.command[:1] == ["--"] else args.command
        if not command or not args.cwd or not Path(args.cwd).is_absolute() or args.timeout <= 0:
            raise ValueError("absolute --cwd, positive --timeout and command after -- are required")
        if not any(PurePosixPath(args.cwd) == PurePosixPath(b["target"]) or
                   PurePosixPath(b["target"]) in PurePosixPath(args.cwd).parents for b in read + write):
            raise ValueError("working directory must be in an explicit binding")
    except (OSError, ValueError) as error:
        parser.error(str(error))
    root = Path(tempfile.mkdtemp(prefix="etna-jail-", dir=args.jail_parent)).resolve()
    try:
        if any(Path(b["source"]) == root or Path(b["source"]) in root.parents for b in read + write):
            raise ValueError("jail must be outside bound source/output prefixes")
        spec = dict(root=str(root), read=read, write=write, environment=environment,
                    cwd=args.cwd, command=command)
        spec_path = root / ".launch.json"
        spec_path.write_text(json.dumps(spec))
        outer = ["/usr/bin/unshare", "--user", "--map-root-user", "--mount", "--net",
                 "--pid", "--fork", "--kill-child=KILL", sys.executable,
                 str(Path(__file__).resolve()), "--inside", str(spec_path)]
        process = subprocess.Popen(outer, env=clean_environment([]), stdin=subprocess.DEVNULL,
                                   start_new_session=True)
        try:
            return process.wait(timeout=args.timeout)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
            print("ISOLATED COMMAND TIMEOUT", file=sys.stderr)
            return 124
        except BaseException:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
            raise
    finally:
        shutil.rmtree(root)


if __name__ == "__main__":
    raise SystemExit(main())
