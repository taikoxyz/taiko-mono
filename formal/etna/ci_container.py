#!/usr/bin/env python3
"""Run the unchanged Etna gate in an offline Docker runtime assembled locally."""
import argparse
import hashlib
import io
import importlib.util
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tarfile
import time
import uuid

ISOLATION_SPEC = importlib.util.spec_from_file_location(
    "etna_isolation", Path(__file__).resolve().parent / "conformance/run_isolated.py")
ISOLATION = importlib.util.module_from_spec(ISOLATION_SPEC)
ISOLATION_SPEC.loader.exec_module(ISOLATION)

OWNER_LABEL = "io.taiko.etna-ci.owner"
ENVIRONMENT = {"PATH": "/usr/bin:/bin", "LANG": "C.UTF-8"}
ENTRY = ('import os, signal, sys; signal.signal(signal.SIGINT, signal.default_int_handler); '
         'signal.signal(signal.SIGTERM, signal.SIG_DFL); '
         'os.execv(sys.executable, [sys.executable, "-B", *sys.argv[1:]])')


class Cancelled(Exception):
    def __init__(self, signum):
        self.signum = signum


def cancel(signum, _frame):
    raise Cancelled(signum)


class Docker:
    def __init__(self, executable, runtime, owner):
        self.command = [executable, "--config", str(runtime / "docker-config")]
        self.owner = owner
        self.calls = []

    def call(self, *args, timeout=15):
        command = [*self.command, *args]
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                timeout=timeout, env=ENVIRONMENT, text=True, check=False)
        self.calls.append(dict(command=command, returncode=result.returncode, output=result.stdout))
        if result.returncode:
            raise RuntimeError(f"Docker {args[0]} failed ({result.returncode}): {result.stdout[-2000:]}")
        return result.stdout.strip()

    def resources(self, kind):
        identities = self.call(kind, "ls", "--all", "--quiet", "--no-trunc", "--filter",
                               f"label={OWNER_LABEL}={self.owner}").splitlines()
        if any(re.fullmatch(r"(?:sha256:)?[0-9a-f]{64}", value) is None for value in identities):
            raise ValueError("Docker returned an invalid resource identity")
        return sorted(set(identities))

    def cleanup(self):
        """Only remove IDs whose daemon metadata proves this invocation owns them."""
        errors = []
        for kind in ("container", "image"):
            try:
                for identity in self.resources(kind):
                    data = json.loads(self.call(kind, "inspect", identity))[0]
                    if data["Config"]["Labels"].get(OWNER_LABEL) != self.owner:
                        raise ValueError("resource ownership changed; refusing removal")
                    self.call(kind, "rm", *(["--force"] if kind == "container" else []), identity)
                if self.resources(kind):
                    raise RuntimeError("owned resources remain after cleanup")
            except (OSError, ValueError, KeyError, IndexError, RuntimeError,
                    subprocess.TimeoutExpired) as error:
                errors.append(f"{kind}: {error}")
        return errors


def runtime_tar(path, uid, gid):
    files = {
        "etc/passwd": f"sample_user:x:{uid}:{gid}:Validation:/nonexistent:/bin/false\n",
        "etc/group": f"sample_group:x:{gid}:\n",
        "etc/nsswitch.conf": "passwd: files\ngroup: files\nhosts: files\n",
    }
    with tarfile.open(path, "w") as archive:
        for directory in ("usr", "bin", "lib", "lib64", "etc", "tmp", "sbin", "nonexistent"):
            item = tarfile.TarInfo(directory)
            item.type, item.mode = tarfile.DIRTYPE, 0o755
            archive.addfile(item)
        for name, content in files.items():
            data = content.encode()
            item = tarfile.TarInfo(name)
            item.size, item.mode = len(data), 0o644
            archive.addfile(item, io.BytesIO(data))


def configured_bindings(source, java, jar, output):
    return [(source, "/tmp/etna-ci/source", False), (java, "/tmp/etna-ci/java", False),
            (jar, "/tmp/etna-ci/tla2tools.jar", False), (output, "/tmp/etna-ci/output", True)]


def mounts(source, java, jar, output):
    bindings = [(Path(name).resolve(), name, False) for name in ("/usr", "/bin", "/lib", "/lib64")]
    bindings += configured_bindings(source, java, jar, output)
    return [arg for origin, target, writable in bindings for arg in
            ("--mount", f"type=bind,src={origin},dst={target}" + ("" if writable else ",readonly"))]


