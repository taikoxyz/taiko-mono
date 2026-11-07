# Governance recovery operations

`taiko-client abci-recover` prepares and activates an explicitly requested, L1-finalized
Etna generation using usable local EL state at the retained height **c**. It supports
validators and consensus full nodes, with an optional lander using its original account
journal. It does not execute the governance transaction. Use only disposable development
chains: the lander still uses `DummyProofProvider` (`0x00`); the end-to-end fixtures use an
explicit disposable `MockVerifier`. Real proving, snapshot/app import, Unzen migration,
upgrade activation and verifier-failure rollback are outside this workflow.

Recovery authenticates the full deployment domain, generation and recovery execution block
**R** against the operator's own finalized L1. Fresh Comet genesis uses the full generation
chain ID, `initial_height=c+1`, `genesis_time=R.timestamp` and `app_hash=ELHash(c)`. Its first
block has empty LastBlockID/LastCommit. The global epoch schedule `H(t)=1+t*L` and global
K grid continue unchanged; the initial committee is the R snapshot for `floor(c/L)`,
effective at c+1. Old pending committee updates are discarded. The app's validator state
starts at c as stock CometBFT's genesis state for that committee. The landing record at c keeps
its original generation's EL, Comet and validator-state hashes; checkpoint trust does not
compare that validator-state hash, and the first new-generation landing starts from the genesis
state instead. No registered key, prior HRS, old Comet WAL/history or signed landing transaction
is copied into a new generation.

## Before preparation

- Retain usable canonical EL state at c, old EL ancestry, own L1 headers/storage proofs and
  required registry/admission history. Preparation makes read-only availability checks;
  activation performs a real unpromoted build on c. Keep
  `--engine.allow-unwind-canonical-header` disabled. The old EL head may remain above c
  until the recovered app commits its first branch through normal Engine calls.
- Stop original systemd/container/Kubernetes services and their restart controllers before
  activation. The local controller can stop only children it owns. It cannot adopt detached
  processes, infer ownership from saved PIDs, stop arbitrary services or detect an unrelated
  writer against the same EL when its store was not declared.
- Preserve the original app, Comet and optional lander directories. Retain the registered
  key, original generation-zero HRS, authority registry, all historical domain states and
  adjacent `.lock`/`.authority.json` files outside every Comet mount and disposable root.
  Keep backups protected with the same care as the key. Never initialize replacement HRS.
  Never restore an older HRS, FilePV state, or signing-authority backup to resume the same
  validator identity: a backup can omit signatures already released. If the latest state
  is lost or uncertain, stop signing and resolve the identity through governance; restoring
  app/EL/Comet data does not authorize rolling back signer state.
- All participating packaged processes must share the same protected persistent **parent**
  mount/inode namespace for adjacent ownership leases. Separate component-directory mounts
  alone do not share those locks. The installation parent must be protected and searchable
  by the actual Comet UID; a different UID/GID requires sufficient controller privileges.
- Supply a stock Comet v0.40.0 `goleveldb` config and the original Ed25519 P2P
  `config/node_key.json`. P2P identity is separate from the registered consensus key.
  Custom node-key paths, Unix RPC/ABCI endpoints, active state sync and custom TLS layouts
  require a supported template and a new preparation. A missing P2P identity is a prerequisite,
  never permission to silently replace it.

## Private validator profile

Write `/etc/taiko/recovery.toml` with mode 0600 (no group/other permissions). All path
values must be absolute. Replace the illustrative deployment, endpoints and paths below;
`chain.toml` must describe the actual deployment, including matching Inbox/registry and
chain identities. The profile is private, including executable prefixes and environment.
Programs execute directly with literal arguments; no shell expansion occurs.

```toml
schema = 1
role = "validator"
l1_chain_id = "0x1"
l2_chain_id = 167001
chain_config = "/etc/taiko/chain.toml"
l1_http = "http://127.0.0.1:8545"
l2_http = "http://127.0.0.1:8546"
l2_auth = "http://127.0.0.1:8551"
jwt_secret = "/var/lib/taiko/private/jwt.hex"
app_data_dir = "/var/lib/taiko/app"
comet_home = "/var/lib/taiko/comet"
installation_parent = "/var/lib/taiko/consensus"
peers = ["0123456789012345678901234567890123456789@peer.example:26656"]

[app]
program = "/opt/taiko/taiko-client"
argv = ["abci"]
env = {}

[comet]
program = "/opt/taiko/cometbft"
argv = ["start"]
env = {}

[inspector]
program = "/opt/taiko/etna-comet-inspect"
argv = []
env = {}

[signer]
key = "/var/lib/taiko/private/registered-key.json"
state = "/var/lib/taiko/private/original-generation-zero-hrs.json"
authority = "/var/lib/taiko/private/authority"

[signer.executable]
program = "/opt/taiko/etna-signer"
argv = []
env = {}

[signer.supervisor]
program = "/usr/bin/python3"
argv = ["/opt/taiko/script/etna_validator.py"]
env = {}
```

