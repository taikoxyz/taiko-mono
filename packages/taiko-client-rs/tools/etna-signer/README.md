# Guarded native Etna signer

Build the standalone helper with Go 1.27.2 using `just signer` from
`packages/taiko-client-rs`. The host binary is
`target/etna-signer/etna-signer`; the production client image contains
`/app/etna-signer`. The module pins unmodified CometBFT v0.40.0.

## Bootstrap a new validator

Create a private directory outside the Comet home and every Comet mount. Run
these commands only for a new identity, before registration and genesis creation:

```sh
umask 077
mkdir ./private-validator
./target/etna-signer/etna-signer keygen \
  --priv-key ./private-validator/priv_validator_key.json \
  --priv-state ./private-validator/priv_validator_state.json
```

Success writes two exclusive, mode-0600, stock FilePV JSON files and prints one
JSON object with `publicKey` (0x-prefixed compressed 33-byte SEC1 key) and `address`
(0x-prefixed 20-byte Ethereum consensus address). Either existing output,
including a symlink, causes failure without replacing it. Parent directories must
already exist. Bootstrap uses stock OS-random `secp256k1eth` key generation. It
never exports a private key to stdout.

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

## Serve using existing authoritative files

Keep the existing guarded serve flags:

```sh
./target/etna-signer/etna-signer \
  --comet-signer-addr unix:///absolute/comet-home/run/signer-0123456789abcdef.sock \
  --trust-socket /absolute/path/app-store/checkpoint-trust.sock \
  --chain-id "$ETNA_CHAIN_ID" \
  --priv-key /absolute/private/priv_validator_key.json \
  --priv-state /absolute/private/priv_validator_state.json
```

Serve requires both existing regular files and a native `secp256k1eth` FilePV
identity with matching public metadata. It canonicalizes symlinks, refuses
hard-linked state and takes the existing state owner lock before loading the
stock FilePV. It never initializes or resets HRS. Preserve both signing files,
Comet WAL and app history on restart; never use `keygen` as a recovery action.

Use `script/start_etna_validator.sh` to supervise existing key/state paths and a
configured Comet home after starting the ABCI app. The script runs `cometbft start`
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
including a cached same-HRS retry, checks that private session again. PubKey and
Ping remain available while closed. Private trust control has one schema, 1. It requires
canonical 32-byte `target.comet_hash` and `target.val_state_hash` alongside the EL
checkpoint hash, and an always-present, nullable `recovery_origin`; absent, null,
malformed, unknown or duplicate fields fail closed. Denial never invokes FilePV signing.
Only stock FilePV writes signing state after authorization.

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
children, retains the halt in memory, and stays alive retrying persistence. The signer
closes its owned transport before stock server shutdown, so a blocked stock read cannot
delay terminal or signal shutdown until the transport deadline.

Observation publishing uses an exclusive random temporary file. A safe private regular
single-link `signer-denial.json.tmp` left by an older signer is preserved and ignored,
including a truncated write; it is never reused. Unsafe aliases still fail startup.
This diagnostic exception does not apply to signing uncertainty or halt evidence.

## Generation authority

For `script/start_etna_validator.sh`, set the existing `ETNA_COMET_HOME`,
`ETNA_APP_STORE`, `ETNA_PRIV_KEY`, `ETNA_PRIV_STATE`, and `ETNA_CHAIN_ID`, plus:

```sh
export ETNA_GENERATION=2
export ETNA_AUTHORITY_ROOT=/absolute/private/authority
export ETNA_L1_CHAIN_ID=1 ETNA_L2_CHAIN_ID=167001
export ETNA_INBOX=0x1111111111111111111111111111111111111111
# Only explicit activation after fencing the previous owner may request enrollment:
export ETNA_ENROLL_LEGACY=1
```

`ETNA_CHAIN_ID` must exactly match the installed Comet genesis. The signer checks
the full canonical domain against generation and deployment before opening
authority. Nonzero generations require authority mode; authority mode requires
all deployment fields and an explicit decimal uint48 generation.
`ETNA_PRIV_STATE` always names the original generation-zero HRS. The authority root,
key and original state must remain outside the Comet home/mounts and disposable app
store. The supervisor canonicalizes these paths and passes them to the signer.

`ETNA_ENROLL_LEGACY` accepts only `0` (default) or `1`; matching activation retries
may retain `1`. The supervisor never infers enrollment or changes generations from
observations. A same-generation refusal restart retains the configured flags and
requires the new signer's session to become Ready before restarting Comet. A new
generation observation halts the configured instance. Existing durable halt latches
remain in place across explicit generation changes and restartAlways restarts;
independent safety evidence requires operator investigation and repair.

After the previous signer has stopped, use the same registered key and original
state path with these additional serve options:

```sh
--authority-root /absolute/private/authority \
--l1-chain-id 1 --l2-chain-id 167001 \
--inbox 0x1111111111111111111111111111111111111111 \
--generation 2 --enroll-legacy
```

