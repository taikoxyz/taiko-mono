# CS-R3-01: do not retire signing history on a young L1 recovery

**[assumed: review record; open: A/J acceptance]** This is B's repair of A's Medium [CS-R3-01 finding](https://github.com/taikoxyz/taiko-mono/pull/22191#issuecomment-5982725987), against accepted D90 head `55bef135e00b9b2861375a625a88d496cf9f1a83`. It is not a new red-team round, a merge decision or a readiness verdict. [J's judgment](https://github.com/taikoxyz/taiko-mono/pull/22191#issuecomment-5982904786), [accepted by A](https://github.com/taikoxyz/taiko-mono/pull/22191#issuecomment-5982907176), credits round 3 as the first of two qualifying rounds under D44 item 5: its eight standing findings are Medium/Low, with no new Critical/High. All eight still require their recorded dispositions. The other seven belong to A and are reviewed separately in #22250.

## Attack and scope

**[proven: specification trace at the stated head]** S2-R15 said, “Only observing a landed replacement or hatch resets the local lock to that landed end and retires each displaced original generation’s prior attestation and H/F-voting state”; R06 makes that retirement persistent. R09's canonical-age test applied to the following vote, leaving these earlier signing-state mutations unguarded.

1. **[assumed: preconditions]** An honest key has certificate lock A120 in generation X. A qualifying recovery lands incompatible B110 in L1 block N. Heights are illustrative PH identities, not protocol constants.
2. The node observes N at canonical-head age 12 seconds, below the existing 48-second ANCHOR_MIN_AGE, and applies the old immediate RESET. X becomes persistently retired and its usable lock is replaced.
3. A shallow reorg removes N before it is old enough. This schedule respects A-T1's assumption that aged blocks survive.
4. The original X survives on L1, but R06 still bars its attestation/H/F signing. A RESUME referring to N fails R09. The resulting local signing loss can delay or remove the quorum needed for recovery.

**[assumed: attacker model]** The attacker needs an eligible recovery transaction and a shallow L1 reorg, or can exploit a naturally occurring one. Cost is the recovery/proving/gas cost plus any L1 influence needed for the chosen reorg schedule; no numeric cost is measured or claimed. Gain is degradation of honest signing capacity. This challenges the R3 role-failure/liveness story, and R4/R7 service continuity; it does not establish custody theft or an unconditional economic profit. Medium is A's assigned severity, not a new severity ruling by B.

**[proven: related bypass]** Delaying only the explicit RESET or RESUME vote is insufficient: R04 also persists a timeout as a bar on old-opening attestation. A recovery-dependent RESUME timeout must therefore wait for the same transition. Rolling back an in-memory lock cannot retract any already broadcast signature.

## Repair and adversarial checks

**[assumed: proposed mechanism]** The rule is defined once in [S2-R15](../spec/S2-certificates-and-handoff.md#s2-r15-replace-resume-lock-reset-and-landing-binding). R06, R07, the lifecycle diagram and the vectors consume it. It uses R09's existing canonical-age requirement, with age calculated from one authenticated canonical head's timestamp. It changes local signing-state admission; C2/C3 still accept and apply an eligible L1 landing at execution time.

| Schedule | Required result and owner |
|---|---|
| Recovery disappears before maturity; wall-clock age exceeds canonical-head age; malformed/failed/ordinary operation is offered as a recovery | No recovery-dependent signing-state mutation or RESUME timeout/vote. R09/R15, V48. |
| Age is just below, then exactly at the existing threshold | Wait, then apply the authenticated transition once, preserving evidence. V48's sample ages are illustrative; the threshold comes from S2's parameter register. |
| Two notifications arrive out of order, an older landing is replayed, or a process/L2 restart restores the client | Consume complete mature canonical history in order using a durable local cursor; no replay of consumed recovery. R15, V49. |
| A later ordinary landing in the same block advances the tip; another later block contains a young recovery | Use authenticated end-of-trigger-block state, including same-block operations. Do not substitute unrestricted latest state or require the old end to remain the current tip. V49. |
| A compatible higher certificate already exists; a formerly displaced X had signed an incompatible branch | Preserve the compatible certificate and live generation's guards, but never clear X's retirement or old signatures/timeouts/votes. V49. |
| Recovery and C4 CONFLICT restart occur in the same L1 block | No ordinary reset inferred across restart contexts. Hold normal signing under C4's separate successor gate; that identity/regime remains open. V49. |
| A reorg removes an already aged, processed recovery | Outside A-T1; stop inconsistent signing and preserve records. No automatic signature rollback or unretirement is specified. V49. |

**[proven: conditional repair argument]** Under A-T1, A-L1VIEW, authenticated complete replay/PH ancestry and durable signing protection, the first trace changes only a pending observation, which can be discarded. Applied recovery effects refer to a canonical block protected by A-T1. Once-only processing prevents a delayed notification from undoing a later transition; exact ancestry preserves newer compatible locks without erasing older retired scopes. The RESUME-timeout gate closes the indirect R04 bar. These are specification arguments, not executed implementation tests.

**[open: costs and downstream integration]** Complete recovery-history verification and replay throughput are unmeasured. The cursor is local signing-protection data, not a new L1 storage slot, ABI field, message field, role or timeout. C2-R06/C3-R09/S4's descriptions of local recovery must cite R15 without delaying their L1 writes; A owns those projections. C8's client/persistence fixtures must include V48/V49. Age maturity alone does not supply the quorum, historical data, opening chain or bounded landable prefix. S2-V43, C4's successor regime, exact bytes and measurements remain open.

## Alternatives and review record

**[assumed: rejected alternatives]** Reversible retirement would require undoing already broadcast signing actions, so it is not adopted. A new reset-specific timer would duplicate R09's reference-age assumption. Checking only current LastLanded would miss an older qualifying recovery followed by an ordinary descendant; reading latest RPC state would instead import young recovery state. An “event seen” flag lacks successful-execution, ancestry and canonical-context authentication. Each is rejected for its stated schedule, without changing the accepted D1 publication or adopting Rule G or RPT.

**[assumed: independent review record]** B used two read-only delegated reviews of the S2 draft: one checked timeout, ordered replay and restart boundaries; the other independently attacked compatible newer certificates versus permanent old-generation retirement, replayed prefix consumption and same-block C4 restart. Both returned APPROVE with no surviving finding against the inspected draft. Their agent names were `a22246_history` and its `s2_sl2_review` reviewer; both inherited this session's model, with no override requested or made. This focused verification is not counted as a different-model red-team round and does not substitute for A/J review.

**[open: release status]** The course labels CS-R3-01 and this repair as pending, while its current status records the accepted 1-of-2 round count. Acceptance and the ensuing operative teaching update belong to the convergence process. No arbiter-owned WORK status or decision row is changed.
