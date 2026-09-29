# PROPOSAL-0026: Raise Basefee Sharing to 100% and Rotate raiko2 to v0.9.0-rc1

## Executive Summary

Proposal0026 upgrades the mainnet Shasta inbox proxy `0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f`
to a `MainnetInbox` implementation whose `basefeeSharingPctg` is 100 instead of 75, so the whole L2
basefee of every block in a proposal made after execution is paid to that block's coinbase and
nothing is retained by the L2 fee treasury, the Anchor contract
`0x1670000000000000000000000000000000010001`. Every other
configuration value and all five address immutables are the live ones; no storage is touched and no
initializer runs.

The same atomic L1 batch rotates the active proving identifiers from raiko2 v0.8.0-rc1 to
[`v0.9.0-rc1`](https://github.com/taikoxyz/raiko2/releases/tag/v0.9.0-rc1): two RISC0 image IDs,
four SP1 program vkeys, and three SGX MRENCLAVE allowlist entries. It then deletes the active
v0.8.0-rc1 instance ID `2` from both SGX verifier registries. The already-disabled v0.6 values are
not touched. The SGX MRSIGNER and enclave attribute policies are unchanged, and this proposal does
not register replacement SGX instances.

The percentage is a constructor immutable of the inbox implementation (`MainnetInbox.sol`), so
changing it means deploying a new implementation and upgrading the proxy. That `upgradeTo` remains
action 0. The proposal executes **21 L1 actions** in total and has no L2 leg.

## Rationale

### What the percentage splits

`basefeeSharingPctg` divides every L2 block's basefee between two recipients.

The first is the block's **coinbase**, which the block's builder does not get to choose: at
derivation both drivers overwrite it with the `proposer` of the `Proposed` event (taiko-client
`driver/chain_syncer/event/derivation/source_fetcher.go`, taiko-client-rs
`derivation/pipeline/shasta/pipeline/payload.rs`, which rejects a block whose beneficiary disagrees
with the attributes it derived). Proposing is gated by the `PreconfWhitelist`
`0xFD019460881e6EeC632258222393d5821029b2ac`, so the coinbase is always the whitelisted preconfer
that proposed the block.

The second is the **Anchor contract** `0x1670000000000000000000000000000000010001`, which this
runbook calls the L2 treasury. It holds its share as a plain ETH balance — nothing forwards it
anywhere — until the DAO sweeps it with `Anchor.withdraw`, which is `onlyOwner` on the L2 delegate
controller `0xfA06E15B8b4c5BF3FC5d9cfD083d45c53Cbe8C7C` that the DAO drives from L1.

So the 25% that does not go to the coinbase today is a protocol fee on proposers, payable to the
DAO. This proposal removes it.

### Why remove it

That 25% is worth very little to the DAO and a great deal to a proposer, and the asymmetry is the
whole argument.

**To the DAO it is immaterial at current volume.** L2 transaction volume is low, the share that has
accrued in the Anchor has never been swept, and it is not a sum any TAIKO holder is pricing in.
Ending the accrual changes nothing a holder would notice. The balance already accrued is untouched
and stays sweepable.

**To a proposer it decides whether fee sponsorship is viable at all.** A proposer that pays for a
user's transaction funds it from its own balance — basefee plus priority fee — and recovers
`basefee × pctg / 100` plus the whole priority fee as the coinbase of the block it proposes. At 75
every sponsored transaction is a guaranteed loss of a quarter of its basefee: a per-transaction tax
that scales with precisely the activity the sponsor is trying to create, and one no sponsor is
likely to absorb in order to give transactions away. At 100 the round trip is exact. The proposer's
ETH returns to the proposer, and the marginal cost of sponsoring a transaction falls to the L1 data
it adds to a blob the proposer is posting anyway — a cost measured on Ethereum, not on Taiko.

**What that enables.** A preconfer for whom sponsorship is free on L2 can pay for its users'
transactions: a user needs no ETH on Taiko to transact, and a dapp that puts an account-abstraction
path in front of its users (EIP-7702, ERC-4337 or a plain relayer) can onboard them without a wallet
at all. This proposal does not build any of that and commits no operator to it; it removes the
protocol-level reason not to.

**Two limits worth stating plainly.** The round trip is exact only within a preconfer's own
proposals — a sponsor whose transaction lands in a block proposed by a *different* preconfer pays
the fee to that preconfer, so sponsorship pays for itself only for the preconfer proposing the block
it sits in. And the refund covers the L2 fee only; the proposer still carries its L1 proposing cost,
which is what keeps proposing a real business rather than a free one.

### Trade-offs

- **The DAO gives up a revenue line it may want back.** `basefeeSharingPctg` is a constructor
  immutable, so restoring any percentage is exactly this proposal in reverse: deploy an
  implementation with the new constant and `upgradeTo`. The DAO controls the proxy and can do it at
  any time, and would have to if L2 volume grew enough to make the 25% material.
- **A proposer's own L2 gas becomes free.** At 100 a proposer that fills its own blocks with its
  own transactions gets the entire basefee back, so its only remaining cost is the L1 data those
  transactions occupy — bounded further by the L2 block gas limit and by the `PreconfWhitelist`
  deciding who may propose at all. This is the one property the change genuinely weakens, and it
  is a change of degree rather than of kind: at 75 that same self-dealing already cost a proposer
  only a quarter of the basefee.
- **Treasury dashboards will show a step to zero.** See [Client rollout](#client-rollout).

## Scope

| Chain | Contract                                                 | Change                                                                                                                                                                                                               |
| ----- | -------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| L1    | Inbox proxy `0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f` | implementation → `0xA18431d42C8dF9778905fBEa912aCF1881b49D2e` ([codediff](https://codediff.taiko.xyz/?addr=0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f&newimpl=0xA18431d42C8dF9778905fBEa912aCF1881b49D2e&chainid=1)) |
| L1    | RISC0 verifier `0x059dAF31F571da48Ab4e74Ae12F64f907681Cd8b` | disable the two v0.8.0-rc1 image IDs and enable the two v0.9.0-rc1 image IDs |
| L1    | SP1 verifier `0x73A0Db393ef87ce781ac7957bE10D6628432100F` | disable the four v0.8.0-rc1 program vkeys and enable the four v0.9.0-rc1 program vkeys |
| L1    | SGX attesters `0x0ffa…9261`, `0x8d7C…a8A3` | disable the three v0.8.0-rc1 MRENCLAVEs and enable the three v0.9.0-rc1 MRENCLAVEs |
| L1    | SGX verifiers `0x41e7…84Ee`, `0x9D3C…FFd8` | delete active instance ID `2`; replacement registration is a separate post-execution operation |

The verifier implementations are not upgraded. The proposal changes only their trust mappings and
deletes the two named SGX registry entries; it does not change MRSIGNER trust, attribute policies,
verifier ownership, or verifier configuration. Also not touched: the inbox's proof verifier,
proposer checker, prover whitelist, signal service and bond token immutables; every numeric inbox
parameter but the percentage; the proxy's storage; ownership; the dormant Pacaya inbox
`0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a`; every L2 contract; Hoodi and every other network.

`DevnetInbox` moves to 100 in the same PR so local and devnet deployments match mainnet. It is not
in `MainnetInbox`'s dependency tree and no deployed contract reads it; its only consumer is
`DeployProtocolOnL1`, which the taiko-client integration tests run.

## What Changes

### raiko2 v0.9.0-rc1 release rotation

The ZK identifiers below come from `guest-digests-summary.json` in the raiko2 v0.9.0-rc1 release.
The old column is the v0.8.0-rc1 set enabled by Proposal0021; the new column is enabled by this
proposal.

| Role | v0.8.0-rc1 disabled | v0.9.0-rc1 enabled |
| ---- | -------------------- | ------------------ |
| RISC0 proposal image ID | `0xd6ab71c22201c23ef512b706f2e2d720f6da1b559fb76834aa9d4e35276f6e10` | `0x6016d9b774fdb7af1ac3194793039abb241ac869c856d15d2a0f5a5997e970ca` |
| RISC0 aggregation image ID | `0xdd9b8abff96c409ae2418edfb51d893ea2bd10f4873a0226f17a6998c1afc1b7` | `0xc7a55544d3a96ec3953a5bd2705c42056e27757fd6ac72ca9b972931870f8a2a` |
| SP1 proposal vkey BN254 | `0x0025425c22e827507428a3d9c7b0f89635be5462f34bb6780563e3d6086be7c7` | `0x00609a2e8a5834a3675060fa8965315f3e978514aa49fe69f8f407e5d16b941f` |
| SP1 proposal vkey hash bytes | `0x12a12e113a09d41d05147b387b0f89632df2a3174d2ed9e00ac7c7ac086be7c7` | `0x304d1745160d28d96a0c1f51165315f374bc28a52927f9a771e80fcb516b941f` |
| SP1 aggregation vkey BN254 | `0x0051ac1d9e8cfd4196e37f9cfefd08e9b0f7ce653bad4634cd1ee84b71ca3be6` | `0x001047d2068ac6e9b57839a587b07a254ad724d69b69c10197c0d4d2660c2fba` |
| SP1 aggregation vkey hash bytes | `0x28d60ecf233f50655c6ff39f6fd08e9b07be73296eb518d31a3dd09671ca3be6` | `0x0823e90322b1ba6d2f0734b07b07a25456b926b46da704062f81a9a4660c2fba` |

The TEE values come from `tee-attestation-manifest-v0.9.0-rc1.json`:

| Lane | v0.8.0-rc1 MRENCLAVE disabled | v0.9.0-rc1 MRENCLAVE enabled |
| ---- | ----------------------------- | ---------------------------- |
| SGX-geth | `0x5f7da556f3b75dcc71465030e1b7274e82df9e9120c0b3eaf5bb76246a514005` | `0x51701ed3fbd0bfdcea24a2e47ce9e30c5448ca9e4ad9b48bd1530d4a9c022fe4` |
| SGX-reth | `0x3564b6a30089fcb3e2f69c19b22d23f84ce148387cd7a15f5c1df165b2ae5847` | `0xdc994928718200e16e0eb643486ea90e49970a897fd164e39b6ae11262b69ab9` |
| SGX-reth EDMM | `0xae2c7b92b2a71238226cb624ecd1171b66bf943cc372314affca0e6748ccecdf` | `0x7aaf74aaa95cf967844819e5e4504f28308541c0504e6642a12a75a4669f66a3` |

The release source commit is `c4825c5d7e2b51abff5cb1ff09bca86e9df1609e`. Its published runtime
image is
`us-docker.pkg.dev/evmchain/images/raiko2@sha256:41df977ef21c6fe3253e001211985b0d2ac78d8cd0190be78da3e7e4169f6659`.
The TEE images are pinned in the release manifest:

- `raiko2-sgx@sha256:4798744ba980c3d6db0ea41712a5a81f9df25300be6d213b4df55d5a9c17d6f8`
- `raiko2-sgx` EDMM
  `@sha256:7e358a426918982ad85e90309c3e1277997f1b6bfa775e2b46b62909838d42f9`
- `gaiko2-sgxgeth@sha256:870d49869f1017eb201b34abfb7fc39ec05038aa563441f01bdc679bf9566dc3`

Both SGX verifiers have `nextInstanceId() == 3` at the pinned pre-execution state. IDs `0` and `1`
are empty and ID `2` is the active v0.8.0-rc1 registration. Actions 19 and 20 delete ID `2`.
After the proposal executes, each v0.9.0-rc1 provider must register separately; the next successful
registration is expected to receive instance ID `3`. That registration is deliberately not part of
this governance batch.

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

`MainnetInbox` from this branch, built with the live address immutables:
`0xA18431d42C8dF9778905fBEa912aCF1881b49D2e`, deployed by `DeployInboxUpgradeL1` on 2026-09-12 in L1 block
25,961,745 (tx `0x16532ab9b11251324578fd2f1d42b0dac2986523a19771365cefd9f9af42b533`, deployer
`0x56706f118e42ae069f20c5636141b844d1324ae1`, sources at commit
`9deb5b590b4bf303ff161f0b8b14a49ab518a312`), verified on Etherscan, and its creation code is
reproduced byte for byte from the pinned deployment commit (see [Verification](#verification)).
The current proposal and source comment use **Proposal0026**. The deployed source predates that
renumbering and names Proposal0024 in the comment; that comment changes Solidity's metadata hash,
so a full-byte comparison must build the deployment commit, not the current checkout. Its
`getConfig()` was read back on-chain at block 25,961,770 and equals the "new" column below. `DeployInboxUpgradeL1` reads
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
  `9078278909a43a83fc5bb2664f30b81eb5c967f6` and on `main` (17 entries, `activationTimestamp` at
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
- **Provers** take the basefee-sharing value from the event, so that part needs no code change. They
  must nevertheless run the v0.9.0-rc1 artifacts after the verifier rotation. RISC0 and SP1 can
  prove as soon as the batch executes; SGX providers additionally need the separate instance
  registration described above. The bridge UI, relayer and eventindexer are not affected.
- **Treasury income.** The Anchor contract `0x1670000000000000000000000000000000010001` stops
  receiving basefee; dashboards tracking it will show the step to zero. The ETH it has already
  accrued is untouched and stays withdrawable by the DAO through `Anchor.withdraw`.

## Action Order

### L1 — 21 actions

| # | Target | Call |
| - | ------ | ---- |
| 0 | Inbox proxy | `upgradeTo(MAINNET_INBOX_NEW_IMPL)` |
| 1 | RISC0 verifier | `setImageIdTrusted(V0_8_0_RC1_PROPOSAL_IMAGE_ID, false)` |
| 2 | RISC0 verifier | `setImageIdTrusted(V0_8_0_RC1_AGGREGATION_IMAGE_ID, false)` |
| 3 | RISC0 verifier | `setImageIdTrusted(V0_9_0_RC1_PROPOSAL_IMAGE_ID, true)` |
| 4 | RISC0 verifier | `setImageIdTrusted(V0_9_0_RC1_AGGREGATION_IMAGE_ID, true)` |
| 5–8 | SP1 verifier | disable the four v0.8.0-rc1 proposal/aggregation vkeys in the table above |
| 9–12 | SP1 verifier | enable the four v0.9.0-rc1 proposal/aggregation vkeys in the table above |
| 13 | SGX-geth attester | `setMrEnclave(V0_8_0_RC1_SGXGETH_MR_ENCLAVE, false)` |
| 14 | SGX-reth attester | `setMrEnclave(V0_8_0_RC1_SGXRETH_NON_EDMM_MR_ENCLAVE, false)` |
| 15 | SGX-reth attester | `setMrEnclave(V0_8_0_RC1_SGXRETH_EDMM_MR_ENCLAVE, false)` |
| 16 | SGX-geth attester | `setMrEnclave(V0_9_0_RC1_SGXGETH_MR_ENCLAVE, true)` |
| 17 | SGX-reth attester | `setMrEnclave(V0_9_0_RC1_SGXRETH_NON_EDMM_MR_ENCLAVE, true)` |
| 18 | SGX-reth attester | `setMrEnclave(V0_9_0_RC1_SGXRETH_EDMM_MR_ENCLAVE, true)` |
| 19 | SGX-geth verifier | `deleteInstances([2])` |
| 20 | SGX-reth verifier | `deleteInstances([2])` |

No L2 leg: `buildL2Actions` is the `BuildProposal` default (empty), so `_buildAllActions` appends
no `sendMessage`. The ordering keeps the existing Inbox upgrade as action 0 and performs the
release rotation after it in the same atomic controller execution.

## Deployment

Run on 2026-09-12 with `--verify`. `DeployInboxUpgradeL1` logs `MAINNET_INBOX_NEW_IMPL`:

```bash
cd packages/protocol
PRIVATE_KEY=<deployer> ETHERSCAN_API_KEY=<key> FOUNDRY_PROFILE=layer1 forge script \
  script/layer1/mainnet/DeployInboxUpgradeL1.s.sol:DeployInboxUpgradeL1 \
  --rpc-url <L1_RPC> --broadcast --verify
```

The script deploys only: no proxy upgrade, no initializer call on a live contract. It must not be
re-run, and it refuses to run once the live proxy already answers 100. `MainnetInbox` links
`LibForcedInclusion` and `LibInboxSetup` (both have `public` functions), so the broadcast was
**three** creates, all in block 25,961,745 with status 1: the two libraries through CREATE2, then the
implementation. Forge reports "ONCHAIN EXECUTION COMPLETE & SUCCESSFUL" even when the RPC dropped a
transaction (it happened during the Proposal0022 deployment), so the receipts were checked, not the
summary:

```bash
export L1_RPC=<l1 rpc>
cast codesize 0xA18431d42C8dF9778905fBEa912aCF1881b49D2e --rpc-url $L1_RPC   # 23058
cast codesize 0x526957d1a25E9D3F5ab5a4926d07eEE5d612ED42 --rpc-url $L1_RPC   # 2407, LibInboxSetup
cast codesize 0x511e1E5D9b9E23958076ccF1dD0033237a8cE4f8 --rpc-url $L1_RPC   # 1936, LibForcedInclusion
```

The address was then written into `Proposal0026.MAINNET_INBOX_NEW_IMPL` and `DEPLOYED_INBOX_IMPL`
in `test/layer1/proposals/Proposal0026.t.sol`; `Proposal0026.action.md` was generated with
`P=0026 pnpm proposal` after adding the release rotation, and is pinned from then on by
`test_actionFileMatchesTheBuiltCalldata`; the
dry run `P=0026 pnpm proposal:dryrun:l1` reverted with `DryrunSucceeded()` as designed
(`Controller.dryrun` is permissionless and always reverts, so the `--broadcast` in the script can
never send anything); and the fork rehearsal executed the committed calldata against the deployed
implementation. Still to do: record the deployment and, after execution, the upgrade in
`deployments/mainnet-contract-logs-L1.md`.

## Deployed Addresses

Deployed on 2026-09-12 by `0x56706f118e42ae069f20c5636141b844d1324ae1`, all in L1 block 25,961,745.

| Contract                      | Address                                      | Tx                                                                   |
| ----------------------------- | -------------------------------------------- | -------------------------------------------------------------------- |
| `MainnetInbox` implementation | `0xA18431d42C8dF9778905fBEa912aCF1881b49D2e` | `0x16532ab9b11251324578fd2f1d42b0dac2986523a19771365cefd9f9af42b533` |
| `LibInboxSetup` (linked)      | `0x526957d1a25E9D3F5ab5a4926d07eEE5d612ED42` | `0xbbf8ec0cee3151e09b6286e19d629d4e648de60d3b17824f939dc3ff6310ce40` |
| `LibForcedInclusion` (linked) | `0x511e1E5D9b9E23958076ccF1dD0033237a8cE4f8` | `0xf9a89d6ae2feff8a6f9f6339473fb51731eb621a6ade6052da8238b6302f3d1c` |

`MAINNET_INBOX_NEW_IMPL` is the implementation; [codediff](https://codediff.taiko.xyz/?addr=0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f&newimpl=0xA18431d42C8dF9778905fBEa912aCF1881b49D2e&chainid=1) against the live proxy.

## Verification

Every commented value is the expected result.

The fork rehearsal defaults to L1 block **26,075,649**, after the implementation deployment and
Proposal0021 execution but before Proposal0026. At that block all v0.8.0-rc1 identifiers are
trusted, all v0.9.0-rc1 identifiers are untrusted, `nextInstanceId()` is `3` on both SGX verifiers,
IDs `0` and `1` are empty, and ID `2` is active. The deployed `instances(uint256)` getter still has
the historical two-field `(address,uint64)` ABI. Use an archive-capable RPC. Set `L1_FORK_BLOCK` to
another block only if it has the same preconditions; `--fork-block-number` does not select the fork
created inside the test.

```bash
export L1_RPC=<l1 rpc>
export INBOX=0x6f21C543a4aF5189eBdb0723827577e1EF57ef1f
export NEW_IMPL=0xA18431d42C8dF9778905fBEa912aCF1881b49D2e
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

# Authenticate the code, not just the getters. `forge verify-bytecode` refuses library-linked
# contracts ("Unlinked bytecode is not supported"), and compiling with `--libraries` bakes the
# addresses into solc's metadata hash while the deployment linked after compiling. So reproduce what
# the deployment did: build its exact source commit and locked dependencies in a separate
# worktree, patch the link references, append the constructor arguments, and compare with the
# deployment transaction's input. Keep the current checkout and proposal named Proposal0026:
# its renamed source comment changes metadata, so its bytecode is not the historical bytecode.
# Expected output: CREATION CODE MATCH (24,947 bytes).
(
set -e
PROPOSAL0026_REPO_ROOT="$(git rev-parse --show-toplevel)"
PROPOSAL0026_VERIFY_DIR="$(mktemp -d)"
git -C "$PROPOSAL0026_REPO_ROOT" fetch origin 9deb5b590b4bf303ff161f0b8b14a49ab518a312
git -C "$PROPOSAL0026_REPO_ROOT" worktree add --detach "$PROPOSAL0026_VERIFY_DIR/deployment" \
  9deb5b590b4bf303ff161f0b8b14a49ab518a312
cd "$PROPOSAL0026_VERIFY_DIR/deployment"
pnpm install --frozen-lockfile
cd packages/protocol
FOUNDRY_PROFILE=layer1 forge build
TXIN=$(cast tx 0x16532ab9b11251324578fd2f1d42b0dac2986523a19771365cefd9f9af42b533 input --rpc-url "$L1_RPC")
python3 - "$TXIN" <<'PY'
import json, sys
art = json.load(open("out/layer1/MainnetInbox.sol/MainnetInbox.json"))
code, refs = art["bytecode"]["object"][2:], art["bytecode"]["linkReferences"]
libs = {"LibForcedInclusion": "511e1E5D9b9E23958076ccF1dD0033237a8cE4f8",
        "LibInboxSetup": "526957d1a25E9D3F5ab5a4926d07eEE5d612ED42"}
for names in refs.values():
    for name, sites in names.items():
        for site in sites:
            a, l = site["start"] * 2, site["length"] * 2
            code = code[:a] + libs[name] + code[a + l:]
args = "".join(a.rjust(64, "0") for a in (
    "7284aaC05555Ae6559bdAd8B4221eC9584254Eec", "FD019460881e6EeC632258222393d5821029b2ac",
    "Ea798547d97e345395dA071a0D7ED8144CD612Ae", "9e0a24964e5397B566c1ed39258e21aB5E35C77C",
    "10dea67478c5F8C5E2D90e5E9B26dBe60c54d800"))
if bytes.fromhex(code + args) != bytes.fromhex(sys.argv[1][2:]):
    sys.exit("MISMATCH")
print("CREATION CODE MATCH")
PY
cd "$PROPOSAL0026_REPO_ROOT"
git worktree remove "$PROPOSAL0026_VERIFY_DIR/deployment"
rmdir "$PROPOSAL0026_VERIFY_DIR"
)
# Etherscan holds the verified source (MainnetInbox, solc 0.8.30, osaka, optimizer 200 runs):
# https://etherscan.io/address/0xA18431d42C8dF9778905fBEa912aCF1881b49D2e#code

# The calldata: regenerate and diff, then the live dry run, then the historical fork rehearsal. The
# rehearsal executes the 21-action batch from the DAO controller at block 26,075,649. It asserts
# the inbox proxy answers 100 with its other state unchanged, rotates every RISC0/SP1/SGX trust
# value from v0.8.0-rc1 to v0.9.0-rc1, deletes SGX instance ID 2 on both verifiers, and leaves the
# batch with no L2 bridge message. The second test is the dry run itself.
cd packages/protocol
P=0026 pnpm proposal && git diff --exit-code script/layer1/proposals/Proposal0026.action.md
P=0026 pnpm proposal:dryrun:l1                       # reverts DryrunSucceeded()
L1_FORK_URL="$L1_RPC" FOUNDRY_PROFILE=layer1 forge test --match-contract Proposal0026ForkTest -vv
```

After execution:

```bash
cast storage $INBOX 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url $L1_RPC   # 0x…a18431d42c8df9778905fbea912acf1881b49d2e
cast call $INBOX "$CONFIG" --rpc-url $L1_RPC          # thirteenth field 100
cast storage $INBOX 0 --rpc-url $L1_RPC               # still 0x…03
# The next Proposed event carries basefeeSharingPctg = 100, and the L2 blocks derived from it have
# extraData starting with 0x64; blocks of earlier proposals keep 0x4b.
```

Then complete the release cutover:

1. Confirm the two old RISC0 IDs return `false` and the two v0.9.0-rc1 IDs return `true`.
2. Confirm the four old SP1 vkeys return `false` and the four v0.9.0-rc1 vkeys return `true`.
3. Confirm the three old MRENCLAVEs return `false` and the three v0.9.0-rc1 MRENCLAVEs return
   `true`. Confirm MRSIGNER trust and attribute policies are unchanged.
4. Confirm `instances(2)` returns a zero address on both SGX verifiers while `nextInstanceId()`
   remains `3`.
5. Register the v0.9.0-rc1 SGX-geth and SGX-reth providers separately. Each next successful
   registration is expected to receive ID `3`; record and read back the resulting transactions.
6. Restart the whitelisted preconfer nodes as described in [Client rollout](#client-rollout).

## Security Contacts

- security@taiko.xyz