def run(args):
    source, java, jar = args.source.resolve(), args.java_home.resolve(), args.tlc_jar.resolve()
    output, runtime = args.output_dir.resolve(), args.runtime_dir.resolve()
    if not (source / "formal/etna/ci.py").is_file():
        raise ValueError("source must contain formal/etna/ci.py and its repository-relative inputs")
    if not java.is_dir() or not jar.is_file():
        raise ValueError("Java directory and TLC jar must already exist")
    if not output.is_dir():
        raise ValueError("output directory must already exist before binding validation")
    for origin, target, _writable in configured_bindings(source, java, jar, output):
        ISOLATION.parse_binding(f"{origin}={target}")
    executable = java / "bin/java"
    if not executable.is_file() or not os.access(executable, os.X_OK):
        raise ValueError("Java directory must contain an executable bin/java")
    if any(output == p or output in p.parents or p in output.parents for p in (source, java, jar, runtime)):
        raise ValueError("writable output must be separate from source, tools and private runtime")
    if any(runtime == p or runtime in p.parents or p in runtime.parents for p in (source, java, jar)):
        raise ValueError("private runtime must be separate from mounted inputs")
    runtime.mkdir(parents=True, exist_ok=False, mode=0o700)
    output.mkdir(parents=True, exist_ok=True)
    (runtime / "docker-config").mkdir()
    owner = uuid.uuid4().hex
    (runtime / "owner.json").write_text(json.dumps({"owner": owner}) + "\n")
    (runtime / "owner.json").chmod(0o600)
    docker = Docker(args.docker, runtime, owner)
    report = dict(ok=False, returncode=1, owner=owner, uid=os.getuid(), gid=os.getgid(), errors=[])
    process = None
    started = time.monotonic()
    try:
        report["docker_version"] = json.loads(docker.call("version", "--format", "{{json .Server}}"))
        archive = runtime / "rootfs.tar"
        runtime_tar(archive, os.getuid(), os.getgid())
        report["runtime_sha256"] = hashlib.sha256(archive.read_bytes()).hexdigest()
        image = docker.call("import", "--change", f"LABEL {OWNER_LABEL}={owner}", str(archive), timeout=30)
        report["image"] = image
        command = ["create", "--pull=never", "--init", "--name", args.container_name or "etna-ci-" + owner,
                   "--label", f"{OWNER_LABEL}={owner}", "--network", "none", "--read-only",
                   "--cap-drop", "ALL", "--security-opt", "no-new-privileges", "--user",
                   f"{os.getuid()}:{os.getgid()}", "--pids-limit", "256", "--tmpfs",
                   "/tmp:rw,exec,nosuid,nodev,size=256m,mode=1777", *mounts(source, java, jar, output),
                   "--workdir", "/tmp/etna-ci/source/formal/etna", "--entrypoint", "/usr/bin/env",
                   image, "-i", "PATH=/usr/bin:/bin", "LANG=C.UTF-8", "/usr/bin/python3", "-B",
                   "-c", ENTRY, "/tmp/etna-ci/source/formal/etna/ci.py", "--java",
                   "/tmp/etna-ci/java/bin/java", "--tlc-jar", "/tmp/etna-ci/tla2tools.jar",
                   "--output-dir", "/tmp/etna-ci/output/gate"]
        container = docker.call(*command, timeout=30)
        report["container"] = container
        report["inspection"] = json.loads(docker.call("container", "inspect", container))[0]
        with (output / "container.log").open("wb") as stream:
            process = subprocess.Popen([*docker.command, "start", "--attach", container],
                                       stdout=stream, stderr=subprocess.STDOUT, env=ENVIRONMENT,
                                       stdin=subprocess.DEVNULL)
            report["returncode"] = process.wait(timeout=args.timeout)
        state = json.loads(docker.call("container", "inspect", container))[0]["State"]
        report["state"] = state
        if state["Running"] or state["ExitCode"] != 0 or report["returncode"] != 0:
            raise RuntimeError("container gate did not complete successfully")
        report["returncode"] = 0
    except subprocess.TimeoutExpired:
        report["returncode"] = 124
        report["errors"].append("CONTAINER TIMEOUT")
    except Cancelled as error:
        report["returncode"] = 128 + error.signum
        report["errors"].append("CONTAINER CANCELLED")
    except (OSError, ValueError, RuntimeError, KeyError, IndexError) as error:
        report["errors"].append(str(error))
        if report["returncode"] == 0:
            report["returncode"] = 1
    finally:
        signal.signal(signal.SIGINT, signal.SIG_IGN)
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        cleanup_errors = docker.cleanup()
        report["cleanup_ok"] = not cleanup_errors
        report["errors"].extend(cleanup_errors)
        if process is not None and process.poll() is None:
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        report["ok"] = report["returncode"] == 0 and not report["errors"]
        report["seconds"] = round(time.monotonic() - started, 3)
        report["calls"] = docker.calls
        (output / "container-status.json").write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps({k: report[k] for k in ("ok", "returncode", "cleanup_ok", "errors", "seconds")}), flush=True)
    return report["returncode"] if report["returncode"] else (0 if report["ok"] else 1)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--docker", default="docker")
    parser.add_argument("--source", type=Path)
    parser.add_argument("--java-home", type=Path)
    parser.add_argument("--tlc-jar", type=Path)
    parser.add_argument("--output-dir", type=Path, help="existing disposable output directory")
    parser.add_argument("--runtime-dir", required=True, type=Path)
    parser.add_argument("--container-name")
    parser.add_argument("--timeout", type=float, default=2350)
    parser.add_argument("--cleanup-only", action="store_true")
    args = parser.parse_args(argv)
    try:
        if args.cleanup_only:
            state = args.runtime_dir / "owner.json"
            if not state.exists():
                return 0
            owner = json.loads(state.read_text())["owner"]
            if re.fullmatch(r"[0-9a-f]{32}", owner) is None:
                raise ValueError("invalid runtime ownership identity")
            errors = Docker(args.docker, args.runtime_dir, owner).cleanup()
            print(json.dumps({"cleanup_errors": errors}), flush=True)
            return 1 if errors else 0
        if any(value is None for value in (args.source, args.java_home, args.tlc_jar, args.output_dir)) or args.timeout <= 0:
            raise ValueError("source, Java, jar, output and a positive timeout are required")
        signal.signal(signal.SIGINT, cancel)
        signal.signal(signal.SIGTERM, cancel)
        return run(args)
    except (OSError, ValueError, KeyError) as error:
        parser.error(str(error))


if __name__ == "__main__":
    sys.exit(main())
