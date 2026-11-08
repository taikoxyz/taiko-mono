#!/usr/bin/env python3
"""Supervise stock Comet and its guarded signer, retaining authoritative storage.

Only private observation and signer refusal events trigger recovery. Neither is
signing authorization: every new transport still obtains a fresh closed session.
A durable terminal latch keeps restartAlways containers quiescent until repair.

Stock Comet never retries a refused or timed-out signing request; only the WAL
replay of a restarted Comet asks for that step again. Recovery therefore runs in
this order: a refusal, then waiting for Ready trust, then a stop of both children
and a restart of only the signer with --await-trust. That signer begins a fresh
session and connects to Comet's priv_validator_laddr only once the app has
authenticated it. Comet starts once the app reports that published session Ready,
and its WAL replay then requests the refused step again. A first start instead
runs the signer without --await-trust together with Comet: a node that is behind
regains trust only after Comet syncs, and Comet's startup needs the signer.

While the recovery signer waits, trust staying closed only keeps it waiting,
logged, without a restart: another restart would begin another session and
restart the app's check. The exception is a pinned checkpoint above the committed
head, which only Comet can reach; the supervisor then starts the signer and Comet
together as on a first start, and a refusal there recovers again once Ready.
"""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import secrets
import signal
import socket
import stat
import subprocess
import sys
import time
import tempfile
import tomllib

# These exact process-lifecycle revocations are transient only across app restart.
APP_LIFECYCLE_STOPS = ("ABCI server stopped", "app worker stopped", "checkpoint control listener stopped")
# Each signer+Comet pair rendezvouses at <home>/run/signer-<16 hex>.sock. Names with this
# prefix and suffix belong to the supervisor; stale ones are removed before every start.
SIGNER_SOCKET_PREFIX = "signer-"
SIGNER_SOCKET_SUFFIX = ".sock"
MAX_UNIX_SOCKET_PATH = 103  # macOS sun_path holds 104 bytes with the terminating NUL
# The app's one private trust-control version. Every response carries recovery_origin:
# null for generation zero, the authenticated origin after recovery.
CONTROL_SCHEMA = 1


