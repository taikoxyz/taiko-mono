# Unzen to Etna handoff

The restored `driver` command synchronizes existing Unzen history. `etna-handoff` uses that
complete driver until the finalized L1 view closes Unzen proposals, then serves Etna ABCI on
the same EL. The standalone lander supports the same nonzero start. Real proving integration
and switch deployment remain separate work.

## Required deployment inputs

Use alethia-reth revision `398702f29917534a4d696d022336787156e0ffa9` or a compatible release.
Its Unzen and Etna Engine methods are forkchoiceUpdatedV3/getPayloadV5/newPayloadV4. Configure
the same Etna timestamp on the EL and in the client deployment configuration. Existing L2
history and state stay in place. Etna-aware Anchor/SignalService and EIP-4788/2935 code must
already be present. Retain S's state until the first landing, or provide its verifiable historical
state proofs through the own EL.

The current built-in Etna parameters are devnet-only. Supply the usual devnet `--chain-config`
with the correct Inbox, registry and consensus parameters and an additional table:

```toml
[switch]
unzen_inbox = "0x0000000000000000000000000000000000000001"
fork_timestamp = 1800000000
anchor_implementation = "0x0000000000000000000000000000000000000002"
```

Addresses and timestamp above are placeholders. `unzen_inbox` must equal `--shasta.inbox`;
`anchor_implementation` is the expected implementation, not the proxy. The configuration file
does not authenticate S. While S is the latest landing checkpoint, the app verifies the
Anchor proxy's implementation proof at S, then calls `etnaTimestamp()` through the own EL
at that same canonical block hash. Signing stays closed if the timestamp is unavailable,
and a mismatch with `fork_timestamp` halts the app. Set the EL's fork schedule to the same
timestamp as part of the deployment. Formal network parameters must be compiled into their
chain configuration.

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

Run the lander with the same switching chain configuration and public L1/L2 endpoints. Its
landing endpoints are S+nK, where K is GRID_INTERVAL; global epoch boundaries remain unchanged.
The initial validators are committee 0 until an actual post-S switch takes effect.

While the Inbox checkpoint is S, the lander waits for every accepted Unzen proposal to finalize,
checks that Unzen's terminal hash equals ELHash(S), and checks the SignalService checkpoint at S
against that hash and the recorded state root. It reads these facts at one canonical L1 snapshot
after fork-cutoff and start-block finality. Pending nonce and receipt reconciliation continues
independently of this gate.

The first proof request retains and host-verifies an EIP-1186 proof of the Anchor proxy's
EIP-1967 implementation slot under S's state root. Keep S's state available until the first
landing. The included DummyProofProvider remains suitable only for development deployments;
a real backend must verify this witness as well as the remaining private inputs.

Lander journal schema 17 includes this witness. Older journals are refused, never rewritten.
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
