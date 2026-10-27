"""Smoke the actual Linux runtime-tools stage without compiling the Rust app."""
import hashlib
import json
import os
from pathlib import Path
import signal
import struct
import subprocess
import tempfile
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
    config = f'proxy_app = "tcp://127.0.0.1:26658"\npriv_validator_laddr = "unix://{home}/run/signer.sock"\n'
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
                if observed.get("cometbft") == "10001" and observed.get("etna-signer") == "0":
                    break
                time.sleep(.05)
            assert observed.get("cometbft") == "10001" and observed.get("etna-signer") == "0", observed
            time.sleep(.3)
            assert not (app / "validator-supervisor.halted").exists(), "runtime child failed during smoke"
            assert len(Path(f"/proc/{supervisor.pid}/task/{supervisor.pid}/children").read_text().split()) == 2
        finally:
            supervisor.send_signal(signal.SIGTERM)
            supervisor.wait(timeout=20)
            log.seek(0)
            diagnostics = log.read()
        assert supervisor.returncode == 0, diagnostics
    assert before == (key.read_bytes(), state.read_bytes()), "runtime must not reset HRS"
    # Stock DefaultNewNode creates a dummy FilePV before replacing it with SocketPV.
    # It must be an unregistered identity and must never sign or substitute for the helper.
    unused = json.loads((home / "config/priv_validator_key.json").read_bytes())
    assert unused["pub_key"] != native
    assert json.loads((home / "data/priv_validator_state.json").read_bytes())["height"] == "0"
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
                          unused_local_identity_never_signed=True, missing_key_or_HRS_aborts_before_Comet=True)))
