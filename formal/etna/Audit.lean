import Etna.Common.Words
import Etna.FI.Examples
import Etna.FI.Proofs
import Etna.Refinement.Rust.EtnaConsensusCore
import Etna.Refinement.Rust.Forced
import Lean
set_option pp.universes false
set_option pp.explicit true
set_option pp.fullNames true
-- FI-01; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.fi01_due
  unless info.isTheorem do throwError "Etna.FI.fi01_due is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (timestamp delay anchor : Etna.Word64), Etna.FI.isDue timestamp.val delay.val anchor.val = true ↔ timestamp.val + delay.val ≤ anchor.val))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.fi01_due: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.fi01_due
-- FI-fi01-sum-bound; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.fi01_sum_bound
  unless info.isTheorem do throwError "Etna.FI.fi01_sum_bound is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (timestamp delay : Etna.Word64), timestamp.val + delay.val < 2^128))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.fi01_sum_bound: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.fi01_sum_bound
-- FI-02; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.fi02_pending
  unless info.isTheorem do throwError "Etna.FI.fi02_pending is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (cursor tail : Nat) (witness : Option Nat), Etna.FI.pending cursor tail witness = .ok true ↔ cursor < tail ∧ witness = some cursor))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.fi02_pending: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.fi02_pending
-- FI-fi02-authenticated; explicit assumptions: ["Authentication.sound: verified root/inbox/exact ordered slots bind stored entry; ContextEvidence binds anchor root/time/tail where required"]
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.fi02_authenticated
  unless info.isTheorem do throwError "Etna.FI.fi02_authenticated is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (a : Etna.FI.Authentication) (c : Etna.FI.Context) (w : Etna.FI.Witness)
    (context : Etna.FI.ContextEvidence a c)
    (verified : a.verify c.stateRoot c.inbox (Etna.FI.entrySlots a.slot c.cursor.val)
      w.entry w.proof = true), a.storageEntry (a.committedRoot c.anchorHash) c.inbox
      (Etna.FI.entrySlots a.slot c.cursor.val) = some w.entry))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.fi02_authenticated: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.fi02_authenticated
-- FI-fi02-bad-proof-rejects; explicit assumptions: ["Authentication.sound: verified root/inbox/exact ordered slots bind stored entry; ContextEvidence binds anchor root/time/tail where required"]
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.fi02_bad_proof_rejects
  unless info.isTheorem do throwError "Etna.FI.fi02_bad_proof_rejects is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (a : Etna.FI.Authentication) (codec : Etna.FI.Codec) (c : Etna.FI.Context)
    (w : Etna.FI.Witness) (txs : List Etna.FI.Bytes) (pendingBound : c.cursor.val < c.tail.val)
    (index : w.index = c.cursor.val)
    (rejected : a.verify c.stateRoot c.inbox (Etna.FI.entrySlots a.slot c.cursor.val)
      w.entry w.proof = false), Etna.FI.evaluate a codec c (some w) txs = .error .malformed))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.fi02_bad_proof_rejects: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.fi02_bad_proof_rejects
-- FI-fi02-evaluate-authenticated; explicit assumptions: ["Authentication.sound: verified root/inbox/exact ordered slots bind stored entry; ContextEvidence binds anchor root/time/tail where required"]
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.fi02_evaluate_authenticated
  unless info.isTheorem do throwError "Etna.FI.fi02_evaluate_authenticated is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (a : Etna.FI.Authentication) (codec : Etna.FI.Codec) (c : Etna.FI.Context)
    (w : Etna.FI.Witness) (txs : List Etna.FI.Bytes) (pendingBound : c.cursor.val < c.tail.val)
    (index : w.index = c.cursor.val)
    (verified : a.verify c.stateRoot c.inbox (Etna.FI.entrySlots a.slot c.cursor.val)
      w.entry w.proof = true), Etna.FI.evaluate a codec c (some w) txs = Etna.FI.classify (Etna.FI.scalarFacts codec c w txs)))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.fi02_evaluate_authenticated: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.fi02_evaluate_authenticated
-- FI-03; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.fi03_included_iff
  unless info.isTheorem do throwError "Etna.FI.fi03_included_iff is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (f : Etna.FI.ForcedFacts)
    (prechecked : Etna.FI.checkPreimage f.preimageLen f.preimageHashMatches = .ok ()), Etna.FI.classify f = .ok (.included f.cursor) ↔ f.firstMatches = true))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.fi03_included_iff: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.fi03_included_iff
