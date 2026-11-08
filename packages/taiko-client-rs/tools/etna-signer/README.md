# Guarded native Etna signer

Build the standalone helper with Go 1.27.2 using `just signer` from
`packages/taiko-client-rs`. The host binary is
`target/etna-signer/etna-signer`; the production client image contains
`/app/etna-signer`. The module pins unmodified CometBFT v0.40.0.

## Bootstrap a new validator

Keep three private locations outside the Comet home, every Comet mount and the app store:
the registered key, the HRS state directory and the domains log. Put the domains log on a
**different volume** from the state directory (its own PVC in Kubernetes): the log is the
evidence that a state existed, so losing the state volume is detected instead of looking like a
fresh start. The signer only checks that the two directories differ; separate volumes are the
operator's duty. Run these commands only for a new identity, before registration and genesis
creation:

```sh
umask 077
mkdir -p /private/key /private/hrs /private/domains
./target/etna-signer/etna-signer keygen --priv-key /private/key/priv_validator_key.json
./target/etna-signer/etna-signer init-domains-log --domains-log /private/domains/domains.log
```

`keygen` writes one exclusive, mode-0600, stock FilePV key and prints one JSON object with
`publicKey` (0x-prefixed compressed 33-byte SEC1 key) and `address` (0x-prefixed 20-byte
Ethereum consensus address). It writes no HRS state. An existing output, including a symlink,
causes failure without replacing it. Parent directories must already exist. Bootstrap uses
stock OS-random `secp256k1eth` key generation. It never exports a private key to stdout.

`init-domains-log` creates the log with only its header line `etna-signer-domains-v1`
(exclusive create, mode 0600, file and directory fsync); it refuses an existing path or symlink.
Run it once per key.

Once the genesis is known, and again for every new generation after a governance recovery,
create that `chain_id`'s HRS state with the signer stopped:

```sh
./target/etna-signer/etna-signer init-state --chain-id "$ETNA_CHAIN_ID" \
  --priv-key /private/key/priv_validator_key.json \
  --priv-state "/private/hrs/$ETNA_CHAIN_ID.json" \
  --domains-log /private/domains/domains.log
```

`init-state` checks that the chain ID matches `[A-Za-z0-9_-]{1,50}` (stock `MaxChainIDLen`;
an Etna chain ID is `etna-<base64url>`), that the state file is named `<chain_id>.json` and that
the log is in another directory. It takes the key's owner lock and an exclusive lock on the log,
refuses a chain ID already in the log and an existing state file, then exclusively creates the
stock unsigned HRS and fsyncs it and its directory, and only then appends `<chain_id>` to the
log in one write and fsyncs the log and its directory. It reports success only once the log
line is durable. A full `chain_id` gets exactly one HRS state, which is never reset or rolled
back (RECOV-8.2-1).

If `init-state` is interrupted after creating the state and before the log line, an unlogged
state remains, and both `serve` and `init-state` refuse it. Check that the file is byte for byte
the stock zero state (`{"height": "0", "round": 0, "step": 0}`, indented as FilePV writes it),
remove it and rerun `init-state`. A state that is not the zero state may have signed:
never remove it. Never edit the log by hand. The one documented exception is the repair of a
torn tail (Repairing a torn domains log).

Create the registration proof for the actual owner, registry and L1 chain:

```sh
./target/etna-signer/etna-signer pop \
  --priv-key ./private-validator/priv_validator_key.json \
  --owner 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
  --registry 0x2222222222222222222222222222222222222222 \
  --l1-chain-id 1
```

Success prints one JSON object with `publicKey` and `signature`, both 0x-prefixed
hex. The signature is exactly 65 bytes `R || S || V`, with low S and V in {0,1}.
The EIP-712 domain is name `EtnaStakingRegistry`, version `1`, the full decimal
uint256 L1 chain ID and verifying registry. Its message is `Register(address
owner)`. The helper passes `0x1901 || domainSeparator || structHash` to stock
`secp256k1eth.Sign`, which applies legacy Keccak exactly once. PoP neither reads
nor writes consensus HRS state and can run offline. Registering on L1 is a separate
operator/deployment action.

## Serve one chain_id

