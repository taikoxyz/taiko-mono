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

A signer exit the supervisor did not ask for restarts the pair the same way: Comet is
reaped, and a fresh signer with the same state path and --await-trust gets Comet once its
new session is Ready. Unsafe signing state never restarts (SYNC-9-14): exit 3, a retained
fence, a signer that had to be SIGKILLed on stop, and five exits within 600 s latch. All but
the last also leave validator-supervisor.signer-unsafe in the app store, independent of the
first-cause latch, and <chain_id>.signer-unsafe beside the domains log, which survives a fresh
app store and which the signer itself refuses (RECOV-8.2-3); a kill is recorded in both before
the SIGKILL is sent.
"""
import fcntl
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
# The signer's exit status for lost or uncertain signing state (RECOV-8.2-3). It, a retained
# fence and a signer the supervisor had to SIGKILL latch; every other exit restarts the pair,
# up to SIGNER_CRASH_LIMIT exits within SIGNER_CRASH_WINDOW seconds (SYNC-9-14).
SIGNER_UNSAFE_EXIT = 3
SIGNER_CRASH_LIMIT = 5
SIGNER_CRASH_WINDOW = 600.0
# Seconds a signer has to exit after SIGTERM before stop() kills it.
SIGNER_STOP_GRACE = 5
SIGNER_UNSAFE_LATCH = ("signer refused unsafe signing state; inspect its stderr, `<state>.uncertain` "
                       "and the domains log")
# The durable record, beside and independent of the first-cause latch, that the signer's state
# may be uncertain: a signer the supervisor kills (written before the SIGKILL), an unsafe exit, or
# a fence. run(), start() and tick refuse while it exists; only an operator repair removes it.
SIGNER_UNSAFE_RECORD = "validator-supervisor.signer-unsafe"
# The same evidence as <chain_id> + this suffix in the domains log's directory, on the log's own
# volume: a fresh app store loses the record, and the signer refuses this marker with exit 3.
SIGNER_UNSAFE_MARKER_SUFFIX = ".signer-unsafe"
SIGNER_UNSAFE_RECORD_LATCH = ("retained signer-unsafe record or marker; inspect "
                              "validator-supervisor.signer-unsafe, <chain_id>.signer-unsafe beside the "
                              "domains log, the signer's stderr, `<state>.uncertain` and the domains log")
SIGNER_KILLED_LATCH = (f"signer did not stop within {SIGNER_STOP_GRACE}s of SIGTERM and was killed; "
                       "its signing state may be uncertain; inspect its stderr, the state volume, "
                       "`<state>.uncertain` and the domains log")


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
        self.chain = os.environ["ETNA_CHAIN_ID"]
        # One stock HRS per full chain_id: the chain_id binds the generation, and init-state
        # created <ETNA_PRIV_STATE_DIR>/<chain_id>.json and logged it in ETNA_DOMAINS_LOG
        # (RECOV-8.2-1). Their existence is the signer's check: it exits 3 on a lost state.
        if not self.chain or "/" in self.chain or self.chain in (".", ".."):
            raise ValueError("ETNA_CHAIN_ID must name one signing state file")
        self.state_dir = Path(os.environ["ETNA_PRIV_STATE_DIR"]).resolve()
        self.state = self.state_dir / (self.chain + ".json")
        self.domains_log = Path(os.environ["ETNA_DOMAINS_LOG"]).resolve()
        # Comet runs as another UID and must never reach the registered key, the HRS states or
        # the log, and the app store never holds them.
        for path in (self.key, self.state_dir, self.domains_log):
            if path.is_relative_to(self.home) or path.is_relative_to(self.store):
                raise ValueError("registered key, signing state and domains log must be outside the Comet home and app store")
        self.denial_route = self.validate_denial_route()
        self.events = self.denial_route
        self.prior_observation = None
        config = tomllib.loads((self.home / "config/config.toml").read_text())
        address = config.get("priv_validator_laddr", "")
        if json.loads((self.home / "config/genesis.json").read_text())["chain_id"] != self.chain:
            raise ValueError("signer chain ID differs from Comet genesis")
        # Refuse half a Comet identity before any child starts.
        identity = self.comet_identity()
        if address.startswith("unix://"):
            # The configured path only selects Unix mode. Every pair start gets a fresh
            # name in run/, so no Comet-owned stale inode ever needs to be pinned or probed.
            self.unix_run = self.home / "run"
            self.run_owner = identity[0] if identity is not None else os.geteuid()
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
            "--priv-state", str(self.state), "--domains-log", str(self.domains_log)]
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
        # Monotonic times of non-unsafe signer exits; in memory only, so a supervisor restart
        # resets it and container CrashLoopBackOff bounds that case.
        self.crashes = []
        self.signer_killed = False  # stop() had to SIGKILL a running signer

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

    def validate_denial_route(self):
        """Check the signer's diagnostic destination before any child can write.

        It never replaces the key, any chain's HRS or fence, or the domains log.
        """
        default = self.store / "signer-denial.json"
        requested = Path(os.environ.get("ETNA_DENIAL_FILE", str(default)))
        if not requested.is_absolute() or ".." in requested.parts:
            raise ValueError("invalid signer diagnostic path")
        route = requested.parent.resolve(strict=True) / requested.name
        parent = route.parent.stat()
        if parent.st_uid not in (0, os.geteuid()) or parent.st_mode & 0o022:
            raise ValueError("unprotected signer diagnostic parent")
        if (route == self.key or route.is_relative_to(self.state_dir) or route.is_relative_to(self.home)
                or route.is_relative_to(self.domains_log.parent)
                or (route != default and route.is_relative_to(self.store)) or route.is_symlink()):
            raise ValueError("signer diagnostic aliases protected state")
        self.read_observation(route)
        return route

    def acquire_owner(self):
        """Hold the Comet home's sibling owner lock for the supervisor's lifetime.

        Every child inherits this one description (child_options), so while this supervisor or a
        surviving child of an earlier one lives, another supervisor for the home is refused.
        """
        parent = self.home.parent
        metadata = parent.stat()
        if (metadata.st_mode & 0o022 or metadata.st_uid not in (0, os.geteuid())):
            raise ValueError("component ownership is busy; unsafe owner directory")
        path = parent / ("." + self.home.name + ".etna-owner.lock")
        descriptor = os.open(path, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW | os.O_CLOEXEC, 0o600)
        try:
            opened, named = os.fstat(descriptor), path.lstat()
            if (not stat.S_ISREG(opened.st_mode) or opened.st_mode & 0o077
                    or opened.st_uid != os.geteuid() or opened.st_nlink != 1
                    or (opened.st_dev, opened.st_ino) != (named.st_dev, named.st_ino)):
                raise ValueError("component ownership is busy; unsafe owner inode")
            fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            os.close(descriptor)
            raise ValueError("component ownership is busy; stop external owner or surviving children") from error
        except BaseException:
            os.close(descriptor)
            raise
        self.owner_fds = [descriptor]

    def child_options(self):
        """Run a child with the owner lock, in its own session, without the argv overrides."""
        environment = dict(os.environ)
        for name in ("ETNA_SIGNER_COMMAND_JSON", "ETNA_COMET_COMMAND_JSON"):
            environment.pop(name, None)
        # Inheriting the owner lock keeps "supervisor lock held => no child of an earlier
        # supervisor survives", which the signer socket cleanup in fresh_transport relies on.
        # A terminal interrupt must reach the supervisor first, so it can stop/reap Comet
        # before the signer. Separate sessions do not authorize group signaling.
        return dict(pass_fds=tuple(self.owner_fds), env=environment, start_new_session=True)

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
        """Reap Comet, then the signer, and return the signer's exit status (None if none ran).

        Never touches HRS, WAL or history, and never writes the first-cause latch: callers latch
        an unsafe status (signer_unsafe). A signer still running SIGNER_STOP_GRACE seconds after
        SIGTERM may be blocked in a failed fsync or its fence write on a failing state volume
        (RECOV-8.2-3, SYNC-9-13), in D-state, where SIGKILL cannot reap it until that I/O
        returns. So the kill is recorded durably in the app store and beside the domains log
        before the SIGKILL is sent, and a supervisor killed during the unbounded wait that follows
        still leaves both. While either cannot be written, the signer is left running and stop()
        keeps retrying, so a SIGTERM to the supervisor waits too.
        """
        code = None
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
            running = self.signer.poll() is None
            if running:
                self.signer.terminate()
            try:
                self.signer.wait(timeout=SIGNER_STOP_GRACE)
            except subprocess.TimeoutExpired:
                self.record_signer_kill(f"signer {self.signer.pid} did not stop within {SIGNER_STOP_GRACE}s "
                                        "of SIGTERM; recording before SIGKILL")
                self.signer.kill()
                self.signer.wait()
            code = self.signer.returncode
            if running and code == -signal.SIGKILL and not getattr(self, "signer_killed", False):
                # Another party's SIGKILL during the grace period, recorded once reaped.
                self.record_signer_kill(f"signer {self.signer.pid} was SIGKILLed while stopping")
            self.signer = None
        return code

    def record_signer_kill(self, detail):
        """Mark the signer killed and make that durable in the record and the marker, retrying
        until both are on disk."""
        self.signer_killed = True
        print(f"etna_supervisor_signer_killed: {detail}", flush=True)
        while not self.record_unsafe_signer(SIGNER_KILLED_LATCH + "\n"):
            time.sleep(.1)
        print(f"etna_supervisor_signer_kill_recorded: {self.unsafe_record} and {self.unsafe_marker}", flush=True)

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
        """Start a fresh signer, and Comet with it unless the signer must first be trusted.

        Runs only with both earlier children reaped, so their flocks are released, and never
        while a fence or the unsafe record exists. Every start gets a fresh transport
        (fresh_transport).
        """
        if self.refuse_unsafe_start():
            return
        self.validate_denial_route()
        self.address = self.fresh_transport()
        # Never unlink an operator-selected file; ignore its old inode on restart.
        previous = self.read_observation(self.events)
        self.prior_observation = previous[0] if previous is not None else None
        self.last_event = None
        args = self.signer_command + ["--comet-signer-addr", self.address, "--denial-file", str(self.events)]
        self.signer = subprocess.Popen(args + (["--await-trust"] if await_trust else []), **self.child_options())
        self.pending = False
        self.session = None
        self.observed_loss = False
        self.was_ready = False
        self.awaiting = None
        if not await_trust:
            self.start_comet()
        print("etna_supervisor_started", flush=True)

    @staticmethod
    def comet_identity():
        """ETNA_COMET_UID and ETNA_COMET_GID together, or neither (None: the supervisor's own).

        Half a configuration fails closed, as in the full-node launcher.
        """
        uid, gid = os.environ.get("ETNA_COMET_UID"), os.environ.get("ETNA_COMET_GID")
        if uid is None and gid is None:
            return None
        if uid is None or gid is None:
            raise ValueError("ETNA_COMET_UID and ETNA_COMET_GID must be set together")
        return int(uid), int(gid)

    def start_comet(self):
        command = self.comet_command
        if self.unix_run is not None:
            command = command + ["--priv_validator_laddr", self.address]
        identity = {}
        configured = self.comet_identity()
        if configured is not None:
            # The supported image keeps registered FilePV secrets inaccessible to Comet.
            uid, gid = configured
            # A same-identity unprivileged local runner cannot call setgroups. Preserve its
            # existing identity; privileged/different-identity launches still drop all groups.
            if os.geteuid() == 0 or uid != os.geteuid() or gid != os.getegid():
                identity = dict(user=uid, group=gid, extra_groups=[])
        self.comet = subprocess.Popen(command, cwd=self.home, **identity, **self.child_options())

    @property
    def unsafe_record(self):
        return self.store / SIGNER_UNSAFE_RECORD

    @property
    def unsafe_marker(self):
        """This chain_id's signer-unsafe marker beside the domains log, where the signer checks."""
        return self.domains_log.parent / (self.chain + SIGNER_UNSAFE_MARKER_SUFFIX)

    @staticmethod
    def present(path):
        """Whether any inode exists at path. Only ENOENT proves absence; any other error
        (EACCES, EIO) counts as present, as for the fence (RECOV-8.2-3)."""
        try:
            os.lstat(path)
        except FileNotFoundError:
            return False
        except OSError:
            return True
        return True

    def unsafe_evidence(self):
        """The record in the app store or the marker beside the domains log exists."""
        return self.present(self.unsafe_record) or self.present(self.unsafe_marker)

    @staticmethod
    def persist_record(path, text):
        """Make a plain-text record durable: create it exclusively, or keep an existing one as it
        is; then fsync it and its directory."""
        try:
            created = path.open("x")
        except FileExistsError:
            descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
            with os.fdopen(descriptor, "rb") as source:
                if not stat.S_ISREG(os.fstat(source.fileno()).st_mode):
                    raise ValueError(f"{path.name} is not regular")
                os.fsync(source.fileno())
        else:
            with created as file:
                file.write(text)
                file.flush()
                os.fsync(file.fileno())
        directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)

    def persistence_pending(self, error):
        message = str(error)
        if getattr(self, "halt_error", None) != message:
            print(f"etna_supervisor_halt_persistence_pending: {message}", flush=True)
            self.halt_error = message

    def record_unsafe_signer(self, text):
        """Durably record that the signer's state may be uncertain, apart from the first-cause
        latch, so repairing only another latched cause never restarts it (RECOV-8.2-3): the
        record in the app store, and the marker beside the domains log, which a fresh app store
        cannot lose and which the signer refuses."""
        self.halted = True
        if getattr(self, "unsafe_retry", None) is None:
            self.unsafe_retry = text
        return self.retry_unsafe_record()

    def retry_unsafe_record(self):
        """Persist the pending record and marker; True only once both are durable. Each attempt
        tries both, so one failing volume never holds back the other's evidence."""
        text = getattr(self, "unsafe_retry", None)
        if text is None:
            return True
        failure = None
        for path in (self.unsafe_record, self.unsafe_marker):
            try:
                self.persist_record(path, text)
            except (OSError, ValueError) as error:
                failure = failure or error
        if failure is not None:
            self.persistence_pending(failure)
            return False
        self.unsafe_retry = None
        return True

    def retain_latch(self, text):
        """Keep the owner alive and quiescent if terminal evidence cannot be flushed.

        A first cause still waiting for persistence is kept; a later cause never replaces it.
        """
        self.halted = True
        if getattr(self, "halt_retry", None) is None:
            self.halt_retry = text
        return self.retry_latch()

    def retry_latch(self):
        """Retry durability without overwriting any existing first cause."""
        if getattr(self, "halt_retry", None) is None:
            return True
        try:
            self.persist_record(self.latch, self.halt_retry)
        except (OSError, ValueError) as error:
            self.persistence_pending(error)
            return False
        self.halt_retry = None
        self.halt_error = None
        return True

    def signer_unsafe(self, code):
        """Whether a signer exit forbids a restart (RECOV-8.2-3, SYNC-9-14): exit 3, a fence
        beside the HRS, a signer that stop() had to kill, or a retained unsafe record or marker."""
        return (code == SIGNER_UNSAFE_EXIT or getattr(self, "signer_killed", False) or self.signer_uncertain()
                or self.unsafe_evidence())

    def unsafe_reason(self):
        return SIGNER_KILLED_LATCH if getattr(self, "signer_killed", False) else SIGNER_UNSAFE_LATCH

    def halt_if_unsafe(self, code):
        """Latch an unsafe signer exit status; True if it did."""
        if not self.signer_unsafe(code):
            return False
        self.record_unsafe_signer(self.unsafe_reason() + "\n")
        self.halt(self.unsafe_reason())
        return True

    def refuse_unsafe_start(self):
        """Halt instead of starting a signer over a fence or a retained unsafe record or marker,
        including on a fresh app store that has only the marker."""
        if self.signer_uncertain():
            self.halt(SIGNER_UNSAFE_LATCH)
            return True
        if self.unsafe_evidence():
            self.halt(SIGNER_UNSAFE_RECORD_LATCH)
            return True
        return False

    def signer_exited(self, code):
        """Handle a signer exit the supervisor did not ask for.

        Exit 3, a fence and a crash loop latch. Any other exit (0, 1, 2 or a signal) restarts the
        pair: Comet is reaped, then a fresh signer with the same HRS path begins a new closed
        session on a fresh transport and dials Comet only once that session is Ready; Comet
        starts then (start_comet_once_trusted, SYNC-9-12). Stock FilePV continues from the HRS
        on disk: no signature was released before both fsyncs (SYNC-9-13).
        """
        if self.halt_if_unsafe(code):
            return
        now = time.monotonic()
        self.crashes = [at for at in self.crashes if now - at < SIGNER_CRASH_WINDOW] + [now]
        if len(self.crashes) >= SIGNER_CRASH_LIMIT:
            self.halt(f"signer exited {SIGNER_CRASH_LIMIT} times within {SIGNER_CRASH_WINDOW:g}s; inspect diagnostics")
            return
        print(f"etna_supervisor_signer_restart: exit status {code}, {len(self.crashes)} of {SIGNER_CRASH_LIMIT} "
              f"within {SIGNER_CRASH_WINDOW:g}s", flush=True)
        if self.halt_if_unsafe(self.stop()):
            return
        self.start(await_trust=True)

    def signer_uncertain(self):
        """The signer's fence beside this chain's HRS."""
        return self.present(self.state.with_name(self.state.name + ".uncertain"))

    def halt(self, reason):
        """Latch the first cause durably, then stop Comet and the signer.

        A superseded generation (RECOV-8-14/16) is one such cause when the app reports "halted":
        this plain-text latch and the app's fatal evidence stay in the old store, which
        `abci-recover install` never reuses. An app that exits on the safety halt instead leaves
        observation failing, so nothing is latched, and signing stays refused.
        """
        self.retain_latch(reason + "\n")
        # A signer killed, or exiting unsafe, while halting for another cause keeps its own record.
        if self.signer_unsafe(self.stop()):
            self.record_unsafe_signer(self.unsafe_reason() + "\n")
        print("etna_supervisor_halted: operator repair required", flush=True)

    def tick(self):
        if getattr(self, "halted", False) or self.present(self.latch) or self.unsafe_evidence():
            if self.comet is not None or self.signer is not None:
                # An existing latch keeps its first cause, but never hides an unsafe exit.
                if self.signer_unsafe(self.stop()):
                    self.record_unsafe_signer(self.unsafe_reason() + "\n")
            self.halted = True
            self.retry_latch()
            self.retry_unsafe_record()
            return
        observed = self.read_observation(self.events)
        if observed is not None and observed[0] != self.prior_observation:
            _, event = observed
            self.session = event["session_id"]
            sequence = event["sequence"]
            if sequence > 0 and sequence != self.last_event:
                self.pending = True
                self.last_event = sequence
        # A signer exit never authorizes bootstrapping or resetting signing state; only an
        # ordinary crash restarts the pair with the same state (signer_exited).
        code = self.signer.poll()
        if code is not None:
            self.signer_exited(code)
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
        # remain sticky. The chain_id binds the generation, so another generation is another
        # chain_id.
        if status.get("chain_id") not in (None, self.chain):
            self.halt("terminal deployment identity")
            return
        lifecycle_stop = status.get("reason") in APP_LIFECYCLE_STOPS
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
            if self.halt_if_unsafe(self.stop()):
                return
            self.start(await_trust=True)
            print("etna_supervisor_awaiting_trust: Comet starts after the signer's fresh session is Ready", flush=True)

    def ready(self, status):
        """The app's trust phase is its only readiness signal (SYNC-9-15), bound to this chain_id."""
        return status.get("phase") == "ready" and status.get("chain_id") == self.chain

    def start_comet_once_trusted(self):
        """Recovery: start Comet only when the signer's own published session is Ready.

        Comet is stopped, so no step can be refused meanwhile. Unavailable observation and
        app shutdown keep waiting; the signer begins a new session on a fresh app.
        """
        try:
            status = self.observe()
        except (OSError, ValueError, KeyError):
            return  # Unavailable observation never authorizes starting Comet.
        if status.get("chain_id") not in (None, self.chain):
            self.halt("terminal deployment identity")
            return
        if status.get("phase") == "halted":
            if status.get("reason") not in APP_LIFECYCLE_STOPS:
                self.halt("terminal app trust or deployment identity")
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
            if self.halt_if_unsafe(self.stop()):
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
            if not self.refuse_unsafe_start() and not self.present(self.latch):
                self.start()
            while self.running:
                self.tick()
                time.sleep(.1)
        finally:
            # A restartAlways supervisor restarts the signer, so an unsafe exit at shutdown latches.
            self.halt_if_unsafe(self.stop())
            while not (self.retry_latch() and self.retry_unsafe_record()):
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
