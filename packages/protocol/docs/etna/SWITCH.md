# Switching from Unzen to Etna

This document is the one-time procedure that ends the Unzen chain at its last block S and starts Etna at S + 1. It accepts a short outage in exchange for a simple procedure: the Unzen Inbox stops accepting proposals, a multisig records where Etna starts, and Etna produces blocks without waiting for Unzen's final proofs. The rules it relies on are in [SPEC.md](SPEC.md), mainly the Etna start in [section 10](SPEC.md#10-startup-and-deployment) and the first-landing check in [6.1](SPEC.md#61-land), and in [ANCHORLESS.md](ANCHORLESS.md) for the anchorless fork and its L2 contract upgrades. Where this document and SPEC.md disagree, SPEC.md governs.

## 1. Overview

| Name                          | Meaning                                                                                                                                                                                 |
| ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ETNA_FORK_TIME`              | The single switch time: the clients' Etna fork time, the L2 `Anchor`'s `etnaTimestamp` and an EtnaInbox immutable. Every Unzen block is earlier and every Etna block is at or after it. |
| S                             | The Etna start: the last Unzen block. Etna's first block is S + 1, and CometBFT heights continue the L2 block numbers.                                                                  |
| `originWriter`                | A multisig named by an EtnaInbox immutable. It can call `setOrigin(S, hash, stateRoot)` once, after `ETNA_FORK_TIME` (SPEC START-10-5a).                                                |
| R₀                            | The L1 block that executes `setOrigin`. It becomes `L1_0`, generation 0's L1 origin, so every Etna anchor is at or after it.                                                            |
| `PROPOSE_MARGIN`, `FI_MARGIN` | How long before `ETNA_FORK_TIME` the Unzen Inbox stops accepting proposals and forced inclusions ([section 3](#3-the-dao-proposal)).                                                    |

The switch runs in these stages:

```text
1. propose cutoff       at ETNA_FORK_TIME − PROPOSE_MARGIN the Unzen Inbox stops accepting proposals;
                        the last block of the last proposal is S
2. L1 past fork time    the first L1 block with timestamp ≥ ETNA_FORK_TIME is finalized
3. setOrigin            the originWriter writes (S, hash, stateRoot) in L1 block R₀
4. R₀ finalized         nodes build CometBFT genesis and start
5. first Etna block     S + 1, with timestamp ≥ R₀.timestamp ≥ ETNA_FORK_TIME
6. Unzen's final proof  the Unzen Inbox finalizes through S and saves the checkpoint at S
                        (runs alongside stages 2–5 and may finish after them)
7. first landing        settles Etna blocks once stage 6 has landed

