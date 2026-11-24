# Unzen to Etna handoff

The restored `driver` command synchronizes existing Unzen history. `etna-handoff` uses that
complete driver until the finalized L1 view closes Unzen proposals, then serves Etna ABCI on
the same EL. The standalone lander supports the same nonzero start. Real proving integration
and switch deployment remain separate work.

## Required deployment inputs

Use alethia-reth revision `493b6074b6d5749cea5e566b444bced8f14b258b` or a compatible release.
Its Unzen and Etna Engine methods are forkchoiceUpdatedV3/getPayloadV5/newPayloadV4. Run it with
exactly the client's Etna time ([below](#the-els-etna-time)). Existing L2 history and state stay
in place. The Etna L2 SignalService implementation and the EIP-4788/2935 code must already be
present, and so must the `EtnaStaking` proxy at the staking address the configuration hash
commits, holding the built-in implementation, deployed by an ordinary L2 transaction before the
fork. Until the first landing, every EL behind `--l2.http` must serve proofs of S's state
([below](#ss-state-until-the-first-landing)).

The current built-in Etna parameters are devnet-only. Supply the usual devnet `--chain-config`
with the correct Inbox, staking proxy and consensus parameters and an additional table:

```toml
[switch]
unzen_inbox = "0x0000000000000000000000000000000000000001"
fork_timestamp = 1800000000
signal_service_implementation = "0x0000000000000000000000000000000000000002"
staking_implementation = "0x0000000000000000000000000000000000000003"
```

Addresses and timestamp above are placeholders. `unzen_inbox` must equal `--shasta.inbox`;
`signal_service_implementation` is the Etna L2 SignalService implementation, not the proxy, and
`staking_implementation` the `EtnaStaking` implementation, not the proxy. The
configuration file does not authenticate S. While S is the latest landing checkpoint, the app
verifies the L2 SignalService proxy's implementation proof at S, then the `EtnaStaking` proxy's
implementation proof at S against `staking_implementation`, S's header timestamp below the fork
time and its state root against the Inbox's start record, and that S is the last Unzen block
(SYNC-9-5a). A proof the EL cannot serve yet keeps signing closed; another implementation halts
the app. Before every trust grant, whatever the latest checkpoint, it also reads the switching
EtnaInbox's immutable `etnaForkTime()` by `eth_call` at the hash of the own finalized L1 block
that proved the checkpoint. Signing stays closed if that value is unavailable, and a mismatch with
`fork_timestamp` halts the app. A nonzero S without a `[switch]` table also keeps signing closed,
at every checkpoint. Formal network parameters must be compiled into their chain configuration.

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

While the Inbox's latest checkpoint is S, the app proves the L2 SignalService and `EtnaStaking`
proxies' implementation slots at S before it trusts the chain (SYNC-9-5a), and the lander proves
both for the first proof (PROOF-6.2-46a). Both read them with `eth_getProof` pinned to S's hash
from their `--l2.http` endpoint (SYNC-9-16). reth answers historical proofs only within
`--rpc.eth-proof-window` blocks of its head, 0 by default, so once the L2 head passes S the read
fails: the app keeps signing closed and the lander waits, both retrying. Until the first landing
is final in own L1, give each such EL a proof window of at least `unsettled_limit` (U) blocks
plus a margin and keep S's state, or point `--l2.http` at an archive endpoint. Back-pressure
keeps the head within U blocks of the checkpoint its anchors show, but the head can pass S + U
once the first landing executes, before it is final. After the first landing no node needs S's
state. The lander's endpoint needs a proof window of at least `unsettled_limit` +
`maxBatchBlocks` blocks on every network anyway, for the `EtnaStaking` proofs of each batch (see
the README's lander section).

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
`setOrigin` transaction ([below](#writing-the-etna-start)). It writes initial_height=S+1 and the original R0-based genesis once;
an identical installed file is accepted, a different file is refused. Initialize Comet home
beforehand, but do not leave an unrelated generated genesis at `--genesis-out`.

Start the existing guarded signer/Comet configuration with that fixed genesis after it is ready.
The ABCI server is exposed only after the driver has drained. The command holds the Engine
lease throughout both stages. Unzen tail proving may continue independently using retained
history and blobs. No signing state is reset by this command.

## Writing the Etna start

S is the last Unzen block. On a switching network the EtnaInbox records it once, in the start
write `setOrigin(uint48 S)`. Only the designated multisig, the EtnaInbox's immutable
`originMultisig()`, may send it (START-10-5a, LAND-6.1-8a). The multisig supplies only S and is
trusted only for that height; the contract checks everything else and reverts otherwise:

- the sender is `originMultisig()` (`NotOriginMultisig`);
- the Inbox is initialized and the start is unwritten, and L1 time has reached its
  `etnaForkTime()`;
- the live Unzen Inbox's `proposeCutoff()` is set and reached, so no proposal can follow;
- its `getCoreState()` shows every accepted proposal finalized
  (`nextProposalId == lastFinalizedProposalId + 1`) and a nonzero `lastFinalizedBlockHash`
  (`UnzenTipHashZero`);
- the L1 SignalService holds a checkpoint at S, which an Unzen proof saved, with a nonzero state
  root.

The start takes its hash from the Unzen Inbox's `lastFinalizedBlockHash` and its state root
from the checkpoint at S. The L1 SignalService stores only state roots, so nothing on L1 ties
that hash to the height S. Once the final Unzen proof's L1 block is finalized, the multisig
therefore verifies that S is the number of the L2 block whose hash is `lastFinalizedBlockHash`,
Unzen's finalized tip, and that the checkpoint at S holds that block's state root:

```sh
CORE=$(cast call --rpc-url "$L1_RPC" --block finalized "$UNZEN_INBOX" 'getCoreState()')
cast block --rpc-url "$L2_RPC" "0x${CORE: -64}" --field number # must print S
cast block --rpc-url "$L2_RPC" "$S" --field stateRoot
cast call --rpc-url "$L1_RPC" --block finalized "$L1_SIGNAL_SERVICE" \
  'getStateRoot(uint64)(bytes32)' "$S" # must print the same root
```

The multisig then submits one transaction to `$ETNA_INBOX` with value 0 and the data below, for
a Safe as a transaction its owners sign and execute. On a development L1 whose node holds the
multisig account unlocked, `cast send --from` sends it directly:

```sh
cast calldata 'setOrigin(uint48)' "$S"
cast send --rpc-url "$L1_RPC" --unlocked --from "$ORIGIN_MULTISIG" \
  "$ETNA_INBOX" 'setOrigin(uint48)' "$S"
cast call --rpc-url "$L1_RPC" "$ETNA_INBOX" 'etnaStart()(uint48,bytes32)'
```

| Failure                                                                                    | Effect                                                                                                                                                                                                                                                                                                              |
| ------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Before the fork time, before the Unzen cutoff, or while an Unzen proposal is not finalized | Reverts. The multisig sends the same S again later.                                                                                                                                                                                                                                                                 |
| Any sender other than the multisig                                                         | Reverts (`NotOriginMultisig`).                                                                                                                                                                                                                                                                                      |
| No checkpoint at S, a zero finalized hash or a zero checkpoint root                        | Reverts and the Etna forced inclusion queue stays closed.                                                                                                                                                                                                                                                           |
| Another checkpointed height than Unzen's finalized tip                                     | The write succeeds and is final once its block is: every node halts on the mismatch (SYNC-9-5a), `etna-handoff` refuses the start as different from the derived Unzen end, the lander refuses S's header, and the guests reject the origin. The multisig cannot retry (`StartAlreadyWritten`); escalate to the DAO. |

A second successful write is impossible (`StartAlreadyWritten`), and from the start write on the
Unzen checkpoint forwarder reverts at every height (`ForwardingClosed`). Neither a landing nor
governance recovery changes the start (START-10-5c). Nodes do not trust the transaction or its
sender's height: each binds S to Unzen's finalized tip hash from its own finalized L1 view and
checks its own EL header of S, its number, hash and state root, before it signs (SYNC-9-5a).

## First landing

Run the lander with the same switching chain configuration and public L1/L2 endpoints. A
landing may end at any height above S. Generation 0's origin fallback keys, the CometBFT genesis
validators, sign S + 1 and S + 2; from then on every block H decides the set that signs H + 2
under the staking rules, as on a new network.

The lander reads no Unzen state: the start write already required closed, fully proven Unzen
proposals, so the first landing is built from S like any other once blocks above it are decided.
It checks its EL header of S against the recorded height, hash and state root, so a wrong height
stops it as it stops the nodes.

The first proof request retains and host-verifies EIP-1186 proofs of the L2 SignalService and
`EtnaStaking` proxies' EIP-1967 implementation slots under S's state root (PROOF-6.2-46a), the
latter at the staking address the configuration hash commits, read as
[above](#ss-state-until-the-first-landing). The included DummyProofProvider remains suitable
only for development deployments; a real backend must verify this witness as well as the
remaining private inputs.

Lander journal schema 22 includes these witnesses (`start_staking_witness` for the staking
proxy). Older journals are refused, never rewritten.
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

Generation 0 starts at S + 1, so a crash between CometBFT saving that first block and saving its
state stops the stock handshake (CONS-3.1-9). This command does not repair Comet stores or reset
signer HRS; `etna-comet-import repair-first-block` installs the certified block offline (see
[First-block repair](first-block-repair.md)).