-- FI-fi03-head-binding; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.fi03_head_binding
  unless info.isTheorem do throwError "Etna.FI.fi03_head_binding is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (codec : Etna.FI.Codec) (entry : Etna.FI.Entry) (txs : List Etna.FI.Bytes), Etna.FI.firstMatches codec entry txs = true ↔
      ∃ head rest, txs = head :: rest ∧ head.length ≤ 8192 ∧
        codec.canonical head = true ∧ codec.hash head = entry.digest))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.fi03_head_binding: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.fi03_head_binding
-- FI-fi03-authenticated-inclusion; explicit assumptions: ["Authentication.sound: verified root/inbox/exact ordered slots bind stored entry; ContextEvidence binds anchor root/time/tail where required"]
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.fi03_authenticated_inclusion
  unless info.isTheorem do throwError "Etna.FI.fi03_authenticated_inclusion is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (a : Etna.FI.Authentication) (codec : Etna.FI.Codec) (c : Etna.FI.Context)
    (w : Etna.FI.Witness) (txs : List Etna.FI.Bytes) (context : Etna.FI.ContextEvidence a c)
    (pendingBound : c.cursor.val < c.tail.val) (index : w.index = c.cursor.val)
    (verified : a.verify c.stateRoot c.inbox (Etna.FI.entrySlots a.slot c.cursor.val)
      w.entry w.proof = true)
    (prechecked : Etna.FI.checkPreimage w.preimage.length (decide (codec.hash w.preimage = w.entry.digest)) = .ok ()), a.storageEntry (a.committedRoot c.anchorHash) c.inbox (Etna.FI.entrySlots a.slot c.cursor.val) = some w.entry ∧
    (Etna.FI.evaluate a codec c (some w) txs = .ok (.included c.cursor.val) ↔
      ∃ head rest, txs = head :: rest ∧ head.length ≤ 8192 ∧ codec.canonical head = true ∧
        codec.hash head = w.entry.digest)))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.fi03_authenticated_inclusion: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.fi03_authenticated_inclusion
-- FI-fi03-exact-bytes; explicit assumptions: ["Trace-local hash separation only for admitted and candidate bytes"]
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.fi03_exact_bytes
  unless info.isTheorem do throwError "Etna.FI.fi03_exact_bytes is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (codec : Etna.FI.Codec) (admitted candidate : Etna.FI.Bytes)
    (separated : Etna.FI.LocallySeparated codec.hash admitted candidate)
    (sameHash : codec.hash admitted = codec.hash candidate), admitted = candidate))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.fi03_exact_bytes: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.fi03_exact_bytes
-- FI-classify-branches; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.classify_branches
  unless info.isTheorem do throwError "Etna.FI.classify_branches is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (f : Etna.FI.ForcedFacts)
    (prechecked : Etna.FI.checkPreimage f.preimageLen f.preimageHashMatches = .ok ()), Etna.FI.classify f =
      if f.firstMatches then .ok (.included f.cursor)
      else if Etna.FI.isDue f.timestamp f.delay f.anchorTimestamp then
        if f.preimageHashMatches then
          if f.preimageCanonical then .ok (.needsSkip f.cursor)
          else .ok (.skippedInvalid f.cursor)
        else .error .hashMismatch
      else .ok .ordinary))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.classify_branches: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.classify_branches
-- FI-04; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.fi04_predue
  unless info.isTheorem do throwError "Etna.FI.fi04_predue is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (f : Etna.FI.ForcedFacts)
    (prechecked : Etna.FI.checkPreimage f.preimageLen f.preimageHashMatches = .ok ())
    (head : f.firstMatches = false)
    (early : f.anchorTimestamp < f.timestamp + f.delay), Etna.FI.classify f = .ok .ordinary))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.fi04_predue: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.fi04_predue
