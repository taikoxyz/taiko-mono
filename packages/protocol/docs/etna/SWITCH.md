# Switching from Unzen to Etna

The Unzen Inbox stops accepting proposals. Its final proof establishes the tip of that closed chain. Anyone can then record that tip as S on L1. Etna nodes start at S + 1 once the start-write block R₀ is finalized. [SPEC.md section 10](SPEC.md#10-startup-and-deployment) governs the handoff. [ANCHORLESS.md](ANCHORLESS.md) covers the L2 execution and bridge upgrades.

## 1. Overview

| Name                          | Meaning                                                                                                                                                                                                                    |
| ----------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ETNA_FORK_TIME`              | The single switch time: the clients' Etna fork time and an EtnaInbox immutable, from which the Unzen Inbox's cutoffs derive. No L2 contract holds it. Every Unzen block is earlier and every Etna block is at or after it. |
| S                             | The Etna start: the last Unzen block. Etna's first block is S + 1, and CometBFT heights continue the L2 block numbers.                                                                                                     |
| R₀                            | The L1 block that executes `setOrigin`. It becomes `L1_0`, generation 0's L1 origin, so every Etna anchor is at or after it.                                                                                               |
| `PROPOSAL_LEAD`               | How long before `ETNA_FORK_TIME` the DAO proposal must execute ([section 3](#3-the-dao-proposal)).                                                                                                                         |
| `PROPOSE_MARGIN`, `FI_MARGIN` | How long before `ETNA_FORK_TIME` the Unzen Inbox stops accepting proposals and forced inclusions (SPEC START-10-5d, PARAM-11-12b).                                                                                         |

The proposal installs the cutoffs and queues the L2 upgrade. Operators verify it has executed on L2 with enough time left to retry it, or to postpone the schedule on L1, before the cutoffs. Unzen stops accepting forced inclusions first and proposals second. Provers finish the remaining proposals and save the tip checkpoint through the EtnaInbox. At or after `ETNA_FORK_TIME`, with the proposal set closed and fully proven, anyone submits `setOrigin(S)`. A reorg before R₀ finalizes can undo the proof and start write. Nodes wait for finalized R₀, check the L2 state and start the chain. The first Etna landing then follows ordinary settlement.

Measure the outage from the propose cutoff to the first Etna block, including the outstanding final proof, origin transaction, L1 finality and node startup. Etna forced inclusion opens with the start write. Back-pressure is measured from the start of production: the first Etna landing must be finalized and adopted by an anchor within U blocks ([SPEC.md 6.4](SPEC.md#64-back-pressure)).

## 2. Prerequisites

Everything below is in place before the DAO proposal of [section 3](#3-the-dao-proposal) executes:

- **Unzen Inbox.** The live Unzen Inbox is a proxy upgradeable by the DAO, its owner, which [section 3](#3-the-dao-proposal), action 1, relies on.
- **Registry and committee 0.** The EtnaInbox proxy (not yet initialized) and the registry are deployed (SPEC START-10-1). Committee-0 validators have registered and become active before the DAO proposal is drafted, because the proposal fixes genesisCutoff and the committee-0 record hash (START-10-2). A validator who registers later joins at an ordinary rotation after S once it is active and selected at that rotation's snapshot.
- **Software.**
  - Execution layer: alethia-reth with Etna rules from `ETNA_FORK_TIME`. Nodes that run taiko-geth move to alethia-reth, with full Unzen history, before the switch.
  - Consensus: the Etna ABCI application, the guarded signer and CometBFT. Clients and guests build in the address of the Etna L2 `SignalService` implementation for the L2 chain id (PARAM-11-12a).
  - Unzen proposers and preconfirmers stop before the propose cutoff and never propose after it.
- **L2 implementation.** The Etna L2 `SignalService` implementation is deployed on L2 at its final address before clients and guests are built, because both build in that address. It fixes its immutable `_authorizedSyncer` to the `Anchor` proxy and `usesBeaconRoots` to true, and it holds no fork time; the same contract code is used on L1 with the configuration in section 3. The `Anchor` is not upgraded.
- **L2 system contracts.** The canonical runtime code hashes and actual EIP-2935 and EIP-4788 system writes are verified on L2 ([ANCHORLESS.md section 7](ANCHORLESS.md#7-prerequisite-eip-4788-and-eip-2935-on-l2)). This comes before the L2 message of [section 3](#3-the-dao-proposal) executes, because the upgraded `SignalService` reads EIP-4788 whenever it saves a checkpoint.
- **Guests.** The Unzen guests read both checkpoint layouts ([ANCHORLESS.md section 8](ANCHORLESS.md#upgrade-order), step 2), and the Etna guests are built for the deployment. SGX instances for the EtnaInbox's SGX sub-verifier are registered at least that verifier's `instanceValidityDelay` ahead, and not so far ahead that they reach its instance expiry before the first landing, so an SGX + ZK first landing does not wait for them.

## 3. The DAO proposal

One DAO proposal carries every L1 and L2 action of the switch. It executes at least `PROPOSAL_LEAD` before `ETNA_FORK_TIME`. `PROPOSAL_LEAD` is longer than `FI_MARGIN`, and long enough to relay the L2 message, retry the relay if it fails, pass the go/no-go check of [section 4](#4-switch-day), and still leave the DAO's fastest path time to move the fork time if that check fails ([section 7](#7-failure-handling)). Once it has executed and its L2 message has executed on L2, nothing in the switch needs the DAO.

L1 actions, which take effect when the proposal executes:

0. **Guard.** Reverts if `block.timestamp > ETNA_FORK_TIME − PROPOSAL_LEAD`, so a late execution changes nothing; executing exactly `PROPOSAL_LEAD` before `ETNA_FORK_TIME` is on time.
1. **Unzen Inbox upgrade** (SPEC START-10-5d).
   - Expose `proposeCutoff() external view returns (uint48)` on the Unzen proxy. It returns `ETNA_FORK_TIME − PROPOSE_MARGIN`, the value at which `propose` starts reverting (`block.timestamp >= cutoff`).
   - `saveForcedInclusion` reverts when `block.timestamp >= ETNA_FORK_TIME − FI_MARGIN`.
   - `prove` and the bond functions are unchanged, so Unzen's remaining proposals can still be proven and bonds withdrawn.
   - `prove` saves its checkpoint through the EtnaInbox (action 4) instead of in the SignalService directly. The new implementation's `signalService` immutable, which `prove` uses only for `saveCheckpoint`, names the EtnaInbox proxy, so `getConfig().signalService` reports the EtnaInbox from then on. Tooling that prepares this upgrade from the live Unzen Inbox's `getConfig()` must accept two states and tell them apart: before this proposal executes, `signalService` is the L1 SignalService proxy; once it has executed, as when a replacement proposal is prepared ([section 7](#moving-the-fork-time)), it is the EtnaInbox proxy. In both, the new implementation names the EtnaInbox proxy and every other `getConfig()` field equals the live one.
2. **L1 SignalService upgrade** (START-10-5).
   - Deploy the shared SignalService implementation with immutable `_authorizedSyncer` set to the EtnaInbox and `usesBeaconRoots` false, the configuration of a new L1 network. It accepts checkpoints only from the EtnaInbox and reads no Inbox state.
   - `VERSION` stays 1: checkpoints are stored under `_checkpoints[VERSION]`, so a new version would hide every checkpoint the Unzen Inbox saved, including the one at S. That would break L2 → L1 claims for Unzen blocks and the start check.
3. **Unzen verifier.** It trusts the Unzen guest images that read both checkpoint layouts. This happens on L1 at execution, before the L2 part of the proposal reaches L2, which [ANCHORLESS.md section 8](ANCHORLESS.md#upgrade-order) requires.
4. **EtnaInbox.** The proxy is upgraded to an implementation whose immutables include `unzenInbox` (the Unzen Inbox address) and `ETNA_FORK_TIME` (SPEC PARAM-11-12a). It is then initialized with every parameter of START-10-5. Initialization does not write the start.
   - Its `saveCheckpoint` forwards calls only from the live Unzen Inbox while slot 273 is zero. The start write permanently closes this entry point at every height. Etna’s own landings continue writing checkpoints directly to SignalService.
   - Actions 1, 2 and 4 execute in the same proposal, so no Unzen `prove` lands between them.
5. **EtnaInbox verifier.** The EtnaInbox uses its own `ZkRequiredVerifier` instance with its own sub-verifier instances, SGX, RISC0 and SP1, which trust the Etna guest images (SPEC PROOF-6.2-3). Image trust lives in the sub-verifiers, and an SP1 proof's public input binds the sub-verifier's own address, not the Inbox's. Sharing a sub-verifier with the Unzen Inbox would therefore let trust in an Etna image widen what the Unzen Inbox accepts.

L2 action:

6. **One L2 message** to the `DelegateController` upgrades the L2 `SignalService` to the shared implementation configured with `_authorizedSyncer = address(Anchor)` and `usesBeaconRoots = true` ([ANCHORLESS.md section 8](ANCHORLESS.md#upgrade-order), step 3). It upgrades no other proxy, so the Etna `SignalService` implementation shows that the message executed. The batch begins with a precondition and ends with a postcondition, both encoded as calls to a deployed, code-hash-pinned read-only helper. The precondition reverts unless three things hold: the `SignalService` proxy's current implementation, read through `SignalServiceProxy.impl()` (the inherited UUPS getter reads the proxy's EIP-1967 slot through delegatecall), is the pre-Etna implementation; the EIP-4788 contract has its canonical runtime code; and that contract returns a zero root for the current block's timestamp. The last two show that the execution engines make the EIP-4788 call and that the batch runs in a block before Etna; without them the upgraded `SignalService` would reject the `Anchor`'s checkpoints. The postcondition reverts unless `proxy.impl()` is the expected address. The controller checks only call success: a getter or helper that returns false without reverting cannot guard this batch. Use the same reverting-helper pattern for the L1 deadline and schedule cross-checks. The batch carries no deadline and no fork time: it can execute in any Unzen block, and moving the schedule does not touch it ([section 7](#moving-the-fork-time)). The message must still execute on L2 well before the propose cutoff, because no Unzen block exists after it. The go/no-go check confirms it by comparing the `SignalService` proxy's EIP-1967 implementation slot with the address clients and guests build in.

Finally, the proposal cross-checks `ETNA_FORK_TIME`. Its last L1 action reverts unless the Unzen Inbox's cutoff times and the EtnaInbox's `ETNA_FORK_TIME` derive from the same value. The L2 batch needs no such check, because the L2 `SignalService` holds no time. After the cutoff no Unzen block can carry the L2 message, and the first Etna block must already run the implementation that closes checkpoints, because the golden touch key is public. Honest nodes refuse a start whose L2 `SignalService` lacks the Etna implementation (SYNC-9-5a), and so does the guest of the first proof from S (PROOF-6.2-46a).

Once the proposal's L1 part executes, `ETNA_FORK_TIME` is fixed in the Unzen Inbox and the EtnaInbox; [section 7](#7-failure-handling) covers moving it.

**Choosing `PROPOSE_MARGIN`.** It must make every block derivable from an accepted proposal earlier than `ETNA_FORK_TIME` (SPEC PARAM-11-12b).

- Blocks from a proposal's normal source have timestamps at or below the proposal's L1 timestamp.
- Forced-inclusion blocks and default blocks take the parent's timestamp plus one second ([Derivation.md](../Derivation.md#timestamp-validation)). There are at most 11 of them per proposal: up to 10 forced inclusions plus one default block.
- The Unzen Inbox enforces on chain that it accepts at most one proposal per L1 block. With L1 slots of at least 12 s, a proposal at time p therefore yields no block later than p + 11 s, and `PROPOSE_MARGIN = 12 s` suffices.

With slots of at least 12 s no lead of the L2 timestamp over L1 time builds up, so 12 s holds whatever happened before the cutoff. With shorter slots it does not: forced inclusion blocks consumed earlier can already put the L2 timestamp ahead of L1 time, and that lead persists. The margin must then be computed for the shortest slot interval expected and exceed the lead at the cutoff plus 11 s + ⌈Q/10⌉ × max(0, 11 s − slot time), and never fall below 12 s (SPEC PARAM-11-12b). A margin fixed days ahead cannot bound that lead, so this procedure claims its 12 s margin only for slots of at least 12 s. If L1 shortens its slots before the switch, recompute the margin and upgrade the Unzen Inbox's cutoff before that L1 fork activates. In every case, nodes and both guests check the timestamp in S’s authenticated header before signing or proving from S.

**Choosing `FI_MARGIN`.** `FI_MARGIN = PROPOSE_MARGIN + forcedInclusionDelay + buffer`, where `forcedInclusionDelay` is the Unzen Inbox's `forcedInclusionDelay` and the buffer is at least the longest expected gap between Unzen proposals, counting the interval before the propose cutoff in which proposers and preconfirmers have already stopped ([section 4](#4-switch-day), step 3). Every forced inclusion the Unzen Inbox accepts is then due before the propose cutoff, and every proposal must take the due entries, up to 10 per proposal. A queue deeper than the remaining proposals can take, or a gap with no proposal at all, can still leave entries behind ([section 7](#7-failure-handling)).

## 4. Switch day

1. **Unzen provers, before the cutoff.** Keep the proving backlog drained, so that only the last few proposals remain to prove after the cutoff.
2. **Verify L2 before the cutoffs.** Read the L2 proxy's implementation slot at an Unzen block accepted and proven on L1, and match it against the address that clients and guests build in. If the relay is delayed or the invocation failed, follow its Bridge status to retry. If it cannot execute before the propose cutoff, postpone the schedule ([section 7](#moving-the-fork-time)).
3. **Preconfirmers.** Stop ahead of the propose cutoff and submit every preconfirmed block. Announce the cutoff so users can resubmit transactions that never reached a proposal.
4. **Finish Unzen.** At the propose cutoff the set of proposals closes. Prove through its final block S and confirm that the Unzen proof saved its checkpoint in the L1 SignalService. Keep independent copies of proposal blobs for retries beyond L1 blob retention.
5. **Record the start.** Once L1 reaches the fork time, anyone calls `setOrigin(S)`. The Inbox requires the cutoff returned by Unzen’s `proposeCutoff()` to be nonzero and already reached. It checks that all accepted proposals are finalized, matches the final hash against the checkpoint at the supplied height, and copies that hash and the checkpoint’s stateRoot into the start. It writes the start once and leaves the SignalService checkpoint untouched (START-10-5a–5c, LAND-6.1-8a).
6. **Wait for R₀ finality.** Nodes authenticate the start from their own finalized L1 view. Check S’s hash, stateRoot and timestamp, the L2 proxy implementation at S and their own fork time under SYNC-9-5a. Missing material leaves the node untrusted. An authenticated mismatch halts it. The operator’s go/no-go check cannot authorize an exception.
7. **Start Etna.** Generate CometBFT genesis under START-10-20, with `initial_height = S + 1`, `genesis_time = R₀.timestamp`, the appHash of S and the genesis validator state, and committee 0. Start the EL, ABCI app, guarded signer and CometBFT (START-10-6).

## 5. The first landing

An Etna landing from S uses its recorded origin and the ordinary checks in [SPEC.md 6.1](SPEC.md#61-land). Both guests authenticate S’s header and the L2 SignalService implementation slot under its stateRoot (PROOF-6.2-46a). These checks also apply to a later proof from S. The final Unzen proof already established the start on L1. The first Etna landing enables L2 → L1 withdrawals for the Etna blocks it settles and advances the committee snapshot used for exit confirmations.

## 6. Bridge during and after the switch

- **L2 → L1.** The L1 Bridge verifies messages against SignalService checkpoints indexed by L2 block number, and it does not change.
  - Checkpoints at or below S come from the Unzen Inbox's proofs. From the DAO proposal on, they reach the SignalService through the EtnaInbox's forwarder.
  - Checkpoints above S come from the EtnaInbox's own landings.
  - Neither overwrites the other. The Unzen Inbox accepts no proposal at or after the propose cutoff, so a sound Unzen proof never covers heights above S, and the EtnaInbox's forwarder is closed once the start is written. The EtnaInbox lands only above S.
- **L1 → L2.** This follows the anchorless design ([ANCHORLESS.md section 4](ANCHORLESS.md#4-bridge-verification) and [section 8](ANCHORLESS.md#8-fork-and-migration)). From the first Etna block on, the L2 SignalService saves no checkpoint and verifies new proofs against the EIP-4788 roots of Etna anchors. A message sent on L1 before the cutoff and not yet processed on L2 is proven against an Etna block's root, whose anchor is at or after R₀, or against a checkpoint that the upgraded `SignalService` saved before the switch and that already covers it.
- **Unchanged by the switch.** The switch does not change the Bridge, the vaults or the QuotaManager. A later verifier-failure rollback does upgrade the L1 SignalService and the Bridge (SPEC RECOV-8-26).

## 7. Failure handling

| Situation                                                        | Effect and response                                                                                                                                                                                                                                                    |
| ---------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Initial proposal misses its deadline                             | The guard reverts the batch. Publish a later schedule and client release before clients reach their configured fork.                                                                                                                                                   |
| An L2 invocation fails                                           | Look up the exact message status. Process a NEW message, or retry a RETRIABLE invocation with sufficient gas. Execution ID 0 has no next-ID dependency. If the upgrade cannot execute before the propose cutoff, postpone the schedule with the procedure below.       |
| The schedule has to move after the proposal executed             | Postpone it with one L1 batch before that batch's inclusion deadline (below). A batch that misses the deadline reverts, and the old schedule stands.                                                                                                                   |
| The final Unzen proof is missing                                 | The latch reverts and Etna cannot start. Preserve Unzen data, repair proving if needed and submit the remaining proof. An Etna governance recovery cannot create a proven origin.                                                                                      |
| The L2 implementation, fork time or S timestamp fails validation | Signing stays closed and proofs from S fail when S’s timestamp or implementation is wrong. A permissionless origin transaction authenticates Unzen’s tip, regardless of this operator check. Escalate the configuration mismatch to the DAO before attempting startup. |
| L1 reorganizes before R₀ finality                                | Discard the orphaned handoff, read the canonical cutoff, proof and checkpoint again, and retry if needed. Nodes start only from a finalized R₀.                                                                                                                        |
| Unzen FI entries or preconfirmations remain at cutoff            | Unconsumed FI fees remain in Unzen, and preconfirmations outside a proposal are dropped. Announce the cutoff and resubmit to Etna once it opens.                                                                                                                       |
| The committee cannot produce after an authenticated start        | Unzen stays closed. Use governance recovery under SPEC §8 when its prerequisites hold.                                                                                                                                                                                 |
| The first Etna landing is later rolled back                      | Restore the one-time start and preserve Unzen’s checkpoint. The next proof from S still checks the L2 implementation (RECOV-8-27, RECOV-8-28, PROOF-6.2-46a).                                                                                                          |

### Moving the fork time

No L2 contract holds the fork time, so moving it takes one L1 batch and a client release. The L2 upgrade of [section 3](#3-the-dao-proposal) does not depend on the date: if it has not executed yet, it is retried under either schedule and only has to execute before the propose cutoff in force.

**Deadline.** Let C be the earlier of the installed L1 forced-inclusion and proposal cutoffs. Fix the batch's exclusive L1 inclusion deadline in the batch itself: `B = min(C, oldForkTime − rolloutBudget)`. The budget covers the batch's finality, activation of the staged releases on the Unzen nodes and operating slack, using the slowest measured activation in the rehearsal. If the measured intervals do not fit before B, keep the installed schedule.

1. **Prepare.** Require a later fork time with the new `PROPOSAL_LEAD` still available when the batch executes. Pin the old and new schedules, both chain IDs, the new EtnaInbox and Unzen Inbox implementations, the new guest images and the release hashes. Stage the matching clients and guests; keep the old release available while the old schedule remains active.
2. **One DAO batch on L1.** It checks an unwritten start, the exact old configuration, `block.timestamp < B` at inclusion and the lead for the new fork time, each through a reverting helper. Only then does it install the Unzen cutoffs, the EtnaInbox fork time and the guest trust together and repeat the proposal's cross-check of the two L1 configurations. Prepare the replacement from the live `getConfig()`: the Unzen checkpoint store already names the EtnaInbox. Preserve every unrelated config field and storage value.
3. **Roll out.** Once the batch is final, enable the staged releases for the new schedule. A node whose fork time differs from the EtnaInbox's does not become trusted (SYNC-9-5a).
4. **If the batch is late.** A batch submitted before B and included at or after it reverts, and the old schedule stands. Retry the same authorized batch only while its guards still pass. If the old schedule cannot proceed either, because the L2 upgrade has still not executed, keep signing closed and escalate to a separately reviewed governance migration.

## 8. Afterwards

- **Unzen Inbox.** It stays deployed, so bonds can be withdrawn.
- **EtnaInbox.** A later upgrade may remove the checkpoint forwarder once Unzen's last checkpoint is saved.
- **SignalService.** The switch needs no later upgrade of it. A later L1 implementation must keep `_authorizedSyncer` set to the EtnaInbox, `usesBeaconRoots` false and `VERSION` unchanged; a later L2 one follows [ANCHORLESS.md section 8](ANCHORLESS.md#upgrade-order), step 6.
- **Anchor.** A later clean-up may delete `anchorV4` and its state ([ANCHORLESS.md section 8](ANCHORLESS.md#8-fork-and-migration)).

## 9. Rehearsal

Run the whole procedure on a test network that runs Unzen first, then on mainnet. [ACCEPTANCE.md section 8](ACCEPTANCE.md#8-switch-rehearsal-switchmd) lists what the rehearsal must show.
