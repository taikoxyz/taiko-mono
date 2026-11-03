# Switching from Unzen to Etna

This document is the one-time procedure that ends the Unzen chain at its last block S and starts Etna at S + 1. It accepts a short outage in exchange for a simple procedure: the Unzen Inbox stops accepting proposals, a multisig records where Etna starts, and Etna produces blocks without waiting for Unzen's final proofs. The rules it relies on are in [SPEC.md](SPEC.md), mainly the Etna start in [section 10](SPEC.md#10-startup-and-deployment) and the first-landing check in [6.1](SPEC.md#61-land), and in [ANCHORLESS.md](ANCHORLESS.md) for the anchorless fork and its L2 contract upgrades. Where this document and SPEC.md disagree, SPEC.md governs.

## 1. Overview

| Name                          | Meaning                                                                                                                                                                                 |
| ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ETNA_FORK_TIME`              | The single switch time: the clients' Etna fork time, the L2 `Anchor`'s `etnaTimestamp` and an EtnaInbox immutable. Every Unzen block is earlier and every Etna block is at or after it. |
| S                             | The Etna start: the last Unzen block. Etna's first block is S + 1, and CometBFT heights continue the L2 block numbers.                                                                  |
| `originWriter`                | A multisig named by an EtnaInbox immutable. It can call `setOrigin(S, hash, stateRoot)` once, after `ETNA_FORK_TIME` (SPEC START-10-5a).                                                |
| R₀                            | The L1 block that executes `setOrigin`. It becomes `L1_0`, generation 0's L1 origin, so every Etna anchor is at or after it.                                                            |
| `PROPOSAL_LEAD`               | How long before `ETNA_FORK_TIME` the DAO proposal must execute ([section 3](#3-the-dao-proposal)).                                                                                      |
| `PROPOSE_MARGIN`, `FI_MARGIN` | How long before `ETNA_FORK_TIME` the Unzen Inbox stops accepting proposals and forced inclusions (SPEC START-10-5d, PARAM-11-12b).                                                      |

The switch runs in these stages:

```text
1. DAO proposal         executes at least PROPOSAL_LEAD before ETNA_FORK_TIME; its L2 message executes on L2
2. go/no-go             well before the cutoffs, the L2 Anchor's implementation slot holds the Etna Anchor
3. propose cutoff       at ETNA_FORK_TIME − PROPOSE_MARGIN the Unzen Inbox stops accepting proposals;
                        the last block of the last proposal is S
4. L1 past fork time    the first L1 block with timestamp ≥ ETNA_FORK_TIME is finalized
5. setOrigin            the originWriter writes (S, hash, stateRoot) in L1 block R₀
6. R₀ finalized         nodes build CometBFT genesis and start
7. first Etna block     S + 1, with timestamp ≥ R₀.timestamp ≥ ETNA_FORK_TIME
8. Unzen's final proof  the Unzen Inbox finalizes through S and saves the checkpoint at S
                        (runs alongside stages 4–7 and may finish after them)
9. first landing        settles Etna blocks once stage 8 has landed