-- FI-05; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.fi05_due_skip
  unless info.isTheorem do throwError "Etna.FI.fi05_due_skip is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (f : Etna.FI.ForcedFacts)
    (prechecked : Etna.FI.checkPreimage f.preimageLen f.preimageHashMatches = .ok ())
    (head : f.firstMatches = false) (due : f.timestamp + f.delay ≤ f.anchorTimestamp)
    (hash : f.preimageHashMatches = true), Etna.FI.classify f = .ok (if f.preimageCanonical then .needsSkip f.cursor else .skippedInvalid f.cursor)))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.fi05_due_skip: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.fi05_due_skip
-- FI-06; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.fi06_resolve
  unless info.isTheorem do throwError "Etna.FI.fi06_resolve is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (index : Nat) (outcome : Etna.FI.SingletonOutcome), Etna.FI.resolve (.needsSkip index) outcome = .ok (some index) ↔ outcome = .completedEmpty))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.fi06_resolve: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.fi06_resolve
-- FI-fi06-completed-context; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.fi06_completed_context
  unless info.isTheorem do throwError "Etna.FI.fi06_completed_context is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (request : Etna.FI.BuildRequest) (response : Etna.FI.BuildResponse), Etna.FI.singletonOutcome request response = .completedEmpty ↔ response = .completed request []))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.fi06_completed_context: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.fi06_completed_context
-- FI-fi06-execution-evidence; explicit assumptions: ["Execution.sound: completed response binds actual request to validExecution; deterministic run for equal inputs"]
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.fi06_execution_evidence
  unless info.isTheorem do throwError "Etna.FI.fi06_execution_evidence is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (execution : Etna.FI.Execution) (c : Etna.FI.Context) (tx : Etna.FI.Bytes)
    (empty : Etna.FI.singletonOutcome (Etna.FI.singletonRequest c tx)
      (execution.run (Etna.FI.singletonRequest c tx)) = .completedEmpty), execution.validExecution ⟨c.parent, c.attributes, c.anchorHash, [tx]⟩ []))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.fi06_execution_evidence: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.fi06_execution_evidence
-- FI-fi07-advance; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.fi07_advance
  unless info.isTheorem do throwError "Etna.FI.fi07_advance is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (cursor : Etna.Word64) (tail : Etna.Word48) (pendingBound : cursor.val < tail.val), Etna.FI.advance cursor.val (some cursor.val) = .ok (cursor.val + 1) ∧ cursor.val + 1 < 2^64))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.fi07_advance: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.fi07_advance
-- FI-valid-step-count; explicit assumptions: ["Each trace step carries successful classify/resolve/advance evidence and authenticated 48-bit tail bound"]
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.valid_step_count
  unless info.isTheorem do throwError "Etna.FI.valid_step_count is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ {before after : Nat} {consumed : Option Nat}
    (step : Etna.FI.ValidStep before after consumed), after = before + (if consumed.isSome then 1 else 0)))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.valid_step_count: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.valid_step_count
-- FI-07; explicit assumptions: ["Each trace step carries successful classify/resolve/advance evidence and authenticated 48-bit tail bound"]
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.fi07_trace_count
  unless info.isTheorem do throwError "Etna.FI.fi07_trace_count is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ {before after : Nat} {steps : List (Option Nat)}
    (trace : Etna.FI.ValidTrace before steps after), after = before + Etna.FI.consumptionCount steps))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.fi07_trace_count: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.fi07_trace_count
-- FI-fi07-trace-bound; explicit assumptions: ["Each trace step carries successful classify/resolve/advance evidence and authenticated 48-bit tail bound"]
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.fi07_trace_bound
  unless info.isTheorem do throwError "Etna.FI.fi07_trace_bound is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ {before after : Nat} {steps : List (Option Nat)}
    (initial : before < 2^64) (trace : Etna.FI.ValidTrace before steps after), after < 2^64))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.fi07_trace_bound: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.fi07_trace_bound
-- FI-fi07-count-le-blocks; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.fi07_count_le_blocks
  unless info.isTheorem do throwError "Etna.FI.fi07_count_le_blocks is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (steps : List (Option Nat)), Etna.FI.consumptionCount steps ≤ steps.length))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.fi07_count_le_blocks: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.fi07_count_le_blocks
-- FI-fi07-consumed-index; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.fi07_consumed_index
  unless info.isTheorem do throwError "Etna.FI.fi07_consumed_index is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (f : Etna.FI.ForcedFacts) (d : Etna.FI.Decision) (o : Etna.FI.SingletonOutcome) (index : Nat)
    (classified : Etna.FI.classify f = .ok d) (resolved : Etna.FI.resolve d o = .ok (some index)), index = f.cursor))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.fi07_consumed_index: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.fi07_consumed_index