```sh
./target/etna-signer/etna-signer \
  --comet-signer-addr unix:///absolute/comet-home/run/signer-0123456789abcdef.sock \
  --trust-socket /absolute/path/app-store/checkpoint-trust.sock \
  --chain-id "$ETNA_CHAIN_ID" \
  --priv-key /private/key/priv_validator_key.json \
  --priv-state "/private/hrs/$ETNA_CHAIN_ID.json" \
  --domains-log /private/domains/domains.log
```

Serve is the default command and has one mode: it signs only for `--chain-id`, into that chain
ID's own HRS state. A recovered generation has a new full `chain_id`, so it is served with its
own state from `init-state` and the same key and log (RECOV-8.2-5/8.2-6). The optional flags are
`--denial-file`, `--trust-timeout` and `--await-trust`.

Before serving, the signer checks, in this order: the chain ID, the state's `<chain_id>.json`
name and the log's directory; the key (an existing single-link native `secp256k1eth` FilePV
identity with matching public metadata) and its exclusive owner lock `<key>.lock`; the log,
opened without following symlinks under a shared lock, which must be well formed, is fsynced
with its directory (so a line from an `init-state` killed before its own fsync is durable
before any signature depends on it) and must list the chain ID; the state, which must exist
for a logged chain, have exactly one link and resolve to `<chain_id>.json`, and its exclusive
owner lock `<state>.lock`; the absence of the `<state>.uncertain` fence and of the supervisor's
`<chain_id>.signer-unsafe` marker beside the log; and the HRS, which must be the stock zero
state or carry a signature by the registered key over that chain ID's canonical sign bytes.
Only then does it load the stock FilePV. It never creates, initializes or resets HRS. The
locks are held while serving, so two signers sharing these files never both serve
(RECOV-8.2-2); another host is outside their reach (see Failover). Preserve the key, every
state, the log, the Comet WAL and app history on restart; never use `keygen` or `init-state`
as a recovery action.

The signer creates `<key>.lock` beside the key and `<state>.lock` beside the state, so both
directories must be writable by the signer. The key file itself may be read-only, but a
read-only key directory, such as a Kubernetes Secret volume, fails startup with exit 1.

### Refusal matrix and exit codes

| Code  | Meaning                                                                                                                                           | Supervisor action                            |
| ----- | ------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| 0     | Signal stop                                                                                                                                       | —                                            |
| 1     | Configuration, transport or lock error (a missing flag or key, a wrong state name, the log in the state directory, another signer holding a lock) | Restart; the fifth exit within 600 s latches |
| 2     | Go panic, for example a failed stock FilePV state write; no signature was released                                                                | Restart; counts toward the same limit        |
| **3** | Signing state lost or uncertain (RECOV-8.2-3)                                                                                                     | Halt (latch), never restarted                |

Exit 3 covers every case where the state cannot be trusted, and nothing is created, repaired or
reset:

| Case                                      | Example                                                                                            |
| ----------------------------------------- | -------------------------------------------------------------------------------------------------- |
| Domains log missing or not a regular file | the log volume is lost, or the path is a symlink                                                   |
| Domains log malformed                     | wrong header, torn last line (no final newline), blank or invalid line, duplicate line, over 1 MiB |
| Domains log uncertain                     | the log or its directory fails its startup fsync                                                   |
| Chain ID not in the log                   | `init-state` never ran for it, or was interrupted before its log line                              |
| Chain ID logged, state missing            | the state file or the state volume is lost                                                         |
| HRS ambiguous                             | a hard-linked state, a state that resolves to another chain's file, unknown or duplicate fields    |
| HRS unauthentic                           | a signed state without a valid signature by the registered key over this chain ID                  |
| Retained fence                            | `<state>.uncertain` exists                                                                         |
| Retained signer-unsafe marker             | `<chain_id>.signer-unsafe` exists beside the domains log (see Supervisor restarts and latches)     |
| Persistence failure while serving         | a state or directory fsync fails; the signer writes the fence, then exits 3                        |

The domains log detects only absence: a missing log, a chain it does not list, or a logged
chain whose state is missing. It never detects rollback. It records chain IDs, never heights,
so an older HRS restored from a backup, with or without the log, is still signed by the
registered key for a logged chain: it passes every check and is served. Losing both the state
and the log volume likewise looks like a fresh deployment. Neither can be detected; both are
forbidden operational practice: never restore any signing state from a backup (RECOV-8.2-1,
RECOV-8.2-6).

### Repairing a torn domains log

