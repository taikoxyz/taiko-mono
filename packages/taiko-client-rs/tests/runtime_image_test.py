"""Smoke the actual Linux runtime-tools stage without compiling the Rust app."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import signal
import socket
import struct
import subprocess
import tempfile
import threading
import time
import tomllib
from unittest.mock import patch

assert os.getuid() == 0, "supported supervisor uses root to drop Comet privileges"
assert os.environ["ETNA_COMET_UID"] == os.environ["ETNA_COMET_GID"] == "10001"
# OCI platform labels and successful execution under binfmt do not prove that
# every bundled executable is native. In particular, the upstream v0.40.0
# arm64 image packaged an x86-64 Comet binary that Docker Desktop could emulate.
expected_platform = os.environ["ETNA_EXPECTED_PLATFORM"]
expected_uname, expected_machine = {
    "linux/arm64": ("aarch64", 183), "linux/amd64": ("x86_64", 62)
}[expected_platform]
assert os.uname().machine == expected_uname, (expected_platform, os.uname().machine)
binary_machines = {}
for executable in ["/app/etna-signer", "/usr/bin/cometbft", "/app/taiko-client"]:
    path = Path(executable)
    if executable == "/app/taiko-client" and not path.exists():
        continue  # runtime-tools target deliberately excludes the Rust app.
    with path.open("rb") as binary:
        header = binary.read(20)
    assert header[:4] == b"\x7fELF", f"not a Linux ELF executable: {executable}"
    machine = struct.unpack("<H", header[18:20])[0]
    binary_machines[executable] = machine
    assert machine == expected_machine, (executable, os.uname().machine, machine, expected_machine)
version = subprocess.check_output(["cometbft", "version"], text=True).strip()
# Exact stock source 0880b4d retains this upstream stale version constant.
assert version == "0.39.0+0880b4d", version
with tempfile.TemporaryDirectory(prefix="etna-image-") as directory:
    root = Path(directory)
    root.chmod(0o755)
    private = root / "private"
    private.mkdir(mode=0o700)
    key, state = private / "key.json", private / "state.json"
    public = json.loads(subprocess.check_output([
        "/app/etna-signer", "keygen", "--priv-key", str(key), "--priv-state", str(state)]))
    pop = json.loads(subprocess.check_output([
        "/app/etna-signer", "pop", "--priv-key", str(key), "--owner", "0x" + "11" * 20,
        "--registry", "0x" + "22" * 20, "--l1-chain-id", "31337"]))
    assert pop["publicKey"] == public["publicKey"] and len(pop["signature"]) == 132
    before = key.read_bytes(), state.read_bytes()
    home = root / "comet"
    (home / "config").mkdir(parents=True)
    (home / "data").mkdir()
    (home / "run").mkdir()
    chain = "etna-runtime-smoke"
    config = f'proxy_app = "kvstore"\npriv_validator_laddr = "unix://{home}/run/signer.sock"\n'
    (home / "config/config.toml").write_text(config)
    assert tomllib.loads(config)["priv_validator_laddr"].startswith("unix://")
    # Only public registered metadata is installed in the Comet home.
    native = json.loads(key.read_bytes())["pub_key"]
    genesis = dict(genesis_time="2026-01-01T00:00:00Z", chain_id=chain, initial_height="1",
                   validators=[dict(address=public["address"][2:].upper(), pub_key=native,
                                    power="1", name="smoke")], app_hash="", app_state={})
    (home / "config/genesis.json").write_text(json.dumps(genesis))
    for path in [home, *home.rglob("*")]:
        os.chown(path, 10001, 10001)
    app = root / "app"
    app.mkdir(mode=0o700)
    denied = subprocess.run(["python3", "-c", "import sys;open(sys.argv[1]).read()", str(key)],
                            user=10001, group=10001, extra_groups=[], capture_output=True)
    assert denied.returncode != 0 and b"PermissionError" in denied.stderr
    environment = dict(os.environ, ETNA_COMET_HOME=str(home), ETNA_APP_STORE=str(app),
                       ETNA_PRIV_KEY=str(key), ETNA_PRIV_STATE=str(state), ETNA_CHAIN_ID=chain)
    # The stock node uses its built-in kvstore only to complete startup. This
    # private peer always closes/denies signing trust; no synthetic authorization.
    control = socket.socket(socket.AF_UNIX)
    control.bind(str(app / "checkpoint-trust.sock"))
    control.listen()
    control.settimeout(.1)
    done = threading.Event()
    sessions = []
    def serve_control():
        while not done.is_set():
            try:
                peer, _ = control.accept()
            except socket.timeout:
                continue
            with peer:
                request = json.loads(peer.makefile("rb").readline())
                if request["op"] == "begin_session":
                    sessions.append(len(sessions) + 1)
                response = dict(schema_version=1, session_id=f"closed-{len(sessions)}",
                                chain_id=chain, generation=0, trust_ready=False, syncing=True,
                                phase="acquiring", target=None, committed_head=None,
                                trusted_consensus_head=None, reason="image smoke denies signing")
                peer.sendall((json.dumps(response) + "\n").encode())
    server = threading.Thread(target=serve_control, daemon=True)
    server.start()
    # Actual stock Comet must bind again over the same retained home and authority.
    for incarnation in range(2):
        with (root / "runtime.log").open("w+") as log:
            supervisor = subprocess.Popen(["python3", "/app/script/etna_validator.py"],
                                          env=environment, stdout=log, stderr=log)
            try:
                deadline = time.monotonic() + 8
                observed = {}
                while time.monotonic() < deadline:
                    assert supervisor.poll() is None, "supervisor exited during image smoke"
                    children = Path(f"/proc/{supervisor.pid}/task/{supervisor.pid}/children").read_text().split()
                    for pid in children:
                        try:
                            name = Path(f"/proc/{pid}/comm").read_text().strip()
                            status = Path(f"/proc/{pid}/status").read_text().splitlines()
                            uid = next(line for line in status if line.startswith("Uid:")).split()[1]
                            observed[name] = uid
                        except FileNotFoundError:
                            pass
                    listening = any(line.split()[-1] == str(home / "run/signer.sock")
                                    and line.split()[3] == "00010000"
                                    for line in Path("/proc/net/unix").read_text().splitlines()[1:])
                    if listening and observed.get("cometbft") == "10001" and observed.get("etna-signer") == "0":
                        break
                    time.sleep(.05)
                assert observed.get("cometbft") == "10001" and observed.get("etna-signer") == "0", observed
                assert listening, "stock Comet did not open its Unix signer listener"
                time.sleep(.3)
                assert not (app / "validator-supervisor.halted").exists(), "runtime child failed during smoke"
                assert len(Path(f"/proc/{supervisor.pid}/task/{supervisor.pid}/children").read_text().split()) == 2
            except BaseException:
                log.flush()
                log.seek(0)
                print(log.read(), flush=True)
                raise
            finally:
                supervisor.send_signal(signal.SIGTERM)
                supervisor.wait(timeout=20)
                log.seek(0)
                diagnostics = log.read()
            assert supervisor.returncode == 0, diagnostics
    done.set()
    server.join(timeout=2)
    control.close()
    assert len(sessions) >= 2, "each stock Unix incarnation must open a fresh closed session"
    assert before == (key.read_bytes(), state.read_bytes()), "runtime must not reset HRS"
    # Stock DefaultNewNode creates a dummy FilePV before replacing it with SocketPV.
    # It must be an unregistered identity and must never sign or substitute for the helper.
    unused = json.loads((home / "config/priv_validator_key.json").read_bytes())
    assert unused["pub_key"] != native
    assert json.loads((home / "data/priv_validator_state.json").read_bytes())["height"] == "0"
    empty_quarantines = list((home / "run").glob(".etna-transport-*"))
    assert empty_quarantines, "successful stale cleanup must retain its empty private directory"
    for quarantine in empty_quarantines:
        assert list(quarantine.iterdir()) == [quarantine / "capture"]
        for private_directory in [quarantine, quarantine / "capture"]:
            assert private_directory.stat().st_uid == 0 and private_directory.stat().st_mode & 0o777 == 0o700
        assert not list((quarantine / "capture").iterdir())
    # Reproduce the reviewed race with an actual unprivileged Comet-UID writer.
    spec = importlib.util.spec_from_file_location("etna_validator_under_test", "/app/script/etna_validator.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    transport = home / "run/signer.sock"
    directory = transport.parent.stat()
    real_fstat = os.fstat
    replaced = []
    def replace_after_endpoint_stat(descriptor):
        observed_directory = real_fstat(descriptor)
        if not replaced and (observed_directory.st_dev, observed_directory.st_ino) == (directory.st_dev, directory.st_ino):
            subprocess.run(["python3", "-c",
                            "import os,pathlib,sys; assert os.getuid()==10001; "
                            "assert int(next(l.split()[1] for l in pathlib.Path('/proc/self/status').read_text().splitlines() if l.startswith('CapEff:')),16)==0; "
                            "p=pathlib.Path(sys.argv[1]); p.unlink(); p.write_text('raced replacement')", str(transport)],
                           user=10001, group=10001, extra_groups=[], check=True)
            replaced.append(transport.stat().st_ino)
        return observed_directory
    with patch.dict(os.environ, environment), patch.object(module.os, "fstat", replace_after_endpoint_stat):
        try:
            module.Supervisor().prepare_transport()
        except ValueError as error:
            assert "preserved at" in str(error), error
        else:
            raise AssertionError("changed endpoint must refuse startup")
    assert replaced and transport.read_text() == "raced replacement"
    retained = list((home / "run").glob(".etna-transport-*/capture/endpoint"))
    assert len(retained) == 1 and retained[0].stat().st_ino == replaced[0]
    assert retained[0].parent.stat().st_uid == 0 and retained[0].parent.stat().st_mode & 0o777 == 0o700
    denied = subprocess.run(["python3", "-c", "import os,sys; os.unlink(sys.argv[1])", str(retained[0])],
                            user=10001, group=10001, extra_groups=[], capture_output=True)
    assert denied.returncode != 0 and b"PermissionError" in denied.stderr
    subprocess.run(["python3", "-c", "import os,sys; os.unlink(sys.argv[1])", str(transport)],
                   user=10001, group=10001, extra_groups=[], check=True)
    assert retained[0].read_text() == "raced replacement", "protected backup must survive loss of restored public name"
    assert before == (key.read_bytes(), state.read_bytes())
    # A Comet-UID writer can also substitute an old root-owned quarantine
    # between its public-name mkdir and open. Its prior evidence must survive.
    subprocess.run(["python3", "-c", "import socket,sys; s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); s.close()", str(transport)],
                   user=10001, group=10001, extra_groups=[], check=True)
    stale_inode = transport.stat().st_ino
    old_quarantine = home / "run/retained-prior-quarantine"
    old_quarantine.mkdir(mode=0o700)
    (old_quarantine / "endpoint").write_text("prior mismatch evidence")
    prior_inode = (old_quarantine / "endpoint").stat().st_ino
    real_open = os.open
    substituted = []
    def substitute_before_open(path, flags, *args, **kwargs):
        if not substituted and isinstance(path, str) and path.startswith(".etna-transport-"):
            destination = home / "run" / path
            subprocess.run(["python3", "-c",
                            "import os,pathlib,sys; assert os.getuid()==10001; "
                            "assert int(next(l.split()[1] for l in pathlib.Path('/proc/self/status').read_text().splitlines() if l.startswith('CapEff:')),16)==0; "
                            "os.rename(sys.argv[1],sys.argv[2])", str(old_quarantine), str(destination)],
                           user=10001, group=10001, extra_groups=[], check=True)
            substituted.append(destination)
        return real_open(path, flags, *args, **kwargs)
    with patch.dict(os.environ, environment), patch.object(module.os, "open", substitute_before_open):
        try:
            module.Supervisor().prepare_transport()
        except ValueError as error:
            assert "nonempty Unix quarantine" in str(error), error
        else:
            raise AssertionError("substituted prior quarantine must refuse startup")
    assert substituted and (substituted[0] / "endpoint").read_text() == "prior mismatch evidence"
    assert (substituted[0] / "endpoint").stat().st_ino == prior_inode
    assert transport.stat().st_ino == stale_inode
    assert before == (key.read_bytes(), state.read_bytes())
    for missing in [key, state]:
        saved = missing.with_suffix(".saved")
        missing.rename(saved)
        denied_start = subprocess.run(["python3", "/app/script/etna_validator.py"],
                                      env=environment, capture_output=True, timeout=5)
        assert denied_start.returncode != 0 and b"etna_supervisor_started" not in denied_start.stdout
        assert not missing.exists(), "missing authoritative files must never regenerate"
        saved.rename(missing)
    print(json.dumps(dict(architecture=os.uname().machine, expected_platform=expected_platform, binary_elf_machines=binary_machines, comet_source_tag="v0.40.0", comet_version_label=version, python=os.sys.version.split()[0],
                          comet_sha256=hashlib.sha256(Path("/usr/bin/cometbft").read_bytes()).hexdigest(),
                          publicKey=public["publicKey"], child_uids=observed,
                          comet_cannot_read_registered_key=True, HRS_unchanged=True,
                          unused_local_identity_never_signed=True, stock_unix_restart_with_retained_authority=True,
                          replacement_preserved_against_unprivileged_writer=True,
                          prior_quarantine_preserved_against_substitution=True,
                          missing_key_or_HRS_aborts_before_Comet=True)))
