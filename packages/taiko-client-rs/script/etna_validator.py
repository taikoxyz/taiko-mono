#!/usr/bin/env python3
"""Supervise stock Comet and its guarded signer, retaining authoritative storage.

Only private observation and signer refusal events trigger recovery. Neither is
signing authorization: every new transport still obtains a fresh closed session.
A durable terminal latch keeps restartAlways containers quiescent until repair.

Every start runs the signer and Comet together. The signer connects to Comet's
priv_validator_laddr promptly and answers PubKey and Ping while trust is closed
(START-10-6); each connection begins its own closed trust session, and the signer
holds a signing request for at most 3.5 s while that session is still being
authenticated. Stock Comet gives up at once only on a signing request the signer
answered with an error, and retries any other failure (no answer within its fixed
5 s signer read timeout, a dropped connection, a malformed answer). So the signer
always refuses explicitly and in time, and Comet never retries such a refusal; only
the WAL replay of a restarted Comet asks for that step again. Recovery therefore
runs in this order: a published refusal, then waiting for Ready trust, then a stop
of both children and a fresh start of the pair, whose new session the app checks
while Comet's handshake runs and whose replayed step the signer holds until that
check passes (SYNC-9-12). Another refusal repeats the guarded restart once trust is
available again.

Comet's first GetPubKey has a 3 s accept timeout. If Comet exits before the
signer's transport connected, the pair is started again with the same signer
state, without a latch (START-10-6).

A signer exit the supervisor did not ask for restarts the pair the same way. Unsafe
signing state never restarts (SYNC-9-14): exit 3, a retained fence, a signer that had
to be SIGKILLed on stop, and five exits within 600 s latch. All but the last also leave
validator-supervisor.signer-unsafe in the app store, independent of the first-cause
latch, and <chain_id>.signer-unsafe beside the domains log, which survives a fresh app
store and which the signer itself refuses (RECOV-8.2-3); a kill is recorded in both
before the SIGKILL is sent.

Before every Comet start the supervisor reads and checks the effective Comet configuration again
(config.toml, the Comet argv and the CMT_* environment, START-10-6), copies the executable into a
sealed memfd whose digest must be the one the deployment manifest pins and execs exactly that copy
(CONS-3.1-1), and, with Comet stopped, deletes the node's pending-evidence store and nothing else
(CONS-3.1-10). The executable and pending-evidence checks are shared with the full-node launcher
(etna_comet_guard.py). A failed check stops the supervisor before any child of that start runs.

The supervisor also serves the signer's authenticated channel (RECOV-8.2-2): a Unix socket in
its private run directory that only the signer it started may use (peer credentials). Over it
the signer learns, on every Comet connection, which Comet process the supervisor started (PID
and kernel start time) and the store instance ID of the home it runs on, read from
<home>/data/etna-store-instance. A home whose ID file is missing, a first start included, gets a
fresh ID before Comet starts: its stores are new, or rebuilt as far as the signer can tell.
"""
import base64
import fcntl
import importlib.util
import ipaddress
import json
import os
from pathlib import Path
import secrets
import select
import signal
import socket
import stat
import struct
import subprocess
import sys
import threading
import time
import tomllib


