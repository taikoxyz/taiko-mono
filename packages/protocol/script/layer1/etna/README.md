# Switching an Unzen chain to Etna

These scripts prepare the switch of a live Unzen chain to Etna as described in
[SWITCH.md](../../../docs/etna/SWITCH.md) and SPEC START-10-5 to START-10-5d. They never upgrade a
proxy and never send a DAO action:

| Script                                                                                     | Does                                                                                                                       |
| ------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------- |
| `DeployEtnaSwitch.s.sol`                                                                   | Deploys the Etna bootstrap proxy, registry, the three switch implementations and the `EtnaSwitchGuard`.                    |
| `DeployEtnaVerifiers.s.sol`                                                                | Deploys the EtnaInbox's own SGX, RISC0 and SP1 sub-verifiers and their `ZkRequiredVerifier`.                               |
| `BuildEtnaSwitchProposals.s.sol`                                                           | Checks every input against L1 and logs the L1 DAO actions of each proposal and their `abi.encode`. It broadcasts nothing.  |
| [`BuildEtnaReadinessL2Message.s.sol`](../../layer2/etna/BuildEtnaReadinessL2Message.s.sol) | Checks every input against L2 and logs the readiness proposal's one L2 message (`LibEtnaReadinessL2Message.buildActions`). |

The switch takes two DAO proposals: **readiness** prepares L2 while Unzen stays open, and
**scheduling** installs the schedule on L1. A **postponement** batch moves an installed schedule
before the start is written. `MainnetDAOController.execute` runs each action list in order and
reverts on the first failed call, so each list is atomic. The controller checks only call success,
so every check in a list is a call to `EtnaSwitchGuard` that reverts with a named error.

The L2 `SignalService` implementation is deployed with
[`DeployShastaL2Contracts`](../../layer2/DeployShastaL2Contracts.s.sol); the `Anchor` is not
upgraded. EIP-2935 and EIP-4788 must already run on L2. Clients and guests build in the L2
`SignalService` implementation address. A node trusts the start only after checking, under
SYNC-9-5a, the L2 `SignalService` proxy's EIP-1967 implementation slot at S and that its own fork
time equals the EtnaInbox's `etnaForkTime()`.

## Inputs and deployment order

Use the same L1 RPC and `L1_CHAIN_ID` for every step. `PRIVATE_KEY` selects the deployer;
`CONTRACT_OWNER` is required and names the DAO controller, which must own the live Unzen Inbox and
L1 SignalService, the new proxies and every image-trusting verifier the actions touch, with no
pending ownership transfer. `UNZEN_INBOX` is the live Unzen proxy and `SIGNAL_SERVICE` its L1
SignalService proxy (`VERSION` 1). The scripts read the live `getConfig()` and accept its
`signalService` in two states: `SIGNAL_SERVICE` before the scheduling proposal executes and
`INBOX_PROXY` after it, as when a postponement is prepared. `INBOX_PROXY` must differ from both.