A log whose last byte is not a newline is torn: an `init-state` append was interrupted, and
every serve refuses the log (exit 3). This is the one documented exception to never editing the
log by hand. Only an operator repairs it, in this order; nothing repairs it automatically.

1. Stop every signer that uses the log, and every supervisor and restart controller that could
   start one.
2. Identify the torn chain. Every complete line, ending in a newline, is valid: keep each one as
   it is. The bytes after the last newline are a prefix of the chain ID whose `init-state` append
   was interrupted. Its state is the one `<chain_id>.json` in the state directory that no
   complete line lists. That chain was never served, because serving needs its complete line.
3. Check that this unlogged state is byte for byte the stock zero state (see Bootstrap). If it is
   not, if no state or more than one is unlogged, or if the torn bytes are not a prefix of its
   chain ID, stop without truncating: the state may have signed, and it is resolved through
   governance (RECOV-8.2-3).
4. Copy the log byte for byte, and keep the copy as evidence.
5. Only then truncate the bytes after the last newline, and fsync the log, for example:
   `python3 -c 'import os,sys; p=sys.argv[1]; n=open(p,"rb").read().rindex(b"\n")+1; f=os.open(p,os.O_WRONLY); os.ftruncate(f,n); os.fsync(f)' /private/domains/domains.log`
6. Remove the zero state and rerun `init-state` for that chain.
7. The refusal was an exit 3: the supervisor latched it and left its signer-unsafe record in the
   app store and the marker `<chain_id>.signer-unsafe` beside the log, for the chain_id it was
   started with. Remove the latch, the record and the marker only under the evidence rules of
   Supervisor restarts and latches: no fence, and no I/O error for the state volume in the kernel
   log or in the signer's stderr.

Never remove or change a complete line, and never truncate a log that ends in a newline.

### Supervision and trust

Use `script/start_etna_validator.sh` to supervise the signer and a configured Comet home after
starting the ABCI app. Set `ETNA_COMET_HOME`, `ETNA_APP_STORE`, `ETNA_PRIV_KEY`,
`ETNA_PRIV_STATE_DIR` (the state directory), `ETNA_DOMAINS_LOG` and `ETNA_CHAIN_ID`, which must
equal the installed Comet genesis. The supervisor passes `--priv-state
<ETNA_PRIV_STATE_DIR>/<ETNA_CHAIN_ID>.json --domains-log <ETNA_DOMAINS_LOG>` and refuses a key,
state directory or log inside the Comet home or the app store. It does not check that the
state exists: the signer does, and exits 3. It writes its signer-unsafe marker into the log's
directory, which must therefore be writable by the supervisor. The script runs `cometbft start`
directly. Container callers must likewise invoke the stock binary directly with
`--entrypoint /usr/bin/cometbft`; the image's default entrypoint can initialize
files and must not be used for validator runtime. Its `priv_validator_laddr` is
mandatory. A `unix://` value only selects Unix mode: for every signer+Comet start the
supervisor names a fresh `<comet-home>/run/signer-<16 hex>.sock`, passes it to Comet as
`--priv_validator_laddr` and to the signer as `--comet-signer-addr`. With a `tcp://`
value Comet listens on that address and the signer dials it. Keep the registered private
key inaccessible to Comet. Node P2P and SecretConnection transport identities remain
separate Ed25519 keys.

Every transport connection opens a fresh closed trust session. Every signature,
including a cached same-HRS retry, checks that private session again over its own bounded
connection (SYNC-9-10). PubKey and Ping remain available while closed. Private trust control
has one schema, 1, and the signer reads only `schema_version`, `session_id`, `chain_id` and
`phase` from it: it signs only when the reply is for the transport's current session, names
the served chain ID and reports phase `ready`. Keys match exactly, so a case variant such as
`Phase` is just another field. Every other field, known or unknown, is ignored; the app
reports `ready` only after its own checkpoint target, validator-state and InitChain checks
(SYNC-9-5, RECOV-8.2-4). A reply for another session also drops the armed session. A
missing, null or empty session, a missing or null phase, a null, empty or other chain ID,
another schema, a malformed, oversize or duplicate-key reply, an absent app and a timeout all
deny (SYNC-9-11). Denial never invokes FilePV signing. Only stock FilePV writes signing state
after authorization.

Run `just signer-test` for Go race/process/native interop tests. No Cargo build is
needed for this helper.

