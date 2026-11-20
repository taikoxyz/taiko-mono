# Governance recovery operations

`taiko-client abci-recover` has three one-shot commands. `prepare` authenticates an explicitly
requested, L1-finalized Etna generation and writes a plan file. `install` writes a fresh Comet
home and an empty app directory from that plan. `status` summarizes a plan offline. None of them
starts, stops or signals a service: the operator stops the old services and starts the new ones.
The commands do not execute the governance transaction.

Use only disposable development chains: the lander still uses `DummyProofProvider` (`0x00`),
and the end-to-end fixtures use an explicit disposable `MockVerifier`. Real proving, Unzen
migration, upgrade activation and verifier-failure rollback are outside this workflow.

## Scope

A recovery starts a new generation from the retained landing at height **c**, executed on L1 at
block **R**. Every node authenticates c and R from its own finalized L1 view (RECOV-8.4-2) and
builds the same genesis (RECOV-8.4-7..9):

- `chain_id` is the full chain ID of the new generation;
- `initial_height = c+1` and `genesis_time = R.timestamp`;
- InitChain returns `app_hash` = appHash of ELHash(c) and the genesis validator state
  (CONS-3.1-8), and the EL state must match c's authenticated hash and state root;
- the validators are the committee selected on R's registry snapshot for epoch `floor(c/L)`.

The first block uses stock genesis's empty LastBlockID/LastCommit (RECOV-8.4-10). The FI cursor
starts at the authenticated origin head (RECOV-8.4-11). Every anchor and L1 root the new
generation uses is at or after R (RECOV-8.4-12/13). The global epoch schedule continues
unchanged, and old pending committee updates are discarded. Votes in different
generations use different signing domains and are not double signs; the new generation keeps
its own HRS state from c+1 (RECOV-8.2-5/6). The app's InitChain repeats every check `prepare`
makes, against its own L1 and EL.

The Etna start is written once and never corrected (START-10-5c): a recovery at c = S starts
from the start record itself, and every generation's witness must show the same start, hash and
state root as the deployment proof at `L1_0`.

## Before you start