-- FI-08; explicit assumptions: ["Authentication.sound: verified root/inbox/exact ordered slots bind stored entry; ContextEvidence binds anchor root/time/tail where required", "Execution.sound: completed response binds actual request to validExecution; deterministic run for equal inputs", "Cached intermediate classification and singleton outcome agree with fresh deterministic facts; canonical envelope/context checked"]
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.fi08_success_equivalence
  unless info.isTheorem do throwError "Etna.FI.fi08_success_equivalence is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (a : Etna.FI.Authentication) (codec : Etna.FI.Codec) (execution : Etna.FI.Execution)
    (c : Etna.FI.Context) (w : Option Etna.FI.Witness) (txs : List Etna.FI.Bytes) (cache : Etna.FI.CacheEntry) (envelope : Etna.FI.Bytes)
    (usable : Etna.FI.cacheUsable cache c envelope = true)
    (evidence : Etna.FI.CacheEvidence a codec execution c w txs cache), Etna.FI.finalizeCached cache c envelope = Etna.FI.execute a codec execution c w txs))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.fi08_success_equivalence: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.fi08_success_equivalence
-- FI-fi08-commit-reopen; explicit assumptions: ["Authentication.sound: verified root/inbox/exact ordered slots bind stored entry; ContextEvidence binds anchor root/time/tail where required", "Execution.sound: completed response binds actual request to validExecution; deterministic run for equal inputs", "Cached intermediate classification and singleton outcome agree with fresh deterministic facts; canonical envelope/context checked", "Successful durable write/read roundtrip; no availability assumption"]
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.fi08_commit_reopen
  unless info.isTheorem do throwError "Etna.FI.fi08_commit_reopen is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ {Store : Type} (store : Etna.FI.DurableStore Store)
    (a : Etna.FI.Authentication) (codec : Etna.FI.Codec) (execution : Etna.FI.Execution)
    (c : Etna.FI.Context) (w : Option Etna.FI.Witness) (txs : List Etna.FI.Bytes) (cache : Etna.FI.CacheEntry) (envelope : Etna.FI.Bytes)
    (usable : Etna.FI.cacheUsable cache c envelope = true)
    (evidence : Etna.FI.CacheEvidence a codec execution c w txs cache)
    (beforeHot beforeCold afterHot afterCold : Store) (hotCursor coldCursor : Nat)
    (hotSuccess : Etna.FI.finalizeCached cache c envelope = .ok hotCursor)
    (coldSuccess : Etna.FI.execute a codec execution c w txs = .ok coldCursor)
    (hotCommitted : store.write beforeHot hotCursor = .ok afterHot)
    (coldCommitted : store.write beforeCold coldCursor = .ok afterCold), hotCursor = coldCursor ∧ store.reopen afterHot = store.reopen afterCold))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.fi08_commit_reopen: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.fi08_commit_reopen
-- FI-fi08-cache-context; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.fi08_cache_context
  unless info.isTheorem do throwError "Etna.FI.fi08_cache_context is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (cache : Etna.FI.CacheEntry) (c : Etna.FI.Context) (envelope : Etna.FI.Bytes), Etna.FI.cacheUsable cache c envelope = true ↔ cache.context = c ∧ cache.envelope = envelope))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.fi08_cache_context: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.fi08_cache_context
-- FI-09; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.fi09_no_expiry
  unless info.isTheorem do throwError "Etna.FI.fi09_no_expiry is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (f : Etna.FI.ForcedFacts) (later : Nat)
    (due : f.timestamp + f.delay ≤ f.anchorTimestamp)
    (stillDue : f.timestamp + f.delay ≤ later), Etna.FI.classify {f with anchorTimestamp := later} = Etna.FI.classify f))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.fi09_no_expiry: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.fi09_no_expiry
-- FI-ordinary-example; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.ordinary_example
  unless info.isTheorem do throwError "Etna.FI.ordinary_example is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(Etna.FI.pending 0 0 none = .ok false))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.ordinary_example: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.ordinary_example