The supported supervisor adds `--denial-file <app-store>/signer-denial.json`.
It is a private atomic observation, not signing state or authorization: sequence zero
publishes a fresh session ID, and positive sequence increments capture every signing
refusal, including a local-control timeout while the app remains Ready. The supervisor
uses nonmutating `observe`, waits for exact private Ready, then reaps Comet and
the signer with unchanged HRS/WAL/history. Stock Comet never retries a refused request;
only a restarted Comet's WAL replay asks for that step again. So the supervisor first
restarts the signer alone with `--await-trust`: it begins the fresh closed session for its
first transport and dials Comet only after that session passes the same check as every
signature. Until then each dial attempt fails and is retried on the same session; it begins
another only when the app reports a different current session, for example after an app
restart. Once `observe` reports the published session Ready, the supervisor starts Comet,
whose WAL replay then gets the refused step signed. Later reconnects of that process dial
at once, as without the flag: a request made while no signer is connected would fail
inside Comet unreported, whereas a refusal reaches the supervisor. Never pass
`--await-trust` on a first start: Comet's startup needs the signer connected, and a node
that is behind regains trust only after Comet syncs. Every new transport still begins a
closed session. Terminal trust/domain failures persist a latch and leave the supervisor
alive and quiescent, including after container restart. See the package README for the
supported combined image and separate app/supervisor container commands.
If the halt cannot be written or synchronized, the supervisor still stops/reaps its
children, retains the halt in memory, and stays alive retrying persistence; a signer it must
kill is the exception (Supervisor restarts and latches). The signer
closes its owned transport before stock server shutdown, so a blocked stock read cannot
delay terminal or signal shutdown until the transport deadline.

Observation publishing writes an exclusive random temporary file and renames it over the
denial file; it never opens a fixed temporary name.

### Supervisor restarts and latches

A healthy signer exits only when the supervisor stops it. Every other exit is either a crash,
which restarts the signer and Comet as a pair, or unsafe signing state, which latches and is
never restarted (SYNC-9-14):

| Signer exit                                                                   | Fence   | Supervisor action                                                                                                                                                                                                                                                                          |
| ----------------------------------------------------------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 3                                                                             | any     | Latch "signer refused unsafe signing state; inspect its stderr, `<state>.uncertain` and the domains log", and create the signer-unsafe record and marker                                                                                                                                   |
| any                                                                           | present | The same latch, record and marker                                                                                                                                                                                                                                                          |
| still running 5 s after the supervisor's SIGTERM, so SIGKILLed                | any     | Before the SIGKILL, log `etna_supervisor_signer_killed` and create the signer-unsafe record and marker; then latch "signer did not stop within 5s of SIGTERM and was killed; …". It may be blocked on a failing state volume after a failed fsync and before its fence                     |
| 0, 1, 2 or a signal, while the supervisor is not stopping it                  | absent  | Record the exit; the fifth within 600 s latches "signer exited 5 times within 600s; inspect diagnostics". Otherwise reap Comet, start a fresh signer with `--await-trust` on the same state path and a fresh transport, and start Comet once the signer's new session is Ready (SYNC-9-12) |
| 0, 1, 2 or SIGTERM while the supervisor stops it (shutdown, recovery restart) | absent  | Normal                                                                                                                                                                                                                                                                                     |

A restart is safe because it changes nothing the signer relies on. The new signer serves the
same `<chain_id>.json` and repeats every startup check; stock FilePV continues from the HRS on
disk, returns the stored signature for the same step and refuses conflicting data or a lower
step (RECOV-8.2-1, SYNC-9-13). No signature leaves the signer before both fsyncs, so a crash,
a SIGKILL or a stock persistence panic (exit 2, whose temporary file is never renamed over the
state) released nothing that the HRS on disk does not cover. The dead signer is reaped, which
closes its descriptors and releases its key and state flocks, and Comet is reaped before the
new signer starts: two signers never overlap (RECOV-8.2-2). Each pair begins a new closed trust
session on its own transport; in Unix mode it never reuses the dead pair's socket.

Each restart costs one Comet restart and one trust re-authentication. Five exits within ten
minutes are a persistent fault and latch. The count lives in the supervisor's memory and is not
reset by a successful restart; a supervisor or container restart resets it, and the container's
`CrashLoopBackOff` bounds that case.