`--chain-id` must equal the canonical domain derived from both full decimal
uint256 chain IDs, Inbox and generation. Keep the authority directory, key,
original state and their adjacent `.lock` / `.authority.json` files outside
Comet mounts and all disposable app/recovery directories. The canonical key,
original state and authority root have exclusive owner locks. Symlink aliases
share ownership; hard-linked signing files are refused.

`--enroll-legacy` explicitly enrolls the existing generation-zero HRS once,
checking any signed bytes against that domain without rewriting the key or HRS.
Repeating the flag with exactly the same binding is idempotent. Incomplete marker
publication requires this flag to resume; missing completed markers, registry or
enrolled HRS require investigation. Neither enrollment nor a prepared recovery
plan grants permission to sign. Once either external enrollment marker exists,
standalone serve mode refuses that key/state.

A recovered generation's `recovery_origin` contains
`generation`, `height`, `l1_number`, `l1_hash`, `l1_timestamp`, `el_hash`,
`comet_hash`, `forced_cursor`, and `committee_hash` (the initial committee set
root). The app derives this summary from independently verified bootstrap
witnesses. It is null before authentication and for generation zero; generation zero
signs only with a null origin, a recovered generation only with its own origin.
PubKey/Ping and the initial Comet handshake work while trust is closed and do not
create a recovered HRS. Every signature and retry requires fresh private session
Ready with the configured domain and consistent checkpoint/origin.

An authenticated transition fsyncs an intent that permanently fences older
generations, exclusively creates an unsigned stock state named `<chain-id>.json`,
and atomically publishes enrollment plus the generation watermark before any
signature. Generations may be skipped. After inspecting any interrupted operation's
uncertainty fence, an operator restart can finish a matching intent with absent or
provably unsigned staging, after obtaining fresh authorization.
Signed orphan state, missing/corrupt enrolled state, changed binding or changed
origin fails closed. Preserve the entire registry and every historical state;
never delete metadata to retry recovery. Stock FilePV still owns HRS checks and
signing, with directory fsync completed before the transport receives a signature.
Before any FilePV signing step, enrollment metadata write, or authority transition,
the signer exclusively creates and fsyncs `<original-priv-state>.uncertain` and its
parent directory. This write-ahead fence lives in the existing writable original-HRS
namespace, remains shared across all generations, and is removed only after the changed
HRS and metadata are durable. Failure to arm it prevents the mutation. A failed state or
directory fsync, a stock persistence panic, or SIGKILL during a mutation leaves
signer-owned evidence before the supervisor can observe the exit; no post-failure disk
write is needed to block restart. Cached retries are fenced too. An idle SIGKILL leaves
no operation fence and can restart normally.

Every existing fence inode fails startup, including malformed, unreadable, or aliased
evidence. Both signer and supervisor refuse to rearm it across app/container restarts or
generation changes, and a supersession latch cannot acknowledge this uncertainty. The
signer exits nonzero on typed persistence uncertainty. After stopping all owners, inspect
and preserve the fence, original HRS, all per-generation HRS, manifest/intent/markers, and
supervisor/app first-cause evidence. An interrupted operation may be fully durable; the
fence deliberately still requires inspection. Only an explicit operator repair after
that inspection may remove the fence and resolve the supervisor halt. Never restore an
older HRS or authority backup, reset signed bytes, or delete authority metadata to resume
the identity.

## Recovery controller and retention

Use the [governance recovery runbook](../../docs/governance-recovery.md) for the exact
private validator/full-node profiles and prepare/activate/status commands. Activation is
foreground and starts the supported supervisor after fencing declared old owners. Stop
external services and their restart controllers first. Share protected persistent parent
mounts for adjacent leases; a component-only mount does not provide shared ownership.

The controller supplies explicit enrollment and canonical lowercase `ETNA_INBOX`. It
retains the registered key and original generation-zero HRS paths across every generation.
Keep both external authority markers, registry manifest/intent/watermark and every domain
state together with their locks. Missing enrolled files, ambiguous signed staging or generic
fatal/latch evidence require investigation and repair, never replacement files or resets.
Historical expected supersession is accepted only with matching typed authenticated evidence;
its original fatal/sidecar/latch bytes remain in place.

Stock Comet creates its own disposable, unregistered FilePV in fresh standard local paths
before replacing it with the mandatory guarded external signer. That dummy never signs for
a validator. Do not copy registered key/HRS into Comet, clear those standard paths or enable
a registered local fallback. The installed P2P node key remains a separate private identity.

Successful or replayed recovery InitChain keeps the signer-established private session.
Unavailable evidence closes readiness in that same session; contradictions halt. The owned
controller can observe a supervisor-rearmed same-boot session only when its private signer
incarnation matches, then must see fresh Ready. An app boot change or conflicting domain
fails closed. Offline status and persisted phases never authorize a signature.