def comet_guard():
    """The pre-start checks shared with the full-node launcher (etna_comet_guard.py beside this
    script), loaded by path so that isolated interpreters (python3 -I, PYTHONSAFEPATH) find them."""
    spec = importlib.util.spec_from_file_location("etna_comet_guard", Path(__file__).resolve().with_name("etna_comet_guard.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


GUARD = comet_guard()

# These exact process-lifecycle revocations are transient only across app restart.
APP_LIFECYCLE_STOPS = ("ABCI server stopped", "app worker stopped", "checkpoint control listener stopped")
# Each signer+Comet pair rendezvouses at <home>/run/signer-<16 hex>.sock. Names with this
# prefix and suffix belong to the supervisor; stale ones are removed before every start.
SIGNER_SOCKET_PREFIX = "signer-"
SIGNER_SOCKET_SUFFIX = ".sock"
MAX_UNIX_SOCKET_PATH = 103  # macOS sun_path holds 104 bytes with the terminating NUL
# The app's one private trust-control version. Every response carries recovery_origin:
# null for generation zero, the authenticated origin after recovery, whose fallback_keys_hash
# replaced version 1's committee hash.
CONTROL_SCHEMA = 2
# The signer's exit status for lost or uncertain signing state (RECOV-8.2-3). It, a retained
# fence and a signer the supervisor had to SIGKILL latch; every other exit restarts the pair,
# up to SIGNER_CRASH_LIMIT exits within SIGNER_CRASH_WINDOW seconds (SYNC-9-14).
SIGNER_UNSAFE_EXIT = 3
SIGNER_CRASH_LIMIT = 5
SIGNER_CRASH_WINDOW = 600.0
# Seconds a signer has to exit after SIGTERM before stop() kills it.
SIGNER_STOP_GRACE = 5
SIGNER_UNSAFE_LATCH = ("signer refused unsafe signing state; inspect its stderr, `<state>.uncertain`, "
                       "`<state>.inflight` and the domains log")
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
# Seconds before a pair whose Comet exited before the signer connected starts again.
MISSED_CONNECTION_RETRY = 1.0
# The engine every validator runs (CONS-3.1-1): the deployment manifest names its official
# executable per platform by digest, and the supervisor refuses any other executable.
COMET_MANIFEST_SCHEMA, COMET_RELEASE, COMET_SOURCE_COMMIT = (
    GUARD.COMET_MANIFEST_SCHEMA, GUARD.COMET_RELEASE, GUARD.COMET_SOURCE_COMMIT)
comet_platform, sha256_file = GUARD.comet_platform, GUARD.sha256_file
# The supervisor channel's one wire version, its socket's name in the private run directory and
# the bound on one request line.
SUPERVISOR_SCHEMA = 1
SUPERVISOR_SOCKET = "signer.sock"
MAX_SUPERVISOR_FRAME = 16384
# The store instance ID file in the Comet home: 32 lowercase hex characters (128 random bits) and
# a newline. Every path that creates, imports, restores or rebuilds the stores writes a fresh one;
# the signer binds its key to it (RECOV-8.2-2). It is never copied from another home.
STORE_INSTANCE = "data/etna-store-instance"
# Database backends whose stores live at <db_dir>/<name>.db in stock cometbft-db v0.14.1 and
# that the official executable supports.
COMET_DB_BACKENDS = GUARD.COMET_DB_BACKENDS


def peer_list(value):
    """Stock splitAndTrimEmpty(value, ",", " "): the non-empty, space-trimmed list entries."""
    return [entry.strip(" ") for entry in value.split(",") if entry.strip(" ")]


def require_false(value, _runtime):
    return value is False


# CometBFT v0.40.0 settings every validator pins (START-10-6), by Viper path: the stock default
# and the requirement the effective value must meet. Adaptive sync runs consensus while block
# sync catches up, which can sign votes for heights already decided; a nonzero double-sign check
# height stops a restarted Comet whose key signed recent blocks; a node's clock stays synchronized
# well inside the 60 s block time tolerance (CONS-3.4-12). A validator exchanges P2P messages only
# with nodes its operator lists: peer exchange off, no seeds or seed mode, no unsafe RPC that dials
# arbitrary peers and the stock (non-libp2p) switch, so it dials only persistent_peers; no inbound
# slot, so only unconditional peers connect inbound, and those are exactly the listed inbound IDs
# (LIMIT-12-2). Unlike the first three, the stock defaults of pex, max_num_inbound_peers and
# unconditional_peer_ids must be overridden.
PINNED_SETTINGS = {
    "blocksync.adaptive_sync": (False, "bool", "false", require_false),
    "consensus.double_sign_check_height": (0, "int", "0", lambda value, _: type(value) is int and value == 0),
    "consensus.block_time_tolerance": ("1m0s", "duration", "60s",
                                       lambda value, _: value in ("1m0s", "60s", "1m")),
    "p2p.pex": (True, "bool", "false", require_false),
    "p2p.seeds": ("", "str", "empty", lambda value, _: isinstance(value, str) and not peer_list(value)),
    "p2p.seed_mode": (False, "bool", "false", require_false),
    "p2p.libp2p.enabled": (False, "bool", "false", require_false),
    "rpc.unsafe": (False, "bool", "false", require_false),
    "p2p.max_num_inbound_peers": (40, "int", "0", lambda value, _: type(value) is int and value == 0),
    "p2p.unconditional_peer_ids": ("", "str", "exactly ETNA_P2P_INBOUND_PEER_IDS",
                                   lambda value, inbound: isinstance(value, str)
                                   and sorted(peer_list(value)) == inbound),
}
# Settings the supervisor reads but does not pin, by Viper path, with their stock defaults.
READ_SETTINGS = {"db_dir": "data", "db_backend": "goleveldb", "node_key_file": "config/node_key.json",
                 "consensus.wal_file": "data/cs.wal/wal"}
# The log observer of RECOV-8.2-2 ("Observing stock v0.40.0 replay") parses Comet's records in the
# stock JSON log format, from a pipe it owns, and needs the consensus module's Info and Error
# records. Stock defaults are log_format "plain" and log_level "info".
OBSERVER_SETTINGS = {"log_format": "plain", "log_level": "info"}
OBSERVER_FORMAT = "json"
# Consensus records (module "consensus") that open, end or cancel a replay attempt.
REPLAY_OPEN = "Catchup by replaying consensus messages"
REPLAY_DONE = "Replay: Done"
REPLAY_CANCEL = ("data has been corrupted in last height of consensus WAL",
                 "the WAL file is corrupted; attempting repair", "the WAL repair failed",
                 "successful WAL repair", "error on catchup replay; proceeding to start state anyway",
                 "Replay: wal.group.Search returned EOF", "CONSENSUS FAILURE!!!")
REPLAY_REPAIRED = "successful WAL repair"
REPLAY_COMMIT = "finalizing commit of block"
# Restarts of the pair after a stock repair of a torn WAL tail that the startup check found.
MAX_REPAIR_RESTARTS = 3
# The planned ruleset upgrade during a pause (START-10.1-14b, RECOV-8.2-2): the operator's request
# file in the run directory arms the signer to stop on a precommit, unless same-height replay could
# not confirm that precommit after the upgrade (stop_refusal), in which case the outcome names the
# reason and nothing is armed; once the signer reports that its gate closed after one, the
# supervisor waits STOP_GRACE seconds for Comet to record and send that precommit, stops the pair,
# writes the outcome beside the request and stays quiescent.
STOP_REQUEST = "stop-on-precommit"
STOP_DONE = "stop-on-precommit.done"
STOP_GRACE = 2.0
# Go strconv.ParseBool, which Viper's weak decoding applies to a CMT_* string.
ENV_BOOLS = {"1": True, "t": True, "T": True, "TRUE": True, "true": True, "True": True,
             "0": False, "f": False, "F": False, "FALSE": False, "false": False, "False": False}
BASE58 = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"


def base58(raw):
    """Bitcoin-alphabet base58, as libp2p peer IDs are printed."""
    number, out = int.from_bytes(raw, "big"), ""
    while number:
        number, digit = divmod(number, 58)
        out = BASE58[digit] + out
    return "1" * (len(raw) - len(raw.lstrip(b"\0"))) + out


def ed25519_peer_id(path, what):
    """The libp2p peer ID of the Ed25519 key in a stock node-key JSON file: the identity multihash
    of the protobuf public key {Type: Ed25519, Data}, base58-encoded (go-libp2p IDFromPublicKey)."""
    try:
        document = json.loads(Path(path).read_bytes())
        key = document["priv_key"]
        raw = base64.b64decode(key["value"], validate=True)
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise ValueError(f"{what} {path} is not a stock Ed25519 node key: {error}") from error
    if set(document) != {"priv_key"} or key.get("type") != "tendermint/PrivKeyEd25519" or len(raw) != 64:
        raise ValueError(f"{what} {path} is not a stock Ed25519 node key")
    public = b"\x08\x01\x12\x20" + raw[32:]
    return base58(b"\x00" + bytes([len(public)]) + public)


def process_start(pid):
    """A live process's start time in clock ticks since boot (/proc/<pid>/stat field 22), which
    with its PID identifies it across PID reuse; None where the platform has no /proc."""
    if not sys.platform.startswith("linux"):
        return None
    raw = Path(f"/proc/{pid}/stat").read_bytes()
    fields = raw[raw.rindex(b")") + 1:].split()
    return fields[19].decode()


def peer_credentials(peer):
    """The PID and UID of a connected Unix socket's peer (SO_PEERCRED; LOCAL_PEERPID and
    LOCAL_PEERCRED on macOS)."""
    if sys.platform.startswith("linux"):
        pid, uid, _ = struct.unpack("3i", peer.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, struct.calcsize("3i")))
        return pid, uid
    if sys.platform == "darwin":
        pid = peer.getsockopt(0, 2)  # SOL_LOCAL, LOCAL_PEERPID
        _, uid = struct.unpack("Ii", peer.getsockopt(0, 1, 8))  # LOCAL_PEERCRED: version, uid
        return pid, uid
    raise OSError(f"no peer credentials on {sys.platform}")


def consensus_log_level(value):
    """The level stock ParseLogLevel gives module "consensus" for log_level value, or None when
    stock would refuse it."""
    items = value.split(",") if ":" in value else ["*:" + value]
    default, own = "info", None
    for item in items:
        parts = item.split(":")
        if len(parts) != 2 or parts[1] not in ("debug", "info", "warn", "error", "none"):
            return None
        if parts[0] == "*":
            default = parts[1]
        elif parts[0] == "consensus":
            own = parts[1]
    return own or default


class LogObserver:
    """The supervisor-owned, process-specific pipe that one Comet process writes its log records
    to, synchronously and unbuffered (stock writes each record with one write to stdout). A
    thread forwards every line to the supervisor's stdout and follows the replay attempts; a
    signer request first consumes every record already written (snapshot). Comet blocks while
    the pipe is full, so no record is lost."""

    def __init__(self, descriptor):
        os.set_blocking(descriptor, False)
        self.descriptor = descriptor
        self.lock = threading.Lock()
        self.buffer = b""
        self.closed = False
        self.attempt = 0
        self.open = False
        self.height = 0
        self.tainted = False
        self.repaired = False
        self.committed = {}
        threading.Thread(target=self.follow, daemon=True).start()

    def follow(self):
        while True:
            try:
                select.select([self.descriptor], [], [], .2)
            except (OSError, ValueError):
                return
            with self.lock:
                if not self.pump():
                    return

    def pump(self):
        """Read and handle every complete record available now; False once Comet closed the pipe.
        The caller holds the lock."""
        if self.closed:
            return False
        while True:
            try:
                chunk = os.read(self.descriptor, 65536)
            except BlockingIOError:
                return True
            except OSError:
                chunk = b""
            if not chunk:
                self.closed, self.open, self.tainted = True, False, True
                os.close(self.descriptor)
                if self.buffer:
                    self.forward(self.buffer + b"\n")
                return False
            self.buffer += chunk
            *lines, self.buffer = self.buffer.split(b"\n")
            for line in lines:
                self.forward(line + b"\n")
                self.handle(line)

    @staticmethod
    def forward(line):
        try:
            os.write(sys.stdout.fileno(), line)
        except OSError:
            pass

    def handle(self, line):
        try:
            record = json.loads(line)
        except ValueError:
            return
        if not isinstance(record, dict) or record.get("module") != "consensus":
            return
        message, height = record.get("_msg"), record.get("height")
        if message == REPLAY_OPEN:
            if self.open or self.tainted or type(height) is not int:
                self.open, self.tainted = False, True
            else:
                self.attempt, self.open, self.height = self.attempt + 1, True, height
        elif message == REPLAY_DONE:
            self.open = False
        elif message in REPLAY_CANCEL:
            self.open, self.tainted = False, True
            self.repaired = self.repaired or message == REPLAY_REPAIRED
        elif message == REPLAY_COMMIT and type(height) is int and isinstance(record.get("hash"), str):
            self.committed[height] = record["hash"].lower()
            for old in [h for h in self.committed if h < height - 8]:
                del self.committed[old]

    def snapshot(self):
        """The replay state after every record already written was consumed."""
        with self.lock:
            self.pump()
            return dict(attempt=self.attempt, open=self.open, height=self.height,
                        tainted=self.tainted, repaired=self.repaired)

    def committed_hash(self, height):
        with self.lock:
            return self.committed.get(height)


def valid_store_instance(raw):
    """Exactly 32 lowercase hex characters and a newline."""
    return len(raw) == 33 and raw.endswith(b"\n") and all(c in b"0123456789abcdef" for c in raw[:32])


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

    @staticmethod
    def config_values(config):
        """Every value config.toml gives each Viper path. Viper folds key case and also reads a
        literal dotted key, so one path can have several spellings."""
        found = {}
        def walk(table, prefix=""):
            for key, value in table.items():
                path = prefix + key.lower()
                found.setdefault(path, []).append(value)
                if isinstance(value, dict):
                    walk(value, path + ".")
        walk(config)
        return found

    @staticmethod
    def env_values(path, kind):
        """Every CMT_* override of a Viper path that stock Comet could apply, decoded as Viper's
        weak decoding would. Both CMT_P2P_PEX and the copied CMTP2P_PEX spelling count; an empty
        value is ignored, as by Viper. A value that cannot be evaluated exactly is refused."""
        suffix = path.upper().replace(".", "_").replace("-", "_")
        values = []
        for name in ("CMT_" + suffix, "CMT" + suffix):
            raw = os.environ.get(name, "")
            if raw == "":
                continue
            if kind == "bool" and raw in ENV_BOOLS:
                values.append((name, ENV_BOOLS[raw]))
            elif kind == "int" and (raw == "0" or (raw[:1] in "123456789" and raw.isdigit())):
                values.append((name, int(raw)))
            elif kind in ("str", "duration"):
                values.append((name, raw))
            else:
                raise ValueError(f"cannot evaluate {name}={raw!r} for CometBFT {path} (START-10-6)")
        return values

    def effective_values(self, path, default, kind):
        """(source, value) for every value of path stock Comet could use: each config.toml
        spelling, or the stock default when there is none, and each CMT_* override. Whether
        Viper applies an override depends on the key, so every candidate must pass."""
        values = [("config.toml", value) for value in self.config_settings.get(path, [])]
        return (values or [("stock default", default)]) + self.env_values(path, kind)

    def check_effective_settings(self):
        """Refuse a validator whose effective CometBFT configuration moves a pinned setting
        (START-10-6, LIMIT-12-2), a Comet argv that sets one by flag, which would beat both
        config.toml and the environment, and a CMTHOME/TMHOME that moves Comet off its home."""
        for name in ("CMTHOME", "TMHOME"):
            value = os.environ.get(name, "")
            if value and Path(value).resolve() != self.home:
                raise ValueError(f"{name}={value} would start Comet outside ETNA_COMET_HOME")
        flagged = {argument.lstrip("-").split("=", 1)[0].lower()
                   for argument in self.comet_command[1:] if argument.startswith("-")}
        for path in [*PINNED_SETTINGS, *READ_SETTINGS, "priv_validator_laddr"]:
            if path in flagged:
                raise ValueError(f"validator startup refuses a --{path} flag in the Comet argv; set it in config.toml (START-10-6)")
        for path, (default, kind, requirement, check) in PINNED_SETTINGS.items():
            for source, value in self.effective_values(path, default, kind):
                if not check(value, self.inbound_peers):
                    raise ValueError(f"validator startup requires CometBFT {path} {requirement}; "
                                     f"{source} gives {value!r} (START-10-6)")

    def read_setting(self, path):
        """The one value stock Comet uses for an unpinned setting; candidates that disagree are
        refused, since the supervisor could not tell which one Comet applies."""
        values = {value for _, value in self.effective_values(path, READ_SETTINGS[path], "str")}
        if len(values) != 1 or not all(isinstance(value, str) and value for value in values):
            raise ValueError(f"CometBFT {path} is ambiguous or invalid across config.toml and CMT_* overrides: {sorted(map(repr, values))}")
        return values.pop()

    def observer_refusal(self):
        """Why the log observer cannot follow this Comet's replay (START-10-6), or None: the
        effective log_format must be the pinned parser's, the consensus module must emit Info and
        Error, and no argv flag may override either."""
        flagged = {argument.lstrip("-").split("=", 1)[0].lower()
                   for argument in self.comet_command[1:] if argument.startswith("-")}
        for path in OBSERVER_SETTINGS:
            if path in flagged:
                return f"the Comet argv sets --{path}"
        try:
            formats = {value for _, value in self.effective_values("log_format", OBSERVER_SETTINGS["log_format"], "str")}
            levels = {value for _, value in self.effective_values("log_level", OBSERVER_SETTINGS["log_level"], "str")}
        except ValueError as error:
            return str(error)
        if formats != {OBSERVER_FORMAT}:
            return f"log_format is {sorted(map(str, formats))}, not the observer's {OBSERVER_FORMAT!r}"
        if len(levels) != 1 or consensus_log_level(str(next(iter(levels)))) not in ("debug", "info"):
            return f"log_level {sorted(map(str, levels))} does not emit the consensus module's Info and Error records"
        return None

    def helper_run(self, *arguments):
        """Run a WAL or store helper as the Comet UID, which reads Comet's files and creates
        nothing another UID would own; its one JSON line, or None on any failure."""
        try:
            done = subprocess.run(self.helper + list(arguments), capture_output=True, timeout=30,
                                  **self.comet_identity_options())
        except (OSError, subprocess.SubprocessError) as error:
            print(f"etna_supervisor_replay_helper_failed: {arguments[0]}: {error}", flush=True)
            return None
        if done.returncode != 0:
            print(f"etna_supervisor_replay_helper_failed: {arguments[0]}: {done.stderr.decode(errors='replace').strip()}", flush=True)
            return None
        try:
            return json.loads(done.stdout)
        except ValueError:
            return None

    def signed_binding(self):
        """The signer state's last signed height and saved replay binding, read with the signer
        stopped; None when it has none."""
        try:
            state = json.loads(self.state.read_bytes())
            height, binding = int(state["height"]), state["replay"]
        except (OSError, ValueError, KeyError, TypeError):
            return None
        if height <= 0 or not isinstance(binding, dict):
            return None
        try:
            return height, dict(marker=int(binding["marker"]), predecessor=str(binding["predecessor"]).lower(),
                                wal_length=int(binding["wal_length"]), wal_sha256=str(binding["wal_sha256"]).lower())
        except (KeyError, ValueError, TypeError):
            return None

    def replay_preflight(self):
        """The startup check of RECOV-8.2-2, with Comet and the signer stopped: whether stock can
        replay the last signed height from the verified predecessor through the bound WAL prefix,
        and the pinned startup prefix. Returns the report for the signer channel, or None, in which
        case the signer fences that height. Only goleveldb stores are read."""
        self.head = None
        if self.read_setting("db_backend") == "goleveldb" and (self.db_dir / "state.db").is_dir():
            head = self.helper_run("comet-head", "--db-dir", str(self.db_dir))
            if isinstance(head, dict) and type(head.get("height")) is int and isinstance(head.get("hash"), str):
                self.head = (head["height"], head["hash"].lower())
        if self.observer_reason is not None:
            return None
        saved = self.signed_binding()
        if saved is None or self.head is None:
            return None
        height, binding = saved
        result = self.helper_run("wal-preflight", "--wal", str(self.wal_file), "--db-dir", str(self.db_dir),
                                 "--height", str(height), "--marker", str(binding["marker"]),
                                 "--length", str(binding["wal_length"]), "--digest", binding["wal_sha256"],
                                 "--predecessor", binding["predecessor"])
        if not isinstance(result, dict) or not (result.get("eligible") or result.get("repair")):
            reason = result.get("reason") if isinstance(result, dict) else "helper failed"
            print(f"etna_supervisor_replay_ineligible: height {height}: {reason}; the signer fences it", flush=True)
            return None
        startup = result.get("startup") or {}
        try:
            pinned = dict(marker=int(startup["marker"]), predecessor=binding["predecessor"],
                          wal_length=int(startup["wal_length"]), wal_sha256=str(startup["wal_sha256"]))
        except (KeyError, ValueError, TypeError):
            return None
        repair = bool(result.get("repair"))
        print(f"etna_supervisor_replay_preflight: height {height} {'needs a stock WAL repair first' if repair else 'eligible'}; "
              f"startup prefix {pinned['wal_length']} bytes", flush=True)
        return dict(height=height, binding=binding, startup=pinned, repair=repair)

    def live_binding(self, height):
        """The live replay binding of a signing request at height: the flushed WAL bytes after the
        predecessor's end-height marker and the predecessor block's hash; None when either is
        unknown."""
        if type(height) is not int or height < self.initial_height or self.observer_reason is not None:
            return None
        marker = 0 if height == self.initial_height else height - 1
        predecessor = ""
        if marker:
            observer = self.observer
            predecessor = observer.committed_hash(marker) if observer is not None else None
            if predecessor is None and self.head is not None and self.head[0] == marker:
                predecessor = self.head[1]
            if not predecessor:
                return None
        result = self.helper_run("wal-binding", "--wal", str(self.wal_file), "--marker", str(marker))
        binding = result.get("binding") if isinstance(result, dict) else None
        if not isinstance(binding, dict):
            return None
        return dict(marker=marker, predecessor=predecessor, wal_length=binding.get("wal_length"),
                    wal_sha256=binding.get("wal_sha256"))

    def rooted(self, path):
        """Stock rootify: an absolute path as is, a relative one under the Comet home."""
        return Path(path) if os.path.isabs(path) else self.home / path

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
        # Comet runs as another UID and must never reach the registered or fallback key, the HRS
        # states or the log, and the app store never holds them.
        for path in (self.key, self.state_dir, self.domains_log):
            if path.is_relative_to(self.home) or path.is_relative_to(self.store):
                raise ValueError("registered or fallback key, signing state and domains log must be outside the Comet home and app store")
        # The supervisor's private run directory holds the signer channel's socket.
        # Its parent is resolved, never the directory itself: prepare_run_dir refuses a symlink.
        run_dir = Path(os.environ.get("ETNA_SUPERVISOR_RUN_DIR", str(self.store / "supervisor")))
        if not run_dir.is_absolute() or run_dir.name in ("", ".", ".."):
            raise ValueError("ETNA_SUPERVISOR_RUN_DIR must be an absolute directory path")
        self.run_dir = run_dir.parent.resolve() / run_dir.name
        if (self.run_dir.is_relative_to(self.home) or self.run_dir.is_relative_to(self.state_dir)
                or self.run_dir.is_relative_to(self.domains_log.parent) or self.run_dir == self.key):
            raise ValueError("the supervisor run directory must be outside the Comet home and the signer's files")
        self.channel_path = self.run_dir / SUPERVISOR_SOCKET
        if len(os.fsencode(self.channel_path)) > MAX_UNIX_SOCKET_PATH:
            raise ValueError("supervisor run directory too long for its Unix socket")
        self.channel = None
        # The Comet process the supervisor runs, as the signer channel reports it; None while no
        # Comet runs.
        self.comet_report = None
        self.denial_route = self.validate_denial_route()
        self.events = self.denial_route
        self.prior_observation = None
        self.latch = self.store / "validator-supervisor.halted"
        binary = os.environ.get("ETNA_SIGNER_BIN", str(Path(__file__).resolve().parents[1] / "etna-signer"))
        # The WAL and store helpers of the replay checks, run as the Comet UID.
        self.helper = self.command_prefix("ETNA_SIGNER_HELPER_JSON", [binary])
        # start() adds each pair's --comet-signer-addr (and, for Noise, --transport-key).
        self.signer_command = self.command_prefix("ETNA_SIGNER_COMMAND_JSON", [binary]) + [
            "--trust-socket", str(self.store / "checkpoint-trust.sock"),
            "--supervisor-socket", str(self.channel_path),
            "--chain-id", self.chain, "--priv-key", str(self.key),
            "--priv-state", str(self.state), "--domains-log", str(self.domains_log)]
        # Comet's complete argv. start_comet() appends only the pair's --priv_validator_laddr.
        self.comet_command = self.command_prefix("ETNA_COMET_COMMAND_JSON", [
            os.environ.get("ETNA_COMET_BIN", "cometbft"), "start", "--home", str(self.home)])
        # The operator's listed inbound peers (LIMIT-12-2), which unconditional_peer_ids must equal.
        inbound = peer_list(os.environ.get("ETNA_P2P_INBOUND_PEER_IDS", ""))
        if len(set(inbound)) != len(inbound):
            raise ValueError("ETNA_P2P_INBOUND_PEER_IDS lists a peer twice")
        self.inbound_peers = sorted(inbound)
        self.load_comet_config()
        self.observer = None
        self.preflight = None
        self.head = None
        self.repair_restarts = 0
        self.stop_armed = False
        self.stop_reached = None
        self.stopped_for_upgrade = False
        self.manifest = GUARD.load_manifest()
        os.close(self.comet_executable())
        self.address = self.comet_listener = None
        self.signer = self.comet = None
        self.running = True
        self.pending = False
        self.last_event = None
        self.connected = False  # the current pair's signer published its connection
        self.observed_loss = False
        self.was_ready = False
        self.owner_fds = []
        self.halted = False
        self.halt_retry = None
        self.halt_error = None
        # Monotonic times of non-unsafe signer exits; in memory only, so a supervisor restart
        # resets it and container CrashLoopBackOff bounds that case.
        self.crashes = []
        self.signer_killed = False  # stop() had to SIGKILL a running signer

    def load_comet_config(self):
        """Read and check the effective Comet configuration that the next Comet start uses: at
        startup and again before every Comet start, since Comet reads its own files afresh each
        time (START-10-6). It covers config.toml, the Comet argv and the CMT_* environment (the
        pinned settings, the stores' backend and location, the WAL, the log observer's
        prerequisites), the genesis chain ID and initial height, and the signer transport that
        priv_validator_laddr selects. A failed check raises before any child of the start runs, so
        signing stays closed and the supervisor exits naming the setting. A log observer that
        cannot follow this Comet is recorded in observer_reason: observer-dependent signing stays
        closed for that start."""
        config = tomllib.loads((self.home / "config/config.toml").read_text())
        self.config_settings = self.config_values(config)
        self.check_effective_settings()
        if self.read_setting("db_backend") not in COMET_DB_BACKENDS:
            raise ValueError(f"validator startup requires CometBFT db_backend in {COMET_DB_BACKENDS}")
        # Stock cometbft-db keeps the evidence pool's store at <db_dir>/evidence.db.
        self.db_dir = self.rooted(self.read_setting("db_dir"))
        self.evidence_store = self.db_dir / "evidence.db"
        self.wal_file = self.rooted(self.read_setting("consensus.wal_file"))
        self.observer_reason = self.observer_refusal()
        genesis = json.loads((self.home / "config/genesis.json").read_text())
        if genesis["chain_id"] != self.chain:
            raise ValueError("signer chain ID differs from Comet genesis")
        self.initial_height = int(genesis.get("initial_height") or 1)
        # Refuse half a Comet identity before any child starts.
        identity = self.comet_identity()
        address = config.get("priv_validator_laddr", "")
        if not isinstance(address, str):
            address = ""
        self.unix_run = self.noise = None
        if address.startswith("unix://"):
            # The configured path only selects Unix mode. Every pair start gets a fresh
            # name in run/, so no Comet-owned stale inode ever needs to be pinned or probed.
            self.unix_run = self.home / "run"
            self.run_owner = identity[0] if identity is not None else os.geteuid()
            sample = self.unix_run / (SIGNER_SOCKET_PREFIX + "0" * 16 + SIGNER_SOCKET_SUFFIX)
            if len(os.fsencode(sample)) > MAX_UNIX_SOCKET_PATH:
                raise ValueError("Comet home too long for a Unix signer socket")
        elif address.startswith("noise://"):
            self.noise = (*self.noise_transport(address), address)
            self.comet_peer_id()  # Refuse a missing Comet node key before any child starts.
        elif address.startswith("tcp://"):
            raise ValueError("validator startup refuses a bare tcp:// priv_validator_laddr, whose stock listener "
                             "generates a fresh identity at every start; use unix:// or "
                             "noise://<signer-peer-id>@<ip>:<port> (START-10-6)")
        else:
            raise ValueError("validator startup requires priv_validator_laddr unix://… or noise://<signer-peer-id>@<ip>:<port>")

    def noise_transport(self, address):
        """Comet's stock noise://<signer-peer-id>@<ip>:<port> listener (START-10-6): Comet pins
        the signer's transport key, ETNA_SIGNER_TRANSPORT_KEY, whose peer ID must be the one the
        address names, and the signer pins the peer ID of Comet's persistent node key. Returns
        the signer's transport key and the host:port both sides use."""
        signer_peer, separator, hostport = address.removeprefix("noise://").rpartition("@")
        host, _, port = hostport.rpartition(":")
        try:
            ipaddress.ip_address(host.removeprefix("[").removesuffix("]"))
            valid_port = port.isdigit() and 0 < int(port) < 65536
        except ValueError:
            valid_port = False
        if not separator or not signer_peer or not valid_port or (":" in host and not host.startswith("[")):
            raise ValueError("priv_validator_laddr must be noise://<signer-peer-id>@<ip>:<port> with an IP literal")
        key = os.environ.get("ETNA_SIGNER_TRANSPORT_KEY")
        if not key:
            raise ValueError("a noise:// priv_validator_laddr needs ETNA_SIGNER_TRANSPORT_KEY")
        key = Path(key).resolve()
        if key.is_relative_to(self.home) or key.is_relative_to(self.store):
            raise ValueError("the signer transport key must be outside the Comet home and app store")
        if ed25519_peer_id(key, "signer transport key") != signer_peer:
            raise ValueError(f"ETNA_SIGNER_TRANSPORT_KEY is not the signer {signer_peer} that priv_validator_laddr pins")
        return key, hostport

    def comet_peer_id(self):
        """The libp2p peer ID of Comet's persistent node key, which the Noise signer pins. A
        missing key is refused: stock Comet would generate a fresh one the signer cannot know."""
        return ed25519_peer_id(self.rooted(self.read_setting("node_key_file")), "Comet node key")

    def comet_executable(self):
        """The official executable the next Comet start runs, by its digest in the deployment
        manifest (ETNA_COMET_MANIFEST or comet-manifest.json beside script/): a reported version
        string alone does not identify the build (CONS-3.1-1). Checked before every Comet start,
        it is an open, sealed copy of the bytes it hashed (etna_comet_guard), which start_comet
        execs; the caller closes it."""
        return GUARD.sealed_comet_executable(self.manifest, self.comet_command[0])

    def remove_pending_evidence(self):
        """Delete the node's pending-evidence store, and only that, with Comet stopped, before
        every start (CONS-3.1-10, LIMIT-12-22): no block commits evidence, so the stock pool is
        bounded only by expiry. WAL, block, state, app/EL and signer stores stay. The removal is
        made durable before Comet starts."""
        if self.comet is not None:
            raise ValueError("pending-evidence store removal requires a stopped Comet")
        GUARD.remove_pending_evidence(self.evidence_store, "etna_supervisor")

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
        # No signer session is admitted for a Comet that is stopping.
        self.comet_report = None
        self.observer = None
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
        """Return the next pair's signer address and Comet listener, after removing stale Unix
        rendezvous names.

        Unix: runs with both children reaped and the home owner lock held. Refuses a missing,
        symlinked or sticky run/, one not owned by the Comet UID or open to its group or others,
        and a prefixed entry that cannot be unlinked, so only the bound Comet process and the
        root signer reach the socket (START-10-6). Names with the signer prefix are the
        supervisor's own namespace: they are unlinked through the opened run/ without type,
        inode or liveness checks, so a live orphan can only lose its name.

        Noise: Comet listens on its configured noise://<signer-peer-id>@<ip>:<port>, and the
        signer dials that <ip>:<port> pinning the peer ID of Comet's node key, read again at
        every start.
        """
        if self.comet is not None or self.signer is not None:
            raise ValueError("signer transport cleanup requires reaped children")
        if self.noise is not None:
            _, hostport, listener = self.noise
            return f"noise://{self.comet_peer_id()}@{hostport}", listener
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
            if metadata.st_mode & 0o077:
                raise ValueError(f"{self.unix_run} must be private to the Comet UID (mode 0700), not {stat.S_IMODE(metadata.st_mode):04o}")
            for name in os.listdir(descriptor):
                if name.startswith(SIGNER_SOCKET_PREFIX) and name.endswith(SIGNER_SOCKET_SUFFIX):
                    os.unlink(name, dir_fd=descriptor)  # Errors (e.g. a directory) fail closed.
        finally:
            os.close(descriptor)
        address = "unix://" + str(self.unix_run / (SIGNER_SOCKET_PREFIX + secrets.token_hex(8) + SIGNER_SOCKET_SUFFIX))
        return address, address

    def start(self):
        """Start a fresh signer and Comet together (START-10-6, SYNC-9-12).

        Runs only with both earlier children reaped, so their flocks are released, and never
        while a fence or the unsafe record exists. Every start gets a fresh transport
        (fresh_transport); the signer connects promptly and begins that transport's own
        closed trust session. Comet's configuration, executable, pending-evidence store and store
        instance are checked, cleared and assigned first, so a refused start leaves no child
        running.
        """
        if self.refuse_unsafe_start():
            return
        self.load_comet_config()
        if self.observer_reason is not None:
            print(f"etna_supervisor_log_observer_disabled: {self.observer_reason}; same-height replay "
                  "stays closed and this start fences the last signed height (START-10-6, RECOV-8.2-2)", flush=True)
        self.validate_denial_route()
        self.address, self.comet_listener = self.fresh_transport()
        executable = self.comet_executable()
        try:
            self.remove_pending_evidence()
            instance = self.store_instance()
            self.preflight = self.replay_preflight()
            # Never unlink an operator-selected file; ignore its old inode on restart.
            previous = self.read_observation(self.events)
            self.prior_observation = previous[0] if previous is not None else None
            self.last_event = None
            args = self.signer_command + ["--comet-signer-addr", self.address, "--denial-file", str(self.events)]
            if self.noise is not None:
                args += ["--transport-key", str(self.noise[0])]
            self.signer = subprocess.Popen(args, **self.child_options())
            self.pending = False
            self.connected = False
            self.observed_loss = False
            self.was_ready = False
            self.start_comet(instance, executable)
        finally:
            os.close(executable)
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

    def store_instance(self):
        """The Comet home's store instance ID (RECOV-8.2-2), read before every Comet start. A home
        without one, an empty home on its first start or stores that exist without an ID (treated
        as rebuilt), gets a fresh ID first, written atomically: a temporary file, its fsync, a
        rename and the directory's fsync. An absent data/ is created for the Comet UID where the
        supervisor may chown it; the image's supervisor has no CAP_CHOWN, so its homes are prepared
        with data/. Any other inode or content at the path is refused."""
        path = self.home / STORE_INSTANCE
        data = path.parent
        if not data.exists():
            data.mkdir(mode=0o700)
            identity = self.comet_identity()
            if identity is not None and identity != (os.geteuid(), os.getegid()):
                try:
                    os.chown(data, *identity)
                except PermissionError as error:
                    data.rmdir()
                    raise ValueError(f"create {data} owned by the Comet UID before the first start; "
                                     "the supervisor has no CAP_CHOWN") from error
            self.sync_directory(self.home)
        try:
            descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        except FileNotFoundError:
            return self.assign_store_instance(path)
        except OSError as error:
            raise ValueError(f"{path} is not a regular file: {error}") from error
        with os.fdopen(descriptor, "rb") as source:
            if not stat.S_ISREG(os.fstat(source.fileno()).st_mode):
                raise ValueError(f"{path} is not a regular file")
            raw = source.read(64)
        if not valid_store_instance(raw):
            raise ValueError(f"{path} is not a store instance ID (32 lowercase hex characters and a newline)")
        return raw[:32].decode()

    def assign_store_instance(self, path):
        """Write a fresh store instance ID at path."""
        fresh = secrets.token_hex(16)
        temporary = path.with_name(f".{path.name}.{secrets.token_hex(8)}")
        descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        try:
            os.write(descriptor, (fresh + "\n").encode())
            os.fsync(descriptor)
        except BaseException:
            os.close(descriptor)
            os.unlink(temporary)
            raise
        os.close(descriptor)
        os.rename(temporary, path)
        self.sync_directory(path.parent)
        print(f"etna_supervisor_store_instance_assigned: {fresh} (no ID in {path}: new or rebuilt stores)", flush=True)
        return fresh

    @staticmethod
    def sync_directory(path):
        directory = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)

    def prepare_run_dir(self):
        """The supervisor's private run directory: created mode 0700 when absent; refused when it
        is a symlink, owned by another UID or open to its group or others."""
        try:
            self.run_dir.mkdir(mode=0o700)
        except FileExistsError:
            pass
        metadata = os.lstat(self.run_dir)
        if (not stat.S_ISDIR(metadata.st_mode) or metadata.st_uid != os.geteuid()
                or metadata.st_mode & 0o077):
            raise ValueError(f"{self.run_dir} must be a directory private to the supervisor (mode 0700)")

    def open_channel(self):
        """Listen on the signer channel (RECOV-8.2-2). The owner lock is held, so a socket left at
        the path belongs to a dead supervisor and is replaced."""
        self.prepare_run_dir()
        try:
            os.unlink(self.channel_path)
        except FileNotFoundError:
            pass
        listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        listener.bind(str(self.channel_path))
        listener.listen()
        listener.settimeout(.1)
        self.channel = listener
        threading.Thread(target=self.serve_channel, args=(listener,), daemon=True).start()

    def close_channel(self):
        listener, self.channel = getattr(self, "channel", None), None
        if listener is not None:
            listener.close()
            try:
                os.unlink(self.channel_path)
            except FileNotFoundError:
                pass

    def serve_channel(self, listener):
        while True:
            try:
                peer, _ = listener.accept()
            except socket.timeout:
                continue
            except OSError:
                return
            threading.Thread(target=self.serve_signer, args=(peer,), daemon=True).start()

    def serve_signer(self, peer):
        """Answer one signer connection. Only the signer this supervisor runs may use it: the
        peer's PID must be the current signer child's and its UID root or the supervisor's. A
        connection ends with the first malformed request, and once that signer is replaced."""
        with peer:
            signer = self.signer
            try:
                pid, uid = peer_credentials(peer)
            except OSError:
                return
            if signer is None or pid != signer.pid or uid not in (0, os.geteuid()):
                print(f"etna_supervisor_channel_refused: peer PID {pid} UID {uid} is not the signer", flush=True)
                return
            peer.settimeout(None)
            source = peer.makefile("rb")
            while True:
                line = source.readline(MAX_SUPERVISOR_FRAME + 1)
                if not line.endswith(b"\n") or self.signer is not signer:
                    return
                try:
                    reply = self.channel_reply(json.loads(line))
                except ValueError:
                    return
                if reply is None:
                    return
                try:
                    peer.sendall((json.dumps(reply) + "\n").encode())
                except OSError:
                    return

    def channel_reply(self, request):
        """One signer request: {"schema": 1, "id": n, "op": ...}. The comet op reports the Comet
        process this supervisor runs, {"pid", "start", "store_instance", "replay"}, or null; observe
        consumes every record that process wrote and reports its replay attempt; wal computes the
        live binding of a signing request at a height."""
        if (not isinstance(request, dict) or request.get("schema") != SUPERVISOR_SCHEMA
                or type(request.get("id")) is not int or not isinstance(request.get("op"), str)):
            return None
        reply = dict(schema=SUPERVISOR_SCHEMA, id=request["id"])
        observer = self.observer
        if request["op"] == "comet":
            reply["comet"] = self.comet_report
        elif request["op"] == "observe" and observer is not None:
            reply["replay"] = observer.snapshot()
        elif request["op"] == "wal":
            reply["binding"] = self.live_binding(request.get("height"))
        elif request["op"] == "stop":
            reply["stop"] = getattr(self, "stop_armed", False)
        elif (request["op"] == "stopped" and getattr(self, "stop_armed", False)
              and type(request.get("height")) is int and type(request.get("round")) is int):
            if getattr(self, "stop_reached", None) is None:
                self.stop_reached = (request["height"], request["round"], time.monotonic())
                print(f"etna_supervisor_signer_stopped_after_precommit: height {request['height']} round "
                      f"{request['round']}; stopping Comet in {STOP_GRACE:g}s", flush=True)
            reply["stopped"] = True
        else:
            reply["error"] = f"op {request['op']!r} is unavailable"
        return reply

    def comet_identity_options(self):
        """Popen options that run a child as the Comet UID/GID without supplementary groups."""
        configured = self.comet_identity()
        if configured is not None:
            # The supported image keeps the registered or fallback FilePV key inaccessible to Comet.
            uid, gid = configured
            # A same-identity unprivileged local runner cannot call setgroups. Preserve its
            # existing identity; privileged/different-identity launches still drop all groups.
            if os.geteuid() == 0 or uid != os.geteuid() or gid != os.getegid():
                return dict(user=uid, group=gid, extra_groups=[])
        return {}

    def start_comet(self, instance, executable):
        """Start Comet on this pair's listener; the flag beats config.toml and CMT_* overrides. It
        execs the sealed copy `executable` that comet_executable hashed, which it inherits, with
        the configured name as argv[0]. The signer channel then reports this process, instance
        (its home's store instance) and the startup replay check. With the log observer, Comet's
        stdout is a fresh pipe the supervisor owns for this process alone."""
        command = self.comet_command + ["--priv_validator_laddr", self.comet_listener]
        options = self.child_options()
        options["pass_fds"] += (executable,)
        streams, write_end = {}, None
        if self.observer_reason is None:
            read_end, write_end = os.pipe()
            streams = dict(stdout=write_end)
        try:
            self.comet = subprocess.Popen(command, executable=GUARD.executable_path(executable), cwd=self.home,
                                          **streams, **self.comet_identity_options(), **options)
        finally:
            if write_end is not None:
                os.close(write_end)
        self.observer = LogObserver(read_end) if write_end is not None else None
        try:
            start = process_start(self.comet.pid)
        except (OSError, ValueError, IndexError):
            start = None  # Already gone: the signer cannot connect to it.
        self.comet_report = dict(pid=self.comet.pid, start=start, store_instance=instance,
                                 replay=self.preflight if self.observer is not None else None)

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
        pair: Comet is reaped, then a fresh signer with the same HRS path and Comet start
        together on a fresh transport, whose new closed session gates every signature
        (SYNC-9-12). Stock FilePV continues from the HRS on disk: no signature was released
        before both fsyncs (SYNC-9-13).
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
        self.start()

    def missed_connection(self):
        """Comet exited before this pair's signer connected, as when the signer misses the 3 s
        accept of Comet's first GetPubKey: start the pair again with the same signer state and
        no latch (START-10-6)."""
        print("etna_supervisor_missed_first_connection: Comet exited before the signer connected; "
              "restarting the pair", flush=True)
        if self.halt_if_unsafe(self.stop()):
            return
        deadline = time.monotonic() + MISSED_CONNECTION_RETRY
        while self.running and time.monotonic() < deadline:
            time.sleep(.05)
        if self.running:
            self.start()

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

    def stop_refusal(self):
        """Why the stop on a precommit must not arm now, or None (RECOV-8.2-2). After the upgrade
        the restarted pair has to confirm the precommit the signer stopped on by same-height
        replay; one it cannot confirm fences that height, and with every validator stopped at the
        same undecided height, too many fenced validators leave it undecided until governance
        recovery. That replay needs the log observer following the running Comet, stores the
        startup check reads (goleveldb), and replay bindings on the signer's signatures, which the
        last one shows (the predecessor's #ENDHEIGHT marker and block hash were known). The signer
        itself also closes only after a precommit that carries a binding."""
        comet, observer = self.comet, getattr(self, "observer", None)
        if self.observer_reason is not None:
            return f"the log observer is off ({self.observer_reason})"
        if comet is None or comet.poll() is not None or observer is None or observer.closed:
            return "the log observer does not follow a running Comet"
        if self.read_setting("db_backend") != "goleveldb":
            return "the startup replay check reads only goleveldb stores"
        if self.signed_binding() is None:
            return ("the signer's last signature carries no replay binding (its predecessor's #ENDHEIGHT "
                    "marker or block hash was unknown), so a restart could not confirm a precommit")
        return None

    def stop_outcome(self, outcome):
        """Publish the stop's outcome beside the request, atomically, and withdraw the request."""
        temporary = self.run_dir / f".{STOP_DONE}.{secrets.token_hex(8)}"
        temporary.write_text(json.dumps(outcome) + "\n")
        os.replace(temporary, self.run_dir / STOP_DONE)
        (self.run_dir / STOP_REQUEST).unlink(missing_ok=True)

    def stop_for_upgrade(self):
        """Arm the stop on a precommit once the operator's request appears, unless stop_refusal
        refuses it, and once the signer reported its gate closed after one and the grace passed,
        stop the pair for good. True while the supervisor stays quiescent for the upgrade."""
        if getattr(self, "stopped_for_upgrade", False):
            return True
        if getattr(self, "run_dir", None) is None:
            return False
        request = self.run_dir / STOP_REQUEST
        if not getattr(self, "stop_armed", False) and request.exists():
            refusal = self.stop_refusal()
            if refusal is not None:
                print(f"etna_supervisor_stop_on_precommit_refused: {refusal}; nothing is armed (RECOV-8.2-2)", flush=True)
                self.stop_outcome(dict(stopped=False, refused=refusal))
                return False
            self.stop_armed = True
            print("etna_supervisor_stop_on_precommit_armed: the signer stops after its next precommit that "
                  "carries a replay binding, or at once if its last signature is one (START-10.1-14b)", flush=True)
        reached = getattr(self, "stop_reached", None)
        if reached is None or time.monotonic() - reached[2] < STOP_GRACE:
            return False
        if self.halt_if_unsafe(self.stop()):
            return True
        self.stopped_for_upgrade = True
        self.stop_outcome(dict(stopped=True, height=reached[0], round=reached[1]))
        print(f"etna_supervisor_stopped_for_upgrade: the signer's last signature is the precommit at height "
              f"{reached[0]} round {reached[1]}; Comet and the signer are stopped. Upgrade, then restart the "
              "supervisor", flush=True)
        return True

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
        if self.stop_for_upgrade():
            return
        observed = self.read_observation(self.events)
        if observed is not None and observed[0] != self.prior_observation:
            _, event = observed
            # The signer publishes when its transport connects, with the session it began or an
            # empty one while the app could not begin it, and again for every refusal. Only a
            # refusal makes Comet restart: a session the app replaced, as after an app restart,
            # is begun again by the signer's next signing request, which it holds there.
            self.connected = True
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
        comet_exited = self.comet.poll() is not None
        if comet_exited and not self.connected:
            self.missed_connection()
            return
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
        observer, preflight = getattr(self, "observer", None), getattr(self, "preflight", None)
        if (ready and observer is not None and preflight is not None and preflight["repair"]
                and observer.snapshot()["repaired"] and self.repair_restarts < MAX_REPAIR_RESTARTS):
            # Stock repaired the torn tail the startup check found, with signing at that height
            # closed; restart from the verified predecessor so a clean replay can confirm it.
            self.repair_restarts += 1
            if self.halt_if_unsafe(self.stop()):
                return
            self.start()
            print("etna_supervisor_restarted_after_wal_repair: the pair replays from the verified predecessor", flush=True)
            return
        if self.pending and ready:
            # The refused step comes back only through a restarted Comet's WAL replay. The new
            # pair's session is checked while Comet's handshake runs, and the signer holds the
            # replayed request until it passes; another refusal repeats this once Ready.
            if self.halt_if_unsafe(self.stop()):
                return
            self.start()
            print("etna_supervisor_restarted_after_refusal: the restarted pair replays the refused step", flush=True)

    def ready(self, status):
        """The app's trust phase is its only readiness signal (SYNC-9-15), bound to this chain_id."""
        return status.get("phase") == "ready" and status.get("chain_id") == self.chain

    def run(self):
        self.acquire_owner()
        def shutdown(_signal, _frame):
            self.running = False
        signal.signal(signal.SIGTERM, shutdown)
        signal.signal(signal.SIGINT, shutdown)
        try:
            self.open_channel()
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
            self.close_channel()
            for descriptor in self.owner_fds:
                os.close(descriptor)
            self.owner_fds = []