-- FI-predue-include-example; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.predue_include_example
  unless info.isTheorem do throwError "Etna.FI.predue_include_example is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(Etna.FI.classify ⟨0, 10, 10, 11, 0, false, false, true⟩ = .ok (.included 0)))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.predue_include_example: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.predue_include_example
-- FI-due-invalid-example; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.due_invalid_example
  unless info.isTheorem do throwError "Etna.FI.due_invalid_example is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(Etna.FI.classify ⟨0, 10, 10, 20, 0, true, false, false⟩ = .ok (.skippedInvalid 0)))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.due_invalid_example: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.due_invalid_example
-- FI-due-empty-example; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.due_empty_example
  unless info.isTheorem do throwError "Etna.FI.due_empty_example is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(Etna.FI.classify ⟨0, 10, 10, 20, 0, true, true, false⟩ = .ok (.needsSkip 0) ∧
    Etna.FI.resolve (.needsSkip 0) .completedEmpty = .ok (some 0)))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.due_empty_example: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.due_empty_example
-- FI-authenticated-ordinary-example; explicit assumptions: ["Authentication.sound: verified root/inbox/exact ordered slots bind stored entry; ContextEvidence binds anchor root/time/tail where required"]
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.authenticated_ordinary_example
  unless info.isTheorem do throwError "Etna.FI.authenticated_ordinary_example is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(Etna.FI.ContextEvidence (Etna.FI.exampleAuthentication ⟨10, 0⟩ 20 0) { Etna.FI.exampleContext with tail := 0 } ∧
    Etna.FI.evaluate (Etna.FI.exampleAuthentication ⟨10, 0⟩ 20 0) Etna.FI.exampleCodec
      { Etna.FI.exampleContext with tail := 0 } none [] = .ok .ordinary))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.authenticated_ordinary_example: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.authenticated_ordinary_example
-- FI-authenticated-predue-include-example; explicit assumptions: ["Authentication.sound: verified root/inbox/exact ordered slots bind stored entry; ContextEvidence binds anchor root/time/tail where required"]
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.authenticated_predue_include_example
  unless info.isTheorem do throwError "Etna.FI.authenticated_predue_include_example is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(Etna.FI.ContextEvidence (Etna.FI.exampleAuthentication ⟨10, 0⟩ 11 1)
      { Etna.FI.exampleContext with anchorTimestamp := 11 } ∧
    Etna.FI.evaluate (Etna.FI.exampleAuthentication ⟨10, 0⟩ 11 1) Etna.FI.exampleCodec
      { Etna.FI.exampleContext with anchorTimestamp := 11 }
      (some ⟨0, ⟨10, 0⟩, [], []⟩) [[]] = .ok (.included 0)))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.authenticated_predue_include_example: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.authenticated_predue_include_example
-- FI-authenticated-due-invalid-example; explicit assumptions: ["Authentication.sound: verified root/inbox/exact ordered slots bind stored entry; ContextEvidence binds anchor root/time/tail where required"]
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.authenticated_due_invalid_example
  unless info.isTheorem do throwError "Etna.FI.authenticated_due_invalid_example is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(Etna.FI.ContextEvidence (Etna.FI.exampleAuthentication ⟨10, 1⟩ 20 1) Etna.FI.exampleContext ∧
    Etna.FI.evaluate (Etna.FI.exampleAuthentication ⟨10, 1⟩ 20 1) Etna.FI.exampleCodec Etna.FI.exampleContext
      (some ⟨0, ⟨10, 1⟩, [0], []⟩) [] = .ok (.skippedInvalid 0)))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.authenticated_due_invalid_example: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.authenticated_due_invalid_example
-- FI-authenticated-due-empty-example; explicit assumptions: ["Authentication.sound: verified root/inbox/exact ordered slots bind stored entry; ContextEvidence binds anchor root/time/tail where required", "Execution.sound: completed response binds actual request to validExecution; deterministic run for equal inputs"]
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.authenticated_due_empty_example
  unless info.isTheorem do throwError "Etna.FI.authenticated_due_empty_example is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(Etna.FI.ContextEvidence (Etna.FI.exampleAuthentication ⟨10, 0⟩ 20 1) Etna.FI.exampleContext ∧
    Etna.FI.execute (Etna.FI.exampleAuthentication ⟨10, 0⟩ 20 1) Etna.FI.exampleCodec Etna.FI.exampleExecution Etna.FI.exampleContext
      (some ⟨0, ⟨10, 0⟩, [], []⟩) [] = .ok 1))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.authenticated_due_empty_example: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.authenticated_due_empty_example
