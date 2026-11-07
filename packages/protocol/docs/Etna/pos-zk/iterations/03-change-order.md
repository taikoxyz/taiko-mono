# Change order 03 — remove forced inclusion; fix R2A-01 and the statement-interface Highs

Frozen base: `f67458b45`. Target: a new frozen snapshot for **review round 3**, then round 4, aiming at
the project's convergence rule (two consecutive full-design rounds with no new Critical or High).

## 1. Forced inclusion is removed (user decision D-6)

Remove, everywhere, all of: FI-01 … FI-05 as rules; the L1 request queue, its fee, its escrow, its
state and its events; the inclusion duty as a proposal-validity condition; the
`forcedInclusionCommitment` public input and its guest check; the forced-inclusion payload list in the
journal; forced-inclusion parameters; the censorship/omission offence; the escape hatch; and every
cross-reference to them. Where a rule formerly depended on forced inclusion, replace the dependency
with the honest substitute and keep the rule otherwise intact.

**The replacement text, to be used consistently:**

> The protocol provides no per-transaction inclusion guarantee and no L1 forced-inclusion path.
> Censorship resistance is the conditional statistical property described in `LIVE-04`: proposer
> selection is hash-based and weighted (CONS-06), so a coalition with less than one third of the voting
> power is selected for strictly fewer than one third of slots in expectation, and a transaction that
> reaches honest validators is included by the first honest proposer with room for it. Under A-CONS-2
> that is a real but conditional resistance. A network-level adversary able to isolate a user from every
> honest proposer can exclude that user's transactions indefinitely, and because a withdrawal is
> initiated by an L2 transaction, such an adversary can also prevent the user from starting a
> withdrawal. The protocol offers no remedy, and a partial relaxation of R10 is disclosed.

## 2. R2A-01 — epoch-lookahead gate (still open, must be fixed)

The set-root commitment for the next epoch must not depend on the Inbox's last accepted height, because
under D5 that lags production by the whole proving pipeline and stalls production at every boundary.
Fix: the L1 staking contract commits the set root for epoch `e + 2` during epoch `e` (**two-epoch
lookahead**), with the normative inequality
`2 * E_EPOCH >= T_PROOF_MAX_PERMITTED + T_SETTLE_PIPELINE + L1_FINALITY + margin`.
The Inbox and the L2 client read the entry for the epoch they need; a missing entry for a **future**
epoch is not a halt condition, and the halt condition applies only when the entry for the epoch being
entered is absent. Update CONS-13, MEM-09, the parameter table, and every sentence that says "one epoch
of lookahead".

## 3. Statement-interface Highs (round 2, proof angle)

- **P-R2-01**: the guest must decode the executed block bodies **from the committed payload** and check
  that each header's `transactions_root` matches the decoded transactions. The witness may not supply
  bodies independently of the committed bytes. State that this is what makes `dataCommitment` a binding
  rather than a claim.
- **P-R2-04**: define the byte-level framing of a batch payload (a single canonical serialisation with
  an explicit rule for length prefixes and field order), so that "the data the proof binds" is a
  function of the published bytes and RISC Zero and SP1 can implement one statement.
- **R2-LIV-05 / E-R2-02 residual**: one authoritative public-input vector with a field-by-field
  reconciliation; already partly done in `spec/04` §2.1 — verify and finish.
- **R2-LIV-07 / R2-LIV-08**: one cap, one unit. State the relation between the production-side cap and
  any post-acceptance retention window, or delete the second cap.
- **R2-LIV-09**: the throughput inequality must be strict (`>`), not `>=`, or a cap-induced halt never
  drains.

## 4. Everything else from round 2

Close or explicitly disposition every remaining round-2 finding in `iterations/03-round.md`.