The signer-unsafe record, `<app-store>/validator-supervisor.signer-unsafe`, is independent of
the first-cause latch: the supervisor's start, every restart and every tick refuse while it
exists, so repairing only another latched cause never restarts the signer. Exit 3, a fence, and
an unsafe exit or kill found while halting for another cause all create it, together with the
signer-unsafe marker `<chain_id>.signer-unsafe` in the domains log's directory. The marker holds
the same text on the log's own volume, so a fresh app store cannot lose it: the supervisor
refuses to start while either exists, and the signer refuses the marker with exit 3, like a
fence (any inode, or any error but its absence). For a signer killed before it wrote its fence,
or an exit 3 whose fence write failed, the record and the marker are the only evidence of an
uncertain HRS. A marker names one chain_id, so a recovered generation's new chain_id is not
refused by an older generation's marker. Nothing removes either automatically. A signer blocked
on a failing volume sleeps uninterruptibly and may not be reaped for minutes, or ever on a hard
NFS mount, and the supervisor may itself be killed during that wait (for example by the
kubelet after `terminationGracePeriodSeconds`). So a kill is recorded before the SIGKILL is
sent: the supervisor logs `etna_supervisor_signer_killed` (recording before SIGKILL), creates the
record and the marker and fsyncs each with its directory, retrying both until both succeed, and
then logs `etna_supervisor_signer_kill_recorded`. So the supervisor does not always stop its
children: while the record or the marker cannot be written, it never sends the SIGKILL, the
signer is left running (Comet is already stopped), and a SIGTERM to the supervisor waits too,
until the kubelet's SIGKILL ends the pod. A stop takes up to 12 s for Comet plus the 5 s grace:
set the pod's `terminationGracePeriodSeconds` above 17 s with margin for the fsyncs, for example
the Kubernetes default of 30 s. A shorter one lets the kubelet SIGKILL a slow signer without a
record. A SIGKILL from someone else during the 5 s grace is recorded only once the supervisor
has reaped the signer. A healthy signer waiting on a slow app can also exceed the grace (each
trust query is bounded by `--trust-timeout`, 1 s by default); that is recorded and latched too,
which is safe. Remove the record, the marker and the latch only after inspection shows that no
fsync failed: no fence, no I/O error for the state volume in the kernel log, none in the
signer's stderr. Otherwise the state is uncertain and is resolved through governance
(RECOV-8.2-3).

The app store is not disposable while it holds this evidence. Never delete or replace an app
store that holds a latch or a signer-unsafe record; preserve it. Before running a validator for a
chain_id on any new app store (a re-import into a new root, cleared stores, a rebuilt pod), check
the old app store for a signer-unsafe record or a latch for an unsafe signer exit or a killed
signer, and the domains log's directory for `<chain_id>.signer-unsafe`. Any one of them is
uncertain signing state for that chain_id, resolved through governance (RECOV-8.2-3), never by a
new store (ACCEPTANCE §7.7).

Residual risk: any death of the signer between a failed fsync and a durable fence leaves no
fence and no exit 3, and the supervisor restarts it like any crash. That covers a SIGKILL from
outside the supervisor (the OOM killer, `kill -9`) and a Go runtime fatal error (exit 2) inside
`writeFence`. On Linux the failed write-back's error may already have been reported and the
dirty pages dropped, so a cached retry's fsync can succeed over state that never reached disk
(SYNC-9-13). The HRS then rolls back after a host crash, or after the kernel evicts those pages
and the signer restarts. Never SIGKILL the signer, and give it enough memory that neither the
OOM killer nor a failed Go allocation ends it. A killed container had the same window before
the supervisor restarted signers.

### Failover

Moving a validator to a standby host is operational practice (RECOV-8.2-6). The key, state and
log flocks protect one host's files only: two hosts holding copies of the key both sign, and the
signer cannot see the other host. Never fail over uncertain state: a host with a
`<state>.uncertain` fence, a `validator-supervisor.signer-unsafe` record, a
`<chain_id>.signer-unsafe` marker beside the domains log, or a latch for an unsafe signer exit
or a killed signer is resolved through governance, not moved (RECOV-8.2-3).
Never run `init-state` (or `init-domains-log`) on the standby: it would start a second history
for a chain that has already signed. Move, never copy:

1. Stop the old host's supervisor and every restart controller that could start it again, and
   fence the host so its signer can never run again: power it off, or detach its volumes.