- Keep usable canonical EL state at c, the block of the retained landing, and the old EL
  ancestry. Keep own-L1 headers back to `L1_0` and the historical `eth_getProof` and
  `debug_getRawHeader` the checks need (SYNC-9-16). `prepare` checks that the state at c is
  readable; it never builds a block. The recovered app's InitChain checks it again and waits,
  with trust closed, while it is missing. Keep `--engine.allow-unwind-canonical-header`
  disabled. The old EL head may stay above c until the recovered app commits its first block
  through normal Engine calls. An EL that holds another block at c, or none, first takes the
  settled one ([Take the settled EL state at c](#take-the-settled-el-state-at-c)).
- Never copy, restore or reset signing state (RECOV-8.2-1..3); only a failover moves the latest
  state, with the old host stopped (signer README, Failover). The signer keeps one HRS state per
  full `chain_id` and never lowers it. A backup can omit signatures already released, so an older
  HRS, FilePV state or domains-log backup must never resume the same validator identity; nothing
  detects such a rollback, because the domains log records chain IDs, never heights. If
  the latest state is lost or uncertain, stop signing and resolve the identity through governance.
  Restoring app, EL or Comet data never authorizes rolling back signer state.
- Keep the registered key, the HRS state directory and the domains log outside every Comet home
  and app store, with the log on another volume than the states. `install` never reads them.

## 1. Stop the old services

Stop the old app, the supervisor (signer and Comet), the lander and every restart controller
that could start them again (systemd, Kubernetes, containers). Fencing and failover are
operational practice (RECOV-8.2-6): nothing in `abci-recover` can stop a process it did not
start. Leave the old app directory, Comet home and lander journal untouched as archives. They are
never reused: a superseded generation's app directory keeps its safety latches, and its records
must not count for the new generation.

## 2. Prepare the plan

Run `prepare` with the node's own endpoints, spelled as for `abci`, and the same chain config
the app uses. The plan file must not exist yet.

```sh
taiko-client abci-recover prepare --l1.http http://127.0.0.1:8545 --l2.http http://127.0.0.1:8546 --l2.auth http://127.0.0.1:8551 --jwt.secret /var/lib/taiko/private/jwt.hex --chain-config /etc/taiko/chain.toml --generation 1 --out /var/lib/taiko/recovery/plan-g1.json --json
```

`prepare` checks the L1 and L2 chain IDs, authenticates generation N, c, R and the reselected
committee on own finalized L1 (RECOV-8.2-4), checks the EL state at c, rechecks own finality and
the current generation, and only then writes the plan with mode 0600. A newer generation on own
L1 fails with `superseded`. The plan holds the deployment parameters, the canonical witness, the
origin and the exact genesis bytes; it holds no endpoint, path or credential.

An EL that holds another block at c than the retained landing, or none, fails `prepare` as a
missing prerequisite that names c and the landing's EL hash at c, and no plan is written. That
is no invalid evidence: take the settled EL state at c first
([Take the settled EL state at c](#take-the-settled-el-state-at-c)).

`prepare` prints the same summary as `status`. Compare `genesis_hash` with the other operators
(ACC §2.2): every honest node of the generation has the same genesis. A later checkpoint never
changes the genesis or the origin, only `observed_checkpoint_height`.

## 3. Install the new stores

```sh
taiko-client abci-recover install --plan /var/lib/taiko/recovery/plan-g1.json --comet-config /var/lib/taiko/comet/config/config.toml --node-key /var/lib/taiko/comet/config/node_key.json --home /var/lib/taiko/comet-g1 --app-dir /var/lib/taiko/app-g1
```

`--comet-config` is the node's stock Comet v0.40 config, used as a template; `--node-key` is
its existing Ed25519 P2P key. P2P identity is separate from the registered consensus key, and a
FilePV or secp256k1 key is refused (RECOV-8.2-2). `install` keeps the template's listeners and
peers and points every path at the new home. A validator template (non-empty
`priv_validator_laddr`) gets the Unix placeholder `unix://run/signer.sock`; the supervisor gives
each start its own socket in `run/`. Unix RPC/ABCI listeners, active state sync, custom TLS files
and a custom `home` are refused, as is a validator template that changes `adaptive_sync`,
`double_sign_check_height` or `block_time_tolerance` from its stock default (START-10-6; see the
[README](../README.md)).

The new home and app directory must be absent or empty, except for files an interrupted
`install` of the same plan wrote: rerun the same command and it completes, and a repeated
install changes nothing. A home holding another genesis is refused. Directories are created with
mode 0700 and files with 0600; `genesis.json` is written last and marks a complete install. Unix
socket paths must fit 103 bytes: `<home>/run/signer-<16 hex>.sock` for a validator and
`<app dir>/checkpoint-trust.sock`, so choose short paths.

The packaged image runs Comet as `ETNA_COMET_UID=10001`. Hand it the new home, for example
`chown -R 10001:10001 /var/lib/taiko/comet-g1`. Then confirm the install:

```sh
taiko-client abci-recover status --plan /var/lib/taiko/recovery/plan-g1.json --home /var/lib/taiko/comet-g1 --json
```

This illustrative report uses c=6, R=100 and a later authenticated checkpoint at 12.

```json
{
  "generation": 1,
  "chain_id": "etna-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
  "origin_height": 6,
  "recovery_l1_block": 100,
  "genesis_time": "2026-11-08T00:00:00Z",
  "genesis_hash": "0x1111111111111111111111111111111111111111111111111111111111111111",
  "validators": 2,
  "observed_checkpoint_height": 12,
  "installed": true
}
```

`status` reads only the plan and the home's `genesis.json`; it never queries a running service.

## 4. Signer state for the new chain_id

A new generation is a new full `chain_id`, so it gets its own stock HRS state, which starts
empty and signs from c+1 (RECOV-8.2-1/8.2-5). With the old signer stopped, create it with the
same registered key, state directory and domains log as before. Read the chain ID from the
plan's `chain_id`:

```text
etna-signer init-state \
  --chain-id <chain_id from the plan> \
  --priv-key /var/lib/taiko/private/key/registered-key.json \
  --priv-state /var/lib/taiko/private/hrs/<chain_id from the plan>.json \
  --domains-log /var/lib/taiko/domains/domains.log

ETNA_COMET_HOME=/var/lib/taiko/comet-g1
ETNA_APP_STORE=/var/lib/taiko/app-g1
ETNA_PRIV_KEY=/var/lib/taiko/private/key/registered-key.json
ETNA_PRIV_STATE_DIR=/var/lib/taiko/private/hrs
ETNA_DOMAINS_LOG=/var/lib/taiko/domains/domains.log
ETNA_CHAIN_ID=<chain_id from the plan>
```

`init-state` refuses a chain ID already in the domains log and an existing state file, so it can
never reset a state. It appends the new chain ID to the log only after the new state is durable;
every older chain's state stays in the directory unchanged and is never served again. The
supervisor environment then names the new chain ID; the key, state directory and log stay the
same. Keep the domains log on another volume than the state directory.

If `init-state` was interrupted, rerunning it may refuse an unlogged state file for the new
chain ID. Check that the file equals the stock zero state, remove it and rerun; any other file
needs investigation. The signer answers PubKey and Ping while trust is closed and signs only
once the new app is trusted. See the [signer operations](../tools/etna-signer/README.md#refusal-matrix-and-exit-codes)
for the refusal rules.

## 5. Start the new services

Start in this order (START-10-6):

1. the EL, then the app on the new directory,
   `taiko-client abci --data-dir /var/lib/taiko/app-g1`, with the same endpoint,
   `--chain-config`, `--abci.addr` and `--fee-recipient` flags as before;
2. the supervisor with the environment of step 4; it starts the signer, then Comet on the new
   home;
3. the lander with its unchanged journal (`--data-dir`) and `--comet.http` at the new home's
   `rpc.laddr`.

The app runs InitChain at c+1, and its checkpoint trust is the ordinary section 9 check.

The lander preserves each old job's proof, blobs, account nonce and signed network bytes.
Never-broadcast obsolete work can finish; possibly broadcast work must reconcile canonical
receipt/account nonce first. When the RPC no longer knows the pending transaction and both
account nonce views still equal its nonce, the runner automatically rebroadcasts the **exact
original signed network bytes**, including after a receipt reorg or generation recovery.
An old-generation call can revert under the new generation and consume that nonce; canonical
receipt/account reconciliation then allows new work. The runner never signs a replacement,
raises its fee caps or allocates another nonce to bypass unresolved work.
A known or underpriced transaction can still leave that job **Waiting** while consensus
continues. If the confirmed account nonce advances without this transaction's receipt, the
runner allows a bounded receipt-index grace period, then stops for reconciliation. Investigate
with the account owner and canonical L1; do not edit the journal, reset the nonce or bypass the
account path.

## Take the settled EL state at c

Honest nodes can hold another block than the one L1 settled at a height at or below c, or no
block there, without any verifier failure (RECOV-8.1-7, RECOV-8.1-8). When more than 1/3 of the
voting power double-signs, L1 can settle the block honest nodes did not commit, and they hold
their own blocks from that height on. A block that only stock CometBFT rejects, such as one whose
header commits another validator state (SYNC-9-5c), stops honest nodes below it. Before
recovery, the settled chain is verified independently from the last settled block honest nodes
executed themselves, by executing the settled blocks up to c from the landings' blobs. Nodes
take the EL state at c from that execution, in place of any blocks of their own that differ.

`prepare` on such a node fails and writes nothing:

```text
recovery prerequisite missing: the EL does not serve the settled block 0x… at c = 6; take the settled EL state at c as docs/governance-recovery.md describes, then run prepare again
```

The hash is c's EL hash in the retained landing, read from your own finalized L1. The recovered
app's InitChain treats the same EL as missing data (SYNC-9-7): it waits until the EL serves the
settled block at c, its authenticated parent and its state. The node keeps trust closed, so its
signer signs nothing, until its EL holds c's authenticated block. An EL that rejects that hash,
or accepts it and keeps serving another block at c, contradicts the settled chain: a safety
halt.

Take the settled state at c in one of these ways:

- **From a peer.** Give your EL a peer whose EL holds the settled chain through c, for example
  the EL of a node that executed it, as a trusted peer. An EL syncs only toward a head it is
  pointed at, and `prepare` makes no forkchoice call. The recovered app's InitChain points the EL
  at c's authenticated hash, as at the Etna start; the EL then switches to the settled blocks or
  downloads them. So install a plan that `prepare` wrote on a node whose EL holds the settled
  block at c, and compare its `genesis_hash` with the other operators: InitChain repeats every
  check of that plan against your own L1 and EL. While the EL lacks the block, InitChain stays
  pending and points the EL at it again after each `--elsync.timeout` (600 s by default); from
  the first, `/trust` names the sync (`execution engine did not reach block <c> …`). Once
  InitChain has answered, run `prepare` on your node to a new `--out` and compare its
  `genesis_hash` again. If the EL does not reach the block, use one of the ways below.
- **Replace the EL datadir.** Stop your EL and replace its datadir with a copy of a stopped EL
  datadir from a node whose EL executed the settled chain through c, then run `prepare`. Copy
  only from a node you trust as you trust your own EL: `prepare` and InitChain check that the
  header at c hashes to the landing and that its state is readable, but they do not recompute
  that state's root.
- **Install it with its state root checked.** `etna-el-import install` builds a fresh datadir
  from a stopped EL whose state is exactly at c, and recomputes the state root. It takes c's EL
  hash (`--trusted-el-hash`, the hash `prepare` names), the stateRoot of the header with that
  hash (`--trusted-state-root`), the original block-zero hash (`--trusted-genesis-hash`, from
  `etna-el-import chain-identity`), the L2 chain id, the EL runtime genesis JSON and a
  `--manifest` of authenticated headers through c with the EL finality fence. No `abci-recover`
  command writes that manifest. `abci-import import` at height c does: it authenticates, on your
  own L1, a package that a node of the new generation exported at the generation's origin with
  its recovery bootstrap, and runs `etna-el-import` with those roots
  ([checkpoint import](checkpoint-import.md)). It also installs the origin's Comet genesis and
  recovery bootstrap, so the node starts from `ROOT/ready` instead of from
  `abci-recover install`.

## Full nodes

A full node follows the same steps without step 4. Its template has an empty
`priv_validator_laddr`, and it starts stock Comet through `script/start_etna_full_node.py`
(`ETNA_COMET_HOME=<new home>`) instead of the supervisor. Like the supervisor, the launcher checks
the executable's digest against the deployment manifest and deletes the pending-evidence store
before every start (CONS-3.1-1, CONS-3.1-10). It has no registered signing authority; stock Comet creates an unregistered
local FilePV in the new home, which never signs.

## Failures

Once an anchor shows a newer generation, the old generation can only stop: its app rejects and
revokes trust, and a decided block or startup check that finds another generation is a terminal
safety halt with generic fatal evidence in the old app directory (RECOV-8-14..16). Safety halts
need investigation; preserve the fatal evidence, supervisor latches and signer-unsafe records,
every HRS, the domains log with any `<chain_id>.signer-unsafe` marker beside it, and the WAL.
Run the new generation from fresh stores as above, never by clearing the old ones.

Read trust from the app's `/status` ABCI query, not from `abci-recover status` or Comet's sync
progress (SYNC-9-15).
