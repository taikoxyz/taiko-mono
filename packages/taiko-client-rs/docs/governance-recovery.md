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
- InitChain returns `app_hash = ELHash(c)`, and the EL state must match c's authenticated hash
  and state root;
- the validators are the committee selected on R's registry snapshot for epoch `floor(c/L)`.

The first block uses stock genesis's empty LastBlockID/LastCommit (RECOV-8.4-10). The FI cursor
starts at the authenticated origin head (RECOV-8.4-11). Every anchor and L1 root the new
generation uses is at or after R (RECOV-8.4-12/13). The global epoch schedule and checkpoint
grid continue unchanged, and old pending committee updates are discarded. Votes in different
generations use different signing domains and are not double signs; the new generation keeps
its own HRS state from c+1 (RECOV-8.2-5/6). The app's InitChain repeats every check `prepare`
makes, against its own L1 and EL.

## Before you start

- Keep usable canonical EL state at c and the old EL ancestry. Keep own-L1 headers back to
  `L1_0` and the historical `eth_getProof` and `debug_getRawHeader` the checks need (SYNC-9-16).
  `prepare` checks that the state at c is readable; it never builds a block. The recovered
  app's InitChain checks it again and waits, with trust closed, while it is missing. Keep
  `--engine.allow-unwind-canonical-header` disabled. The old EL head may stay above c until the
  recovered app commits its first block through normal Engine calls.
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
and a custom `home` are refused.

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
receipt/account nonce first. A reorged receipt with an unchanged account nonce can leave the
old pending job **Waiting**, while consensus continues. The runner does not automatically
rebroadcast/replace obsolete work or allocate a new nonce to bypass it. Investigate with the
account owner and canonical L1. If appropriate, explicit rebroadcast must use the **exact
original signed network bytes**; an old-generation call can revert under the new generation
and consume that nonce. Normal receipt/account reconciliation can then allow new work.
No fee replacement, journal editing, nonce reset or new account-path bypass is implied.

## Full nodes

A full node follows the same steps without step 4. Its template has an empty
`priv_validator_laddr`, and it starts stock Comet (`cometbft start --home <new home>`) instead
of the supervisor. It has no registered signing authority; stock Comet creates an unregistered
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