Use Python 3.11+ for the supervisor. `just signer` builds both pinned native Go helpers;
packaged paths are `/app/etna-signer`, `/app/etna-comet-inspect`,
`/app/script/etna_validator.py`, `/app/taiko-client` and `/usr/bin/cometbft`.
The inspector must be selected before prepare because the profile digest binds it.
The controller appends owned RPC, ChainParams, data-dir, signer and Comet-home arguments.
Do not add conflicting owned flags or enrollment/session overrides to prefixes.

For a full node, change `role = "full-node"` and remove `[signer]`,
`[signer.executable]` and `[signer.supervisor]` entirely; retain app, Comet and inspector.
It has no registered signing authority. Stock Comet creates an unregistered local FilePV
in the fresh standard paths for both roles before selecting the external signer on a
validator. The validator's local dummy never signs; do not copy a registered key there or
clear its local paths.

To let activation own a separate lander process, append this optional profile section.
The signing-key file supplies the existing funded account; use the same original journal
and one active lander per account. Set explicit fee budgets and the sidecar format for your
disposable deployment; the values below are illustrative.

```toml
[lander]
data_dir = "/var/lib/taiko/lander"

[lander.executable]
program = "/opt/taiko/taiko-client"
argv = ["lander", "--signing-key", "/var/lib/taiko/private/lander.key", "--max-blocks", "6", "--max-blobs", "6", "--max-fee-per-gas", "2000000000", "--max-priority-fee-per-gas", "1000000000", "--max-fee-per-blob-gas", "1000000000", "--sidecar", "eip7594"]
env = {}
```

Alternatively omit `[lander]` and run a separately supervised `taiko-client lander` using
its unchanged journal and documented lander flags after recovery starts. Stop that service
before any later activation. Both modes authenticate the current generation and preserve
original pending signed bytes. Another honest lander may produce the finalized landing.

## Prepare, inspect and activate

Choose a short private root with an existing protected parent, disjoint from original
component/input/signer paths. New directories are private 0700 and files 0600. Canonical Unix
socket paths must fit 103 bytes; `runtime-socket-path` means use a shorter root and prepare
again. Do not edit published profile/artifacts. Changes require a new plan.

The commands below use generation 1 and an illustrative full 32-byte plan ID. Replace it
with `plan_id` from prepare output; never infer it from a generation, phase or directory name.

```sh
taiko-client abci-recover prepare --profile /etc/taiko/recovery.toml --generation 1 --root /var/lib/taiko/r --json
```

Prepare checks chain identities, historical proofs, current finalized generation and fixed
c/R, then publishes an immutable bundle. It starts no child and makes no Engine build,
newPayload/forkchoice, key/HRS or lander-journal mutation. Public reports contain no endpoint
credentials, signer paths, argv or private environment. Private `profile.json` stays protected.
An identical published plan is idempotent; a conflicting/corrupt bundle is refused.
Directories use the first 16 hex digits for pathname space, but every load validates the full ID.

```sh
taiko-client abci-recover status --root /var/lib/taiko/r --plan 0x1111111111111111111111111111111111111111111111111111111111111111 --json
```

This illustrative prepared-status object uses c=6, R=100 and a later authenticated checkpoint
at 12. Actual plan IDs/heights/prerequisites depend on authenticated evidence and local inputs.

```json
{
  "plan_id": "0x1111111111111111111111111111111111111111111111111111111111111111",
  "generation": 1,
  "origin_height": 6,
  "recovery_l1_block": 100,
  "phase": "prepared",
  "landed_height": 12,
  "trust_target_height": 12,
  "component_state": "not-observed",
  "committed_height": null,
  "prerequisites": ["activation-build-probe", "comet-node-key"],
  "live_trust": false,
  "last_observation": null,
  "blocker": null
}
```