outage: from stage 3 to stage 7
```

The outage is about `PROPOSE_MARGIN` plus two L1 finality periods (stages 4 and 6), plus the time the originWriter and node operators take. It does not include Unzen's proving time, but that time has a budget: Etna produces at most U blocks beyond its latest checkpoint, which stays S until the first landing. Unzen's final proof, the first Etna landing, its L1 finality and an Etna anchor that picks it up ([SPEC.md 6.4](SPEC.md#64-back-pressure)) must together fit within U × block time from the first Etna block, about 4 h at the reference U = 3,600 and 4 s blocks. Otherwise Etna pauses a second time on back-pressure; no block is lost.

## 2. Prerequisites

Everything below is in place before the DAO proposal of [section 3](#3-the-dao-proposal) executes:

- **Registry and committee 0.** The EtnaInbox proxy (not yet initialized) and the registry are deployed (SPEC START-10-1). Committee-0 validators have registered and become active before the DAO proposal is drafted, because the proposal fixes genesisCutoff and the committee-0 record hash (START-10-2). A validator who registers later joins at an ordinary rotation after S once it is active and selected at that rotation's snapshot.
- **Software.**
  - Execution layer: alethia-reth with Etna rules from `ETNA_FORK_TIME`. Nodes that run taiko-geth move to alethia-reth, with full Unzen history, before the switch.
  - Consensus: the Etna ABCI application, the guarded signer and CometBFT. Clients and guests build in the address of the Etna `Anchor` implementation for the L2 chain id (PARAM-11-12a).
  - Unzen proposers and preconfirmers stop before the propose cutoff and never propose after it.
- **L2 implementations.** The Etna `Anchor` and `SignalServiceL2` implementations are deployed on L2 at their final addresses before clients and guests are built, because both build in the `Anchor` implementation address.
- **L2 system contracts.** EIP-2935 and EIP-4788 have code on L2 ([ANCHORLESS.md section 7](ANCHORLESS.md#7-prerequisite-eip-4788-and-eip-2935-on-l2)).
- **Guests.** The Unzen guests read both checkpoint layouts ([ANCHORLESS.md section 8](ANCHORLESS.md#upgrade-order), step 2), and the Etna guests are built for the deployment. SGX instances for the EtnaInbox's SGX sub-verifier are registered at least that verifier's `instanceValidityDelay` ahead, so an SGX + ZK first landing does not wait for them.

## 3. The DAO proposal

One DAO proposal carries every L1 and L2 action of the switch. It executes at least `PROPOSAL_LEAD` before `ETNA_FORK_TIME`. `PROPOSAL_LEAD` is longer than `FI_MARGIN`, and long enough to relay the L2 message, retry the relay if it fails, pass the go/no-go check of [section 4](#4-switch-day), and still leave the DAO's fastest path time to move the fork time if that check fails ([section 7](#7-failure-handling)). Once it has executed and its L2 message has executed on L2, nothing in the switch needs the DAO.

L1 actions, which take effect when the proposal executes:

0. **Guard.** Reverts if the proposal executes after `ETNA_FORK_TIME − PROPOSAL_LEAD`, so a late execution changes nothing.
1. **Unzen Inbox upgrade** (SPEC START-10-5d).
   - `propose` reverts when `block.timestamp >= ETNA_FORK_TIME − PROPOSE_MARGIN`.
   - `saveForcedInclusion` reverts when `block.timestamp >= ETNA_FORK_TIME − FI_MARGIN`.
   - `prove` and the bond functions are unchanged, so Unzen's remaining proposals can still be proven and bonds withdrawn.
2. **L1 SignalService upgrade** (START-10-5).
   - The SignalService accepts checkpoints from two syncers, the Unzen Inbox and the EtnaInbox.
   - Once the start is written, it rejects Unzen Inbox checkpoints above S. A sound Unzen proof never covers those heights, but `saveCheckpoint` has no range check of its own and overwrites silently, so this costs little and guards against an unsound one.
   - `VERSION` stays 1: checkpoints are stored under `_checkpoints[VERSION]`, so a new version would hide every checkpoint the Unzen Inbox saved, including the one at S. That would break L2 → L1 claims for Unzen blocks and the first-landing check.
3. **Unzen verifier.** It trusts the Unzen guest images that read both checkpoint layouts. This happens on L1 at execution, before the L2 part of the proposal reaches L2, which [ANCHORLESS.md section 8](ANCHORLESS.md#upgrade-order) requires.
4. **EtnaInbox.** The proxy is upgraded to an implementation whose immutables include `originWriter`, `unzenInbox` (the Unzen Inbox address) and `ETNA_FORK_TIME` (SPEC PARAM-11-12a). It is then initialized with every parameter of START-10-5. Initialization does not write the start.
5. **EtnaInbox verifier.** The EtnaInbox uses its own `ZkRequiredVerifier` instance with its own sub-verifier instances, SGX, RISC0 and SP1, which trust the Etna guest images (SPEC PROOF-6.2-3). Image trust lives in the sub-verifiers, and an SP1 proof's public input binds the sub-verifier's own address, not the Inbox's. Sharing a sub-verifier with the Unzen Inbox would therefore let trust in an Etna image widen what the Unzen Inbox accepts.

L2 action:

6. **One L2 message** to the `DelegateController` upgrades the `Anchor` and the L2 `SignalService` to `SignalServiceL2`, with `etnaTimestamp = ETNA_FORK_TIME` ([ANCHORLESS.md section 8](ANCHORLESS.md#upgrade-order), step 3). Both upgrades are in one batch, so the Etna `Anchor` implementation shows that the whole batch executed. The batch begins with a guard that reverts once the L2 block timestamp is at or after `ETNA_FORK_TIME − PROPOSE_MARGIN`. `DelegateController` runs messages with execution id 0 in any order, so without the guard a superseded message could still execute later and install an old implementation. The message must execute on L2 well before the propose cutoff. The go/no-go check confirms it by comparing the `Anchor` proxy's EIP-1967 implementation slot with the address clients and guests build in.

Finally, the proposal cross-checks `ETNA_FORK_TIME`. Its last L1 action reverts unless the Unzen Inbox's cutoff times and the EtnaInbox's `ETNA_FORK_TIME` derive from the same value. The L2 batch's last action, which ANCHORLESS §8 already uses to confirm the `Anchor` upgrade, reverts unless `Anchor.etnaTimestamp()` equals it. After the cutoff no Unzen block can carry it, and the first Etna block must already see the `Anchor`'s gate on `anchorV4`, because the golden touch key is public. Honest nodes refuse a start whose `Anchor` lacks the Etna implementation (SYNC-9-5a), and so does the guest of the first proof from S (PROOF-6.2-46a).

Once the proposal's L1 part executes, `ETNA_FORK_TIME` is fixed in the Unzen Inbox and the EtnaInbox, and once its L2 message executes, in the `Anchor`; [section 7](#7-failure-handling) covers moving it.

**Choosing `PROPOSE_MARGIN`.** It must make every block derivable from an accepted proposal earlier than `ETNA_FORK_TIME` (SPEC PARAM-11-12b).

- Blocks from a proposal's normal source have timestamps at or below the proposal's L1 timestamp.
- Forced-inclusion blocks and default blocks take the parent's timestamp plus one second ([Derivation.md](../Derivation.md#timestamp-validation)). There are at most 11 of them per proposal: up to 10 forced inclusions plus one default block.
- The Unzen Inbox accepts at most one proposal per L1 block. With L1 slots of at least 12 s, a proposal at time p therefore yields no block later than p + 11 s, and `PROPOSE_MARGIN = 12 s` suffices.

With slots shorter than 12 s, this per-proposal bound no longer holds on its own: blocks from successive proposals can drift ahead while forced inclusions keep arriving, so the margin also depends on the forced inclusion backlog at the cutoff. Choose the margin for the shortest slot interval expected at the cutoff. The originWriter's check in [section 4](#4-switch-day), step 6, is the required safety net that catches a margin that turned out too small.

**Choosing `FI_MARGIN`.** `FI_MARGIN = PROPOSE_MARGIN + forcedInclusionDelay + buffer`, where `forcedInclusionDelay` is the Unzen Inbox's `forcedInclusionDelay` and the buffer is at least the longest expected gap between Unzen proposals. Every forced inclusion the Unzen Inbox accepts is then due before the propose cutoff, and every proposal must take the due entries, up to 10 per proposal. A queue deeper than the remaining proposals can take, or a gap with no proposal at all, can still leave entries behind ([section 7](#7-failure-handling)).

## 4. Switch day

1. **Unzen provers, before the cutoff.** Keep the proving backlog drained, so that only the last few proposals remain to prove after the cutoff.
2. **Operators: go/no-go, well before the cutoffs.** Check that the L2 `Anchor` proxy's EIP-1967 implementation slot at the L2 head holds the Etna `Anchor` implementation address that clients and guests build in. If it does not, retry relaying the L2 message. If it still has not executed with time running out, for example because another proposal's L2 message used the next execution id first, move the fork time ([section 7](#7-failure-handling)).
3. **Preconfirmers, before the propose cutoff.** Stop preconfirming and propose every preconfirmed block. Transactions that are only in preconfirmed blocks not proposed by the cutoff are dropped, so announce the cutoff in advance.
4. **The cutoff.** At `ETNA_FORK_TIME − PROPOSE_MARGIN` the Unzen Inbox stops accepting proposals. The last block of the last proposal is S. Unzen provers prove the remaining proposals at once.
5. **Everyone: wait for L1.** Wait until the first L1 block with timestamp at or after `ETNA_FORK_TIME` is finalized. From then on no L1 reorg can add or remove an Unzen proposal, so S is fixed. Waiting only for the block that holds the last proposal is not enough, because later blocks before `ETNA_FORK_TIME` could still be reorganized to include another proposal.
6. **originWriter signers and node operators: check S.** Derive S from finalized L1 on independent nodes and check three things:

   - S's timestamp is below `ETNA_FORK_TIME`;
   - S's hash and stateRoot agree across the nodes;
   - the L2 `Anchor` proxy's EIP-1967 implementation slot at block S holds the Etna `Anchor` implementation address that clients and guests build in, which shows the L2 message executed.

   If any check fails, do not call `setOrigin` ([section 7](#7-failure-handling)).

7. **originWriter: call `setOrigin(S, hash, stateRoot)`** (SPEC START-10-5a).
   - It writes the Etna start and opens forced inclusion on the EtnaInbox (START-10-5b).
   - It does not write the SignalService (START-10-5c).
   - Its L1 block is R₀.
8. **Node operators: start Etna once R₀ is finalized.**
   - Generate CometBFT genesis per START-10-20: `initial_height = S + 1`, `genesis_time = R₀.timestamp`, `app_hash` = S's hash and the validators of committee 0.
   - Start the execution layer, the ABCI application, the signer and CometBFT (START-10-6).
   - Before a node trusts the chain and signs, it runs SYNC-9-5a's checks: S is the last block of the Unzen chain, its header of S has the start's stateRoot, and, while the latest checkpoint is S, the L2 `Anchor` at S has the Etna implementation. That last check needs the L2 state at S, which a node keeps until the first landing or reads through a verified `eth_getProof` (SYNC-9-16).
9. **Unzen provers: finish proving through S.** The `prove` call that finalizes the last Unzen proposal saves the checkpoint at S in the L1 SignalService.
10. **Landers: land from S.** The first landing, with proof origin S, succeeds once step 9 has landed ([section 5](#5-the-first-landing)).

## 5. The first landing

While the latest checkpoint is still S, `land` additionally requires three things before it verifies any proof (SPEC LAND-6.1-8a):

1. the Unzen Inbox has finalized every proposal it accepted;
2. the Unzen Inbox's last finalized block hash equals the hash the originWriter wrote for S;
3. the L1 SignalService holds a checkpoint at S with that hash and the stateRoot the originWriter wrote.

The three together prove that the originWriter wrote Unzen's last block.

- `setOrigin` only runs after `ETNA_FORK_TIME`, and the Unzen Inbox accepts no proposal after the propose cutoff (START-10-5d), so by the time of any landing the set of Unzen proposals is closed.
- Conditions 1 and 2 make the written block the end of the last Unzen proposal, not some earlier block that happens to have a checkpoint.
- Condition 3 ties the written height and stateRoot to the block Unzen's own proof settled.
- The guest of that first proof also checks that the L2 `Anchor` at S has the Etna implementation (PROOF-6.2-46a). Proofs therefore cannot settle a chain that started without the `anchorV4` gate.

A wrong start therefore never passes. Honest nodes also refuse it before signing (SYNC-9-5a), because they compare S, its hash, its stateRoot and the `Anchor` implementation at S with their own state. The originWriter can delay or stop Etna, but cannot make L1 accept a forged state.

Block production does not wait for this check. Etna produces up to U blocks beyond its latest checkpoint, which is S until the first landing. It then pauses on back-pressure until a landing is finalized on L1 and picked up by an Etna anchor ([SPEC.md 6.4](SPEC.md#64-back-pressure)); no block is lost. Until the first landing succeeds, two things wait for it: L2 → L1 withdrawals from Etna blocks, and registry exit confirmations.

## 6. Bridge during and after the switch

- **L2 → L1.** The L1 Bridge verifies messages against SignalService checkpoints indexed by L2 block number, and it does not change.
  - Checkpoints at or below S come from the Unzen Inbox, including those its final proofs save after Etna has started.
  - Checkpoints above S come from the EtnaInbox.
  - Neither overwrites the other. The Unzen Inbox accepts no proposal after the cutoff, so a sound Unzen proof never covers heights above S, and the upgraded SignalService also rejects Unzen Inbox checkpoints above S once the start is written. The EtnaInbox lands only above S.
- **L1 → L2.** This follows the anchorless design ([ANCHORLESS.md section 4](ANCHORLESS.md#4-bridge-verification) and [section 8](ANCHORLESS.md#8-fork-and-migration)). From the first Etna block on, the L2 SignalService verifies proofs against the EIP-4788 roots of Etna anchors. A message sent on L1 before the cutoff and not yet processed on L2 is proven against an Etna block's root, whose anchor is at or after R₀. A proof built before the switch must be rebuilt.
- **Unchanged.** The Bridge, the vaults and the QuotaManager do not change.

## 7. Failure handling

| Situation                                                                                        | Effect                                                                                                                                                                                                                                                                                          | Response                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| ------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| The DAO proposal executes late or not at all                                                     | Its first action reverts after `ETNA_FORK_TIME − PROPOSAL_LEAD`, so nothing changes on chain, but clients would still apply Etna rules at `ETNA_FORK_TIME`                                                                                                                                      | Before `ETNA_FORK_TIME`, release clients with a later fork time, then submit a new proposal with that time                                                                                                                                                                                                                                                                                                                                                                                                                 |
| The L2 message fails the go/no-go check                                                          | The `Anchor` is not upgraded yet, for example because another proposal's L2 message used the next execution id first                                                                                                                                                                            | Retry the relay. If it cannot execute well before the propose cutoff, move `ETNA_FORK_TIME` (last row)                                                                                                                                                                                                                                                                                                                                                                                                                     |
| The L2 message has not executed by the propose cutoff                                            | Etna would start with an ungated `anchorV4`, so anyone could save a forged L2 checkpoint with the public golden touch key. Honest nodes refuse such a start (SYNC-9-5a), and the message can no longer reach L2                                                                                 | Do not call `setOrigin`; the switch stops until the DAO acts                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| The originWriter writes a wrong (S, hash, stateRoot)                                             | Honest nodes refuse the start and produce nothing (SYNC-9-5a); any landing on it reverts (LAND-6.1-8a); funds are unaffected. A start below the true S also makes the Unzen Inbox's final `prove` revert until the rewrite (START-10-5c), so Unzen withdrawals above the written start wait too | The start is written once, so a DAO upgrade of the EtnaInbox must rewrite it as START-10-5c describes, which starts the corrected start as a new generation with its own signing domain; the outage then includes the DAO authorization delay (SPEC section 12 item 9)                                                                                                                                                                                                                                                     |
| The originWriter does not act                                                                    | The outage grows                                                                                                                                                                                                                                                                                | Keep the signers on call for the switch and rehearse the procedure ([section 9](#9-rehearsal)). If the originWriter is lost, the DAO upgrades the EtnaInbox implementation to name a new one, which START-10-16 allows before the start write                                                                                                                                                                                                                                                                              |
| L1 reorganizes blocks before `ETNA_FORK_TIME`                                                    | No effect                                                                                                                                                                                                                                                                                       | The originWriter waits until the first L1 block at or after `ETNA_FORK_TIME` is finalized                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| An Unzen block has a timestamp at or after `ETNA_FORK_TIME`                                      | Its `anchorV4` hits the `Anchor`'s gate and the execution layer applies Etna rules to it, so Unzen cannot derive or prove it                                                                                                                                                                    | Do not call `setOrigin`; the switch stops until the DAO acts. A `PROPOSE_MARGIN` sized by [section 3](#3-the-dao-proposal) prevents this                                                                                                                                                                                                                                                                                                                                                                                   |
| Unzen's final proof is slow                                                                      | Etna produces up to U blocks, then pauses on back-pressure without losing blocks                                                                                                                                                                                                                | Production resumes once the first landing is finalized and picked up by an Etna anchor                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Unzen's final proof can never be produced, for example because of a bug in the Unzen guest image | Etna stays paused on back-pressure; no landing is possible                                                                                                                                                                                                                                      | The DAO trusts a fixed Unzen image in the Unzen verifier; the proof then lands and Etna resumes. No block is lost as long as the fixed proof lands within the reference-header bound (SPEC BATCH-6.3-6, about 18 days); after that, the suffix above S can only be discarded by governance recovery                                                                                                                                                                                                                        |
| Forced inclusions remain in the Unzen Inbox's queue at the cutoff                                | They are never derived; their fees stay in the Unzen Inbox                                                                                                                                                                                                                                      | `FI_MARGIN` makes this unlikely. Their fees are not refunded, an accepted loss, and users resubmit to the EtnaInbox                                                                                                                                                                                                                                                                                                                                                                                                        |
| Preconfirmed blocks were not proposed by the cutoff                                              | Their transactions are dropped                                                                                                                                                                                                                                                                  | Announce the cutoff; preconfirmers propose everything first ([section 4](#4-switch-day), step 3)                                                                                                                                                                                                                                                                                                                                                                                                                           |
| Etna's committee cannot start                                                                    | Unzen stays stopped; there is no automatic return to Unzen                                                                                                                                                                                                                                      | DAO action: governance recovery ([SPEC.md section 8](SPEC.md#8-halts-and-recovery)) or an upgrade                                                                                                                                                                                                                                                                                                                                                                                                                          |
| A verifier-failure rollback finds that the first Etna landing was bad                            | The EtnaInbox returns to the values the start write recorded, and c returns to S                                                                                                                                                                                                                | LAND-6.1-8a applies again to the next landing; the Unzen Inbox's checkpoints at or below S are kept (SPEC RECOV-8-27, RECOV-8-28)                                                                                                                                                                                                                                                                                                                                                                                          |
| `ETNA_FORK_TIME` must move                                                                       | It is fixed in the Unzen Inbox, the EtnaInbox (an immutable), the `Anchor` and the client releases                                                                                                                                                                                              | Before the old propose cutoff: DAO upgrades of the Unzen Inbox and, through an L2 message, the `Anchor`; an upgrade of the EtnaInbox implementation, which START-10-16 allows before the start write; and client releases with the new time. `etnaTimestamp` is an `Anchor` immutable, so a new time means a new `Anchor` implementation: clients and guests are rebuilt with its address, and the EtnaInbox's sub-verifiers trust the new guest images. The superseded L2 message cannot execute after its own guard time |

## 8. Afterwards

- **Unzen Inbox.** It stays deployed, so bonds can be withdrawn and its final proofs can land.
- **SignalService.** A later upgrade may remove the Unzen Inbox from the SignalService's syncers once Unzen's last checkpoint is saved. It must keep `VERSION` unchanged.
- **Anchor.** Clean-up follows [ANCHORLESS.md section 8](ANCHORLESS.md#upgrade-order), step 6.

## 9. Rehearsal

Run the whole procedure on a test network that runs Unzen first, then on mainnet. [ACCEPTANCE.md section 6](ACCEPTANCE.md#6-switch-rehearsal-switchmd) lists what the rehearsal must show.