-- FI-authenticated-cache-example; explicit assumptions: ["Authentication.sound: verified root/inbox/exact ordered slots bind stored entry; ContextEvidence binds anchor root/time/tail where required", "Execution.sound: completed response binds actual request to validExecution; deterministic run for equal inputs", "Cached intermediate classification and singleton outcome agree with fresh deterministic facts; canonical envelope/context checked"]
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.authenticated_cache_example
  unless info.isTheorem do throwError "Etna.FI.authenticated_cache_example is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(Etna.FI.CacheEvidence (Etna.FI.exampleAuthentication ⟨10, 0⟩ 20 1) Etna.FI.exampleCachedCodec Etna.FI.exampleExecution
      Etna.FI.exampleContext (some ⟨0, ⟨10, 0⟩, [], []⟩) [] Etna.FI.exampleCache ∧
    Etna.FI.finalizeCached Etna.FI.exampleCache Etna.FI.exampleContext [] = .ok 1))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.authenticated_cache_example: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.authenticated_cache_example
-- FI-rust-pending-refines; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.rust_pending_refines
  unless info.isTheorem do throwError "Etna.Refinement.Rust.rust_pending_refines is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (cursor tail : Aeneas.Std.U64) (witness : Option Aeneas.Std.U64), etna_consensus_core.forced.pending_entry cursor tail witness =
      .ok (Etna.Refinement.Rust.result id (Etna.FI.pending cursor.val tail.val (witness.map Aeneas.Std.UScalar.val)))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Refinement.Rust.rust_pending_refines: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Refinement.Rust.rust_pending_refines
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.rust_pending_refines
  Lean.Meta.forallTelescopeReducing info.type fun _ body => do
    let body ← Lean.Meta.whnf body
    unless body.isAppOfArity ``Eq 3 do
      throwError "refinement must be an exact total output equality"
    let args := body.getAppArgs
    unless args[1]!.getAppFn.isConstOf `etna_consensus_core.forced.pending_entry do
      throwError "refinement left side must call the generated function"
    unless args[2]!.getAppFn.isConstOf ``Aeneas.Std.Result.ok do
      throwError "refinement right side must be outer Result.ok"
-- FI-rust-preimage-refines; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.rust_preimage_refines
  unless info.isTheorem do throwError "Etna.Refinement.Rust.rust_preimage_refines is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (size : Aeneas.Std.U64) (hashMatches : Bool), etna_consensus_core.forced.check_preimage size hashMatches =
      .ok (Etna.Refinement.Rust.result id (Etna.FI.checkPreimage size.val hashMatches))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Refinement.Rust.rust_preimage_refines: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Refinement.Rust.rust_preimage_refines
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.rust_preimage_refines
  Lean.Meta.forallTelescopeReducing info.type fun _ body => do
    let body ← Lean.Meta.whnf body
    unless body.isAppOfArity ``Eq 3 do
      throwError "refinement must be an exact total output equality"
    let args := body.getAppArgs
    unless args[1]!.getAppFn.isConstOf `etna_consensus_core.forced.check_preimage do
      throwError "refinement left side must call the generated function"
    unless args[2]!.getAppFn.isConstOf ``Aeneas.Std.Result.ok do
      throwError "refinement right side must be outer Result.ok"
