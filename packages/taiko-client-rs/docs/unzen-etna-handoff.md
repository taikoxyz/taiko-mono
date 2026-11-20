# Unzen to Etna handoff

The restored `driver` command synchronizes existing Unzen history. `etna-handoff` uses that
complete driver until the finalized L1 view closes Unzen proposals, then serves Etna ABCI on
the same EL. The standalone lander supports the same nonzero start. Real proving integration
and switch deployment remain separate work.

## Required deployment inputs

Use alethia-reth revision `53f33b708d869cfb3f8cccd597381fa2e92a5be5` or a compatible release.
Its Unzen and Etna Engine methods are forkchoiceUpdatedV3/getPayloadV5/newPayloadV4. Run it with
exactly the client's Etna time ([below](#the-els-etna-time)). Existing L2 history and state stay
in place. The Etna L2 SignalService implementation and the EIP-4788/2935 code must already be
present. Until the first landing, every EL behind `--l2.http` must serve proofs of S's state
([below](#ss-state-until-the-first-landing)).

The current built-in Etna parameters are devnet-only. Supply the usual devnet `--chain-config`
with the correct Inbox, registry and consensus parameters and an additional table:

```toml
[switch]
unzen_inbox = "0x0000000000000000000000000000000000000001"
fork_timestamp = 1800000000
signal_service_implementation = "0x0000000000000000000000000000000000000002"
```

Addresses and timestamp above are placeholders. `unzen_inbox` must equal `--shasta.inbox`;
`signal_service_implementation` is the Etna L2 SignalService implementation, not the proxy. The
configuration file does not authenticate S. While S is the latest landing checkpoint, the app
verifies the L2 SignalService proxy's implementation proof at S (SYNC-9-5a). Before every trust
grant, whatever the latest checkpoint, it also calls `beaconRootsFrom()` on that implementation
address, not through the proxy, in its own EL's state at the checkpoint block. Signing stays
closed if that value is unavailable, and a mismatch with `fork_timestamp` halts the app. A
nonzero S without a `[switch]` table also keeps signing closed, at every checkpoint. Formal
network parameters must be compiled into their chain configuration.

### The EL's Etna time

The fork time the client runs with is `fork_timestamp`, or the built-in value on a formal
network. alethia-reth takes its own Etna time from its built-in chainspec or, on a devnet, from
`--devnet-etna-timestamp` (`ALETHIA_RETH_DEVNET_ETNA_TIMESTAMP`), and no RPC reports it, so the
client cannot check it. Run the EL with exactly the client's value. The app's fork-time check
(SYNC-9-5a) sees only the client's value, so a different EL value is not caught there; the EL
fails instead. An earlier EL value applies Etna rules to any Unzen block at or after it, so the driver
cannot derive that block and the handoff never completes. A later one applies Unzen rules to the
Etna blocks from S+1 until its own time, so the EL rejects or misbuilds them: the node can
neither propose nor accept them, and a decided block its EL rejects stops the app as any
execution engine contradiction does.

### S's state until the first landing

While the Inbox's latest checkpoint is S, the app proves the L2 SignalService proxy's
implementation slot at S before it trusts the chain (SYNC-9-5a), and the lander proves it for
the first proof (PROOF-6.2-46a). Both read it with `eth_getProof` pinned to S's hash from their
`--l2.http` endpoint (SYNC-9-16). reth answers historical proofs only within
`--rpc.eth-proof-window` blocks of its head, 0 by default, so once the L2 head passes S the read
fails: the app keeps signing closed and the lander waits, both retrying. Until the first landing
is final in own L1, give each such EL a proof window of at least `unsettled_limit` (U) blocks
plus a margin and keep S's state, or point `--l2.http` at an archive endpoint. Back-pressure
keeps the head within U blocks of the checkpoint its anchors show, but the head can pass S + U
once the first landing executes, before it is final. After the first landing no node needs S's
state.

## Starting the staged runtime

Pass the existing common RPC/JWT/observability options, driver blob/sync options and ABCI
options to `taiko-client etna-handoff`. Required additions are `--shasta.inbox`,
`--genesis-out` (Comet's fixed genesis file), and the switching `--chain-config`.

```sh
taiko-client etna-handoff \
  --l1.http http://127.0.0.1:8545 \
  --l1.beacon http://127.0.0.1:5052 \
  --l2.http http://127.0.0.1:28545 \
  --l2.auth http://127.0.0.1:28551 \
  --jwt.secret /srv/node/jwt.hex \
  --engine-control-dir /srv/node/engine-control \
  --shasta.inbox 0x0000000000000000000000000000000000000001 \
  --chain-config /srv/node/etna.toml \
  --fee-recipient 0x0000000000000000000000000000000000000003 \
  --data-dir /srv/node/app \
  --genesis-out /srv/node/comet/config/genesis.json
```

Stop the old proposer/preconfirmation service before the proposal cutoff. No other old driver
may keep writing the Engine. Every `driver`, `etna-handoff` and standalone `abci` controlling
this EL must share `--engine-control-dir` (or ENGINE_CONTROL_DIR), including the same mounted
directory across containers. The directory contains the writer lease and the durable Unzen completion receipt. Different paths do not
coordinate, and external EL controllers must be stopped separately.

The command derives all accepted proposals, checks the final proposal's table-backed confirmed
boundary against own finalized L1 and the own canonical EL, and waits for the finalized
`setOrigin` transaction. It writes initial_height=S+1 and the original R0-based genesis once;
an identical installed file is accepted, a different file is refused. Initialize Comet home
beforehand, but do not leave an unrelated generated genesis at `--genesis-out`.

Start the existing guarded signer/Comet configuration with that fixed genesis after it is ready.
The ABCI server is exposed only after the driver has drained. The command holds the Engine
lease throughout both stages. Unzen tail proving may continue independently using retained
history and blobs. No signing state is reset by this command.

## First landing

Run the lander with the same switching chain configuration and public L1/L2 endpoints. A
landing may end at any height above S; global epoch boundaries remain unchanged.
The initial validators are committee 0 until an actual post-S switch takes effect.

While the Inbox checkpoint is S, the lander waits for every accepted Unzen proposal to finalize,
checks that Unzen's terminal hash equals ELHash(S), and checks the SignalService checkpoint at S
against that hash and the recorded state root. It reads these facts at one canonical L1 snapshot
after fork-cutoff and start-block finality. Pending nonce and receipt reconciliation continues
independently of this gate.

The first proof request retains and host-verifies an EIP-1186 proof of the L2 SignalService
proxy's EIP-1967 implementation slot under S's state root (PROOF-6.2-46a), read as
[above](#ss-state-until-the-first-landing). The included DummyProofProvider remains suitable
only for development deployments; a real backend must verify this witness as well as the
remaining private inputs.

Lander journal schema 19 includes this witness. Older journals are refused, never rewritten.
Resolve outstanding signed jobs with their compatible lander before upgrading. Nonzero-S
[checkpoint import/export](checkpoint-import.md) preserves the fixed Comet genesis and uses the
original EL block-zero chainspec independently of the Etna start hash at S.

## Restart behavior

A completion receipt is written and fsynced only after the whole closing proposal has been
derived and authenticated, before Etna can start. Its deployment, proposal and S identities
are rechecked against own finalized L1 and canonical EL state on restart, including when the
EL tip has entered Etna and the final Unzen proof is still pending. A batch mapping alone does
not establish completion: EL updates it during intermediate block builds. Without a valid
receipt, the driver replays the closing proposal, unless the finalized Unzen Inbox already
authenticates its terminal hash. Keep the receipt with the shared Engine control directory.
The command accepts the same fixed genesis and resumes the app store. Missing history or
metadata keeps the handoff pending; authenticated origin contradictions stop the process.
After a first landing, ordinary authenticated checkpoint startup can use the standalone app.

Stock CometBFT's documented nonzero initial-height first-block crash limitation remains;
this command does not repair Comet stores or reset signer HRS to bypass it.
