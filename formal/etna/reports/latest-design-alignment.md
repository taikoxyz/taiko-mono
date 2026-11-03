# Latest Etna design alignment

Authority: main `1135c9b24fd03f50cb48eab250879435fd54f528`, including SPEC, ACCEPTANCE,
ANCHORLESS and SWITCH. The protocol documents themselves are unchanged by this update.
This report records design evidence, not production or launch sign-off.

## What changed

The previous model had a height-scoped conditional upgrade sketch, reusable slot IDs,
zero-based landing grids and no Unzen switch. Current `Etna.Design.Current` definitions
cover selected replacement rules. Original definitions and exact theorem contracts remain
historical, with independently hashed archived authorities. No current source is matched
to an old clause by fuzzy similarity or line number.

| Current obligation                    | Exact evidence                                                                                | Scope                                                                                                                                                                                                                                                                                                                                                 |
| ------------------------------------- | --------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Timestamp rules and strict deadlines  | `Rules.schedule_rules_result`, `rules_require_owner`, `preserves_visible_window`              | A successful schedule call preserves selection for timestamps in [now, now+maxAnchorAge); this is a local visibility lemma, not the whole canonical-history consistency proof.                                                                                                                                                                        |
| Stop and recovery rules               | `Rules.schedule_stop_result`, `stop_requires_owner`, `recover_clears_stop`                    | Decoded owner/initialization, 48-bit fields and grid checks; nonzero recovery rules must equal nextRules+1. Structural upgrades still require the full governance recovery outside this focused schedule model.                                                                                                                                       |
| Cross-ruleset proof batches           | `Rules.covered_batch_keeps_every_ruleset`                                                     | Induction covers every timestamp in the batch; no historical noCrossing restriction. Actual image declarations, dual-verifier soundness and canonical anchor authentication remain external.                                                                                                                                                          |
| Field bounds through schedule history | `Rules.trace_fields_fit`                                                                      | Induction over successful scheduleRules/scheduleStop calls, from fitting initial fields. Recovery is a separate checked operation.                                                                                                                                                                                                                    |
| Permanent bond issuance               | `Registry.registration_issues_fresh`, `trace_issuance_monotone`                               | Lifetime IDs increase; 4096 bounds slots, not total issued bonds. The generic modify operation is plumbing, not an arbitrary public registry endpoint.                                                                                                                                                                                                |
| Permanent key registration            | `Registry.registration_retains_keys`, `trace_keys_permanent`                                  | Present bond 0 differs from absence. Every lookup already present is retained through the modeled trace.                                                                                                                                                                                                                                              |
| Displacement and withdrawal           | `Registry.displacement_keeps_old_bond`, `withdrawal_identity`, `withdrawal_preserves_counter` | Old owner/key/effective and pending principal remain on displacement; withdrawal preserves issued/key/exit identity. Examples check confirmation without an origin record, slashing while slotless and withdrawal without erasing the replacement. Full token custody, forfeiture transitions and current checkpoint-tree derivation remain unproved. |
| Unissued IDs                          | `Registry.unissued_modify_rejected`, `unissued_withdraw_rejected`                             | Default storage cannot authenticate an unissued ID, including a recovery exclusion.                                                                                                                                                                                                                                                                   |
| Start and landing fence               | `Start.grid_offset`, `first_landing_fenced`, `origin_written_once`                            | Explicit height≥S prevents truncated subtraction accepting pre-S heights. Unzen final proposal count, final block hash and SignalService hash/root must all match for the first landing.                                                                                                                                                              |
| Corrected start                       | `Start.correction_new_generation`, `trace_generations_monotone`, `trace_origins_retained`     | Only at the refused start before landing; a new generation is created and old origin records are retained. Replacement-state authentication and the complete DAO recovery transition remain external.                                                                                                                                                 |
| Imported data and signer state        | `Import.invalid_data_rejected`, `authenticated_conflict_halts`, `publish_boundary`            | Bad unauthenticated input rejects; authenticated conflicting EL hashes halt even when material is missing. Publication requires durability, preserves the entire signer and grants no trust. The complete header-number range is constructed; actual header contents, EL indexes and stock metadata stores require adapter refinement.                |

All short theorem names in the table are under `Etna.Design.Current`.
Supporting results are not promoted into induction-derived general claims. The current
rule map narrows shared clauses to the exact rule IDs supported by the six properties.
It reports 4 partial and 562 deferred clauses across the four current documents.

## Executable evidence

`tests/CurrentDesign.lean` exercises timestamp equality, strict rescheduling deadlines,
stop cancellation (including an unstored sum above the 48-bit field range), rules-number recovery, crossing batches, S-offset grids versus absolute
epochs, first-generation anchors, bond/slot zero, pending-value admission and tie breaking,
full-slot displacement, slotless slashing/confirmation/withdrawal, permanent withdrawn
identity, unissued default storage, origin writes/corrections and import failure priority.

The 23 semantic mutants in `test_current_mutations.py` must first compile silently as
Model-only sources; unchanged proofs and examples must then fail semantically. Source-pin
mutations cover all seven independent authorities. Separate tests reject historical proof
edges in current coverage and claims silently relabelled between authorities.

## Design review outcome

No confirmed new defect was found in the reviewed current design. The independent review
checked timestamp-schedule visibility, cancellation/promotion, cross-ruleset batches,
planned-stop/K alignment, displaced-bond liability, authenticated import boundaries and
the Unzen first-landing fence. Differences from the previous model are corrected or
explicitly scoped as historical; they are not reported as new protocol defects.

Current-spec limitations remain: DAO/validator upgrade availability, governance recovery's
unsettled suffix loss, operational consensus archive availability, decoder/crypto/EL/Comet
implementation refinement, and deployment/switch resource measurements. Complete current
H1–H3 composition has not been established. The full current bond lifecycle, authenticated
schedule history, and stock import implementation cannot be inferred from these local
models or from the archived headline proofs.

## Validation on final sources

All 406 Python tests passed, including the 23 current semantic mutants. Source lint,
the five-library import graph, `lake build`, all eight historical JSON vector files'
freshness, deterministic generated artifacts, all seven authority pins and the current
rule report passed. The exact-type/role/axiom audit and fresh kernel replay passed for
1,243 theorem contracts; all 22 Lean regression modules replayed without diagnostics.
The audit recorded 254 property derivation chains. Every original theorem/type pair and
all seven historical headline premise-field uses remain intact. `git diff --check` passed.