class Supervisor:
    @staticmethod
    def command_prefix(variable, fallback):
        """Read an explicit JSON argv without shell expansion."""
        value = os.environ.get(variable)
        if value is None:
            return fallback
        prefix = json.loads(value)
        if not isinstance(prefix, list) or not prefix or not all(isinstance(arg, str) and "\0" not in arg for arg in prefix) or not Path(prefix[0]).is_absolute():
            raise ValueError("invalid explicit executable prefix")
        return prefix

    def __init__(self):
        self.home = Path(os.environ["ETNA_COMET_HOME"]).resolve()
        self.store = Path(os.environ["ETNA_APP_STORE"]).resolve()
        self.key = Path(os.environ["ETNA_PRIV_KEY"]).resolve()
        self.state = Path(os.environ["ETNA_PRIV_STATE"]).resolve()
        root = os.environ.get("ETNA_AUTHORITY_ROOT", "")
        self.denial_route = self.validate_denial_route(root)
        self.events = self.denial_route
        self.prior_observation = None
        self.chain = os.environ["ETNA_CHAIN_ID"]
        generation = os.environ.get("ETNA_GENERATION", "0")
        if not generation.isascii() or not generation.isdecimal() or int(generation) >= 1 << 48:
            raise ValueError("ETNA_GENERATION must be a decimal uint48")
        self.generation = int(generation)
        deployment = [os.environ.get(name, "") for name in
                      ("ETNA_L1_CHAIN_ID", "ETNA_L2_CHAIN_ID", "ETNA_INBOX")]
        enrollment = os.environ.get("ETNA_ENROLL_LEGACY", "0")
        if enrollment not in ("0", "1"):
            raise ValueError("ETNA_ENROLL_LEGACY must be 0 or 1")
        authority_args = []
        if root:
            if "ETNA_GENERATION" not in os.environ or not all(deployment):
                raise ValueError("authority mode requires explicit generation and complete deployment identity")
            authority = Path(root).resolve()
            for path in (authority, self.key, self.state):
                if path.is_relative_to(self.home) or path.is_relative_to(self.store):
                    raise ValueError("authority storage must be outside Comet home and app store")
            # The native signer validates the canonical full chain domain against these
            # IDs before opening authority. Never infer enrollment from observations.
            authority_args = ["--authority-root", str(authority),
                              "--l1-chain-id", deployment[0], "--l2-chain-id", deployment[1],
                              "--inbox", deployment[2], "--generation", str(self.generation)]
            if enrollment == "1":
                authority_args.append("--enroll-legacy")
        elif self.generation or any(deployment) or enrollment == "1":
            raise ValueError("generation and authority options require ETNA_AUTHORITY_ROOT")
        for path in (self.key, self.state):
            if not path.is_file() or path.is_relative_to(self.home):
                raise ValueError("existing registered key/state must be outside the Comet home")
        config = tomllib.loads((self.home / "config/config.toml").read_text())
        address = config.get("priv_validator_laddr", "")
        if json.loads((self.home / "config/genesis.json").read_text())["chain_id"] != self.chain:
            raise ValueError("signer chain ID differs from Comet genesis")
        if address.startswith("unix://"):
            # The configured path only selects Unix mode. Every pair start gets a fresh
            # name in run/, so no Comet-owned stale inode ever needs to be pinned or probed.
            self.unix_run = self.home / "run"
            self.run_owner = int(os.environ.get("ETNA_COMET_UID", os.geteuid()))
            sample = self.unix_run / (SIGNER_SOCKET_PREFIX + "0" * 16 + SIGNER_SOCKET_SUFFIX)
            if len(os.fsencode(sample)) > MAX_UNIX_SOCKET_PATH:
                raise ValueError("Comet home too long for a Unix signer socket")
            self.address = None
        elif address.startswith("tcp://"):
            self.unix_run = None
            self.address = address  # Comet listens here; the signer dials it.
        else:
            raise ValueError("validator startup requires explicit priv_validator_laddr")
        self.latch = self.store / "validator-supervisor.halted"
        binary = os.environ.get("ETNA_SIGNER_BIN", str(Path(__file__).resolve().parents[1] / "etna-signer"))
        # start() adds each pair's --comet-signer-addr.
        self.signer_command = self.command_prefix("ETNA_SIGNER_COMMAND_JSON", [binary]) + [
            "--trust-socket", str(self.store / "checkpoint-trust.sock"),
            "--chain-id", self.chain, "--priv-key", str(self.key),
            "--priv-state", str(self.state)] + authority_args
        # Comet's complete argv. start_comet() appends only the Unix pair's --priv_validator_laddr.
        self.comet_command = self.command_prefix("ETNA_COMET_COMMAND_JSON", [
            os.environ.get("ETNA_COMET_BIN", "cometbft"), "start", "--home", str(self.home)])
        self.signer = self.comet = None
        self.running = True
        self.pending = False
        self.last_event = None
        self.session = None
        self.observed_loss = False
        self.was_ready = False
        self.awaiting = None  # last logged wait state of a recovery signer
        self.owner_fds = []
        self.halted = False
        self.halt_retry = None
        self.halt_error = None

    @staticmethod
    def read_observation(path):
        """Read one bounded native refusal record without following aliases or opening a FIFO."""
        try:
            fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        except FileNotFoundError:
            return None
        with os.fdopen(fd, "rb") as source:
            meta = os.fstat(source.fileno())
            if (not stat.S_ISREG(meta.st_mode) or meta.st_nlink != 1 or meta.st_uid != os.geteuid()
                    or meta.st_mode & 0o022 or meta.st_size > 16384):
                raise ValueError("unsafe signer diagnostic inode")
            data = source.read(16385)
        if len(data) > 16384:
            raise ValueError("oversized signer diagnostic")
        value = json.loads(data)
        if (not isinstance(value, dict) or set(value) != {"sequence", "session_id"}
                or type(value["sequence"]) is not int or not 0 <= value["sequence"] < 1 << 64
                or not isinstance(value["session_id"], str)):
            raise ValueError("unrecognized signer diagnostic; preserving existing file")
        return (meta.st_dev, meta.st_ino, meta.st_ctime_ns), value

    def validate_denial_route(self, authority_root):
        """Check the signer's diagnostic destination before any child can write."""
        default = self.store / "signer-denial.json"
        requested = Path(os.environ.get("ETNA_DENIAL_FILE", str(default)))
        if not requested.is_absolute() or ".." in requested.parts:
            raise ValueError("invalid signer diagnostic path")
        route = requested.parent.resolve(strict=True) / requested.name
        parent = route.parent.stat()
        if parent.st_uid not in (0, os.geteuid()) or parent.st_mode & 0o022:
            raise ValueError("unprotected signer diagnostic parent")
        if (route in (self.key, self.state, self.state.with_name(self.state.name + ".uncertain")) or route.is_relative_to(self.home)
                or (authority_root and route.is_relative_to(Path(authority_root).resolve()))
                or (route != default and route.is_relative_to(self.store)) or route.is_symlink()):
            raise ValueError("signer diagnostic aliases protected state")
        self.read_observation(route)
        return route

    def acquire_owner(self):
        """Retain canonical sibling ownership, including inherited all-reservation barriers."""
        parent = self.home.parent
        metadata = parent.stat()
        if (metadata.st_mode & 0o022 or metadata.st_uid not in (0, os.geteuid())):
            raise ValueError("component ownership is busy; unsafe owner directory")
        path = parent / ("." + self.home.name + ".etna-owner.lock")
        descriptor = os.open(path, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW | os.O_CLOEXEC, 0o600)
        retained = []
        try:
            opened, named = os.fstat(descriptor), path.lstat()
            if (not stat.S_ISREG(opened.st_mode) or opened.st_mode & 0o077
                    or opened.st_uid != os.geteuid() or opened.st_nlink != 1
                    or (opened.st_dev, opened.st_ino) != (named.st_dev, named.st_ino)):
                raise ValueError("component ownership is busy; unsafe owner inode")
            holds, join = os.environ.get("ETNA_OWNER_FDS"), os.environ.get("ETNA_OWNER_JOIN")
            if holds is None and join is None:
                fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
                retained.append(descriptor)
                descriptor = None
            else:
                if not holds or not join or len(holds.split(",")) > 64:
                    raise ValueError("component ownership is busy; invalid owner grant")
                role, selected = join.split(":")
                selected = int(selected)
                if role != "supervisor" or selected < 3:
                    raise ValueError("component ownership is busy; wrong owner grant")
                found = False
                for value in holds.split(","):
                    original = int(value)
                    if original < 3:
                        raise ValueError("component ownership is busy; invalid owner descriptor")
                    duplicate = os.dup(original)
                    retained.append(duplicate)
                    item = os.fstat(duplicate)
                    if (not stat.S_ISREG(item.st_mode) or item.st_mode & 0o077
                            or item.st_uid != os.geteuid() or item.st_nlink != 1):
                        raise ValueError("component ownership is busy; unsafe inherited inode")
                    if original == selected:
                        found = (item.st_dev, item.st_ino) == (opened.st_dev, opened.st_ino)
                if not found:
                    raise ValueError("component ownership is busy; mismatched owner grant")
                try:
                    fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
                except BlockingIOError:
                    pass
                else:
                    raise ValueError("component ownership is busy; unheld owner grant")
                fcntl.flock(selected, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.owner_fds = retained
            retained = []
        except BlockingIOError as error:
            raise ValueError("component ownership is busy; stop external owner or surviving children") from error
        finally:
            if descriptor is not None:
                os.close(descriptor)
            for held in retained:
                os.close(held)

    def child_options(self, child_env=None):
        """Stock descendants inherit hold-only locks, without participant join capabilities."""
        environment = dict(os.environ)
        lifetime = environment.get("ETNA_OWNER_LIFETIME_FD")
        if child_env is not None:
            overrides = json.loads(os.environ.get(child_env, "{}"))
            if not isinstance(overrides, dict) or not all(isinstance(k, str) and isinstance(v, str) for k, v in overrides.items()):
                raise ValueError("invalid child environment")
            environment.update(overrides)
        for name in ("ETNA_SIGNER_COMMAND_JSON", "ETNA_COMET_COMMAND_JSON", "ETNA_SIGNER_ENV_JSON", "ETNA_COMET_ENV_JSON"):
            environment.pop(name, None)
        environment.pop("ETNA_OWNER_FDS", None)
        environment.pop("ETNA_OWNER_JOIN", None)
        environment.pop("ETNA_OWNER_LIFETIME_FD", None)
        inherited = list(self.owner_fds)
        if lifetime is not None:
            descriptor = int(lifetime)
            if descriptor < 3 or not stat.S_ISSOCK(os.fstat(descriptor).st_mode):
                raise ValueError("invalid descendant lifetime descriptor")
            inherited.append(descriptor)
        # A terminal interrupt must reach the supervisor first, so it can stop/reap
        # Comet before the signer. Separate sessions do not authorize group signaling.
        return dict(pass_fds=tuple(inherited), env=environment, start_new_session=True)

    def observe(self):
        with socket.socket(socket.AF_UNIX) as peer:
            peer.settimeout(1)
            peer.connect(str(self.store / "checkpoint-trust.sock"))
            peer.sendall((json.dumps(dict(schema_version=CONTROL_SCHEMA, op="observe")) + "\n").encode())
            data = peer.makefile("rb").readline(16385)
            if len(data) > 16384 or not data.endswith(b"\n"):
                raise ValueError("invalid private observation frame")
            value = json.loads(data)
            if (value.get("schema_version") != CONTROL_SCHEMA
                    or not isinstance(value.get("session_id"), str)
                    or "recovery_origin" not in value):
                raise ValueError("invalid private observation schema")
            return value

    def stop(self):
        # Bound and reap Comet before removing the signer. Never touch HRS/WAL/history.
        signer_failed = False
        if self.comet is not None:
            if self.comet.poll() is None:
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
            # A fatal signer exit can race tick's poll while observe or Comet's
            # shutdown is in progress. Reaping must retain that failure before rearm.
            signer_failed = self.signer.returncode not in (0, -signal.SIGTERM)
            self.signer = None

        if signer_failed:
            self.record_signer_failure()
        return signer_failed

    def fresh_transport(self):
        """Return the next pair's signer address, after removing stale Unix rendezvous names.

        Runs with both children reaped and the home owner lock held. Refuses a missing,
        symlinked or sticky run/, one not owned by the Comet UID, and a prefixed entry that
        cannot be unlinked. Names with the signer prefix are the supervisor's own namespace:
        they are unlinked through the opened run/ without type, inode or liveness checks, so a
        live orphan can only lose its name.
        """
        if self.comet is not None or self.signer is not None:
            raise ValueError("signer transport cleanup requires reaped children")
        if self.unix_run is None:
            return self.address  # Comet listens on the configured TCP address.
        # Never follow a substituted run/; a missing one fails startup.
        descriptor = os.open(self.unix_run, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            # Refuse a misconfigured run/ at every start, not after the first unclean Comet
            # exit: without CAP_FOWNER a sticky run/ keeps Comet's stale socket.
            metadata = os.fstat(descriptor)
            if metadata.st_mode & stat.S_ISVTX:
                raise ValueError(f"{self.unix_run} must not be sticky")
            if metadata.st_uid != self.run_owner:
                raise ValueError(f"{self.unix_run} must be owned by the Comet UID {self.run_owner}, not {metadata.st_uid}")
            for name in os.listdir(descriptor):
                if name.startswith(SIGNER_SOCKET_PREFIX) and name.endswith(SIGNER_SOCKET_SUFFIX):
                    os.unlink(name, dir_fd=descriptor)  # Errors (e.g. a directory) fail closed.
        finally:
            os.close(descriptor)
        name = SIGNER_SOCKET_PREFIX + secrets.token_hex(8) + SIGNER_SOCKET_SUFFIX
        return "unix://" + str(self.unix_run / name)

    def start(self, await_trust=False):
        """Start a fresh signer, and Comet with it unless the signer must first be trusted."""
        if self.signer_uncertain():
            self.record_signer_failure()
            self.halt("retained signer uncertainty fence; inspect signing authority")
            return
        self.validate_denial_route(os.environ.get("ETNA_AUTHORITY_ROOT", ""))
        self.address = self.fresh_transport()
        # Never unlink an operator-selected file; ignore its old inode on restart.
        previous = self.read_observation(self.events)
        self.prior_observation = previous[0] if previous is not None else None
        self.last_event = None
        args = self.signer_command + ["--comet-signer-addr", self.address, "--denial-file", str(self.events)]
        self.signer = subprocess.Popen(args + (["--await-trust"] if await_trust else []), **self.child_options("ETNA_SIGNER_ENV_JSON"))
        self.pending = False
        self.session = None
        self.observed_loss = False
        self.was_ready = False
        self.awaiting = None
        if not await_trust:
            self.start_comet()
        print("etna_supervisor_started", flush=True)

    def start_comet(self):
        command = self.comet_command
        if self.unix_run is not None:
            command = command + ["--priv_validator_laddr", self.address]
        identity = {}
        if "ETNA_COMET_UID" in os.environ:
            # The supported image keeps registered FilePV secrets inaccessible to Comet.
            uid, gid = int(os.environ["ETNA_COMET_UID"]), int(os.environ["ETNA_COMET_GID"])
            # A same-identity unprivileged local runner cannot call setgroups. Preserve its
            # existing identity; privileged/different-identity launches still drop all groups.
            if os.geteuid() == 0 or uid != os.geteuid() or gid != os.getegid():
                identity = dict(user=uid, group=gid, extra_groups=[])
        self.comet = subprocess.Popen(command, cwd=self.home, **identity, **self.child_options("ETNA_COMET_ENV_JSON"))

    def expected_supersession(self, snapshot):
        """Classify only typed first-cause bytes; generic latch/reason text never authorizes it."""
        if not snapshot or snapshot.get("phase") != "halted" or snapshot.get("chain_id") != self.chain or snapshot.get("generation") != self.generation:
            return None
        def bounded(name):
            descriptor = os.open(self.store / name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
            with os.fdopen(descriptor, "rb") as source:
                metadata = os.fstat(source.fileno())
                if not stat.S_ISREG(metadata.st_mode) or metadata.st_size > 16 * 1024 * 1024:
                    raise ValueError("invalid terminal evidence")
                return source.read(16 * 1024 * 1024 + 1)
        try:
            raw = bounded("generation-superseded.json")
            evidence = json.loads(raw)
            state_bytes, fatal = bounded("abci-state.json"), bounded("fatal-evidence.txt")
            state = json.loads(state_bytes)
            if (set(evidence) != {"schema", "chain_id", "previous_generation", "current_generation", "inbox", "state_digest", "fatal_digest"}
                    or evidence["schema"] != 1 or evidence["chain_id"] != self.chain
                    or evidence["previous_generation"] != self.generation
                    or not isinstance(evidence["current_generation"], int)
                    or not self.generation < evidence["current_generation"] < 1 << 48
                    or state.get("chain_id") != self.chain or state.get("generation") != self.generation
                    or state.get("inbox") != evidence["inbox"]
                    or hashlib.sha256(state_bytes).hexdigest() != evidence["state_digest"]
                    or hashlib.sha256(fatal).hexdigest() != evidence["fatal_digest"]):
                return None
            return dict(schema=1, kind="expected-generation-supersession", chain_id=self.chain,
                        previous_generation=self.generation, current_generation=evidence["current_generation"],
                        evidence_digest=hashlib.sha256(raw).hexdigest())
        except (OSError, ValueError, KeyError, TypeError):
            return None

    def persist_latch(self, text, replace=False):
        """Durably create a halt, or atomically replace its classification after joined shutdown."""
        temporary = None
        try:
            if replace:
                descriptor, temporary = tempfile.mkstemp(prefix=".validator-halt-", dir=self.store)
                target = os.fdopen(descriptor, "w")
            else:
                target = self.latch.open("x")
            with target as file:
                file.write(text)
                file.flush()
                os.fsync(file.fileno())
            if replace:
                os.replace(temporary, self.latch)
            directory = os.open(self.store, os.O_RDONLY)
            try:
                os.fsync(directory)
            finally:
                os.close(directory)
        finally:
            if temporary is not None and os.path.exists(temporary):
                os.unlink(temporary)

    def record_signer_failure(self):
        """Block recovery acknowledgement without replacing an existing generic first cause."""
        try:
            descriptor = os.open(self.latch, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        except FileNotFoundError:
            self.retain_latch("signer exited; inspect diagnostics\n")
            return
        except OSError:
            self.retain_latch("signer exited; inspect diagnostics\n")
            return
        try:
            with os.fdopen(descriptor, "rb") as file:
                metadata = os.fstat(file.fileno())
                if not stat.S_ISREG(metadata.st_mode) or metadata.st_size > 1024 * 1024:
                    return  # These records already fail recovery's bounded JSON check.
                raw = file.read(1024 * 1024 + 1)
        except OSError:
            self.retain_latch("signer exited; inspect diagnostics\n")
            return
        try:
            value = json.loads(raw)
        except ValueError:
            return
        if isinstance(value, dict) and value.get("kind") == "expected-generation-supersession":
            self.retain_latch("signer exited; inspect diagnostics\n", replace=True)

    def retain_latch(self, text, replace=False):
        """Keep the owner alive and quiescent if terminal evidence cannot be flushed."""
        self.halted = True
        self.halt_retry = (text, replace)
        return self.retry_latch()

    def retry_latch(self):
        """Retry durability without overwriting any existing generic first cause."""
        if getattr(self, "halt_retry", None) is None:
            return True
        text, replace = self.halt_retry
        try:
            if not replace and os.path.lexists(self.latch):
                descriptor = os.open(self.latch, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
                with os.fdopen(descriptor, "rb") as source:
                    if not stat.S_ISREG(os.fstat(source.fileno()).st_mode):
                        raise ValueError("terminal latch is not regular")
                    os.fsync(source.fileno())
                descriptor = os.open(self.store, os.O_RDONLY | os.O_DIRECTORY)
                try:
                    os.fsync(descriptor)
                finally:
                    os.close(descriptor)
            else:
                self.persist_latch(text, replace=replace)
        except (OSError, ValueError) as error:
            message = str(error)
            if getattr(self, "halt_error", None) != message:
                print(f"etna_supervisor_halt_persistence_pending: {message}", flush=True)
                self.halt_error = message
            return False
        self.halt_retry = None
        self.halt_error = None
        return True

    def signer_uncertain(self):
        """The original HRS sibling fence applies to every authority generation."""
        try:
            self.state.with_name(self.state.name + ".uncertain").lstat()
        except FileNotFoundError:
            return False
        except OSError:
            return True
        return True

    def halt(self, reason, terminal_snapshot=None):
        self.halted = True
        pending = reason + "\n"
        created = not os.path.lexists(self.latch)
        evidence = self.expected_supersession(terminal_snapshot) if created else None
        durable = False
        if created:
            durable = self.retain_latch(pending)
        signer_failed = self.stop()
        # A generic durable marker blocks acknowledgement throughout shutdown and
        # after any crash. Only a clean join and unchanged first-cause bytes allow
        # the exact expected supersession to become acknowledgeable.
        try:
            if (created and durable and evidence and not signer_failed and not self.signer_uncertain()
                    and self.expected_supersession(terminal_snapshot) == evidence
                    and self.latch.read_bytes() == pending.encode()):
                self.retain_latch(json.dumps(evidence, sort_keys=True) + "\n", replace=True)
        except OSError:
            self.retain_latch(pending)
        print("etna_supervisor_halted: operator repair required", flush=True)

    def tick(self):
        if getattr(self, "halted", False) or os.path.lexists(self.latch):
            if self.comet is not None or self.signer is not None:
                self.stop()
            self.retry_latch()
            return
        observed = self.read_observation(self.events)
        if observed is not None and observed[0] != self.prior_observation:
            _, event = observed
            self.session = event["session_id"]
            sequence = event["sequence"]
            if sequence > 0 and sequence != self.last_event:
                self.pending = True
                self.last_event = sequence
        # A signer exit is never authorization to bootstrap or retry broken signing state.
        if self.signer.poll() is not None:
            self.halt("signer exited; inspect diagnostics")
            return
        if self.comet is None:
            self.start_comet_once_trusted()
            return
        comet_exited = self.comet.poll() is not None
        try:
            status = self.observe()
        except (OSError, ValueError, KeyError):
            self.observed_loss = True
            self.pending = self.pending or comet_exited
            return  # Unavailable observation never authorizes recovery.
        # Authenticated contradictions and every halted reason but an app lifecycle stop
        # remain sticky.
        if status.get("generation") not in (None, self.generation) or status.get("chain_id") not in (None, self.chain):
            self.halt("terminal deployment identity")
            return
        lifecycle_stop = status.get("reason") in APP_LIFECYCLE_STOPS
        if status.get("phase") == "halted" and lifecycle_stop:
            self.observed_loss = True
            self.pending = True
            return
        if status.get("phase") == "halted":
            self.halt("terminal app trust or deployment identity", status)
            return
        # Session changes after app restart also leave stock Comet at a refused step.
        session = status["session_id"]
        if self.session is not None and session != self.session:
            self.pending = True
        ready = self.ready(status)
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
            if self.stop():
                self.halt("signer exited during recovery; inspect diagnostics")
                return
            self.start(await_trust=True)
            print("etna_supervisor_awaiting_trust: Comet starts after the signer's fresh session is Ready", flush=True)

    def ready(self, status):
        """The app's trust phase is its only readiness signal (SYNC-9-15), bound to this identity."""
        origin = status.get("recovery_origin")
        return (status.get("phase") == "ready" and status.get("chain_id") == self.chain
                and status.get("generation") == self.generation
                and (self.generation == 0 or
                     (isinstance(origin, dict) and origin.get("generation") == self.generation)))

    def start_comet_once_trusted(self):
        """Recovery: start Comet only when the signer's own published session is Ready.

        Comet is stopped, so no step can be refused meanwhile. Unavailable observation and
        app shutdown keep waiting; the signer begins a new session on a fresh app.
        """
        try:
            status = self.observe()
        except (OSError, ValueError, KeyError):
            return  # Unavailable observation never authorizes starting Comet.
        if status.get("generation") not in (None, self.generation) or status.get("chain_id") not in (None, self.chain):
            self.halt("terminal deployment identity")
            return
        if status.get("phase") == "halted":
            if status.get("reason") not in APP_LIFECYCLE_STOPS:
                self.halt("terminal app trust or deployment identity", status)
            return
        if self.session is None or status["session_id"] != self.session:
            return  # The signer has not published the session it begins for this transport.
        if self.ready(status):
            self.start_comet()
            self.was_ready = True  # A later trust loss explains a Comet exit.
            print("etna_supervisor_recovered_after_refusal", flush=True)
            return
        target, head = status.get("target"), status.get("committed_head")
        if (status.get("phase") == "catching_up" and isinstance(target, dict) and isinstance(head, dict)
                and isinstance(target.get("height"), int) and isinstance(head.get("height"), int)
                and head["height"] < target["height"]):
            # Only Comet can commit up to this checkpoint, so waiting could never end.
            print("etna_supervisor_trust_needs_comet: starting signer and Comet together", flush=True)
            if self.stop():
                self.halt("signer exited during recovery; inspect diagnostics")
                return
            self.start()
            return
        state = (self.session, status.get("phase"), status.get("reason"))
        if self.awaiting is None or self.awaiting[0] != state or time.monotonic() - self.awaiting[1] > 60:
            self.awaiting = (state, time.monotonic())
            print(f"etna_supervisor_awaiting_trust: session={state[0]} phase={state[1]} reason={state[2]}", flush=True)

    def run(self):
        self.acquire_owner()
        def shutdown(_signal, _frame):
            self.running = False
        signal.signal(signal.SIGTERM, shutdown)
        signal.signal(signal.SIGINT, shutdown)
        try:
            if self.signer_uncertain():
                self.record_signer_failure()
                self.halt("retained signer uncertainty fence; inspect signing authority")
            elif not os.path.lexists(self.latch):
                self.start()
            while self.running:
                self.tick()
                time.sleep(.1)
        finally:
            if self.stop():
                self.halt("signer exited during shutdown; inspect diagnostics")
            while not self.retry_latch():
                time.sleep(.1)
            for descriptor in self.owner_fds:
                os.close(descriptor)
            self.owner_fds = []


if __name__ == "__main__":
    try:
        Supervisor().run()
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f"etna supervisor: {error}", file=sys.stderr)
        sys.exit(1)
