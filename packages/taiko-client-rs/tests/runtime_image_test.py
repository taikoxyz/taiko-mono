"""Smoke the actual Linux runtime-tools stage without compiling the Rust app."""
import hashlib
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
    # The operator's bootstrap: the key, the domains log on its own volume (here its own
    # directory), then init-state for the chain_id.
    key, hrs, domains = private / "key.json", private / "hrs", private / "domains"
    hrs.mkdir(mode=0o700)
    domains.mkdir(mode=0o700)
    chain = "etna-runtime-smoke"
    state, log = hrs / (chain + ".json"), domains / "domains.log"
    public = json.loads(subprocess.check_output([
        "/app/etna-signer", "keygen", "--priv-key", str(key)]))
    pop = json.loads(subprocess.check_output([
        "/app/etna-signer", "pop", "--priv-key", str(key), "--owner", "0x" + "11" * 20,
        "--registry", "0x" + "22" * 20, "--l1-chain-id", "31337"]))
    assert pop["publicKey"] == public["publicKey"] and len(pop["signature"]) == 132
    subprocess.check_call(["/app/etna-signer", "init-domains-log", "--domains-log", str(log)])
    subprocess.check_call(["/app/etna-signer", "init-state", "--chain-id", chain, "--priv-key", str(key),
                           "--priv-state", str(state), "--domains-log", str(log)])
    assert log.read_text() == "etna-signer-domains-v1\n" + chain + "\n"
    before = key.read_bytes(), state.read_bytes(), log.read_bytes()
    # The packaged signer refuses a chain_id the log does not list with exit 3, creating nothing.
    unlogged = hrs / "etna-unlogged.json"
    refused_domain = subprocess.run([
        "/app/etna-signer", "--comet-signer-addr", "tcp://127.0.0.1:26659",
        "--trust-socket", str(root / "not-started.sock"), "--chain-id", "etna-unlogged",
        "--priv-key", str(key), "--priv-state", str(unlogged), "--domains-log", str(log)],
        capture_output=True, timeout=5)
    assert refused_domain.returncode == 3, refused_domain
    assert b"not initialized" in refused_domain.stderr
    assert not unlogged.exists()
    assert before == (key.read_bytes(), state.read_bytes(), log.read_bytes())
    home = root / "comet"
    (home / "config").mkdir(parents=True)
    (home / "data").mkdir()
    (home / "run").mkdir(mode=0o700)
    # The configured path only selects Unix mode; the supervisor names each pair's socket.
    config = 'proxy_app = "kvstore"\npriv_validator_laddr = "unix://run/signer.sock"\n'
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
                       ETNA_PRIV_KEY=str(key), ETNA_PRIV_STATE_DIR=str(hrs),
                       ETNA_DOMAINS_LOG=str(log), ETNA_CHAIN_ID=chain)
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
                                chain_id=chain, generation=0, phase="acquiring", target=None,
                                committed_head=None, trusted_consensus_head=None,
                                reason="image smoke denies signing", recovery_origin=None)
                peer.sendall((json.dumps(response) + "\n").encode())
    server = threading.Thread(target=serve_control, daemon=True)
    server.start()
    # Actual stock Comet must bind again over the same retained home and authority,
    # each time at the fresh run/signer-<16 hex>.sock its supervisor assigns. Both
    # supervisors hold only the documented capabilities: with empty inheritable and ambient
    # sets, an exec'd root process gets exactly its bounding set as permitted and effective.
    supervisor_command = ["setpriv", "--inh-caps=-all", "--ambient-caps=-all",
                          "--bounding-set=-all,+setuid,+setgid,+kill,+dac_override",
                          "--", "python3", "/app/script/etna_validator.py"]
    documented_caps = 0xe2  # DAC_OVERRIDE | KILL | SETGID | SETUID
    stale = home / "run/signer-deadbeefdeadbeef.sock"
    listeners = []
    for incarnation in range(2):
        if incarnation == 1:
            # The stale socket of an unclean stock exit: Comet-owned, bound and closed.
            subprocess.run(["python3", "-c", "import socket,sys;s=socket.socket(socket.AF_UNIX);s.bind(sys.argv[1]);s.close()",
                            str(stale)], user=10001, group=10001, extra_groups=[], check=True)
            assert stale.is_socket() and stale.lstat().st_uid == 10001
        with (root / "runtime.log").open("w+") as log:
            supervisor = subprocess.Popen(supervisor_command, env=environment, stdout=log, stderr=log)
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
                    listening = None
                    for line in Path("/proc/net/unix").read_text().splitlines()[1:]:
                        fields = line.split()
                        path = Path(fields[-1])
                        if (len(fields) == 8 and fields[3] == "00010000" and path.parent == home / "run"
                                and path.name.startswith("signer-") and path.name.endswith(".sock")):
                            try:
                                if path.lstat().st_uid == 10001:
                                    listening = path
                            except FileNotFoundError:
                                pass
                    if listening and observed.get("cometbft") == "10001" and observed.get("etna-signer") == "0":
                        break
                    time.sleep(.05)
                assert observed.get("cometbft") == "10001" and observed.get("etna-signer") == "0", observed
                assert listening, "stock Comet did not open its Unix signer listener"
                # The children exist, so setpriv has exec'd the supervisor.
                status = Path(f"/proc/{supervisor.pid}/status").read_text().splitlines()
                cap_eff = int(next(line.split()[1] for line in status if line.startswith("CapEff:")), 16)
                assert cap_eff == documented_caps, hex(cap_eff)
                assert listening != stale and listening not in listeners, (listening, listeners)
                if incarnation == 1:
                    assert not os.path.lexists(stale), "stale signer socket survived the restart"
                listeners.append(listening)
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
    assert listeners[0] != listeners[1], "each signer+Comet pair must use a fresh socket name"
    assert not os.path.lexists(stale), "stale signer socket survived the restart"
    assert before == (key.read_bytes(), state.read_bytes(), log.read_bytes()), "runtime must not reset HRS"
    # Stock DefaultNewNode creates a dummy FilePV before replacing it with SocketPV.
    # It must be an unregistered identity and must never sign or substitute for the helper.
    unused = json.loads((home / "config/priv_validator_key.json").read_bytes())
    assert unused["pub_key"] != native
    assert json.loads((home / "data/priv_validator_state.json").read_bytes())["height"] == "0"
    # The real signer refuses a lost key, HRS or domains log, and nothing is regenerated. A lost
    # HRS or log is lost signing state (exit 3, RECOV-8.2-3), which latches at once; a lost key
    # is a configuration error (exit 1), which the supervisor restarts until the fifth exit
    # within 600 s latches. Exit 3 also leaves the signer-unsafe record, which this smoke clears
    # with the latch before the next case, as an operator repair would.
    latch, unsafe = app / "validator-supervisor.halted", app / "validator-supervisor.signer-unsafe"
    for missing in [key, state, log]:
        saved = missing.with_suffix(".saved")
        missing.rename(saved)
        with (root / "refused.log").open("w+") as refused_log:
            refused = subprocess.Popen(["python3", "/app/script/etna_validator.py"], env=environment,
                                       stdout=refused_log, stderr=refused_log)
            try:
                deadline = time.monotonic() + 30
                while not latch.exists() and time.monotonic() < deadline:
                    assert refused.poll() is None, "a latching supervisor stays alive"
                    time.sleep(.05)
                refused_log.seek(0)
                assert latch.exists(), refused_log.read()
            finally:
                refused.send_signal(signal.SIGTERM)
                refused.wait(timeout=20)
        assert not missing.exists(), "missing authoritative files must never regenerate"
        assert unsafe.exists() == (missing != key), "only lost signing state is recorded unsafe"
        latch.unlink()
        unsafe.unlink(missing_ok=True)
        saved.rename(missing)
    print(json.dumps(dict(architecture=os.uname().machine, expected_platform=expected_platform, binary_elf_machines=binary_machines, comet_source_tag="v0.40.0", comet_version_label=version, python=os.sys.version.split()[0],
                          comet_sha256=hashlib.sha256(Path("/usr/bin/cometbft").read_bytes()).hexdigest(),
                          publicKey=public["publicKey"], child_uids=observed,
                          comet_cannot_read_registered_key=True, HRS_unchanged=True,
                          unused_local_identity_never_signed=True, stock_unix_restart_with_retained_authority=True,
                          fresh_signer_socket_per_start=True, supervisor_cap_eff=hex(cap_eff),
                          stale_comet_socket_removed_under_documented_caps=True,
                          missing_key_HRS_or_domains_log_latches=True)))