outage: from stage 1 to stage 5
```

The outage is about `PROPOSE_MARGIN` plus two L1 finality periods (stages 2 and 4), plus the time the originWriter and node operators take. It does not include Unzen's proving time.

## 2. Prerequisites

Everything below is in place before the DAO proposal of [section 3](#3-the-dao-proposal) executes:

- **Registry and committee 0.** The EtnaInbox proxy (not yet initialized) and the registry are deployed (SPEC START-10-1). Committee-0 validators have registered and become active before the DAO proposal is drafted, because the proposal fixes genesisCutoff and the committee-0 record hash (START-10-2). Validators who register later join at the first ordinary rotation after S.
- **Software.**
  - Execution layer: alethia-reth with Etna rules from `ETNA_FORK_TIME`. Nodes that run taiko-geth move to alethia-reth, with full Unzen history, before the switch.
  - Consensus: the Etna ABCI application, the guarded signer and CometBFT.
  - Unzen proposers and preconfirmers stop before the propose cutoff and never propose after it.
- **L2 system contracts.** EIP-2935 and EIP-4788 have code on L2 ([ANCHORLESS.md section 7](ANCHORLESS.md#7-prerequisite-eip-4788-and-eip-2935-on-l2)).
- **Guests.** The Unzen guests read both checkpoint layouts ([ANCHORLESS.md section 8](ANCHORLESS.md#upgrade-order), step 2), and the Etna guests are built for the deployment.

## 3. The DAO proposal

One DAO proposal carries every L1 and L2 action of the switch. It executes before `ETNA_FORK_TIME − FI_MARGIN`. After it executes, nothing in the switch needs the DAO.

L1 actions, which take effect when the proposal executes:

1. **Unzen Inbox upgrade.**
   - `propose` reverts when `block.timestamp >= ETNA_FORK_TIME − PROPOSE_MARGIN`.
   - `saveForcedInclusion` reverts when `block.timestamp >= ETNA_FORK_TIME − FI_MARGIN`.
   - `prove` and the bond functions are unchanged, so Unzen's remaining proposals can still be proven and bonds withdrawn.
2. **L1 SignalService upgrade.** The SignalService accepts checkpoints from two syncers, the Unzen Inbox and the EtnaInbox. `VERSION` stays 1: checkpoints are stored under `_checkpoints[VERSION]`, so a new version would hide every checkpoint the Unzen Inbox saved, including the one at S. That would break L2 → L1 claims for Unzen blocks and the first-landing check.
3. **Unzen verifier.** It trusts the Unzen guest images that read both checkpoint layouts. This happens on L1 at execution, before the L2 part of the proposal reaches L2, which [ANCHORLESS.md section 8](ANCHORLESS.md#upgrade-order) requires.
4. **EtnaInbox.** The proxy is upgraded to an implementation whose immutables include `originWriter`, `unzenInbox` (the Unzen Inbox address) and `ETNA_FORK_TIME` (SPEC PARAM-11-12a). It is then initialized with every parameter of START-10-5. Initialization does not write the start.
5. **EtnaInbox verifier.** The EtnaInbox uses its own `ZkRequiredVerifier` instance, which trusts only the Etna guest images. Trusting the Etna images therefore does not widen what the Unzen Inbox accepts.

L2 action:

6. **One L2 message** to the `DelegateController` upgrades the `Anchor` and the L2 `SignalService` to `SignalServiceL2`, with `etnaTimestamp = ETNA_FORK_TIME` ([ANCHORLESS.md section 8](ANCHORLESS.md#upgrade-order), step 3).

Once the proposal executes, `ETNA_FORK_TIME` is fixed in the Unzen Inbox, the EtnaInbox and the `Anchor`; [section 7](#7-failure-handling) covers moving it.

**Choosing `PROPOSE_MARGIN`.** It must make every block derivable from an accepted proposal earlier than `ETNA_FORK_TIME`.

- Blocks from a proposal's normal source have timestamps at or below the proposal's L1 timestamp.
- Forced-inclusion blocks and default blocks take the parent's timestamp plus one second ([Derivation.md](../Derivation.md#timestamp-validation)). There are at most 11 of them per proposal: up to 10 forced inclusions plus one default block.
- The Unzen Inbox accepts at most one proposal per L1 block. With L1 slots of at least 12 s, a proposal at time p therefore yields no block later than p + 11 s, and `PROPOSE_MARGIN = 12 s` suffices.

Shorter L1 slots need a larger margin, computed from the same bound. The originWriter's check in [section 4](#4-switch-day), step 4, backs this up.

**Choosing `FI_MARGIN`.** `FI_MARGIN = PROPOSE_MARGIN + forcedInclusionDelay + buffer`, where the buffer is at least the longest expected gap between Unzen proposals. Every forced inclusion the Unzen Inbox accepts is then due before the propose cutoff. Each proposal must take the due entries, up to 10 per proposal, so the queue drains before the cutoff.

## 4. Switch day

1. **Preconfirmers, before the propose cutoff.** Stop preconfirming and propose every preconfirmed block. Transactions that are only in preconfirmed blocks not proposed by the cutoff are dropped, so announce the cutoff in advance.
2. **The cutoff.** At `ETNA_FORK_TIME − PROPOSE_MARGIN` the Unzen Inbox stops accepting proposals. The last block of the last proposal is S.
3. **Everyone: wait for L1.** Wait until the first L1 block with timestamp at or after `ETNA_FORK_TIME` is finalized. From then on no L1 reorg can add or remove an Unzen proposal, so S is fixed. Waiting only for the block that holds the last proposal is not enough, because later blocks before `ETNA_FORK_TIME` could still be reorganized to include another proposal.
4. **originWriter signers and node operators: check S.** Derive S from finalized L1 on independent nodes. Check that S's timestamp is below `ETNA_FORK_TIME`, and that S's hash and stateRoot agree across the nodes. If S's timestamp is not below `ETNA_FORK_TIME`, do not call `setOrigin` ([section 7](#7-failure-handling)).
5. **originWriter: call `setOrigin(S, hash, stateRoot)`** (SPEC START-10-5a).
   - It writes the Etna start and opens forced inclusion on the EtnaInbox (START-10-5b).
   - It does not write the SignalService (START-10-5c).
   - Its L1 block is R₀.
6. **Node operators: start Etna once R₀ is finalized.**
   - Generate CometBFT genesis per START-10-20: `initial_height = S + 1`, `genesis_time = R₀.timestamp`, `app_hash` = S's hash and the validators of committee 0.
   - Start the execution layer, the ABCI application, the signer and CometBFT (START-10-6).
   - Before a node trusts the chain and signs, it checks that S is the last block of the Unzen chain it derives itself (SYNC-9-5a).
7. **Unzen provers: finish proving through S.** The `prove` call that finalizes the last Unzen proposal saves the checkpoint at S in the L1 SignalService.
8. **Landers: land from S.** The first landing, with proof origin S, succeeds once step 7 has landed ([section 5](#5-the-first-landing)).

## 5. The first landing

While the latest checkpoint is still S, `land` additionally requires three things before it verifies any proof (SPEC LAND-6.1-8a):

1. the Unzen Inbox has finalized every proposal it accepted;
2. the Unzen Inbox's last finalized block hash equals the hash the originWriter wrote for S;
3. the L1 SignalService holds a checkpoint at S with that hash and the stateRoot the originWriter wrote.

The three together prove that the originWriter wrote Unzen's last block.

- `setOrigin` only runs after `ETNA_FORK_TIME`, and the Unzen Inbox accepts no proposal after the propose cutoff, so by the time of any landing the set of Unzen proposals is closed.
- Conditions 1 and 2 make the written block the end of the last Unzen proposal, not some earlier block that happens to have a checkpoint.
- Condition 3 ties the written height and stateRoot to the block Unzen's own proof settled.

A wrong value therefore never passes. Honest nodes also refuse it before signing (SYNC-9-5a). The originWriter can delay or stop Etna, but cannot make L1 accept a forged state.

Block production does not wait for this check. Etna produces up to U blocks beyond its latest checkpoint, which is S until the first landing, and then pauses on back-pressure ([SPEC.md 6.4](SPEC.md#64-back-pressure)) until a landing succeeds; no block is lost. Until the first landing succeeds, two things wait for it: L2 → L1 withdrawals from Etna blocks, and registry exit confirmations.

## 6. Bridge during and after the switch

- **L2 → L1.** The L1 Bridge verifies messages against SignalService checkpoints indexed by L2 block number, and it does not change.
  - Checkpoints at or below S come from the Unzen Inbox, including those its final proofs save after Etna has started.
  - Checkpoints above S come from the EtnaInbox.
  - Neither overwrites the other: the Unzen Inbox accepts no proposal after the cutoff, so it never writes above S, and the EtnaInbox lands only above S.
- **L1 → L2.** This follows the anchorless design ([ANCHORLESS.md section 4](ANCHORLESS.md#4-bridge-verification) and [section 8](ANCHORLESS.md#8-fork-and-migration)). From the first Etna block on, the L2 SignalService verifies proofs against the EIP-4788 roots of Etna anchors. A message sent on L1 before the cutoff and not yet processed on L2 is proven against an Etna block's root, whose anchor is at or after R₀. A proof built before the switch must be rebuilt.
- **Unchanged.** The Bridge, the vaults and the QuotaManager do not change.

## 7. Failure handling

| Situation                                                         | Effect                                                                                                                       | Response                                                                                                                                                    |
| ----------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| The originWriter writes a wrong (S, hash, stateRoot)              | Honest nodes refuse the start and produce nothing (SYNC-9-5a); any landing on it reverts (LAND-6.1-8a); funds are unaffected | The start is written once, so a DAO upgrade of the EtnaInbox must rewrite it; the outage then includes the DAO authorization delay (SPEC section 12 item 9) |
| The originWriter does not act                                     | The outage grows                                                                                                             | Keep the signers on call for the switch and rehearse the procedure ([section 9](#9-rehearsal))                                                              |
| L1 reorganizes blocks before `ETNA_FORK_TIME`                     | No effect                                                                                                                    | The originWriter waits until the first L1 block at or after `ETNA_FORK_TIME` is finalized                                                                   |
| An Unzen block has a timestamp at or after `ETNA_FORK_TIME`       | Its `anchorV4` hits the `Anchor`'s gate and the execution layer applies Etna rules to it, so Unzen cannot derive or prove it | Do not call `setOrigin`; the switch stops until the DAO acts. A `PROPOSE_MARGIN` sized by [section 3](#3-the-dao-proposal) prevents this                    |
| Unzen's final proof is slow                                       | Etna produces up to U blocks, then pauses on back-pressure without losing blocks                                             | Production resumes when the proof lands and the first landing succeeds                                                                                      |
| Forced inclusions remain in the Unzen Inbox's queue at the cutoff | They are never derived; their fees stay in the Unzen Inbox                                                                   | `FI_MARGIN` makes this unlikely; users resubmit to the EtnaInbox                                                                                            |
| Preconfirmed blocks were not proposed by the cutoff               | Their transactions are dropped                                                                                               | Announce the cutoff; preconfirmers propose everything first ([section 4](#4-switch-day), step 1)                                                            |
| Etna's committee cannot start                                     | Unzen stays stopped; there is no automatic return to Unzen                                                                   | DAO action: governance recovery ([SPEC.md section 8](SPEC.md#8-halts-and-recovery)) or an upgrade                                                           |
| A verifier-failure rollback happens before the first landing      | The EtnaInbox returns to the values the start write recorded                                                                 | The Unzen Inbox's checkpoints at or below S are kept (SPEC RECOV-8-27, RECOV-8-28)                                                                          |
| `ETNA_FORK_TIME` must move                                        | It is fixed in the Unzen Inbox, the EtnaInbox and the `Anchor`                                                               | DAO upgrades of all three, executed before the old propose cutoff                                                                                           |

## 8. Afterwards

- **Unzen Inbox.** It stays deployed, so bonds can be withdrawn and its final proofs can land.
- **SignalService.** A later upgrade may remove the Unzen Inbox from the SignalService's syncers once Unzen's last checkpoint is saved. It must keep `VERSION` unchanged.
- **Anchor.** Clean-up follows [ANCHORLESS.md section 8](ANCHORLESS.md#upgrade-order), step 6.

## 9. Rehearsal

Run the whole procedure on a devnet that runs Unzen, then on Hoodi, before mainnet. Section 6 of [ACCEPTANCE.md](ACCEPTANCE.md) lists what the rehearsal must show.
