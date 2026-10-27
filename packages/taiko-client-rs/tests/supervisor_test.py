"""Real child-process supervision with a controlled private trust peer."""
import json
import os
from pathlib import Path
import socket
import signal
import subprocess
import tempfile
import threading
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SupervisorTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="etna-supervisor-", dir="/tmp")
        self.root = Path(self.tmp.name)
        self.home = self.root / "comet"
        (self.home / "config").mkdir(parents=True)
        (self.home / "config/config.toml").write_text('priv_validator_laddr = "tcp://127.0.0.1:26659"\n')
        (self.home / "config/genesis.json").write_text('{"chain_id":"etna-test"}')
        self.store = self.root / "app"
        self.store.mkdir()
        self.key = self.root / "key.json"
        self.state = self.root / "state.json"
        self.key.write_text("existing key")
        self.state.write_text("authoritative HRS")
        self.count = self.root / "starts"
        self.events = self.root / "denial.json"
        self.ready = True
        self.phase = "ready"
        self.generation = 0
        self.session = "same-session"
        self.ops = []
        self.socket = socket.socket(socket.AF_UNIX)
        self.socket.bind(str(self.store / "checkpoint-trust.sock"))
        self.socket.listen()
        self.socket.settimeout(.1)
        self.done = threading.Event()
        self.server = threading.Thread(target=self.serve)
        self.server.start()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name, body in {
            "cometbft": 'from pathlib import Path\nimport os,time\np=Path(os.environ["STARTS"])\np.open("a").write("start\\n")\nPath(os.environ["COMET_PID"]).write_text(str(os.getpid()))\ntime.sleep(60)',
            "signer": 'import time\ntime.sleep(60)',
        }.items():
            path = self.bin / name
            path.write_text("#!/usr/bin/env python3\n" + body + "\n")
            path.chmod(0o755)
        self.env = dict(os.environ, ETNA_COMET_HOME=str(self.home), ETNA_APP_STORE=str(self.store),
                        ETNA_PRIV_KEY=str(self.key), ETNA_PRIV_STATE=str(self.state),
                        ETNA_CHAIN_ID="etna-test", ETNA_SIGNER_BIN=str(self.bin / "signer"),
                        ETNA_DENIAL_FILE=str(self.events), STARTS=str(self.count), COMET_PID=str(self.root / "comet.pid"),
                        PATH=str(self.bin) + os.pathsep + os.environ["PATH"])
        self.log = (self.root / "runtime.log").open("w+")
        self.proc = subprocess.Popen(["bash", str(ROOT / "script/start_etna_validator.sh")], env=self.env,
                                     stdout=self.log, stderr=self.log)
        self.wait(lambda: self.starts() == 1)

    def serve(self):
        while not self.done.is_set():
            try:
                peer, _ = self.socket.accept()
            except socket.timeout:
                continue
            with peer:
                request = json.loads(peer.makefile("rb").readline())
                self.ops.append(request["op"])
                response = dict(schema_version=1, session_id=self.session, chain_id="etna-test",
                                generation=self.generation, phase=self.phase, trust_ready=self.ready,
                                syncing=not self.ready)
                peer.sendall((json.dumps(response) + "\n").encode())

    def starts(self):
        return len(self.count.read_text().splitlines()) if self.count.exists() else 0

    def wait(self, predicate):
        deadline = time.monotonic() + 5
        while not predicate() and time.monotonic() < deadline:
            time.sleep(.05)
        self.assertTrue(predicate(), "supervisor did not perform the expected lifecycle transition")

    def tearDown(self):
        self.proc.terminate()
        try:
            self.proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            self.proc.wait()
        self.done.set()
        self.server.join()
        self.socket.close()
        self.log.close()
        self.tmp.cleanup()

    def test_signer_timeout_recovers_even_if_app_stayed_ready(self):
        self.events.write_text(json.dumps(dict(sequence=1, session_id=self.session)))
        self.wait(lambda: self.starts() == 2)
        time.sleep(.4)
        self.assertEqual(self.starts(), 2)
        self.assertEqual(self.state.read_text(), "authoritative HRS")
        self.assertTrue(self.ops)
        self.assertEqual(set(self.ops), {"observe"})

    def test_initial_transport_session_does_not_restart_healthy_comet(self):
        self.session = "fresh-session"
        self.events.write_text('{"sequence":0,"session_id":"fresh-session"}')
        time.sleep(.6)
        self.assertEqual(self.starts(), 1)

    def test_refusal_waits_for_trust_and_halt_never_restarts(self):
        self.ready = False
        self.phase = "acquiring"
        self.events.write_text(json.dumps(dict(sequence=1, session_id=self.session)))
        time.sleep(.5)
        self.assertEqual(self.starts(), 1)
        self.phase = "halted"
        self.wait(lambda: (self.store / "validator-supervisor.halted").exists())
        time.sleep(.4)
        self.assertIsNone(self.proc.poll())
        self.assertEqual(self.starts(), 1)

    def test_stale_generation_latches_across_supervisor_restart(self):
        self.generation = 1
        self.wait(lambda: (self.store / "validator-supervisor.halted").exists())
        self.proc.terminate()
        self.proc.wait(timeout=5)
        self.generation = 0
        self.proc = subprocess.Popen(["bash", str(ROOT / "script/start_etna_validator.sh")],
                                     env=self.env, stdout=self.log, stderr=self.log)
        time.sleep(.5)
        self.assertIsNone(self.proc.poll())
        self.assertEqual(self.starts(), 1)

    def test_missing_authoritative_state_fails_closed(self):
        self.proc.terminate()
        self.proc.wait(timeout=5)
        self.state.unlink()
        self.proc = subprocess.Popen(["bash", str(ROOT / "script/start_etna_validator.sh")],
                                     env=self.env, stdout=self.log, stderr=self.log)
        self.assertNotEqual(self.proc.wait(timeout=5), 0)
        self.assertEqual(self.starts(), 1)
        self.assertFalse(self.state.exists())

    def test_fresh_session_closes_trust_until_revalidated(self):
        self.events.write_text('{"sequence":1,"session_id":"same-session"}')
        self.ready = False
        self.phase = "acquiring"
        time.sleep(.3)
        self.assertEqual(self.starts(), 1)
        self.ready = True
        self.phase = "ready"
        self.wait(lambda: self.starts() == 2)
        self.ready = False
        self.phase = "acquiring"
        self.session = "new-session"
        self.events.write_text('{"sequence":0,"session_id":"new-session"}')
        time.sleep(.3)
        self.assertEqual(self.starts(), 2)
        self.ready = True
        self.phase = "ready"
        time.sleep(.4)
        self.assertEqual(self.starts(), 2)
        self.assertEqual(self.state.read_text(), "authoritative HRS")

    def test_comet_eof_after_observed_control_loss_recovers_only_when_ready(self):
        self.ready = False
        self.phase = "acquiring"
        time.sleep(.4)
        os.kill(int((self.root / "comet.pid").read_text()), signal.SIGTERM)
        time.sleep(.3)
        self.assertFalse((self.store / "validator-supervisor.halted").exists())
        self.assertEqual(self.starts(), 1)
        self.ready = True
        self.phase = "ready"
        self.wait(lambda: self.starts() == 2)
        self.assertEqual(self.state.read_text(), "authoritative HRS")

    def test_comet_exit_with_continuously_ready_app_is_terminal(self):
        time.sleep(.3)
        os.kill(int((self.root / "comet.pid").read_text()), signal.SIGTERM)
        self.wait(lambda: (self.store / "validator-supervisor.halted").exists())
        time.sleep(.4)
        self.assertEqual(self.starts(), 1)
        self.assertIsNone(self.proc.poll())


if __name__ == "__main__":
    unittest.main()