-- FI-rust-is-due-refines; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.rust_is_due_refines
  unless info.isTheorem do throwError "Etna.Refinement.Rust.rust_is_due_refines is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (timestamp delay anchor : Aeneas.Std.U64), etna_consensus_core.forced.is_due timestamp delay anchor =
      .ok (Etna.FI.isDue timestamp.val delay.val anchor.val)))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Refinement.Rust.rust_is_due_refines: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Refinement.Rust.rust_is_due_refines
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.rust_is_due_refines
  Lean.Meta.forallTelescopeReducing info.type fun _ body => do
    let body ← Lean.Meta.whnf body
    unless body.isAppOfArity ``Eq 3 do
      throwError "refinement must be an exact total output equality"
    let args := body.getAppArgs
    unless args[1]!.getAppFn.isConstOf `etna_consensus_core.forced.is_due do
      throwError "refinement left side must call the generated function"
    unless args[2]!.getAppFn.isConstOf ``Aeneas.Std.Result.ok do
      throwError "refinement right side must be outer Result.ok"
-- FI-rust-classify-refines; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.rust_classify_refines
  unless info.isTheorem do throwError "Etna.Refinement.Rust.rust_classify_refines is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (f : etna_consensus_core.forced.ForcedFacts), etna_consensus_core.forced.classify_forced f = .ok (Etna.Refinement.Rust.result Etna.Refinement.Rust.decision (Etna.FI.classify (Etna.Refinement.Rust.facts f)))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Refinement.Rust.rust_classify_refines: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Refinement.Rust.rust_classify_refines
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.rust_classify_refines
  Lean.Meta.forallTelescopeReducing info.type fun _ body => do
    let body ← Lean.Meta.whnf body
    unless body.isAppOfArity ``Eq 3 do
      throwError "refinement must be an exact total output equality"
    let args := body.getAppArgs
    unless args[1]!.getAppFn.isConstOf `etna_consensus_core.forced.classify_forced do
      throwError "refinement left side must call the generated function"
    unless args[2]!.getAppFn.isConstOf ``Aeneas.Std.Result.ok do
      throwError "refinement right side must be outer Result.ok"
-- FI-rust-resolve-refines; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.rust_resolve_refines
  unless info.isTheorem do throwError "Etna.Refinement.Rust.rust_resolve_refines is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (d : etna_consensus_core.forced.ForcedDecision)
    (o : etna_consensus_core.forced.SingletonOutcome), etna_consensus_core.forced.resolve_forced d o =
      .ok (Etna.Refinement.Rust.result (Option.map Etna.Refinement.Rust.word) (Etna.FI.resolve (Etna.Refinement.Rust.modelDecision d) (Etna.Refinement.Rust.modelOutcome o)))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Refinement.Rust.rust_resolve_refines: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Refinement.Rust.rust_resolve_refines
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.rust_resolve_refines
  Lean.Meta.forallTelescopeReducing info.type fun _ body => do
    let body ← Lean.Meta.whnf body
    unless body.isAppOfArity ``Eq 3 do
      throwError "refinement must be an exact total output equality"
    let args := body.getAppArgs
    unless args[1]!.getAppFn.isConstOf `etna_consensus_core.forced.resolve_forced do
      throwError "refinement left side must call the generated function"
    unless args[2]!.getAppFn.isConstOf ``Aeneas.Std.Result.ok do
      throwError "refinement right side must be outer Result.ok"
-- FI-rust-advance-refines; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.rust_advance_refines
  unless info.isTheorem do throwError "Etna.Refinement.Rust.rust_advance_refines is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (cursor : Aeneas.Std.U64) (consumed : Option Aeneas.Std.U64), etna_consensus_core.forced.advance_cursor cursor consumed =
      .ok (Etna.Refinement.Rust.result Etna.Refinement.Rust.word (Etna.FI.advance cursor.val (consumed.map Aeneas.Std.UScalar.val)))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Refinement.Rust.rust_advance_refines: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Refinement.Rust.rust_advance_refines
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.rust_advance_refines
  Lean.Meta.forallTelescopeReducing info.type fun _ body => do
    let body ← Lean.Meta.whnf body
    unless body.isAppOfArity ``Eq 3 do
      throwError "refinement must be an exact total output equality"
    let args := body.getAppArgs
    unless args[1]!.getAppFn.isConstOf `etna_consensus_core.forced.advance_cursor do
      throwError "refinement left side must call the generated function"
    unless args[2]!.getAppFn.isConstOf ``Aeneas.Std.Result.ok do
      throwError "refinement right side must be outer Result.ok"
-- CORE-01; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.checkedWord_some_iff
  unless info.isTheorem do throwError "Etna.checkedWord_some_iff is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (bits n : Nat), (∃ word, Etna.checkedWord bits n = some word) ↔ n < 2 ^ bits))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.checkedWord_some_iff: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.checkedWord_some_iff
-- CORE-02; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.word64_add_fits128
  unless info.isTheorem do throwError "Etna.word64_add_fits128 is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (a b : Etna.Word64), a.val + b.val < 2 ^ 128))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.word64_add_fits128: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.word64_add_fits128