Offline status never queries a live private session. `live_trust` is always false;
`last_observation` and committed/landed heights may be historical. Prepared prerequisites
remain immutable even after activation. They are observations, not signing authority.

After stopping all external original services, activate in the foreground:

```sh
taiko-client abci-recover activate --profile /etc/taiko/recovery.toml --root /var/lib/taiko/r --plan 0x1111111111111111111111111111111111111111111111111111111111111111
```

Activation reauthenticates the plan against own finalized L1, fences declared original and
previous/current stores, inspects safety/native crash evidence, probes usable c state,
installs a separate Comet home, atomically selects it and starts owned app, supervisor/Comet
and optional lander. Registered files and old stores remain in place. SIGINT/SIGTERM await
ordered lander → supervisor/Comet → app shutdown while retaining ownership leases.
Keep the controller supervised as a foreground process; do not background/adopt its children.

The journal phases are `prepared`, `stopping`, `isolated`, `el-origin-ready`, `installed`,
`running`, `trusted`, `settled`. Phases are checked against real facts on every resume.
`trusted` requires the exact private session/domain/origin and current authenticated target;
logical c alone is not a new commit. `settled` additionally requires an own-L1-finalized
new-generation landing above c, matching canonical EL, local committed Comet history and the
app's validator state.
The controller continues monitoring after settlement and clears observed trust on uncertainty.

## Enrollment, waits and interruption

Validator activation explicitly supplies `ETNA_ENROLL_LEGACY=1` with the same registered key,
original generation-zero HRS and permanent authority root. This one-time binding is idempotent
on exact retries. Once markers exist, standalone legacy serving refuses that key/state.
Only fresh private Ready with the authenticated origin can create/enroll a recovered domain.
PubKey/Ping work while closed and create no recovered HRS. Each signature/retry checks Ready again.
A durable transition intent fences all older generations before a new HRS can sign; retain
the intent, manifest, watermark, both external markers and every historical state. See the
[signer operations](../tools/etna-signer/README.md#generation-authority) for persistence rules.

On first start the signer connects without `--await-trust` so closed PubKey/Ping permits
InitChain and sync. Successful/replayed InitChain preserves that private signer session.
Unavailable authentication closes readiness in the same session; integrity failure halts.
A signing refusal causes the owned supervisor to quiesce Comet/signer, start a fresh signer
with `--await-trust`, wait for its exact Ready session and restart Comet for WAL replay.
The controller may reobserve that verified same-app-boot signer incarnation; an app boot
change, counter rollback, malformed/domain-mismatched session or unexpected full-node rearm
fails closed. Denial files, journal phases and public `/trust` are never signing authority.

The lander preserves each old job's proof, blobs, account nonce and signed network bytes.
Never-broadcast obsolete work can finish; possibly broadcast work must reconcile canonical
receipt/account nonce first. A reorged receipt with an unchanged account nonce can leave the
old pending job **Waiting**, while consensus continues. The runner does not automatically
rebroadcast/replace obsolete work or allocate a new nonce to bypass it. Investigate with the
account owner and canonical L1. If appropriate, explicit rebroadcast must use the **exact
original signed network bytes**; an old-generation call can revert under the new generation
and consume that nonce. Normal receipt/account reconciliation can then allow new work.
No fee replacement, journal editing, nonce reset or new account-path bypass is implied.

To resume an interruption, stop and reap any surviving owned descendants through the actual
service owner, then rerun the exact activate command/profile/root/full ID. Live inherited
leases or uncertain ownership return Busy; saved PID records do not authorize signaling or
adoption. An incomplete `.stage-<16hex>` publication also returns Busy and retains evidence.
Inspect it before repair; never delete unverified staging to force progress.

`external-owner`, `evidence-unavailable` and `waiting-for-trust` describe closed waiting;
`component-exited` stops the owned runtime, and `stopped` records ordered cancellation.
`safety-halt` requires investigation. Preserve fatal evidence,
supervisor latches, original HRS/WAL and authority files. Missing/corrupt enrolled HRS,
ambiguous signed staging, a lost registry/marker or a generic old fatal/latch is operator
repair, never a reset instruction or permission to choose a fresh generation path.
Expected historical supersession is acknowledged only with matching typed proof-authenticated
sidecar/state/fatal/latch bytes and a freshly authenticated later generation; those files
are retained. A newly created current fatal/latch halts immediately. Resolve unsupported
layout, local state, ownership and safety prerequisites before a new attempt.
