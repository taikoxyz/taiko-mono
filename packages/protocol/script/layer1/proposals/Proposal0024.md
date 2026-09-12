# PROPOSAL-0024: Raise the Inbox Basefee Sharing Percentage to 100%

## Executive Summary

Proposal0024 upgrades the mainnet Shasta inbox proxy `0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f`
to a `MainnetInbox` implementation whose `basefeeSharingPctg` is 100 instead of 75, so the whole L2
basefee of every block in a proposal made after execution is paid to that block's coinbase and
nothing is retained by the L2 treasury `0x1670000000000000000000000000000000010001`. Every other
configuration value and all five address immutables are the live ones; no storage is touched and no
initializer runs.

The percentage is a constructor immutable of the inbox implementation (`MainnetInbox.sol`), so
changing it means deploying a new implementation and upgrading the proxy: one `upgradeTo`, executed
by the DAO controller, which owns the proxy. The proposal executes **1 L1 action** and has no L2
leg.

> **Status: draft.** The new implementation is not deployed yet. `Proposal0024.MAINNET_INBOX_NEW_IMPL`
> is a placeholder, `P=0024 pnpm proposal` deliberately reverts `ImplementationNotDeployed()`, and
> no `Proposal0024.action.md` exists. [Deployment](#deployment) lists what fills them in.

## Rationale

> **TODO(@dantaik):** write up why the basefee share moves from 75% to 100%: what the 25% treasury
> share was for, why it is no longer needed or is better paid to the coinbase, the expected effect
> on proposer and preconfer economics and on the L2 treasury's income, and any governance context
> (forum post, prior discussion). This section is what TAIKO holders read during the 10-day veto
> window.
>
> Context for the write-up: 75 has been the mainnet value since the Ontake era. `MainnetTaikoL1`
> carried `sharingPctg: 75` in protocol 1.11 (Pacaya), and the Shasta inbox parameters chosen in
> [#21190](https://github.com/taikoxyz/taiko-mono/pull/21190) kept it; no commit in the repository
> has ever set another value on mainnet.

## Scope

| Chain | Contract                                                 | Change                                                                              |
| ----- | -------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| L1    | Inbox proxy `0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f` | implementation → `MAINNET_INBOX_NEW_IMPL` (TBD, deployed by `DeployInboxUpgradeL1`) |

Not touched: the proof verifier, proposer checker, prover whitelist, signal service and bond token
(reproduced as immutables of the new implementation); every numeric parameter but the percentage;
the proxy's storage; ownership (no `transferOwnership`, `acceptOwnership` or initializer call); the
dormant Pacaya inbox `0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a`; every L2 contract; Hoodi and
every other network.

## Current State

Verified on-chain 2026-09-12 at L1 block 25,961,507.

| proxy                                        | owner                                                                                | live impl                                                   | provenance                                                                                            | `_initialized`                       |
| -------------------------------------------- | ------------------------------------------------------------------------------------ | ----------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- | ------------------------------------ |
| `0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f` | DAO controller `0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a` (`controller.taiko.eth`) | `0x5253D4C91e80b880DdB54B78E74082Abe066F6b9` (23,067 bytes) | Proposal0019 (Unzen), upgraded 2026-08-03, built at commit `9078278909a43a83fc5bb2664f30b81eb5c967f6` | 3 (`init3` consumed by Proposal0019) |

Core state at that block: `nextProposalId` 34,874, `lastProposalBlockId` 25,961,499,
`lastFinalizedProposalId` 34,871; `activationTimestamp` 1,775,135,903; forced inclusion queue
`head = tail = 3` (empty). The live `getConfig()` is the "live" column of the table under
[The new implementation](#the-new-implementation).

## What Changes

### How the percentage reaches L2 blocks

- `Inbox.propose` copies the `_basefeeSharingPctg` immutable into every `Proposal` and into the
  `Proposed` event (`Inbox.sol`, `_emitProposedEvent`). It is part of the proposal hash, so a
  proposal keeps the percentage it was proposed with forever.
- The drivers write it as byte 0 of each L2 block's `extraData`, `[basefeeSharingPctg |
proposalId(6)]` (taiko-client `driver/chain_syncer/event/blocks_inserter/common.go`,
  taiko-client-rs `derivation/pipeline/shasta/pipeline/payload.rs`), so every block of the
  proposal carries the same byte.
- The execution clients apply it per transaction. taiko-geth (`core/state_transition.go`) pays
  `gasUsed × baseFee × pctg / 100` to `block.coinbase` and the remainder to the treasury;
  alethia-reth (`crates/block/src/executor.rs`) passes the same byte into its anchor system call.
  With `pctg = 100` the coinbase receives the whole basefee and the treasury remainder is exactly
  0; the split is integer division, so there is no rounding residue.
- Provers take the value from the `Proposed` event they verify (raiko2's Shasta guest input carries
  `proposal.basefeeSharingPctg`), so the proof pipeline needs no change.

### Timing

The upgrade takes effect with the first `propose` after execution. Proposals already made keep 75
and so do the L2 blocks derived from them. A block is stamped with the percentage of the proposal
that carries it, not with the value that was live when it was preconfirmed — see
[Client rollout](#client-rollout) for what that means at the switch.

### The new implementation

`MainnetInbox` from `main`, built with the live address immutables. `DeployInboxUpgradeL1` reads
the live proxy's `getConfig()` before broadcasting and aborts unless its five addresses are the
`LibL1Addrs` constants it compiles in and its percentage is still 75; after deploying it compares
the new implementation's `getConfig()` with the live one and aborts unless the percentage is the
only difference. `test_mainnetInbox_MatchesTheLiveConfigExceptForBasefeeSharing` pins every field
below as a literal.

| `getConfig()` field                 | live                                         | new                                      |
| ----------------------------------- | -------------------------------------------- | ---------------------------------------- |
| `proofVerifier`                     | `0x7284aaC05555Ae6559bdAd8B4221eC9584254Eec` | same (`LibL1Addrs.ZK_REQUIRED_VERIFIER`) |
| `proposerChecker`                   | `0xFD019460881e6EeC632258222393d5821029b2ac` | same (`LibL1Addrs.PRECONF_WHITELIST`)    |
| `proverWhitelist`                   | `0xEa798547d97e345395dA071a0D7ED8144CD612Ae` | same (`LibL1Addrs.PROVER_WHITELIST`)     |
| `signalService`                     | `0x9e0a24964e5397B566c1ed39258e21aB5E35C77C` | same (`LibL1Addrs.SIGNAL_SERVICE`)       |
| `bondToken`                         | `0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800` | same (`LibL1Addrs.TAIKO_TOKEN`)          |
| `minBond`                           | 0                                            | same                                     |
| `livenessBond`                      | 0                                            | same                                     |
| `withdrawalDelay`                   | 604,800 (1 week)                             | same                                     |
| `provingWindow`                     | 14,400 (4 hours)                             | same                                     |
| `permissionlessProvingDelay`        | 432,000 (5 days)                             | same                                     |
| `maxProofSubmissionDelay`           | 180                                          | same                                     |
| `ringBufferSize`                    | 21,600                                       | same                                     |
| **`basefeeSharingPctg`**            | **75**                                       | **100**                                  |
| `forcedInclusionDelay`              | 576                                          | same                                     |
| `forcedInclusionFeeInGwei`          | 1,000,000                                    | same                                     |
| `forcedInclusionFeeDoubleThreshold` | 50                                           | same                                     |
| `permissionlessInclusionMultiplier` | 160                                          | same                                     |

Diffing the implementation's dependency tree (`MainnetInbox.sol` and its 23 imports under
`contracts/`) from `9078278909a43a83fc5bb2664f30b81eb5c967f6` to `main` changes two files:

- `contracts/layer1/mainnet/MainnetInbox.sol`: the `basefeeSharingPctg` literal (this proposal),
  and the `_storeReentryLock` / `_loadReentryLock` overrides through `LibFasterReentryLock` are
  gone because [#22058](https://github.com/taikoxyz/taiko-mono/pull/22058) moved them into the
  base contract.
- `contracts/shared/common/EssentialContract.sol` (#22058): the reentry lock lives in transient
  storage at `_REENTRY_SLOT` `0xa5054f728453d3dbe953bdc43e4d0cb97e662ea32d7958190f3dc2da31d9721b`,
  byte-identical to the slot `LibFasterReentryLock` used in the live implementation; the storage
  variable `__reentry` became `private` and keeps its slot.

So the only behavioural change the new implementation ships is the percentage. Nothing under
`contracts/layer1/core/` changed.

## Upgrade Safety

- **Immutables only.** The percentage is an `immutable`, read by `propose` and `getConfig`. The
  storage layout is untouched: `contracts/layer1/mainnet/MainnetInbox_Layout.sol` is identical at
  `9078278909a43a83fc5bb2664f30b81eb5c967f6` and on `main` (18 entries, `activationTimestamp` at
  slot 251 through the trailing `__gap[43]` at slot 258).
- **No initializer.** The action is `upgradeTo`, not `upgradeToAndCall`. `_initialized` is 3
  (`init` at deployment, `init2` by Proposal0017, `init3` by Proposal0019) and `Inbox` has no
  `init4`; the fork rehearsal asserts slot 0 is unchanged across the upgrade.
- **Same ABI, same event.** The dependency-tree diff changes no function, event or error, so the
  `Proposed` event keeps its shape and every consumer (drivers, provers, eventindexer, relayer)
  decodes it as before.
- **Same reentrancy guard.** `propose`, `prove` and the bond functions stay `nonReentrant` on the
  transient slot the live implementation already uses.
- **100 is in range.** `LibInboxSetup.validateConfig` requires `basefeeSharingPctg <= 100`, and
  both execution clients compute `fee × pctg / 100`, so 100 is the maximum, not an edge case.
- **A wrong constant fails, it does not brick.** `upgradeTo` checks the new implementation's
  `proxiableUUID`, so pointing the proxy at an address without a UUPS implementation reverts; the
  dry run and the fork rehearsal execute the exact calldata the DAO will.

## Client rollout

- **Drivers** (taiko-client, taiko-client-rs) derive the byte from the `Proposed` event of each
  proposal and need no restart.
- **The whitelisted preconfer needs a restart right after execution.** Catalyst reads
  `getConfig().basefeeSharingPctg` once at startup (`shasta/src/l1/protocol_config.rs`, built in
  `shasta/src/l2/taiko.rs`) and stamps the cached value into every block it preconfirms. A node
  still on the cached 75 after execution keeps producing blocks the drivers will re-derive with 100
  once proposed: same transactions, different `extraData`, different state root, so each such
  block is replaced at proposal time (one preconfirmation reorg per block). Until the preconfer
  restarts, preconfirmations are not final. The taiko-client-rs proposer in engine mode reads the
  config per block (`proposer.rs`, `build_payload_attributes`) and needs no restart; the Go preconf
  block API uses the event value.
- **One unavoidable reorg at the switch.** Blocks preconfirmed under 75 but carried by the first
  proposal after execution are re-derived with 100 (same transactions). Executing the proposal
  right after a proposal lands, with the preconfer restart queued, bounds this to a few blocks.
- **Provers** (raiko2) take the value from the event and need no change. The bridge UI, the
  relayer and the eventindexer are not affected.
- **Treasury income.** The L2 treasury `0x1670000000000000000000000000000000010001` stops receiving
  basefee; dashboards tracking it will show the step.

## Action Order

### L1 — 1 action

| #   | Target                                                   | Call                                |
| --- | -------------------------------------------------------- | ----------------------------------- |
| 0   | Inbox proxy `0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f` | `upgradeTo(MAINNET_INBOX_NEW_IMPL)` |

No L2 leg: `buildL2Actions` is the `BuildProposal` default (empty), so `_buildAllActions` appends
no `sendMessage` and the batch is the one action above.

## Deployment

Not run yet. `DeployInboxUpgradeL1` logs `MAINNET_INBOX_NEW_IMPL`:

```bash
cd packages/protocol
PRIVATE_KEY=<deployer> ETHERSCAN_API_KEY=<key> FOUNDRY_PROFILE=layer1 forge script \
  script/layer1/mainnet/DeployInboxUpgradeL1.s.sol:DeployInboxUpgradeL1 \
  --rpc-url <L1_RPC> --broadcast --verify
```

The script deploys only: no proxy upgrade, no initializer call on a live contract. It must not be
re-run after the address is written in, and it refuses to run once the live proxy already answers 100. `MainnetInbox` links `LibInboxSetup` (its `validateConfig` is `public`), so the broadcast is
**two** creates, the library then the implementation. Forge reports "ONCHAIN EXECUTION COMPLETE &
SUCCESSFUL" even when the RPC dropped a transaction (it happened during the Proposal0022 deployment),
so check the receipts, not the summary:

```bash
export L1_RPC=<l1 rpc>
cast codesize <MAINNET_INBOX_NEW_IMPL> --rpc-url $L1_RPC   # non-zero, ~23,000 bytes
cast codesize <LibInboxSetup, first create of the broadcast> --rpc-url $L1_RPC   # non-zero
```

Then, in one change:

1. Put the verified address into `Proposal0024.MAINNET_INBOX_NEW_IMPL` and into
   `DEPLOYED_INBOX_IMPL` in `test/layer1/proposals/Proposal0024.t.sol`.
2. `P=0024 pnpm proposal` and commit `Proposal0024.action.md`;
   `test_actionFileMatchesTheBuiltCalldata` pins it from then on.
3. `P=0024 pnpm proposal:dryrun:l1` — the pass signal is a revert with `DryrunSucceeded()`
   (`Controller.dryrun` is permissionless and always reverts, so the `--broadcast` in the script
   can never send anything).
4. Run the fork rehearsal (below); with the constant filled it executes the committed calldata and
   deploys nothing.
5. Fill in [Deployed Addresses](#deployed-addresses), and record the deployment and, after
   execution, the upgrade in `deployments/mainnet-contract-logs-L1.md`.
6. Mark the PR ready for review.

## Deployed Addresses

| Contract                      | Address | Notes                                          |
| ----------------------------- | ------- | ---------------------------------------------- |
| `MainnetInbox` implementation | TBD     | `MAINNET_INBOX_NEW_IMPL`; codediff link TBD    |
| `LibInboxSetup` (linked)      | TBD     | first create of the `DeployInboxUpgradeL1` run |

## Verification

Every commented value is the expected result.

```bash
export L1_RPC=<l1 rpc>
export INBOX=0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f
export NEW_IMPL=<MAINNET_INBOX_NEW_IMPL>
CONFIG='getConfig()((address,address,address,address,address,uint64,uint64,uint48,uint48,uint48,uint48,uint48,uint8,uint16,uint64,uint64,uint8))'

# The new implementation: the live configuration with the thirteenth field (basefeeSharingPctg) 100.
cast call $NEW_IMPL "$CONFIG" --rpc-url $L1_RPC
cast call $INBOX    "$CONFIG" --rpc-url $L1_RPC   # identical apart from 75 in the thirteenth field
# It is a UUPS implementation (the value upgradeTo checks): the EIP-1967 implementation slot.
cast call $NEW_IMPL "proxiableUUID()(bytes32)" --rpc-url $L1_RPC   # 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc

# The proxy the DAO upgrades: owned by the controller, initializer version 3, Unzen implementation.
cast call    $INBOX "owner()(address)" --rpc-url $L1_RPC   # 0x75Ba76403b13b26AD1beC70D6eE937314eeaCD0a
cast storage $INBOX 0 --rpc-url $L1_RPC                    # 0x…03
cast storage $INBOX 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url $L1_RPC   # 0x…5253d4c91e80b880ddb54b78e74082abe066f6b9

# Authenticate the code, not just the getters. Pass signal: "Creation code matched with status full".
# The creation code embeds the linked LibInboxSetup address, so give it to the linker through the
# `libraries` config (the first create of the broadcast); one Etherscan V2 key is required.
export ETHERSCAN_API_KEY=<key>
FOUNDRY_LIBRARIES="contracts/layer1/core/libs/LibInboxSetup.sol:LibInboxSetup:<LibInboxSetup>" \
FOUNDRY_PROFILE=layer1 forge verify-bytecode $NEW_IMPL \
  contracts/layer1/mainnet/MainnetInbox.sol:MainnetInbox --rpc-url $L1_RPC \
  --encoded-constructor-args $(cast abi-encode "c(address,address,address,address,address)" \
    0x7284aaC05555Ae6559bdAd8B4221eC9584254Eec 0xFD019460881e6EeC632258222393d5821029b2ac \
    0xEa798547d97e345395dA071a0D7ED8144CD612Ae 0x9e0a24964e5397B566c1ed39258e21aB5E35C77C \
    0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800)

# The calldata: regenerate and diff, then the dry run, then the rehearsal against live state. The
# rehearsal executes the batch from the DAO controller on a fork and asserts the proxy answers 100
# with every other configuration field, the core state, the last and last-finalized proposal
# hashes, the forced-inclusion queue, the owner, the activation timestamp and the initializer
# version unchanged; the second test is the dry run itself.
cd packages/protocol
P=0024 pnpm proposal && git diff --exit-code script/layer1/proposals/Proposal0024.action.md
P=0024 pnpm proposal:dryrun:l1                       # reverts DryrunSucceeded()
L1_FORK_URL=$L1_RPC FOUNDRY_PROFILE=layer1 forge test --match-contract Proposal0024ForkTest -vv
```

After execution:

```bash
cast storage $INBOX 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url $L1_RPC   # 0x…<NEW_IMPL>
cast call $INBOX "$CONFIG" --rpc-url $L1_RPC          # thirteenth field 100
cast storage $INBOX 0 --rpc-url $L1_RPC               # still 0x…03
# The next Proposed event carries basefeeSharingPctg = 100, and the L2 blocks derived from it have
# extraData starting with 0x64; blocks of earlier proposals keep 0x4b.
```

Then restart the whitelisted preconfer nodes (see [Client rollout](#client-rollout)).

## Security Contacts

- security@taiko.xyz
