#!/usr/bin/env python3
"""Supervise stock Comet and its guarded signer, retaining authoritative storage.

Only private observation and signer refusal events trigger recovery. Neither is
signing authorization: every new transport still obtains a fresh closed session.
A durable terminal latch keeps restartAlways containers quiescent until repair.
"""
import errno
import json
import os
from pathlib import Path
import signal
import socket
import stat
import subprocess
import sys
import time
import tomllib
import uuid


class Supervisor:
    def __init__(self):
        self.home = Path(os.environ["ETNA_COMET_HOME"]).resolve()
        self.store = Path(os.environ["ETNA_APP_STORE"]).resolve()
        self.key = Path(os.environ["ETNA_PRIV_KEY"]).resolve()
        self.state = Path(os.environ["ETNA_PRIV_STATE"]).resolve()
        self.chain = os.environ["ETNA_CHAIN_ID"]
        for path in (self.key, self.state):
            if not path.is_file() or path.is_relative_to(self.home):
                raise ValueError("existing registered key/state must be outside the Comet home")
        config = tomllib.loads((self.home / "config/config.toml").read_text())
        address = config.get("priv_validator_laddr", "")
        if not address.startswith(("unix://", "tcp://")):
            raise ValueError("validator startup requires explicit priv_validator_laddr")
        if json.loads((self.home / "config/genesis.json").read_text())["chain_id"] != self.chain:
            raise ValueError("signer chain ID differs from Comet genesis")
        self.container = os.environ.get("ETNA_COMET_CONTAINER")  # host Docker test adapter
        self.transport = Path(address[7:]) if not self.container and address.startswith("unix://") else None
        address = os.environ.get("ETNA_SIGNER_ADDR", address)
        self.events = Path(os.environ.get("ETNA_DENIAL_FILE", str(self.store / "signer-denial.json")))
        self.latch = self.store / "validator-supervisor.halted"
        binary = os.environ.get("ETNA_SIGNER_BIN", str(Path(__file__).resolve().parents[1] / "etna-signer"))
        self.signer_command = [binary, "--comet-signer-addr", address,
                               "--trust-socket", str(self.store / "checkpoint-trust.sock"),
                               "--chain-id", self.chain, "--priv-key", str(self.key),
                               "--priv-state", str(self.state), "--denial-file", str(self.events)]
        self.comet_command = (["docker", "start", "--attach", self.container] if self.container else
                              [os.environ.get("ETNA_COMET_BIN", "cometbft"), "start", "--home", str(self.home)])
        self.signer = self.comet = None
        self.running = True
        self.pending = False
        self.last_event = None
        self.session = None
        self.observed_loss = False
        self.was_ready = False

    def observe(self):
        with socket.socket(socket.AF_UNIX) as peer:
            peer.settimeout(1)
            peer.connect(str(self.store / "checkpoint-trust.sock"))
            peer.sendall(b'{"schema_version":1,"op":"observe"}\n')
            data = peer.makefile("rb").readline(16385)
            if len(data) > 16384 or not data.endswith(b"\n"):
                raise ValueError("invalid private observation frame")
            value = json.loads(data)
            if value.get("schema_version") != 1 or not isinstance(value.get("session_id"), str):
                raise ValueError("invalid private observation schema")
            return value

    def stop(self):
        # Bound and reap Comet before removing the signer. Never touch HRS/WAL/history.
        if self.comet is not None:
            if self.container:
                subprocess.run(["docker", "stop", "--time", "10", self.container],
                               stdout=subprocess.DEVNULL, check=False, timeout=20)
            elif self.comet.poll() is None:
                self.comet.terminate()
            try:
                self.comet.wait(timeout=12)
            except subprocess.TimeoutExpired:
                self.comet.kill()
                self.comet.wait()
            self.comet = None
        if self.signer is not None:
            self.signer.terminate()
            try:
                self.signer.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.signer.kill()
                self.signer.wait()
            self.signer = None

    def prepare_transport(self):
        """Remove only a disconnected local transport inode after old children are reaped."""
        if self.transport is None:
            return  # TCP and the host Docker adapter own no local Unix endpoint.
        directory = self.home / "run"
        if (not self.transport.is_absolute() or self.transport.parent.is_symlink()
                or self.transport.parent.resolve() != directory):
            raise ValueError("Unix signer transport must be directly inside Comet home/run")
        self.transport = directory / self.transport.name
        if self.comet is not None or self.signer is not None:
            raise ValueError("Unix transport cleanup requires reaped children")
        # Do not follow a substituted run directory, or unlink through a path
        # which changes while checking a potentially foreign listener.
        descriptor = os.open(directory, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            try:
                original = os.stat(self.transport.name, dir_fd=descriptor, follow_symlinks=False)
            except FileNotFoundError:
                return
            if not stat.S_ISSOCK(original.st_mode):
                raise ValueError("Unix signer transport is not a socket")
            with socket.socket(socket.AF_UNIX) as peer:
                peer.settimeout(1)
                try:
                    peer.connect(str(self.transport))
                except OSError as error:
                    if error.errno != errno.ECONNREFUSED:
                        raise  # Timeouts, permissions and all uncertainty fail closed.
                else:
                    raise ValueError("Unix signer transport still has a live listener")
            current = os.stat(self.transport.name, dir_fd=descriptor, follow_symlinks=False)
            current_directory = directory.lstat()
            opened_directory = os.fstat(descriptor)
            if (not stat.S_ISSOCK(current.st_mode)
                    or (original.st_dev, original.st_ino) != (current.st_dev, current.st_ino)
                    or not stat.S_ISDIR(current_directory.st_mode)
                    or (current_directory.st_dev, current_directory.st_ino)
                    != (opened_directory.st_dev, opened_directory.st_ino)):
                raise ValueError("Unix signer transport changed during stale-socket check")
            # Atomically select the actual object before destroying anything.
            # The Comet UID can replace names in run/, but cannot mutate entries
            # in this fresh supervisor-owned directory, even if it renames it.
            quarantine = ".etna-transport-" + uuid.uuid4().hex
            os.mkdir(quarantine, mode=0o700, dir_fd=descriptor)
            private = os.open(quarantine, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW,
                              dir_fd=descriptor)
            try:
                owned = os.fstat(private)
                if (not stat.S_ISDIR(owned.st_mode) or owned.st_uid != os.geteuid()
                        or stat.S_IMODE(owned.st_mode) != 0o700
                        or owned.st_dev != opened_directory.st_dev):
                    raise ValueError("unsafe Unix transport quarantine")
                os.rename(self.transport.name, "endpoint", src_dir_fd=descriptor, dst_dir_fd=private)
                selected = os.stat("endpoint", dir_fd=private, follow_symlinks=False)
                if (not stat.S_ISSOCK(selected.st_mode)
                        or (selected.st_dev, selected.st_ino) != (original.st_dev, original.st_ino)):
                    # Restore the public name only if still absent. Retain the
                    # protected backup even when this succeeds: another writer
                    # can unlink the restored name immediately afterwards.
                    try:
                        os.link("endpoint", self.transport.name, src_dir_fd=private,
                                dst_dir_fd=descriptor, follow_symlinks=False)
                    except OSError:
                        pass
                    raise ValueError(f"Unix transport changed; preserved at {directory / quarantine / 'endpoint'}")
                os.unlink("endpoint", dir_fd=private)
                # Do not recursively clean quarantine contents or unlink through
                # its mutable parent name. An empty private directory is harmless.
            finally:
                os.close(private)
        finally:
            os.close(descriptor)

    def start(self):
        self.prepare_transport()
        # Each signer incarnation numbers refusals from zero. Discard only its observation
        # file after both old children have been reaped; this is never signing state.
        self.events.unlink(missing_ok=True)
        self.last_event = None
        self.signer = subprocess.Popen(self.signer_command)
        command = self.comet_command
        if self.container:
            running = subprocess.check_output(["docker", "inspect", "-f", "{{.State.Running}}", self.container], text=True).strip()
            if running == "true":
                command = ["docker", "attach", "--sig-proxy=false", self.container]
        identity = {}
        if not self.container and "ETNA_COMET_UID" in os.environ:
            # The supported image keeps registered FilePV secrets inaccessible to Comet.
            identity = dict(user=int(os.environ["ETNA_COMET_UID"]),
                            group=int(os.environ["ETNA_COMET_GID"]), extra_groups=[])
        self.comet = subprocess.Popen(command, **identity)
        self.pending = False
        self.session = None
        self.observed_loss = False
        self.was_ready = False
        print("etna_supervisor_started", flush=True)

    def halt(self, reason):
        if not self.latch.exists():
            with self.latch.open("x") as file:
                file.write(reason + "\n")
                file.flush()
                os.fsync(file.fileno())
            directory = os.open(self.store, os.O_RDONLY)
            try:
                os.fsync(directory)
            finally:
                os.close(directory)
        self.stop()
        print("etna_supervisor_halted: operator repair required", flush=True)

    def tick(self):
        if self.latch.exists():
            if self.comet is not None or self.signer is not None:
                self.stop()
            return
        try:
            event = json.loads(self.events.read_text())
            sequence = event["sequence"]
            if not isinstance(sequence, int) or sequence < 0:
                raise ValueError("invalid denial sequence")
            self.session = event.get("session_id")
            if sequence > 0 and sequence != self.last_event:
                self.pending = True
                self.last_event = sequence
        except FileNotFoundError:
            pass
        # A signer exit is never authorization to bootstrap or retry broken signing state.
        if self.signer.poll() is not None:
            self.halt("signer exited; inspect diagnostics")
            return
        comet_exited = self.comet.poll() is not None
        try:
            status = self.observe()
        except (OSError, ValueError, KeyError):
            self.observed_loss = True
            self.pending = self.pending or comet_exited
            return  # Unavailable observation never authorizes recovery.
        # These exact process-lifecycle revocations are transient only across app restart.
        # Authenticated contradictions and every other halted reason remain sticky.
        if status.get("generation") not in (None, 0) or status.get("chain_id") not in (None, self.chain):
            self.halt("terminal deployment identity")
            return
        lifecycle_stop = status.get("reason") in (
            "ABCI server stopped", "app worker stopped", "checkpoint control listener stopped")
        if status.get("phase") == "halted" and lifecycle_stop:
            self.observed_loss = True
            self.pending = True
            return
        if status.get("phase") == "halted":
            self.halt("terminal app trust or deployment identity")
            return
        # Session changes after app restart also leave stock Comet at a refused step.
        session = status["session_id"]
        if self.session is not None and session != self.session:
            self.pending = True
        ready = status.get("trust_ready") is True and status.get("syncing") is False and status.get("phase") == "ready" and status.get("chain_id") == self.chain and status.get("generation") == 0
        if not ready and self.was_ready:
            self.observed_loss = True
        if comet_exited:
            if not self.pending and not self.observed_loss:
                self.halt("Comet exited without observed trust loss; inspect configuration")
                return
            self.pending = True
        if ready:
            self.was_ready = True
            if not self.pending:
                self.observed_loss = False
        if self.pending and ready:
            self.stop()
            self.start()
            print("etna_supervisor_recovered_after_refusal", flush=True)

    def run(self):
        def shutdown(_signal, _frame):
            self.running = False
        signal.signal(signal.SIGTERM, shutdown)
        signal.signal(signal.SIGINT, shutdown)
        try:
            if not self.latch.exists():
                self.start()
            while self.running:
                self.tick()
                time.sleep(.1)
        finally:
            self.stop()


if __name__ == "__main__":
    try:
        Supervisor().run()
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f"etna supervisor: {error}", file=sys.stderr)
        sys.exit(1)