def request_stop_on_precommit(timeout):
    """`etna_validator.py stop-on-precommit [--timeout S]`, with the supervisor's environment:
    arm the running supervisor's signer to stop on a precommit for a planned ruleset upgrade
    during a pause (START-10.1-14b), wait until it stopped the pair, and print the outcome. A
    supervisor that refuses to arm (stop_refusal) answers with the reason, and the command exits 1
    with nothing armed."""
    run_dir = Path(os.environ.get("ETNA_SUPERVISOR_RUN_DIR", str(Path(os.environ["ETNA_APP_STORE"]) / "supervisor")))
    request, done = run_dir / STOP_REQUEST, run_dir / STOP_DONE
    done.unlink(missing_ok=True)
    descriptor = os.open(request, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    os.close(descriptor)
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if done.exists():
            outcome = done.read_text().strip()
            if json.loads(outcome).get("stopped") is not True:
                print(f"etna supervisor: stop-on-precommit refused: {json.loads(outcome).get('refused')}",
                      file=sys.stderr)
                return 1
            print(outcome, flush=True)
            return 0
        time.sleep(.2)
    print(f"etna supervisor: no precommit within {timeout:g}s; the stop stays armed until the supervisor restarts",
          file=sys.stderr)
    return 1


if __name__ == "__main__":
    if sys.argv[1:2] == ["stop-on-precommit"]:
        arguments = sys.argv[2:]
        if arguments and not (len(arguments) == 2 and arguments[0] == "--timeout"):
            print("usage: etna_validator.py stop-on-precommit [--timeout SECONDS]", file=sys.stderr)
            sys.exit(2)
        try:
            sys.exit(request_stop_on_precommit(float(arguments[1]) if arguments else 600.0))
        except (OSError, ValueError, KeyError) as error:
            print(f"etna supervisor: {error}", file=sys.stderr)
            sys.exit(1)
    try:
        Supervisor().run()
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f"etna supervisor: {error}", file=sys.stderr)
        sys.exit(1)
