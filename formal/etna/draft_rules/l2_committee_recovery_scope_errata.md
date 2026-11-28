# Independent oracle correction and scope qualification, v3

The independent source reviewer found a second verification/oracle defect before
full engine execution: v2 allowed a true no-code call at the fixed staking proxy
while assuming two successful Forfeit calls to that same proxy in that block.
Without code/repair, those successful forfeitures cannot follow. The supplement
also assumed code could reappear at the next block without modeling any repair.
This is an oracle/model abstraction defect, not a protocol finding.

The root accepted removing true NoCode from the selected operational alphabet.
StaleSnapshot now uses Revert, with staking proxy code present throughout the
selected graph. A reverting onBlockStart does not imply ordinary entrypoints
have no code. True no-code's single-step empty-effect semantics remain a source
fact, but code absence/replacement/repair is OPEN and has no positive-history
credit in this selected product.

## Preserved evidence

The prior files remain byte-identical and are not overwritten:

* contract.md: e886214d7948e31dfb5a78859f534a7d0a8922d66e78e996529317b565369e59
* oracle.json: 7cabb4cdbe98e4c4bdcfe54a01e934405ed34e6d7bf8a4d3c0d097ed0668082d
* contract-v2.md: e80490b7b8e0f550a43c4e6bfc90ac066ce3a2d54ddb0df916bd764a29ec0702
* oracle-v2.json: ab05734800dd4bc8faa47bdc1813f5c44dc0b46c8278e498254c04170c125880
* ERRATA-v2.md: 2a43c8d8b040fc1409f10f3bd0af1a6dd70942fff6ded06819aea74e8e0fee87

## Exact correction boundary

The ten literal main commits, their raw ledgers/snapshots, current/next/pending
assignments, validator updates, certificates, c13 rollback and M=3Q initial
parameter remain unchanged. No main-history expected value is recalculated.

The v2 supplement named stale_or_no_code_delays_candidate_one_more_height is
replaced by revert_stale_snapshot_delays_candidate_one_more_height. Its h16
call-outcome list now contains revert_or_exception only. All numeric snapshots,
sets and delay outputs in that supplement remain the same: h16 retains h15's
CD snapshot, selects fallback for h18, h17's fresh snapshot selects CD for h19.

The v2 first_recovery_call_no_code_keeps_old_generation_store supplement is
withdrawn in full. In particular, ordinary_forfeits_still_execute=true in a
true no-code block and the assumed successful onBlockStart at the next block
receive no current credit. The withdrawn claim is retained in the unchanged
v2 file and described as an OPEN future problem in the v3 JSON note.

The selected graph now explicitly states two pre-existing abstraction limits:
each committed block adopts the latest finalized modeled threshold/fallback/
landing (no anchor-lag graph is explored); no temporal fairness, leads-to or
liveness property is actually checked. The stage concerns safety plus selected
finite conditional-witness existence. These statements narrow claim scope;
they do not silently add new transitions or change the main expected histories.

No model, oracle program, test, TLC, Go or other target execution occurred in
this correction. Hash/diff/readback checks concern the static artifacts only.
The original independent source finder owns the v3 re-check before execution.

The first v3 draft's status incorrectly retained 'frozen-before-model-authoring'.
That provenance wording was corrected before canonical acceptance: core main
histories retain their pre-authoring v2 hash, while supplemental corrections
are explicitly after static review and before full model execution. The two
pre-provenance draft artifacts are preserved as contract-v3-pre-provenance.md
(354f7a0ebf496f66572a2f56af04146cbb69b46a95df1d247e2d03bcdeb055cc)
and oracle-v3-pre-provenance.json
(9ec207d1478b7ee23179ee9efea7f6007906899edab299da8f7102a3e4154c2e).