2. With the old host's volumes attached to the standby or a maintenance host, check that its
   state directory holds no fence, its domains log's directory no signer-unsafe marker for any
   chain_id being moved, and its app store no signer-unsafe record or unsafe or kill latch.
   Their absence is not enough: a host that died abruptly, or a pod SIGKILLed inside the grace
   window, leaves none of them even after a failed fsync. So, as before removing a record,
   inspect the old host's kernel log for an I/O error on the state volume and the signer's
   stderr for a failed fsync; if either shows one, the state is uncertain and is resolved
   through governance (RECOV-8.2-3). Then move the key, the latest `<chain_id>.json` of every
   chain and the domains log byte for byte from those volumes, never from a backup or a
   snapshot of a running host. Keep the states and the log on separate volumes.
3. Delete the state files from the old volumes, wherever they are attached, or destroy those
   volumes, before anything could start the old host again; if it does start, it then refuses
   (exit 3, logged chain without state). Then start the standby.

The standby continues from the moved HRS: it returns the stored signature for the same step and
refuses conflicting data and lower steps (`TestHRSSurvivesCrashRestartAndFailover`, ACCEPTANCE
§2.4). A move of the state without its log, even with a newly initialized log, or of the log
without the state, refuses with exit 3. An older state cannot be detected and double-signs
(RECOV-8.2-1/2).

## Fence on fsync failure

Stock FilePV owns HRS checks and signing, and writes each new HRS through an `O_SYNC`
temporary file renamed over the state. Before the transport receives a signature, cached
same-HRS retries included, the signer fsyncs the state file and then its directory: exactly two
fsyncs for each request that reaches FilePV (SYNC-9-13). A crash, SIGKILL or stock persistence
panic (exit 2) writes no fence and needs none: no signature is released before both fsyncs
succeed, and the disk holds either the old or the new HRS, so a restart continues from it and
may sign an unreleased step again without equivocating. Stock FilePV then returns the stored
signature for the same step and refuses conflicting data or a lower step.

A failed state or directory fsync makes the latest state uncertain (RECOV-8.2-3). The signer
withholds the signature and latches in memory, refusing every later request, cached retries
included. It then exclusively creates `<priv-state>.uncertain` beside the HRS, recording the
failed operation, the state path and the error, fsyncs it and its directory, and exits 3, which
the supervisor latches. The fence makes a restarted signer refuse with exit 3 even if the
supervisor's latch is lost; the supervisor's latch and record, on the app-store volume, and its
marker, on the domains log's volume, hold even when the fence or its directory fsync fails. An
existing inode at the fence path is kept as it is.

Every existing fence inode fails startup with exit 3, including malformed, unreadable, or
aliased evidence. Both signer and supervisor refuse to rearm it across app or container
restarts. After stopping all owners, inspect and preserve the fence, the HRS, the domains log
and the supervisor and app first-cause evidence, and check the disk. Only an explicit operator
repair after that inspection may remove the fence and resolve the supervisor halt and its
signer-unsafe record and marker. Never restore an older HRS, reset signed bytes, or edit the log
to resume the identity.

## Governance recovery

Use the [governance recovery runbook](../../docs/governance-recovery.md) for the
`abci-recover prepare`, `install` and `status` commands. The operator stops the old app,
supervisor, lander and their restart controllers, installs fresh stores, runs `init-state` for
the new generation's `chain_id` with the same key, state directory and log, then restarts the
EL and app, the supervisor and the lander in that order. Every older chain's HRS stays in the
state directory, unchanged and never served again. A superseded generation leaves the app's
generic fatal evidence in its old app store, which `install` never reuses; leave those bytes in
place. The supervisor adds its plain-text latch there only when it observes the app's halted
phase. When the app exits on a safety halt instead, observation fails and nothing is latched;
signing stays refused all the same, because trust control is unavailable.

Stock Comet creates its own disposable, unregistered FilePV in fresh standard local paths
before replacing it with the mandatory guarded external signer. That dummy never signs for
a validator. Do not copy registered key/HRS into Comet, clear those standard paths or enable
a registered local fallback. The installed P2P node key remains a separate private identity.

Successful or replayed recovery InitChain keeps the signer-established private session.
Unavailable evidence closes readiness in that same session; contradictions halt. Offline
`abci-recover status` and plan files never authorize a signature.
