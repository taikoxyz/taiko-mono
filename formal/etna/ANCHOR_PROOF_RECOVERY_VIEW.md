# Anchor, proof and recovery state view

The public configs use StateView = ⟨s, cursor, SafetyBits, ObservationBits⟩. The restricted Micro graph offers each transaction input in both inclusion slots and lets the tracked node learn, compare, replay or work on a local proposal independently. Main, Twin and POnly run bounded external scripts. Main chooses its immutable script at initialization. No fairness condition is assumed.

**Transition correspondence.** Equal views agree on the entirety of s and cursor. These determine which offers are available, including every slot argument in Micro and the next consumed input in a larger script. For a common offer, Dispatch reads precisely s and that input. Take constructs the next receipt from the same predecessor s, fresh input and actual operation return. It never consults the previous receipt. The resulting complete successors, including their raw receipts, are equal. Spec also permits stuttering.

**First failures and reach observations.** The view retains the truth of each public safety predicate and each public negated witness. A path with a first failure has an initial representative with identical predicate truth. At every ordinary step a representative can take the same input and reaches the same full successor. Stuttering preserves all bits. Consequently view equality neither discards a first false predicate nor identifies false and true occurrences of a named witness. A private probe which distinguishes receipts differently must include its own truth bit in its own view. A predicate on s alone is already retained. Raw traces use the original variables. Histories preserve input/outcome rows even when inclusion leaves storage unchanged. Script identity, local trust, candidates, jobs and branch-local history identities remain operative state.

**Bounds.** The alphabet fixes certified payload bytes and four fully participating unit-power members per named set. Names represent disjoint valid key lists. The model uses symbolic header identities, commit evidence and ordered statement preimages. The contract's local gate is session-level admission/status. Certified replay can continue while pending. A gate probe records status without sending a Comet refusal. Off-chain STF/QC/guest soundness, owner authority, last-provable prefix audit, outage and new-session bootstrap have the premises in the source contract. The finite graph covers neither deployment nor general protocol outcomes.

The latest own view and the comparison pin are separate node fields. At unchanged generation and checkpoint, advancing own finality retains the pinned 285 read. Local EL contradictions against the independently observed 270/271 value close trust before any 285 lookup. The later pinned read checks both EL and Comet. Fabricated read responses exercise that interface only. Origin rebuild has an independent symbolic archive response, explicit state/origin/genesis/session authentication and checks against lastCheckpoint and SignalService before trust reopens. Record root and ledger fields denote saved ghost projections of EL identity. The fixed slot 285 storage words do not contain either field. Ordinary storage-read roles in this finite alphabet are restricted to the actual selected reference root. Every covered header supplies both current and next membership.

**Interpretation across the two Main scripts.** The retained s.script
separates two components, each with its own jobs and interpretation of
dependent opaque atoms. A consistent injection through state, receipt,
offers and constants preserves equality, membership and the numeric tests
at every step in that component. The same first-failure argument therefore
applies after renaming. The two components supply no transition that imports
a proof from the other history.
[Dependency closure and finite lifting](anchor_proof/MAIN_IDENTITIES.md).