1. `DeployEtnaSwitch.deployInboxProxy()`: the Etna bootstrap proxy. Export `INBOX_PROXY`.
2. `deployRegistry()` with the registry variables of
   [the new-network deployment](../../../contracts/layer1/etna/README.md#deployment). Export
   `STAKING_REGISTRY`. Committee-0 validators register and become active, and a finalized
   `GENESIS_CUTOFF` is chosen, before the scheduling proposal is drafted.
3. `DeployEtnaVerifiers.run()`. Export `ETNA_PROOF_VERIFIER`. Its sub-verifiers are separate from
   Unzen's: an SP1 proof binds the sub-verifier's address, so sharing one would let Etna image trust
   widen what the Unzen Inbox accepts.
4. Set `ETNA_FORK_TIME`, `PROPOSE_MARGIN` and `FI_MARGIN` (seconds) and call
   `deployUnzenInboxImplementation()`. Export `UNZEN_INBOX_IMPLEMENTATION`. Its configuration is the
   live one with `signalService` set to `INBOX_PROXY`, so `prove` saves its checkpoints through the
   EtnaInbox. The script requires its `proposeCutoff()` to equal `ETNA_FORK_TIME - PROPOSE_MARGIN`
   and its `FI_CUTOFF()` to equal `ETNA_FORK_TIME - FI_MARGIN`.
5. Set `REMOTE_SIGNAL_SERVICE` to the L2 SignalService proxy (the chain's canonical predeploy) and
   call `deploySignalServiceImplementation()`: the shared SignalService with `INBOX_PROXY` as its only
   syncer, `usesBeaconRoots` false, `VERSION` 1 and the live proxy's pauser. Export
   `SIGNAL_SERVICE_IMPLEMENTATION`.
6. Set the remaining Inbox, committee and forced-inclusion variables documented in
   `DeployEtnaDevnet` and call `deployInbox()`. Export `ETNA_INBOX_IMPLEMENTATION`. The script checks
   that the cutoff implementation matches the live configuration and the schedule, that the registry
   names `INBOX_PROXY` and the L2 chain, and that the Etna verifier is this build's
   `ZkRequiredVerifier` over sub-verifiers that Unzen does not use.
7. `deploySwitchGuard()`. Export `SWITCH_GUARD`.

Once the EtnaInbox is initialized, steps 4 and 6 deploy a postponement's implementations and
require an `ETNA_FORK_TIME` later than the installed one. No step runs after the start write.

## Trust changes

The proposal builders read optional comma-separated `bytes32` lists named
`<UNZEN|ETNA>_<SGX_GETH|SGX_RETH|RISC0|SP1>_<TRUST|UNTRUST>`. Each id becomes one action on the
sub-verifier that the Unzen or EtnaInbox composite verifier names for that slot: `setMrEnclave` for
the SGX slots, `setImageIdTrusted` for RISC0 and `setProgramTrusted` for SP1, each with `true` for
`TRUST` and `false` for `UNTRUST`. Per slot the trusted ids come first. A list for a slot the
composite lacks, a zero id, or an id that is both trusted and untrusted is refused. SGX instance
registration, MRSIGNER trust and SecureSgxVerifier attribute policies are not covered; configure
them separately, early enough that SGX instances are valid before the first proof that needs them.

## Proposal 1: readiness

`BuildEtnaSwitchProposals.readinessActions()` returns only the proposal's L1 actions: the `UNZEN_*`
trust changes that enable Unzen proof combinations reading both checkpoint layouts. It refuses once
the scheduling proposal has executed. The proposal's one L2 message to the `DelegateController` is
not in that list: `BuildEtnaReadinessL2Message`, run against L2 with the `layer2` profile, logs its
actions, and the proposal returns them from `BuildProposal.buildL2Actions`, which appends the L1
`Bridge.sendMessage` action that carries them. The actions are `[checkBeforeUpgrade(proxy,
preEtnaImpl), SignalService.upgradeTo(etnaImpl), checkAfterUpgrade(proxy, etnaImpl, codehash)]` on
the L2 `EtnaSignalServiceUpgradeGuard`. The builder reads `UPGRADE_GUARD`, `L2_SIGNAL_SERVICE`,
`PRE_ETNA_SIGNAL_SERVICE_IMPL`, `ETNA_SIGNAL_SERVICE_IMPL`, `ANCHOR_PROXY` and `L1_SIGNAL_SERVICE`.
It requires the guard to hold exactly this build's code, the proxy to use
`PRE_ETNA_SIGNAL_SERVICE_IMPL`, the `Anchor`'s checkpoint store to be the proxy, and
`ETNA_SIGNAL_SERVICE_IMPL` to hold exactly this build's `SignalService` constructed with
`ANCHOR_PROXY` as syncer, `L1_SIGNAL_SERVICE` as remote, the live proxy's pauser and
`usesBeaconRoots` true; the postcondition pins that code hash. The message carries no deadline and
no fork time, and no later proposal repeats it.

Before authorizing proposal 2, verify the L2 `SignalService` proxy's implementation slot under the
stateRoot of a proven Unzen checkpoint authenticated on finalized L1, and record the L1 block, the
checkpoint and the slot proof with the proposal. A queued message, a receipt or an unfinalized
checkpoint does not release this gate.

## Proposal 2: scheduling

`BuildEtnaSwitchProposals.schedulingActions()` additionally reads `SWITCH_GUARD`,
`PROPOSAL_LEAD`, `UNZEN_INBOX_IMPLEMENTATION`, `SIGNAL_SERVICE_IMPLEMENTATION`,
`ETNA_INBOX_IMPLEMENTATION`, the `init` variables of `DeployEtnaDevnet` and the trust lists. It
requires the Unzen Inbox to still save into `SIGNAL_SERVICE`, the EtnaInbox to be on its bootstrap,
`PROPOSAL_LEAD > FI_MARGIN` and the lead to be still available, the guard to have this build's code,
and each Inbox implementation to report exactly the expected configuration. The L1 SignalService
implementation's syncer and remote have no getters, so the builder rebuilds this build's
`SignalService` runtime code with `INBOX_PROXY` as syncer, the L2 SignalService of `L2_CHAIN_ID` as
remote, the live proxy's pauser and `usesBeaconRoots` false, sets its UUPS `__self` immutable from
the artifact's `immutableReferences`, and requires it to equal the deployed code byte for byte
(`script/shared/LibRebuiltCode.sol`); action 3 pins that code hash on chain. The actions are:

| #    | Target           | Call                                                                                    |
| ---- | ---------------- | --------------------------------------------------------------------------------------- |
| 0    | guard            | `checkDeadline(ETNA_FORK_TIME, PROPOSAL_LEAD, FI_MARGIN)`                               |
| 1    | Unzen Inbox      | `upgradeTo(UNZEN_INBOX_IMPLEMENTATION)`                                                 |
| 2    | L1 SignalService | `upgradeTo(SIGNAL_SERVICE_IMPLEMENTATION)`                                              |
| 3    | guard            | `checkL1SignalService(SIGNAL_SERVICE, SIGNAL_SERVICE_IMPLEMENTATION, codehash)`         |
| 4    | EtnaInbox        | `upgradeToAndCall(ETNA_INBOX_IMPLEMENTATION, init(...))`, as `ownerUpgradeCall` returns |
| 5…   | sub-verifiers    | the `UNZEN_*` pins for this schedule, then the `ETNA_*` image trust                     |
| last | guard            | `checkSchedule(UNZEN_INBOX, INBOX_PROXY, (ETNA_FORK_TIME, PROPOSE_MARGIN, FI_MARGIN))`  |

Executed later than `ETNA_FORK_TIME - PROPOSAL_LEAD`, the first action reverts and nothing is
installed; executing exactly at the lead is on time. It also reverts unless
`PROPOSAL_LEAD > FI_MARGIN`, so the batch can never execute at or after
`ETNA_FORK_TIME - FI_MARGIN`, the forced-inclusion cutoff its Unzen Inbox upgrade installs (vector
5d.f). Actions 1, 2 and 4 run in one transaction, so
no Unzen `prove` lands between them. `init` does not write the start.

## Postponement

`BuildEtnaSwitchProposals.postponementActions()` reads the new `ETNA_FORK_TIME`, `PROPOSE_MARGIN`
and `FI_MARGIN`, the new `PROPOSAL_LEAD`, `POSTPONEMENT_DEADLINE` (B), `SWITCH_GUARD`, the new
`UNZEN_INBOX_IMPLEMENTATION` and `ETNA_INBOX_IMPLEMENTATION` and the trust lists. It reads the
installed schedule from L1 and requires the scheduling proposal to have executed, the start to be
unwritten, a later fork time whose lead is still available, `now < B` and B no later than the
earlier installed cutoff, and implementations that keep every live configuration field except the
schedule. Choose `B = min(C, oldForkTime - rolloutBudget)` as SWITCH.md section 7 describes. The
actions are:

| #    | Target        | Call                                                                                        |
| ---- | ------------- | ------------------------------------------------------------------------------------------- |
| 0    | guard         | `checkPostponement(UNZEN_INBOX, INBOX_PROXY, oldSchedule, newSchedule, newProposalLead, B)` |
| 1    | Unzen Inbox   | `upgradeTo(UNZEN_INBOX_IMPLEMENTATION)`                                                     |
| 2    | EtnaInbox     | `upgradeTo(ETNA_INBOX_IMPLEMENTATION)`                                                      |
| 3…   | sub-verifiers | the `UNZEN_*` then `ETNA_*` trust changes the new schedule needs                            |
| last | guard         | `checkSchedule(UNZEN_INBOX, INBOX_PROXY, newSchedule)`                                      |

There is no L2 action: no L2 contract holds the fork time. The batch reverts, leaving the old
schedule in force, after the start write, when the live schedule is not the one it names, at or
after B, or without the new lead. Keep the Unzen verifier able to prove every Unzen block through
the new tip, including blocks at and after the old fork time.

## EtnaSwitchGuard

A stateless contract (`contracts/layer1/etna/switch/EtnaSwitchGuard.sol`); every time and schedule
it checks is a parameter fixed in the batch. `Schedule` is `(uint48 etnaForkTime, uint48
proposeMargin, uint48 fiMargin)`.

- `checkDeadline(uint48 etnaForkTime, uint48 proposalLead, uint48 fiMargin)`:
  `ProposalLeadNotAboveFiMargin` unless `proposalLead > fiMargin`; `ProposalLeadMissed` if
  `block.timestamp + proposalLead > etnaForkTime`.
- `checkL1SignalService(address signalService, address expectedImpl, bytes32 expectedCodeHash)`:
  `UnexpectedImplementation` unless the proxy's `impl()` is `expectedImpl`; `UnexpectedCodeHash`
  unless `expectedImpl.codehash` is `expectedCodeHash`; `BeaconRootsUsed` if `usesBeaconRoots()`.
- `checkSchedule(address unzenInbox, address etnaInbox, Schedule schedule)`: `UnzenInboxMismatch`,
  `EtnaForkTimeMismatch`, `UnzenForkTimeMismatch`, `ProposeCutoffMismatch` or
  `ForcedInclusionCutoffMismatch` unless the EtnaInbox names the Unzen Inbox and both hold the
  schedule's fork time with the Unzen `proposeCutoff()` and `FI_CUTOFF()` its margins before it;
  `CheckpointPathMismatch` unless the Unzen Inbox's `getConfig().signalService` is the EtnaInbox.
- `checkPostponement(unzenInbox, etnaInbox, old, new, newProposalLead, deadline)`, the last two
  `uint48`: `StartAlreadyWritten` once `etnaStart()` has a hash, the `checkSchedule` errors for
  `old`, `PostponementDeadlinePassed` unless `block.timestamp < deadline`, `DeadlineAfterCutoff` if
  the deadline is after the earlier of `old`'s cutoffs, then `ForkTimeNotLater`,
  `ProposalLeadNotAboveFiMargin` and `ProposalLeadMissed` for the new schedule.

## Cutoffs and retained state

`InboxWithEtnaCutoffs` keeps Unzen's storage and configuration except that `signalService` names the
EtnaInbox. `propose` reverts from `proposeCutoff() = ETNA_FORK_TIME - PROPOSE_MARGIN` on and
`saveForcedInclusion` from `FI_CUTOFF = ETNA_FORK_TIME - FI_MARGIN` on; `prove` and the bond
functions are unchanged. Its constructor requires `PROPOSE_MARGIN >= 12`,
`FI_MARGIN > PROPOSE_MARGIN + forcedInclusionDelay` and `FI_MARGIN < ETNA_FORK_TIME`. Choose the
buffer and, for L1 slots shorter than 12 s, the margin as SWITCH.md section 3 describes.

The L1 SignalService upgrade adds no storage and keeps `VERSION` 1, so the checkpoints the Unzen
Inbox saved stay readable. It accepts checkpoints only from the EtnaInbox. The EtnaInbox's
`saveCheckpoint` forwards the Unzen Inbox's checkpoints at any height until the start is written
and at none afterwards.

## The start

The scripts do not record the start. Once L1 reaches the fork time and Unzen's final proof has
saved its checkpoint, anyone calls `EtnaInbox.setOrigin(S)`. It requires the Unzen
`proposeCutoff()` to be nonzero and reached, every accepted Unzen proposal to be finalized and the
Unzen `lastFinalizedBlockHash` to match the SignalService checkpoint at S, and copies that hash and
stateRoot into the start (START-10-5a, LAND-6.1-8a). Nodes start only from a finalized start-write
block and check S's header, timestamp and L2 `SignalService` implementation themselves
(SYNC-9-5a).

## Dedicated verifier inputs

`DeployEtnaVerifiers.run()` reads `PRIVATE_KEY`, the required nonzero `CONTRACT_OWNER`,
`L1_CHAIN_ID`, `L2_CHAIN_ID`, `DCAP_ATTESTATION`, `SGX_REGISTRAR` (zero allows permissionless SGX
registration), `SGX_INSTANCE_VALIDITY_DELAY` (positive and at most the 90-day instance lifetime),
`R0_GROTH16_VERIFIER` and `SP1_PLONK_VERIFIER`, and checks dependency code and chain identities. It
creates a SecureSgxVerifier for SGX_RETH, RISC0 and SP1 instances and a `ZkRequiredVerifier` with
SGX_GETH disabled, all with empty trust. Register SGX instances at least `instanceValidityDelay`
ahead of the first landing that needs them, and not so early that they expire before it.

## Tests

```bash
FOUNDRY_PROFILE=layer1 forge test --match-path 'test/layer1/etna/Etna{SwitchGuard,UnzenCutoffs}.t.sol'
FOUNDRY_PROFILE=layer1 forge test --match-path test/layer1/etna/DeployEtnaDevnet.t.sol
FOUNDRY_PROFILE=layer2 forge test --match-path test/layer2/etna/EtnaSignalServiceUpgradeGuard.t.sol
```

The second runs `DeployEtnaSwitchScenarios`, which deploys with these scripts and executes the
readiness, scheduling and postponement lists through a `MainnetDAOController` that owns the
proxies, including late, stale and post-start batches and SignalService implementations or guards
of another identity. The third relays the L2 message through the real Bridge and checks the L2
builder's identity checks.
