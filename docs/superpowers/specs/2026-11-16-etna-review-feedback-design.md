# Etna PR feedback repair: fresh recovery candidate

The user authorized fixing confirmed PR22387 feedback before further verification
work, hourly review checks, and subsequent batches of three. This repair precedes
the next batch. Baseline head is `4c8b96c93c54256770c17a5d9789634471e52091`.

## Confirmed defect

PR comment6914854296 identifies a first-block fixture with recovery origin12/time3
but candidate parent12/time3 and candidate time4. Independent replay reproduces
this on the three stop profiles and original HandoffRecovery profile. The existing
assertions pass; a separately supplied first-block/parent-metadata oracle fails.
This is a verification-model defect, not a confirmed production protocol defect.

Pinned SPEC RECOV-8.4-7/10 fixes the first block's BFT time to recovery genesis
time. CONS-3.2-3 separately defines EL time as max(parent+1, BFT time, anchor time).
For the explicit bounded retained-parent12/time1, recovery3 and anchor3 premise,
the valid fresh candidate time is3. Do not generalize that concrete equality to
all possible EL parent histories.

## Repair

Retain an explicit immutable operational seed for the settled parent's own
metadata12/time1. Construct the first new-generation candidate from that parent
and the recovery-origin timestamp, with a valid recovery-generation anchor.
Do not substitute the held suffix parent18/13 or retimestamp the settled parent.

Capture a separate observation-only audit from accepted raw recovery inputs and
history audit. Strengthen FreshIdentity to bind the complete fresh candidate's
parent height/time, first-block timestamp, generation and exact recovery anchor.
The audit must not call the operational constructor or become an enabling guard.
Keep all existing339 configurations byte-identical; their existing FreshIdentity
binding should enforce the stronger oracle. Public M11 actions/exporters, actual
contracts and the original proof premises are outside this repair.

Require old-source RED evidence and source-only faults for candidate time now+1,
retained parent time2 (still below candidate3), and parent height18. Each fault
must be detected at the intended oracle, with valid normal/restored phases.
Add these three assessed faults to compatible sensitivity cohorts without
loosening exact outcome or Forge test-set checks. Independent review and behavior
verification precede commit/push. Maximum two material review/fix waves.

## Publication and limits

Keep the existing draft PR and branch. The user authorizes verified repair
commits and pushes, without merge, ready conversion, deployment, production or
normative edits. Historical passing counts at the baseline are not fresh results
for the repaired model. Reuse existing pinned tools and the single shared cache;
no new environment/dependencies. Actual client/Comet/EL/proving and unbounded
refinement remain outside this repair.
