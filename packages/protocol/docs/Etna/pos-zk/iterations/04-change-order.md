# Change order 04 — Mode B selected, fee-funded security, treasury penalties, forced inclusion deferred

Base snapshot: `eaa01784c` (plus the course restyle `5111cd878`). Decisions: D-7, D-8, D-9, D-10 in `DECISIONS.md`.

## 1. Mode B becomes the selected recovery mode (D-7)

Rewrite `REC-02` from 'specified but not selected' to the **selected** design, keeping every element it
already lists and adding the missing ones: the objective trigger, who may invoke, the bond, the delay,
cancellation by honest progress, checkpoint and configuration boundaries, late certificates and proofs,
transaction replay, rollback depth, rollback duration, repeated-recovery limits (escalating bond and a
cooldown), and user exposure. Rewrite `REC-03` from 'blocker recorded' to the **required resistance
analysis**: quantify what it costs to induce the trigger, show that within the L2 fault model a
sub-threshold coalition cannot, state the conditions under which it could (L1-level censorship, absence
of any prover), and disclose what cannot be bounded (off-chain profit, platform-level censorship).
State explicitly that this analysis must be independently reviewed and what would falsify it.

Every artifact that describes the recovery mode must change from 'halt, never roll back' to the new
guarantee class: a PoS confirmation above the last accepted checkpoint is **provisional**.

## 2. Status labels change meaning (D-7)

`STATUS-04` becomes **PoS-certified / provisional** for all modes: the certificate is the same, the
guarantee is not. `STATUS-06` (accepted on L1) and above are unchanged and remain the first status a
user may rely on as irreversible. Add the disclosure obligation: any interface showing a confirmation
above the last accepted checkpoint must say it can be replaced.

## 3. The proof statement must carry the recovery authorization (D5, D-7)

The proof statement must bind the configuration under which the batch was certified and include any
recovery authorization, so that an alternative history can never be accepted on execution validity
alone. Add the journal fields and the guest check; state that a batch certified before a recovery is
void above the restored checkpoint but remains admissible as evidence.

## 4. Security funded from L2 fees (D-8)

Specify the path from the L2 fee vault to the L1 reward pool using the preserved Bridge, the sweep
cadence, who may sweep, the accounting identity, and the honest consequences: rewards lag the
settlement pipeline; an empty pool pays nothing; a bridging failure stops rewards. Remove the Open
marker that said the funding path was unspecified.

## 5. Treasury, not burn (D-9)

Set the penalty destination to the protocol treasury with a reporter bounty strictly below the total
penalty. Remove every 'burn' option from the specification and the course.

## 6. Forced inclusion deferred (D-10)

Add the planned-update clause: v1 has no forced-inclusion path, and the later upgrade that adds it must
preserve the D2, D5 and permissionlessness invariants listed there. Keep `FI-REMOVED-01` as the v1
statement and cross-reference the planned update.

## 7. Learning course

The course must teach the new guarantee class plainly: what a provisional confirmation means, when it
can be replaced, who can trigger recovery and what it costs them, what happens to a user's transactions
when history is rolled back, and why the design chose an outage-free rollback over an unbounded halt.
Remove nothing else; keep the light theme, the single left navigation and the simple formats.