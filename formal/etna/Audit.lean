import Etna.Committee.Examples
import Etna.Committee.Proofs
import Etna.Committee.Schedule
import Etna.Common.Words
import Etna.FI.Examples
import Etna.FI.Proofs
import Etna.Integration.Composition
import Etna.Integration.Examples
import Etna.Landing.Examples
import Etna.Landing.Proofs
import Etna.Landing.Statement
import Etna.Refinement.Rust.Committee
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
-- FI-valid-step-count; explicit assumptions: ["Each trace step carries concrete authenticated context and successful evaluate/resolve/advance evidence; the tail bound is derived"]
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
-- FI-07; explicit assumptions: ["Each trace step carries concrete authenticated context and successful evaluate/resolve/advance evidence; the tail bound is derived"]
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
-- FI-fi07-evaluated-consumption; explicit assumptions: ["Authentication.sound: verified root/inbox/exact ordered slots bind stored entry; ContextEvidence binds anchor root/time/tail where required"]
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.fi07_evaluated_consumption
  unless info.isTheorem do throwError "Etna.FI.fi07_evaluated_consumption is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (a : Etna.FI.Authentication) (codec : Etna.FI.Codec) (c : Etna.FI.Context)
    (w : Option Etna.FI.Witness) (txs : List Etna.FI.Bytes) (d : Etna.FI.Decision) (o : Etna.FI.SingletonOutcome) (index : Nat)
    (classified : Etna.FI.evaluate a codec c w txs = .ok d)
    (resolved : Etna.FI.resolve d o = .ok (some index)), index = c.cursor.val ∧ index < c.tail.val))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.fi07_evaluated_consumption: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.fi07_evaluated_consumption
-- FI-valid-step-consumption; explicit assumptions: ["Each trace step carries concrete authenticated context and successful evaluate/resolve/advance evidence; the tail bound is derived"]
run_elab do
  let info ← Lean.getConstInfo `Etna.FI.valid_step_consumption
  unless info.isTheorem do throwError "Etna.FI.valid_step_consumption is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ {before after index : Nat}
    (step : Etna.FI.ValidStep before after (some index)), index = before ∧ before < step.context.tail.val ∧
      before < step.authentication.queueTail step.context.stateRoot step.context.inbox))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.FI.valid_step_consumption: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.FI.valid_step_consumption
-- FI-fi07-trace-bound; explicit assumptions: ["Each trace step carries concrete authenticated context and successful evaluate/resolve/advance evidence; the tail bound is derived"]
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
-- COM-checked_some; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.checked_some
  unless info.isTheorem do throwError "Etna.Committee.checked_some is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ {n v : Nat},
  Iff (@Eq (Option Nat) (Etna.Committee.checked n) (@Option.some Nat v))
    (And (@LE.le Nat instLENat n Etna.Committee.max64) (@Eq Nat v n))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.checked_some: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.checked_some
-- COM-switch_positive; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.switch_positive
  unless info.isTheorem do throwError "Etna.Committee.switch_positive is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ {s : Etna.Committee.Schedule} {h t : Nat},
  @Eq (Option Nat) (Etna.Committee.switchTarget s h) (@Option.some Nat t) →
    @LT.lt Nat instLTNat (@OfNat.ofNat Nat (nat_lit 0) (instOfNatNat (nat_lit 0))) t))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.switch_positive: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.switch_positive
-- COM-starting_iff; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.starting_iff
  unless info.isTheorem do throwError "Etna.Committee.starting_iff is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (s : Etna.Committee.Schedule) (h t : Nat),
  @LT.lt Nat instLTNat (@OfNat.ofNat Nat (nat_lit 0) (instOfNatNat (nat_lit 0))) s.length →
    Iff (@Eq (Option Nat) (Etna.Committee.startingAt s h) (@Option.some Nat t)) (@Eq Nat h (Etna.Committee.H s t))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.starting_iff: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.starting_iff
-- COM-switch_iff; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.switch_iff
  unless info.isTheorem do throwError "Etna.Committee.switch_iff is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (s : Etna.Committee.Schedule) (h t : Nat),
  @LT.lt Nat instLTNat (@OfNat.ofNat Nat (nat_lit 0) (instOfNatNat (nat_lit 0))) s.length →
    Iff (@Eq (Option Nat) (Etna.Committee.switchTarget s h) (@Option.some Nat t))
      (And (@LT.lt Nat instLTNat (@OfNat.ofNat Nat (nat_lit 0) (instOfNatNat (nat_lit 0))) t)
        (And
          (@Eq Nat
            (@HAdd.hAdd Nat Nat Nat (@instHAdd Nat instAddNat) h
              (@OfNat.ofNat Nat (nat_lit 2) (instOfNatNat (nat_lit 2))))
            (Etna.Committee.H s t))
          (@LE.le Nat instLENat
            (@HAdd.hAdd Nat Nat Nat (@instHAdd Nat instAddNat) h
              (@OfNat.ofNat Nat (nat_lit 2) (instOfNatNat (nat_lit 2))))
            Etna.Committee.max64)))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.switch_iff: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.switch_iff
-- COM-01; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.schedule_exact
  unless info.isTheorem do throwError "Etna.Committee.schedule_exact is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (s : Etna.Committee.Schedule) (t : Nat),
  @LE.le Nat instLENat (@OfNat.ofNat Nat (nat_lit 3) (instOfNatNat (nat_lit 3))) s.length →
    @LT.lt Nat instLTNat (@OfNat.ofNat Nat (nat_lit 0) (instOfNatNat (nat_lit 0))) t →
      @LE.le Nat instLENat (Etna.Committee.H s t) Etna.Committee.max64 →
        And
          (@Eq Nat
            (@HAdd.hAdd Nat Nat Nat (@instHAdd Nat instAddNat) (Etna.Committee.D s t)
              (@OfNat.ofNat Nat (nat_lit 1) (instOfNatNat (nat_lit 1))))
            (Etna.Committee.S s t))
          (And
            (@Eq Nat
              (@HAdd.hAdd Nat Nat Nat (@instHAdd Nat instAddNat) (Etna.Committee.S s t)
                (@OfNat.ofNat Nat (nat_lit 2) (instOfNatNat (nat_lit 2))))
              (Etna.Committee.H s t))
            (∀ (h : Nat),
              Iff (@Eq (Option Nat) (Etna.Committee.switchTarget s h) (@Option.some Nat t))
                (@Eq Nat h (Etna.Committee.S s t))))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.schedule_exact: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.schedule_exact
-- COM-epoch_range; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.epoch_range
  unless info.isTheorem do throwError "Etna.Committee.epoch_range is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (s : Etna.Committee.Schedule) (t h : Nat),
  @LT.lt Nat instLTNat (@OfNat.ofNat Nat (nat_lit 0) (instOfNatNat (nat_lit 0))) s.length →
    @LE.le Nat instLENat (Etna.Committee.H s t) h →
      @LT.lt Nat instLTNat h
          (Etna.Committee.H s
            (@HAdd.hAdd Nat Nat Nat (@instHAdd Nat instAddNat) t
              (@OfNat.ofNat Nat (nat_lit 1) (instOfNatNat (nat_lit 1))))) →
        @Eq (Option Nat) (Etna.Committee.epochOf s h) (@Option.some Nat t)))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.epoch_range: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.epoch_range
-- COM-03; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.activation_exact
  unless info.isTheorem do throwError "Etna.Committee.activation_exact is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (s : Etna.Committee.Schedule) (st : Etna.Committee.CommitteeState) (t h : Nat),
  @LT.lt Nat instLTNat (@OfNat.ofNat Nat (nat_lit 0) (instOfNatNat (nat_lit 0))) s.length →
    @LE.le Nat instLENat (Etna.Committee.H s t) h →
      @LT.lt Nat instLTNat h
          (Etna.Committee.H s
            (@HAdd.hAdd Nat Nat Nat (@instHAdd Nat instAddNat) t
              (@OfNat.ofNat Nat (nat_lit 1) (instOfNatNat (nat_lit 1))))) →
        @Eq (Option Etna.Committee.Record) (Etna.Committee.authority s st h) (Etna.Committee.lookup st.records t)))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.activation_exact: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.activation_exact
-- COM-missing_pending; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.missing_pending
  unless info.isTheorem do throwError "Etna.Committee.missing_pending is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (s : Etna.Committee.Schedule) (st : Etna.Committee.CommitteeState) (t : Nat),
  @LT.lt Nat instLTNat (@OfNat.ofNat Nat (nat_lit 0) (instOfNatNat (nat_lit 0))) s.length →
    @Eq (Option Etna.Committee.Record) (Etna.Committee.lookup st.records t) (@Option.none Etna.Committee.Record) →
      @Eq (Option Etna.Committee.Record) (Etna.Committee.authority s st (Etna.Committee.H s t))
        (@Option.none Etna.Committee.Record)))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.missing_pending: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.missing_pending
-- COM-02; explicit assumptions: ["Authentication.sound at exact committed-parent root/cutoff; accepted incoming checks exact epoch/root/cutoff and nonempty members."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.parent_anchor_unique
  unless info.isTheorem do throwError "Etna.Committee.parent_anchor_unique is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (a : Etna.Committee.Authentication) (s : Etna.Committee.Schedule) (p : Etna.Committee.Anchor) (h t : Nat)
  (w : Etna.Committee.Witness) (r : Etna.Committee.Record),
  @Eq (Option Nat) (Etna.Committee.switchTarget s h) (@Option.some Nat t) →
    @Eq (Except Etna.Committee.Failure (Option Etna.Committee.Record))
        (Etna.Committee.incoming a s p h (@Option.some Etna.Committee.Witness w))
        (@Except.ok Etna.Committee.Failure (Option Etna.Committee.Record) (@Option.some Etna.Committee.Record r)) →
      And
        (@Eq (Option Etna.Committee.Snapshot) (a.stored p.stateRoot p.number)
          (@Option.some Etna.Committee.Snapshot w.snapshot))
        (And (@Eq Etna.Committee.Record r (a.derive t w.snapshot))
          (And (@Eq Nat r.epoch t)
            (And (@Eq Etna.Committee.Hash r.root w.snapshot.root)
              (And (@Eq Nat r.cutoff p.number)
                (And (@Eq Nat w.snapshot.cutoff p.number)
                  (@Ne (List Etna.Committee.Member) r.members (@List.nil Etna.Committee.Member)))))))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.parent_anchor_unique: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.parent_anchor_unique
-- COM-nonswitch_witness_rejected; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.nonswitch_witness_rejected
  unless info.isTheorem do throwError "Etna.Committee.nonswitch_witness_rejected is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (a : Etna.Committee.Authentication) (s : Etna.Committee.Schedule) (p : Etna.Committee.Anchor) (h : Nat)
  (w : Etna.Committee.Witness),
  @Eq (Option Nat) (Etna.Committee.switchTarget s h) (@Option.none Nat) →
    @Eq (Except Etna.Committee.Failure (Option Etna.Committee.Record))
      (Etna.Committee.incoming a s p h (@Option.some Etna.Committee.Witness w))
      (@Except.error Etna.Committee.Failure (Option Etna.Committee.Record) Etna.Committee.Failure.witness)))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.nonswitch_witness_rejected: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.nonswitch_witness_rejected
-- COM-different_snapshot_rejected; explicit assumptions: ["Authentication.sound at exact committed-parent root/cutoff; accepted incoming checks exact epoch/root/cutoff and nonempty members."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.different_snapshot_rejected
  unless info.isTheorem do throwError "Etna.Committee.different_snapshot_rejected is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (a : Etna.Committee.Authentication) (s : Etna.Committee.Schedule) (p : Etna.Committee.Anchor) (h t : Nat)
  (w : Etna.Committee.Witness) (stored : Etna.Committee.Snapshot) (r : Etna.Committee.Record),
  @Eq (Option Nat) (Etna.Committee.switchTarget s h) (@Option.some Nat t) →
    @Eq (Option Etna.Committee.Snapshot) (a.stored p.stateRoot p.number) (@Option.some Etna.Committee.Snapshot stored) →
      @Ne Etna.Committee.Snapshot stored w.snapshot →
        @Ne (Except Etna.Committee.Failure (Option Etna.Committee.Record))
          (Etna.Committee.incoming a s p h (@Option.some Etna.Committee.Witness w))
          (@Except.ok Etna.Committee.Failure (Option Etna.Committee.Record) (@Option.some Etna.Committee.Record r))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.different_snapshot_rejected: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.different_snapshot_rejected
-- COM-04; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.certificate_authority
  unless info.isTheorem do throwError "Etna.Committee.certificate_authority is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (crypto : Etna.Committee.Crypto) (chain h hash : Nat) (r : Etna.Committee.Record) (cert : Etna.Committee.Certificate),
  @Eq Bool (Etna.Committee.certificateOK crypto chain h hash r cert) Bool.true →
    And (@Eq Nat cert.chain chain)
      (And (@Eq Nat cert.height h)
        (And (@Eq Etna.Committee.Hash cert.blockHash hash)
          (And (@List.Nodup Nat (@List.map Etna.Committee.Vote Nat Etna.Committee.Vote.signer cert.votes))
            (And (@List.Nodup Nat (@List.map Etna.Committee.Member Nat Etna.Committee.Member.key r.members))
              (And
                (@LT.lt Nat instLTNat (@OfNat.ofNat Nat (nat_lit 0) (instOfNatNat (nat_lit 0)))
                  (Etna.Committee.totalPower r))
                (@GT.gt Nat instLTNat
                  (@HMul.hMul Nat Nat Nat (@instHMul Nat instMulNat)
                    (@OfNat.ofNat Nat (nat_lit 3) (instOfNatNat (nat_lit 3)))
                    (Etna.Committee.signedPower crypto cert r))
                  (@HMul.hMul Nat Nat Nat (@instHMul Nat instMulNat)
                    (@OfNat.ofNat Nat (nat_lit 2) (instOfNatNat (nat_lit 2))) (Etna.Committee.totalPower r))))))))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.certificate_authority: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.certificate_authority
-- COM-nil_absent_zero; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.nil_absent_zero
  unless info.isTheorem do throwError "Etna.Committee.nil_absent_zero is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (crypto : Etna.Committee.Crypto) (cert : Etna.Committee.Certificate) (members : List Etna.Committee.Member)
  (v : Etna.Committee.Vote),
  @Ne Etna.Committee.VoteKind v.kind Etna.Committee.VoteKind.block →
    @Eq Nat (Etna.Committee.votePower crypto cert members v) (@OfNat.ofNat Nat (nat_lit 0) (instOfNatNat (nat_lit 0)))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.nil_absent_zero: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.nil_absent_zero
-- COM-counted_signature; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.counted_signature
  unless info.isTheorem do throwError "Etna.Committee.counted_signature is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (crypto : Etna.Committee.Crypto) (cert : Etna.Committee.Certificate) (members : List Etna.Committee.Member)
  (v : Etna.Committee.Vote),
  @LT.lt Nat instLTNat (@OfNat.ofNat Nat (nat_lit 0) (instOfNatNat (nat_lit 0)))
      (Etna.Committee.votePower crypto cert members v) →
    And (@Eq Etna.Committee.VoteKind v.kind Etna.Committee.VoteKind.block)
      (@Eq Bool (crypto.valid cert.chain cert.height cert.blockHash v.signer v.signature) Bool.true)))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.counted_signature: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.counted_signature
-- COM-equal_two_thirds_rejected; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.equal_two_thirds_rejected
  unless info.isTheorem do throwError "Etna.Committee.equal_two_thirds_rejected is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (crypto : Etna.Committee.Crypto) (chain h hash : Nat) (r : Etna.Committee.Record) (cert : Etna.Committee.Certificate),
  @Eq Nat
      (@HMul.hMul Nat Nat Nat (@instHMul Nat instMulNat) (@OfNat.ofNat Nat (nat_lit 3) (instOfNatNat (nat_lit 3)))
        (Etna.Committee.signedPower crypto cert r))
      (@HMul.hMul Nat Nat Nat (@instHMul Nat instMulNat) (@OfNat.ofNat Nat (nat_lit 2) (instOfNatNat (nat_lit 2)))
        (Etna.Committee.totalPower r)) →
    @Eq Bool (Etna.Committee.certificateOK crypto chain h hash r cert) Bool.false))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.equal_two_thirds_rejected: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.equal_two_thirds_rejected
-- COM-05; explicit assumptions: ["AuthenticatedBlockFacts carry explicit anchor and payload relation evidence for each concrete block; same Context and checkpoint; successful external operations/durable reconstruction where relating real adapters."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.batch_cut_equivalent
  unless info.isTheorem do throwError "Etna.Committee.batch_cut_equivalent is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (ctx : Etna.Committee.Context) (xs ys : List (Etna.Committee.AuthenticatedBlockFacts ctx))
  (st : Etna.Committee.CommitteeState),
  @Eq (Except Etna.Committee.Failure (Prod Etna.Committee.CommitteeState Etna.Committee.Updates))
    (Etna.Committee.replay ctx
      (@HAppend.hAppend (List (Etna.Committee.AuthenticatedBlockFacts ctx))
        (List (Etna.Committee.AuthenticatedBlockFacts ctx)) (List (Etna.Committee.AuthenticatedBlockFacts ctx))
        (@instHAppendOfAppend (List (Etna.Committee.AuthenticatedBlockFacts ctx))
          (@List.instAppend (Etna.Committee.AuthenticatedBlockFacts ctx)))
        xs ys)
      st)
    (@Bind.bind (Except Etna.Committee.Failure)
      (@Monad.toBind (Except Etna.Committee.Failure) (@Except.instMonad Etna.Committee.Failure))
      (Prod Etna.Committee.CommitteeState Etna.Committee.Updates)
      (Prod Etna.Committee.CommitteeState Etna.Committee.Updates) (Etna.Committee.replay ctx xs st) fun __x =>
      Etna.Committee.batch_cut_equivalent.match_1
        (fun x => Except Etna.Committee.Failure (Prod Etna.Committee.CommitteeState Etna.Committee.Updates)) __x
        fun middle u =>
        @Bind.bind (Except Etna.Committee.Failure)
          (@Monad.toBind (Except Etna.Committee.Failure) (@Except.instMonad Etna.Committee.Failure))
          (Prod Etna.Committee.CommitteeState Etna.Committee.Updates)
          (Prod Etna.Committee.CommitteeState Etna.Committee.Updates) (Etna.Committee.replay ctx ys middle) fun __x =>
          Etna.Committee.batch_cut_equivalent.match_1
            (fun x => Except Etna.Committee.Failure (Prod Etna.Committee.CommitteeState Etna.Committee.Updates)) __x
            fun last v =>
            @Pure.pure (Except Etna.Committee.Failure)
              (@Applicative.toPure (Except Etna.Committee.Failure)
                (@Monad.toApplicative (Except Etna.Committee.Failure) (@Except.instMonad Etna.Committee.Failure)))
              (Prod Etna.Committee.CommitteeState Etna.Committee.Updates)
              (@Prod.mk Etna.Committee.CommitteeState Etna.Committee.Updates last
                (@HAppend.hAppend Etna.Committee.Updates Etna.Committee.Updates Etna.Committee.Updates
                  (@instHAppendOfAppend Etna.Committee.Updates
                    (@List.instAppend (Prod Etna.Committee.Record Etna.Committee.Record)))
                  u v)))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.batch_cut_equivalent: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.batch_cut_equivalent
-- COM-06; explicit assumptions: ["AuthenticatedBlockFacts carry explicit anchor and payload relation evidence for each concrete block; same Context and checkpoint; successful external operations/durable reconstruction where relating real adapters."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.replay_deterministic
  unless info.isTheorem do throwError "Etna.Committee.replay_deterministic is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (ctx : Etna.Committee.Context) (xs ys : List (Etna.Committee.AuthenticatedBlockFacts ctx))
  (st middle onlineFinal crashFinal : Etna.Committee.CommitteeState) (u v all : Etna.Committee.Updates),
  @Eq (Except Etna.Committee.Failure (Prod Etna.Committee.CommitteeState Etna.Committee.Updates))
      (Etna.Committee.replay ctx xs st)
      (@Except.ok Etna.Committee.Failure (Prod Etna.Committee.CommitteeState Etna.Committee.Updates)
        (@Prod.mk Etna.Committee.CommitteeState Etna.Committee.Updates middle u)) →
    @Eq (Except Etna.Committee.Failure (Prod Etna.Committee.CommitteeState Etna.Committee.Updates))
        (Etna.Committee.replay ctx ys middle)
        (@Except.ok Etna.Committee.Failure (Prod Etna.Committee.CommitteeState Etna.Committee.Updates)
          (@Prod.mk Etna.Committee.CommitteeState Etna.Committee.Updates crashFinal v)) →
      @Eq (Except Etna.Committee.Failure (Prod Etna.Committee.CommitteeState Etna.Committee.Updates))
          (Etna.Committee.replay ctx
            (@HAppend.hAppend (List (Etna.Committee.AuthenticatedBlockFacts ctx))
              (List (Etna.Committee.AuthenticatedBlockFacts ctx)) (List (Etna.Committee.AuthenticatedBlockFacts ctx))
              (@instHAppendOfAppend (List (Etna.Committee.AuthenticatedBlockFacts ctx))
                (@List.instAppend (Etna.Committee.AuthenticatedBlockFacts ctx)))
              xs ys)
            st)
          (@Except.ok Etna.Committee.Failure (Prod Etna.Committee.CommitteeState Etna.Committee.Updates)
            (@Prod.mk Etna.Committee.CommitteeState Etna.Committee.Updates onlineFinal all)) →
        And (@Eq Etna.Committee.CommitteeState onlineFinal crashFinal)
          (@Eq Etna.Committee.Updates all
            (@HAppend.hAppend Etna.Committee.Updates Etna.Committee.Updates Etna.Committee.Updates
              (@instHAppendOfAppend Etna.Committee.Updates
                (@List.instAppend (Prod Etna.Committee.Record Etna.Committee.Record)))
              u v))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.replay_deterministic: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.replay_deterministic
-- COM-07; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.backpressure_switch_bound
  unless info.isTheorem do throwError "Etna.Committee.backpressure_switch_bound is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (s : Etna.Committee.Schedule) (t cap checkpoint : Nat),
  @LT.lt Nat instLTNat (@OfNat.ofNat Nat (nat_lit 0) (instOfNatNat (nat_lit 0))) t →
    @LE.le Nat instLENat
        (@HAdd.hAdd Nat Nat Nat (@instHAdd Nat instAddNat) cap
          (@OfNat.ofNat Nat (nat_lit 3) (instOfNatNat (nat_lit 3))))
        s.length →
      @LE.le Nat instLENat (@HSub.hSub Nat Nat Nat (@instHSub Nat instSubNat) (Etna.Committee.S s t) checkpoint) cap →
        @GT.gt Nat instLTNat checkpoint
          (Etna.Committee.H s
            (@HSub.hSub Nat Nat Nat (@instHSub Nat instSubNat) t
              (@OfNat.ofNat Nat (nat_lit 1) (instOfNatNat (nat_lit 1)))))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.backpressure_switch_bound: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.backpressure_switch_bound
-- COM-invalid_difference_rejected; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.invalid_difference_rejected
  unless info.isTheorem do throwError "Etna.Committee.invalid_difference_rejected is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (dMax margin : Nat),
  @LT.lt Nat instLTNat dMax margin → @Eq (Option Nat) (Etna.Committee.unsettledCap dMax margin) (@Option.none Nat)))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.invalid_difference_rejected: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.invalid_difference_rejected
-- COM-cap_overflow_rejected; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.cap_overflow_rejected
  unless info.isTheorem do throwError "Etna.Committee.cap_overflow_rejected is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (s : Etna.Committee.Schedule) (cap : Nat),
  @LE.le Nat instLENat (@OfNat.ofNat Nat (nat_lit 3) (instOfNatNat (nat_lit 3))) s.length →
    @LT.lt Nat instLTNat Etna.Committee.max64
        (@HAdd.hAdd Nat Nat Nat (@instHAdd Nat instAddNat) cap
          (@OfNat.ofNat Nat (nat_lit 3) (instOfNatNat (nat_lit 3)))) →
      @Eq (Except Etna.Committee.ScheduleError Unit) (Etna.Committee.validate s cap)
        (@Except.error Etna.Committee.ScheduleError Unit Etna.Committee.ScheduleError.shorterThanCap)))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.cap_overflow_rejected: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.cap_overflow_rejected
-- COM-counted_signature_genuine; explicit assumptions: ["Crypto.sound for exact chain/height/block/key/signature."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.counted_signature_genuine
  unless info.isTheorem do throwError "Etna.Committee.counted_signature_genuine is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (crypto : Etna.Committee.Crypto) (cert : Etna.Committee.Certificate) (members : List Etna.Committee.Member)
  (v : Etna.Committee.Vote),
  @LT.lt Nat instLTNat (@OfNat.ofNat Nat (nat_lit 0) (instOfNatNat (nat_lit 0)))
      (Etna.Committee.votePower crypto cert members v) →
    crypto.genuine cert.chain cert.height cert.blockHash v.signer v.signature))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.counted_signature_genuine: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.counted_signature_genuine
-- COM-derivation_parent_is_D; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.derivation_parent_is_D
  unless info.isTheorem do throwError "Etna.Committee.derivation_parent_is_D is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (s : Etna.Committee.Schedule) (t parent : Nat),
  @LE.le Nat instLENat (@OfNat.ofNat Nat (nat_lit 3) (instOfNatNat (nat_lit 3))) s.length →
    @LT.lt Nat instLTNat (@OfNat.ofNat Nat (nat_lit 0) (instOfNatNat (nat_lit 0))) t →
      @LE.le Nat instLENat (Etna.Committee.H s t) Etna.Committee.max64 →
        @Eq (Option Nat)
            (Etna.Committee.switchTarget s
              (@HAdd.hAdd Nat Nat Nat (@instHAdd Nat instAddNat) parent
                (@OfNat.ofNat Nat (nat_lit 1) (instOfNatNat (nat_lit 1)))))
            (@Option.some Nat t) →
          @Eq Nat parent (Etna.Committee.D s t)))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.derivation_parent_is_D: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.derivation_parent_is_D
-- COM-step_backpressure; explicit assumptions: ["AuthenticatedBlockFacts carry explicit anchor and payload relation evidence for each concrete block; same Context and checkpoint; successful external operations/durable reconstruction where relating real adapters."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.step_backpressure
  unless info.isTheorem do throwError "Etna.Committee.step_backpressure is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (ctx : Etna.Committee.Context) (st next : Etna.Committee.CommitteeState)
  (b : Etna.Committee.AuthenticatedBlockFacts ctx) (updates : Etna.Committee.Updates),
  @Eq (Except Etna.Committee.Failure (Prod Etna.Committee.CommitteeState Etna.Committee.Updates))
      (Etna.Committee.step ctx st b)
      (@Except.ok Etna.Committee.Failure (Prod Etna.Committee.CommitteeState Etna.Committee.Updates)
        (@Prod.mk Etna.Committee.CommitteeState Etna.Committee.Updates next updates)) →
    @LE.le Nat instLENat
      (@HSub.hSub Nat Nat Nat (@instHSub Nat instSubNat) (@Etna.Committee.AuthenticatedBlockFacts.facts ctx b).height
        (@Etna.Committee.AuthenticatedBlockFacts.facts ctx b).anchor.checkpoint)
      ctx.cap))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.step_backpressure: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.step_backpressure
-- COM-conflict_rejected; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.conflict_rejected
  unless info.isTheorem do throwError "Etna.Committee.conflict_rejected is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (s : Etna.Committee.Schedule) (h t : Nat) (outgoing incoming : Bool),
  @Eq (Except Etna.Committee.Failure Etna.Committee.Plan)
    (Etna.Committee.plan s h (Etna.Committee.Relation.conflict t) outgoing incoming)
    (@Except.error Etna.Committee.Failure Etna.Committee.Plan (Etna.Committee.Failure.conflict t))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.conflict_rejected: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.conflict_rejected
-- COM-no_nonswitch_updates; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.no_nonswitch_updates
  unless info.isTheorem do throwError "Etna.Committee.no_nonswitch_updates is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (s : Etna.Committee.Schedule) (h : Nat) (r : Etna.Committee.Relation) (outgoing incoming : Bool)
  (p : Etna.Committee.Plan),
  @Eq (Option Nat) (Etna.Committee.switchTarget s h) (@Option.none Nat) →
    @Eq (Except Etna.Committee.Failure Etna.Committee.Plan) (Etna.Committee.plan s h r outgoing incoming)
        (@Except.ok Etna.Committee.Failure Etna.Committee.Plan p) →
      @Eq (Option Etna.Committee.Switch) p.switch (@Option.none Etna.Committee.Switch)))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.no_nonswitch_updates: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.no_nonswitch_updates
-- COM-checked_schedule_domain; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.checked_schedule_domain
  unless info.isTheorem do throwError "Etna.Committee.checked_schedule_domain is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (s : Etna.Committee.Schedule) (t : Nat),
  @LE.le Nat instLENat (@OfNat.ofNat Nat (nat_lit 3) (instOfNatNat (nat_lit 3))) s.length →
    @LT.lt Nat instLTNat (@OfNat.ofNat Nat (nat_lit 0) (instOfNatNat (nat_lit 0))) t →
      @LE.le Nat instLENat (Etna.Committee.H s t) Etna.Committee.max64 →
        And (@Eq (Option Nat) (Etna.Committee.first s t) (@Option.some Nat (Etna.Committee.H s t)))
          (@Eq (Option Nat) (Etna.Committee.parentHeight s t) (@Option.some Nat (Etna.Committee.D s t)))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.checked_schedule_domain: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.checked_schedule_domain
-- COM-activation_boundary; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.activation_boundary
  unless info.isTheorem do throwError "Etna.Committee.activation_boundary is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (s : Etna.Committee.Schedule) (st : Etna.Committee.CommitteeState) (t : Nat),
  @LT.lt Nat instLTNat (@OfNat.ofNat Nat (nat_lit 0) (instOfNatNat (nat_lit 0))) s.length →
    @LT.lt Nat instLTNat (@OfNat.ofNat Nat (nat_lit 0) (instOfNatNat (nat_lit 0))) t →
      And
        (@Eq (Option Etna.Committee.Record)
          (Etna.Committee.authority s st
            (@HSub.hSub Nat Nat Nat (@instHSub Nat instSubNat) (Etna.Committee.H s t)
              (@OfNat.ofNat Nat (nat_lit 1) (instOfNatNat (nat_lit 1)))))
          (Etna.Committee.lookup st.records
            (@HSub.hSub Nat Nat Nat (@instHSub Nat instSubNat) t
              (@OfNat.ofNat Nat (nat_lit 1) (instOfNatNat (nat_lit 1))))))
        (@Eq (Option Etna.Committee.Record) (Etna.Committee.authority s st (Etna.Committee.H s t))
          (Etna.Committee.lookup st.records t))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.activation_boundary: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.activation_boundary
-- COM-step_missing_authority; explicit assumptions: ["AuthenticatedBlockFacts carry explicit anchor and payload relation evidence for each concrete block; same Context and checkpoint; successful external operations/durable reconstruction where relating real adapters."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.step_missing_authority
  unless info.isTheorem do throwError "Etna.Committee.step_missing_authority is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (ctx : Etna.Committee.Context) (st : Etna.Committee.CommitteeState) (b : Etna.Committee.AuthenticatedBlockFacts ctx),
  @Eq Nat (@Etna.Committee.AuthenticatedBlockFacts.facts ctx b).height
      (@HAdd.hAdd Nat Nat Nat (@instHAdd Nat instAddNat) st.height
        (@OfNat.ofNat Nat (nat_lit 1) (instOfNatNat (nat_lit 1)))) →
    @Eq Nat (@Etna.Committee.AuthenticatedBlockFacts.facts ctx b).chain ctx.chain →
      @Eq Etna.Committee.Hash (@Etna.Committee.AuthenticatedBlockFacts.facts ctx b).parentHash st.blockHash →
        @Eq (Option Etna.Committee.Record)
            (Etna.Committee.authority ctx.schedule st (@Etna.Committee.AuthenticatedBlockFacts.facts ctx b).height)
            (@Option.none Etna.Committee.Record) →
          @Eq (Except Etna.Committee.Failure (Prod Etna.Committee.CommitteeState Etna.Committee.Updates))
            (Etna.Committee.step ctx st b)
            (@Except.error Etna.Committee.Failure (Prod Etna.Committee.CommitteeState Etna.Committee.Updates)
              (Etna.Committee.Failure.unknown
                (@Option.getD Nat
                  (Etna.Committee.epochOf ctx.schedule (@Etna.Committee.AuthenticatedBlockFacts.facts ctx b).height)
                  (@OfNat.ofNat Nat (nat_lit 0) (instOfNatNat (nat_lit 0))))))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.step_missing_authority: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.step_missing_authority
-- COM-comet_activation_exact; explicit assumptions: ["CometAdapter.appliesAfterTwo: external observed validator authority follows Comet update-at-h/apply-at-h+2 semantics; schedule spacing itself is kernel-proved."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.comet_activation_exact
  unless info.isTheorem do throwError "Etna.Committee.comet_activation_exact is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (adapter : Etna.Committee.CometAdapter) (s : Etna.Committee.Schedule) (t h : Nat)
  (outgoing incoming : Etna.Committee.Record),
  @LE.le Nat instLENat (@OfNat.ofNat Nat (nat_lit 3) (instOfNatNat (nat_lit 3))) s.length →
    @LT.lt Nat instLTNat (@OfNat.ofNat Nat (nat_lit 0) (instOfNatNat (nat_lit 0))) t →
      @LE.le Nat instLENat (Etna.Committee.H s t) Etna.Committee.max64 →
        @Eq Etna.Committee.Record (adapter.observed (Etna.Committee.S s t) outgoing incoming h)
          (@ite Etna.Committee.Record (@LT.lt Nat instLTNat h (Etna.Committee.H s t)) (h.decLt (Etna.Committee.H s t))
            outgoing incoming)))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.comet_activation_exact: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.comet_activation_exact
-- COM-valid_first_transition; explicit assumptions: ["Concrete finite authentication interpretation witnesses satisfiability; not a claim of production MPT or ZIP215 implementation correctness."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.Examples.valid_first_transition
  unless info.isTheorem do throwError "Etna.Committee.Examples.valid_first_transition is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(And
  (@Eq (Except Etna.Committee.ScheduleError Unit)
    (Etna.Committee.validate Etna.Committee.Examples.ordinary
      (@OfNat.ofNat Nat (nat_lit 10) (instOfNatNat (nat_lit 10))))
    (@Except.ok Etna.Committee.ScheduleError Unit Unit.unit))
  (And
    (@Eq (Option Nat)
      (Etna.Committee.first Etna.Committee.Examples.ordinary (@OfNat.ofNat Nat (nat_lit 1) (instOfNatNat (nat_lit 1))))
      (@Option.some Nat (@OfNat.ofNat Nat (nat_lit 21) (instOfNatNat (nat_lit 21)))))
    (And
      (@Eq (Option Nat)
        (Etna.Committee.parentHeight Etna.Committee.Examples.ordinary
          (@OfNat.ofNat Nat (nat_lit 1) (instOfNatNat (nat_lit 1))))
        (@Option.some Nat (@OfNat.ofNat Nat (nat_lit 18) (instOfNatNat (nat_lit 18)))))
      (And
        (@Eq (Option Nat)
          (Etna.Committee.switchTarget Etna.Committee.Examples.ordinary
            (@OfNat.ofNat Nat (nat_lit 19) (instOfNatNat (nat_lit 19))))
          (@Option.some Nat (@OfNat.ofNat Nat (nat_lit 1) (instOfNatNat (nat_lit 1)))))
        (@Eq (Option Nat)
          (Etna.Committee.l1First Etna.Committee.Examples.ordinary
            (@OfNat.ofNat Nat (nat_lit 1) (instOfNatNat (nat_lit 1))))
          (@Option.some Nat (@OfNat.ofNat Nat (nat_lit 65) (instOfNatNat (nat_lit 65))))))))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.Examples.valid_first_transition: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.Examples.valid_first_transition
-- COM-accepted_l1_overflow; explicit assumptions: ["Concrete finite authentication interpretation witnesses satisfiability; not a claim of production MPT or ZIP215 implementation correctness."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.Examples.accepted_l1_overflow
  unless info.isTheorem do throwError "Etna.Committee.Examples.accepted_l1_overflow is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(And
  (@Eq (Except Etna.Committee.ScheduleError Unit)
    (Etna.Committee.validate Etna.Committee.Examples.l1Overflow
      (@OfNat.ofNat Nat (nat_lit 10) (instOfNatNat (nat_lit 10))))
    (@Except.ok Etna.Committee.ScheduleError Unit Unit.unit))
  (@Eq (Option Nat)
    (Etna.Committee.l1First Etna.Committee.Examples.l1Overflow
      (@OfNat.ofNat Nat (nat_lit 1) (instOfNatNat (nat_lit 1))))
    (@Option.none Nat))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.Examples.accepted_l1_overflow: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.Examples.accepted_l1_overflow
-- COM-accepted_l2_overflow; explicit assumptions: ["Concrete finite authentication interpretation witnesses satisfiability; not a claim of production MPT or ZIP215 implementation correctness."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.Examples.accepted_l2_overflow
  unless info.isTheorem do throwError "Etna.Committee.Examples.accepted_l2_overflow is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(And
  (@Eq (Except Etna.Committee.ScheduleError Unit)
    (Etna.Committee.validate Etna.Committee.Examples.l2Overflow
      (@OfNat.ofNat Nat (nat_lit 10) (instOfNatNat (nat_lit 10))))
    (@Except.ok Etna.Committee.ScheduleError Unit Unit.unit))
  (@Eq (Option Nat)
    (Etna.Committee.first Etna.Committee.Examples.l2Overflow (@OfNat.ofNat Nat (nat_lit 1) (instOfNatNat (nat_lit 1))))
    (@Option.none Nat))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.Examples.accepted_l2_overflow: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.Examples.accepted_l2_overflow
-- COM-intermediate_last_overflow; explicit assumptions: ["Concrete finite authentication interpretation witnesses satisfiability; not a claim of production MPT or ZIP215 implementation correctness."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.Examples.intermediate_last_overflow
  unless info.isTheorem do throwError "Etna.Committee.Examples.intermediate_last_overflow is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(And
  (@Eq (Option Nat)
    (Etna.Committee.last Etna.Committee.Examples.minimal
      (@OfNat.ofNat Nat (nat_lit 6148914691236517204) (instOfNatNat (nat_lit 6148914691236517204))))
    (@Option.none Nat))
  (@Eq Nat
    (@HMul.hMul Nat Nat Nat (@instHMul Nat instMulNat)
      (@HAdd.hAdd Nat Nat Nat (@instHAdd Nat instAddNat)
        (@OfNat.ofNat Nat (nat_lit 6148914691236517204) (instOfNatNat (nat_lit 6148914691236517204)))
        (@OfNat.ofNat Nat (nat_lit 1) (instOfNatNat (nat_lit 1))))
      Etna.Committee.Examples.minimal.length)
    Etna.Committee.max64)))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.Examples.intermediate_last_overflow: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.Examples.intermediate_last_overflow
-- COM-next_is_not_representable_switch; explicit assumptions: ["Concrete finite authentication interpretation witnesses satisfiability; not a claim of production MPT or ZIP215 implementation correctness."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.Examples.next_is_not_representable_switch
  unless info.isTheorem do throwError "Etna.Committee.Examples.next_is_not_representable_switch is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(And
  (@Eq (Option Nat)
    (Etna.Committee.nextSwitch Etna.Committee.Examples.minimal
      (@HSub.hSub Nat Nat Nat (@instHSub Nat instSubNat) Etna.Committee.max64
        (@OfNat.ofNat Nat (nat_lit 1) (instOfNatNat (nat_lit 1)))))
    (@Option.some Nat (@OfNat.ofNat Nat (nat_lit 6148914691236517205) (instOfNatNat (nat_lit 6148914691236517205)))))
  (@Eq (Option Nat)
    (Etna.Committee.switchTarget Etna.Committee.Examples.minimal
      (@HSub.hSub Nat Nat Nat (@instHSub Nat instSubNat) Etna.Committee.max64
        (@OfNat.ofNat Nat (nat_lit 1) (instOfNatNat (nat_lit 1)))))
    (@Option.none Nat))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.Examples.next_is_not_representable_switch: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.Examples.next_is_not_representable_switch
-- COM-epoch_zero_special; explicit assumptions: ["Concrete finite authentication interpretation witnesses satisfiability; not a claim of production MPT or ZIP215 implementation correctness."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.Examples.epoch_zero_special
  unless info.isTheorem do throwError "Etna.Committee.Examples.epoch_zero_special is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(And
  (@Eq (Option Nat)
    (Etna.Committee.epochOf Etna.Committee.Examples.minimal (@OfNat.ofNat Nat (nat_lit 0) (instOfNatNat (nat_lit 0))))
    (@Option.some Nat (@OfNat.ofNat Nat (nat_lit 0) (instOfNatNat (nat_lit 0)))))
  (And
    (@Eq (Option Nat)
      (Etna.Committee.startingAt Etna.Committee.Examples.minimal
        (@OfNat.ofNat Nat (nat_lit 0) (instOfNatNat (nat_lit 0))))
      (@Option.none Nat))
    (@Eq (Option Nat)
      (Etna.Committee.parentHeight Etna.Committee.Examples.minimal
        (@OfNat.ofNat Nat (nat_lit 0) (instOfNatNat (nat_lit 0))))
      (@Option.none Nat)))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.Examples.epoch_zero_special: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.Examples.epoch_zero_special
-- COM-rust_accepted_l1_overflow; explicit assumptions: ["Concrete finite authentication interpretation witnesses satisfiability; not a claim of production MPT or ZIP215 implementation correctness."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.Examples.rust_accepted_l1_overflow
  unless info.isTheorem do throwError "Etna.Committee.Examples.rust_accepted_l1_overflow is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(And
  (@Eq (Aeneas.Std.Result (Aeneas.Std.core.result.Result Unit etna_consensus_core.schedule.ScheduleError))
    (Etna.Committee.Examples.rustL1Overflow.validate
      (Aeneas.Std.U64.ofNat (@OfNat.ofNat Nat (nat_lit 10) (instOfNatNat (nat_lit 10)))
        Etna.Committee.Examples.rust_accepted_l1_overflow._proof_1))
    (@Aeneas.Std.Result.ok (Aeneas.Std.core.result.Result Unit etna_consensus_core.schedule.ScheduleError)
      (@Aeneas.Std.core.result.Result.Ok Unit etna_consensus_core.schedule.ScheduleError Unit.unit)))
  (@Eq (Aeneas.Std.Result (Option Aeneas.Std.U64))
    (Etna.Committee.Examples.rustL1Overflow.checked_l1_first
      (Aeneas.Std.U64.ofNat (@OfNat.ofNat Nat (nat_lit 1) (instOfNatNat (nat_lit 1)))
        Etna.Committee.Examples.rustL2Overflow._proof_1))
    (@Aeneas.Std.Result.ok (Option Aeneas.Std.U64) (@Option.none Aeneas.Std.U64)))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.Examples.rust_accepted_l1_overflow: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.Examples.rust_accepted_l1_overflow
-- COM-rust_accepted_l2_overflow; explicit assumptions: ["Concrete finite authentication interpretation witnesses satisfiability; not a claim of production MPT or ZIP215 implementation correctness."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.Examples.rust_accepted_l2_overflow
  unless info.isTheorem do throwError "Etna.Committee.Examples.rust_accepted_l2_overflow is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(And
  (@Eq (Aeneas.Std.Result (Aeneas.Std.core.result.Result Unit etna_consensus_core.schedule.ScheduleError))
    (Etna.Committee.Examples.rustL2Overflow.validate
      (Aeneas.Std.U64.ofNat (@OfNat.ofNat Nat (nat_lit 10) (instOfNatNat (nat_lit 10)))
        Etna.Committee.Examples.rust_accepted_l1_overflow._proof_1))
    (@Aeneas.Std.Result.ok (Aeneas.Std.core.result.Result Unit etna_consensus_core.schedule.ScheduleError)
      (@Aeneas.Std.core.result.Result.Ok Unit etna_consensus_core.schedule.ScheduleError Unit.unit)))
  (@Eq (Aeneas.Std.Result (Option Aeneas.Std.U64))
    (Etna.Committee.Examples.rustL2Overflow.h_first
      (Aeneas.Std.U64.ofNat (@OfNat.ofNat Nat (nat_lit 1) (instOfNatNat (nat_lit 1)))
        Etna.Committee.Examples.rustL2Overflow._proof_1))
    (@Aeneas.Std.Result.ok (Option Aeneas.Std.U64) (@Option.none Aeneas.Std.U64)))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.Examples.rust_accepted_l2_overflow: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.Examples.rust_accepted_l2_overflow
-- COM-rust_valid_first_transition; explicit assumptions: ["Concrete finite authentication interpretation witnesses satisfiability; not a claim of production MPT or ZIP215 implementation correctness."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.Examples.rust_valid_first_transition
  unless info.isTheorem do throwError "Etna.Committee.Examples.rust_valid_first_transition is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(And
  (@Eq (Aeneas.Std.Result (Aeneas.Std.core.result.Result Unit etna_consensus_core.schedule.ScheduleError))
    (Etna.Committee.Examples.rustOrdinary.validate
      (Aeneas.Std.U64.ofNat (@OfNat.ofNat Nat (nat_lit 10) (instOfNatNat (nat_lit 10)))
        Etna.Committee.Examples.rust_accepted_l1_overflow._proof_1))
    (@Aeneas.Std.Result.ok (Aeneas.Std.core.result.Result Unit etna_consensus_core.schedule.ScheduleError)
      (@Aeneas.Std.core.result.Result.Ok Unit etna_consensus_core.schedule.ScheduleError Unit.unit)))
  (And
    (@Eq (Aeneas.Std.Result (Option Aeneas.Std.U64))
      (Etna.Committee.Examples.rustOrdinary.h_first
        (Aeneas.Std.U64.ofNat (@OfNat.ofNat Nat (nat_lit 1) (instOfNatNat (nat_lit 1)))
          Etna.Committee.Examples.rustL2Overflow._proof_1))
      (@Aeneas.Std.Result.ok (Option Aeneas.Std.U64)
        (@Option.some Aeneas.Std.U64
          (Aeneas.Std.U64.ofNat (@OfNat.ofNat Nat (nat_lit 21) (instOfNatNat (nat_lit 21)))
            Etna.Committee.Examples.rust_valid_first_transition._proof_1))))
    (@Eq (Aeneas.Std.Result (Option Aeneas.Std.U64))
      (Etna.Committee.Examples.rustOrdinary.checked_l1_first
        (Aeneas.Std.U64.ofNat (@OfNat.ofNat Nat (nat_lit 1) (instOfNatNat (nat_lit 1)))
          Etna.Committee.Examples.rustL2Overflow._proof_1))
      (@Aeneas.Std.Result.ok (Option Aeneas.Std.U64)
        (@Option.some Aeneas.Std.U64
          (Aeneas.Std.U64.ofNat (@OfNat.ofNat Nat (nat_lit 65) (instOfNatNat (nat_lit 65)))
            Etna.Committee.Examples.rust_valid_first_transition._proof_2)))))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.Examples.rust_valid_first_transition: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.Examples.rust_valid_first_transition
-- COM-nonempty_switch_replay; explicit assumptions: ["Concrete finite authentication interpretation witnesses satisfiability; not a claim of production MPT or ZIP215 implementation correctness."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.Examples.nonempty_switch_replay
  unless info.isTheorem do throwError "Etna.Committee.Examples.nonempty_switch_replay is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(@Eq (Except Etna.Committee.Failure (Prod Etna.Committee.CommitteeState Etna.Committee.Updates))
  (Etna.Committee.replay Etna.Committee.Examples.ctx Etna.Committee.Examples.history Etna.Committee.Examples.initial)
  (@Except.ok Etna.Committee.Failure (Prod Etna.Committee.CommitteeState Etna.Committee.Updates)
    (@Prod.mk Etna.Committee.CommitteeState Etna.Committee.Updates Etna.Committee.Examples.finalState
      (@List.cons (Prod Etna.Committee.Record Etna.Committee.Record)
        (@Prod.mk Etna.Committee.Record Etna.Committee.Record Etna.Committee.Examples.outgoingRecord
          Etna.Committee.Examples.incomingRecord)
        (@List.nil (Prod Etna.Committee.Record Etna.Committee.Record)))))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.Examples.nonempty_switch_replay: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.Examples.nonempty_switch_replay
-- COM-missing_pending_scalar; explicit assumptions: ["Concrete finite authentication interpretation witnesses satisfiability; not a claim of production MPT or ZIP215 implementation correctness."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.Examples.missing_pending_scalar
  unless info.isTheorem do throwError "Etna.Committee.Examples.missing_pending_scalar is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(@Eq (Except Etna.Committee.Failure Etna.Committee.Plan)
  (Etna.Committee.plan Etna.Committee.Examples.schedule (@OfNat.ofNat Nat (nat_lit 5) (instOfNatNat (nat_lit 5)))
    Etna.Committee.Relation.none Bool.true Bool.false)
  (@Except.error Etna.Committee.Failure Etna.Committee.Plan
    (Etna.Committee.Failure.unknown (@OfNat.ofNat Nat (nat_lit 1) (instOfNatNat (nat_lit 1)))))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.Examples.missing_pending_scalar: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.Examples.missing_pending_scalar
-- COM-empty_incoming_rejected; explicit assumptions: ["Concrete finite authentication interpretation witnesses satisfiability; not a claim of production MPT or ZIP215 implementation correctness."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.Examples.empty_incoming_rejected
  unless info.isTheorem do throwError "Etna.Committee.Examples.empty_incoming_rejected is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(@Eq (Except Etna.Committee.Failure (Option Etna.Committee.Record))
  (Etna.Committee.incoming Etna.Committee.Examples.emptyAuth Etna.Committee.Examples.schedule
    Etna.Committee.Examples.initial.anchor (@OfNat.ofNat Nat (nat_lit 5) (instOfNatNat (nat_lit 5)))
    (@Option.some Etna.Committee.Witness
      { snapshot := Etna.Committee.Examples.snap,
        proof := @List.cons Nat (@OfNat.ofNat Nat (nat_lit 42) (instOfNatNat (nat_lit 42))) (@List.nil Nat) }))
  (@Except.error Etna.Committee.Failure (Option Etna.Committee.Record) Etna.Committee.Failure.empty)))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.Examples.empty_incoming_rejected: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.Examples.empty_incoming_rejected
-- COM-zero_cap_bootstrap; explicit assumptions: ["Concrete finite authentication interpretation witnesses satisfiability; not a claim of production MPT or ZIP215 implementation correctness."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.Examples.zero_cap_bootstrap
  unless info.isTheorem do throwError "Etna.Committee.Examples.zero_cap_bootstrap is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(And
  (@Eq (Except Etna.Committee.ScheduleError Unit)
    (Etna.Committee.validate Etna.Committee.Examples.schedule (@OfNat.ofNat Nat (nat_lit 0) (instOfNatNat (nat_lit 0))))
    (@Except.ok Etna.Committee.ScheduleError Unit Unit.unit))
  (And
    (@Eq (Option Nat)
      (Etna.Committee.unsettledCap (@OfNat.ofNat Nat (nat_lit 2) (instOfNatNat (nat_lit 2)))
        (@OfNat.ofNat Nat (nat_lit 2) (instOfNatNat (nat_lit 2))))
      (@Option.some Nat (@OfNat.ofNat Nat (nat_lit 0) (instOfNatNat (nat_lit 0)))))
    (@Eq (Except Etna.Committee.Failure (Prod Etna.Committee.CommitteeState Etna.Committee.Updates))
      (Etna.Committee.step Etna.Committee.Examples.stopped Etna.Committee.Examples.initial
        Etna.Committee.Examples.firstStopped)
      (@Except.error Etna.Committee.Failure (Prod Etna.Committee.CommitteeState Etna.Committee.Updates)
        Etna.Committee.Failure.backPressure)))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.Examples.zero_cap_bootstrap: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.Examples.zero_cap_bootstrap
-- COM-zero_cap_ahead_checkpoint; explicit assumptions: ["Concrete finite authentication interpretation witnesses satisfiability; not a claim of production MPT or ZIP215 implementation correctness."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.Examples.zero_cap_ahead_checkpoint
  unless info.isTheorem do throwError "Etna.Committee.Examples.zero_cap_ahead_checkpoint is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(@LE.le Nat instLENat
  (@HSub.hSub Nat Nat Nat (@instHSub Nat instSubNat) (@OfNat.ofNat Nat (nat_lit 1) (instOfNatNat (nat_lit 1)))
    (@OfNat.ofNat Nat (nat_lit 2) (instOfNatNat (nat_lit 2))))
  (@OfNat.ofNat Nat (nat_lit 0) (instOfNatNat (nat_lit 0)))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.Examples.zero_cap_ahead_checkpoint: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.Examples.zero_cap_ahead_checkpoint
-- COM-nonempty_activation_pair; explicit assumptions: ["Concrete finite authentication interpretation witnesses satisfiability; not a claim of production MPT or ZIP215 implementation correctness."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Committee.Examples.nonempty_activation_pair
  unless info.isTheorem do throwError "Etna.Committee.Examples.nonempty_activation_pair is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(And
  (@Eq Etna.Committee.Record
    (Etna.Committee.Examples.concreteComet.observed (@OfNat.ofNat Nat (nat_lit 5) (instOfNatNat (nat_lit 5)))
      Etna.Committee.Examples.outgoingRecord Etna.Committee.Examples.incomingRecord
      (@OfNat.ofNat Nat (nat_lit 6) (instOfNatNat (nat_lit 6))))
    Etna.Committee.Examples.outgoingRecord)
  (@Eq Etna.Committee.Record
    (Etna.Committee.Examples.concreteComet.observed (@OfNat.ofNat Nat (nat_lit 5) (instOfNatNat (nat_lit 5)))
      Etna.Committee.Examples.outgoingRecord Etna.Committee.Examples.incomingRecord
      (@OfNat.ofNat Nat (nat_lit 7) (instOfNatNat (nat_lit 7))))
    Etna.Committee.Examples.incomingRecord)))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Committee.Examples.nonempty_activation_pair: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Committee.Examples.nonempty_activation_pair
-- COM-checked_add; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.Committee.checked_add
  unless info.isTheorem do throwError "Etna.Refinement.Rust.Committee.checked_add is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (a b : Aeneas.Std.U64),
  @Eq (Option Aeneas.Std.U64) (a.checked_add b)
    (@Option.map Nat Aeneas.Std.U64 Etna.Refinement.Rust.word
      (Etna.Committee.add (@Aeneas.Std.UScalar.val Aeneas.Std.UScalarTy.U64 a)
        (@Aeneas.Std.UScalar.val Aeneas.Std.UScalarTy.U64 b)))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Refinement.Rust.Committee.checked_add: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Refinement.Rust.Committee.checked_add
-- COM-checked_mul; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.Committee.checked_mul
  unless info.isTheorem do throwError "Etna.Refinement.Rust.Committee.checked_mul is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (a b : Aeneas.Std.U64),
  @Eq (Option Aeneas.Std.U64) (a.checked_mul b)
    (@Option.map Nat Aeneas.Std.U64 Etna.Refinement.Rust.word
      (Etna.Committee.mul (@Aeneas.Std.UScalar.val Aeneas.Std.UScalarTy.U64 a)
        (@Aeneas.Std.UScalar.val Aeneas.Std.UScalarTy.U64 b)))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Refinement.Rust.Committee.checked_mul: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Refinement.Rust.Committee.checked_mul
-- COM-checked_sub; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.Committee.checked_sub
  unless info.isTheorem do throwError "Etna.Refinement.Rust.Committee.checked_sub is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (a b : Aeneas.Std.U64),
  @Eq (Option Aeneas.Std.U64) (a.checked_sub b)
    (@Option.map Nat Aeneas.Std.U64 Etna.Refinement.Rust.word
      (Etna.Committee.sub (@Aeneas.Std.UScalar.val Aeneas.Std.UScalarTy.U64 a)
        (@Aeneas.Std.UScalar.val Aeneas.Std.UScalarTy.U64 b)))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Refinement.Rust.Committee.checked_sub: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Refinement.Rust.Committee.checked_sub
-- COM-checked_div; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.Committee.checked_div
  unless info.isTheorem do throwError "Etna.Refinement.Rust.Committee.checked_div is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (a b : Aeneas.Std.U64),
  @Eq (Option Aeneas.Std.U64) (a.checked_div b)
    (@Option.map Nat Aeneas.Std.U64 Etna.Refinement.Rust.word
      (Etna.Committee.div (@Aeneas.Std.UScalar.val Aeneas.Std.UScalarTy.U64 a)
        (@Aeneas.Std.UScalar.val Aeneas.Std.UScalarTy.U64 b)))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Refinement.Rust.Committee.checked_div: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Refinement.Rust.Committee.checked_div
-- COM-checked_bound; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.Committee.checked_bound
  unless info.isTheorem do throwError "Etna.Refinement.Rust.Committee.checked_bound is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ {n v : Nat},
  @Eq (Option Nat) (Etna.Committee.checked n) (@Option.some Nat v) →
    @LT.lt Nat instLTNat v
      (@HPow.hPow Nat Nat Nat (@instHPow Nat Nat (@NPow.toPow Nat (@Monoid.toNPow Nat Nat.instMonoid)))
        (@OfNat.ofNat Nat (nat_lit 2) (instOfNatNat (nat_lit 2)))
        (@OfNat.ofNat Nat (nat_lit 64) (instOfNatNat (nat_lit 64))))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Refinement.Rust.Committee.checked_bound: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Refinement.Rust.Committee.checked_bound
-- COM-rust_validate_refines; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.Committee.rust_validate_refines
  unless info.isTheorem do throwError "Etna.Refinement.Rust.Committee.rust_validate_refines is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (s : etna_consensus_core.schedule.Schedule) (cap : Aeneas.Std.U64),
  @Eq (Aeneas.Std.Result (Aeneas.Std.core.result.Result Unit etna_consensus_core.schedule.ScheduleError))
    (s.validate cap)
    (@Aeneas.Std.Result.ok (Aeneas.Std.core.result.Result Unit etna_consensus_core.schedule.ScheduleError)
      (Etna.Refinement.Rust.Committee.scheduleResult
        (Etna.Committee.validate (Etna.Refinement.Rust.Committee.schedule s)
          (@Aeneas.Std.UScalar.val Aeneas.Std.UScalarTy.U64 cap))))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Refinement.Rust.Committee.rust_validate_refines: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Refinement.Rust.Committee.rust_validate_refines
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.Committee.rust_validate_refines
  Lean.Meta.forallTelescopeReducing info.type fun _ body => do
    let body ← Lean.Meta.whnf body
    unless body.isAppOfArity ``Eq 3 do
      throwError "refinement must be an exact total output equality"
    let args := body.getAppArgs
    unless args[1]!.getAppFn.isConstOf `etna_consensus_core.schedule.Schedule.validate do
      throwError "refinement left side must call the generated function"
    unless args[2]!.getAppFn.isConstOf ``Aeneas.Std.Result.ok do
      throwError "refinement right side must be outer Result.ok"
-- COM-word_small; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.Committee.word_small
  unless info.isTheorem do throwError "Etna.Refinement.Rust.Committee.word_small is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ {n : Nat},
  @LT.lt Nat instLTNat n
      (@HPow.hPow Nat Nat Nat (@instHPow Nat Nat (@NPow.toPow Nat (@Monoid.toNPow Nat Nat.instMonoid)))
        (@OfNat.ofNat Nat (nat_lit 2) (instOfNatNat (nat_lit 2)))
        (@OfNat.ofNat Nat (nat_lit 64) (instOfNatNat (nat_lit 64)))) →
    @Eq Nat (@Aeneas.Std.UScalar.val Aeneas.Std.UScalarTy.U64 (Etna.Refinement.Rust.word n)) n))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Refinement.Rust.Committee.word_small: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Refinement.Rust.Committee.word_small
-- COM-rust_first_refines; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.Committee.rust_first_refines
  unless info.isTheorem do throwError "Etna.Refinement.Rust.Committee.rust_first_refines is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (s : etna_consensus_core.schedule.Schedule) (t : Aeneas.Std.U64),
  @Eq (Aeneas.Std.Result (Option Aeneas.Std.U64)) (s.h_first t)
    (@Aeneas.Std.Result.ok (Option Aeneas.Std.U64)
      (@Option.map Nat Aeneas.Std.U64 Etna.Refinement.Rust.word
        (Etna.Committee.first (Etna.Refinement.Rust.Committee.schedule s)
          (@Aeneas.Std.UScalar.val Aeneas.Std.UScalarTy.U64 t))))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Refinement.Rust.Committee.rust_first_refines: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Refinement.Rust.Committee.rust_first_refines
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.Committee.rust_first_refines
  Lean.Meta.forallTelescopeReducing info.type fun _ body => do
    let body ← Lean.Meta.whnf body
    unless body.isAppOfArity ``Eq 3 do
      throwError "refinement must be an exact total output equality"
    let args := body.getAppArgs
    unless args[1]!.getAppFn.isConstOf `etna_consensus_core.schedule.Schedule.h_first do
      throwError "refinement left side must call the generated function"
    unless args[2]!.getAppFn.isConstOf ``Aeneas.Std.Result.ok do
      throwError "refinement right side must be outer Result.ok"
-- COM-first_bound; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.Committee.first_bound
  unless info.isTheorem do throwError "Etna.Refinement.Rust.Committee.first_bound is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ {s : Etna.Committee.Schedule} {t v : Nat},
  @Eq (Option Nat) (Etna.Committee.first s t) (@Option.some Nat v) →
    @LT.lt Nat instLTNat v
      (@HPow.hPow Nat Nat Nat (@instHPow Nat Nat (@NPow.toPow Nat (@Monoid.toNPow Nat Nat.instMonoid)))
        (@OfNat.ofNat Nat (nat_lit 2) (instOfNatNat (nat_lit 2)))
        (@OfNat.ofNat Nat (nat_lit 64) (instOfNatNat (nat_lit 64))))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Refinement.Rust.Committee.first_bound: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Refinement.Rust.Committee.first_bound
-- COM-rust_last_refines; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.Committee.rust_last_refines
  unless info.isTheorem do throwError "Etna.Refinement.Rust.Committee.rust_last_refines is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (s : etna_consensus_core.schedule.Schedule) (t : Aeneas.Std.U64),
  @Eq (Aeneas.Std.Result (Option Aeneas.Std.U64)) (s.h_last t)
    (@Aeneas.Std.Result.ok (Option Aeneas.Std.U64)
      (@Option.map Nat Aeneas.Std.U64 Etna.Refinement.Rust.word
        (Etna.Committee.last (Etna.Refinement.Rust.Committee.schedule s)
          (@Aeneas.Std.UScalar.val Aeneas.Std.UScalarTy.U64 t))))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Refinement.Rust.Committee.rust_last_refines: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Refinement.Rust.Committee.rust_last_refines
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.Committee.rust_last_refines
  Lean.Meta.forallTelescopeReducing info.type fun _ body => do
    let body ← Lean.Meta.whnf body
    unless body.isAppOfArity ``Eq 3 do
      throwError "refinement must be an exact total output equality"
    let args := body.getAppArgs
    unless args[1]!.getAppFn.isConstOf `etna_consensus_core.schedule.Schedule.h_last do
      throwError "refinement left side must call the generated function"
    unless args[2]!.getAppFn.isConstOf ``Aeneas.Std.Result.ok do
      throwError "refinement right side must be outer Result.ok"
-- COM-rust_l1First_refines; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.Committee.rust_l1First_refines
  unless info.isTheorem do throwError "Etna.Refinement.Rust.Committee.rust_l1First_refines is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (s : etna_consensus_core.schedule.Schedule) (t : Aeneas.Std.U64),
  @Eq (Aeneas.Std.Result (Option Aeneas.Std.U64)) (s.checked_l1_first t)
    (@Aeneas.Std.Result.ok (Option Aeneas.Std.U64)
      (@Option.map Nat Aeneas.Std.U64 Etna.Refinement.Rust.word
        (Etna.Committee.l1First (Etna.Refinement.Rust.Committee.schedule s)
          (@Aeneas.Std.UScalar.val Aeneas.Std.UScalarTy.U64 t))))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Refinement.Rust.Committee.rust_l1First_refines: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Refinement.Rust.Committee.rust_l1First_refines
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.Committee.rust_l1First_refines
  Lean.Meta.forallTelescopeReducing info.type fun _ body => do
    let body ← Lean.Meta.whnf body
    unless body.isAppOfArity ``Eq 3 do
      throwError "refinement must be an exact total output equality"
    let args := body.getAppArgs
    unless args[1]!.getAppFn.isConstOf `etna_consensus_core.schedule.Schedule.checked_l1_first do
      throwError "refinement left side must call the generated function"
    unless args[2]!.getAppFn.isConstOf ``Aeneas.Std.Result.ok do
      throwError "refinement right side must be outer Result.ok"
-- COM-rust_parent_refines; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.Committee.rust_parent_refines
  unless info.isTheorem do throwError "Etna.Refinement.Rust.Committee.rust_parent_refines is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (s : etna_consensus_core.schedule.Schedule) (t : Aeneas.Std.U64),
  @Eq (Aeneas.Std.Result (Option Aeneas.Std.U64)) (s.derivation_parent_height t)
    (@Aeneas.Std.Result.ok (Option Aeneas.Std.U64)
      (@Option.map Nat Aeneas.Std.U64 Etna.Refinement.Rust.word
        (Etna.Committee.parentHeight (Etna.Refinement.Rust.Committee.schedule s)
          (@Aeneas.Std.UScalar.val Aeneas.Std.UScalarTy.U64 t))))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Refinement.Rust.Committee.rust_parent_refines: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Refinement.Rust.Committee.rust_parent_refines
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.Committee.rust_parent_refines
  Lean.Meta.forallTelescopeReducing info.type fun _ body => do
    let body ← Lean.Meta.whnf body
    unless body.isAppOfArity ``Eq 3 do
      throwError "refinement must be an exact total output equality"
    let args := body.getAppArgs
    unless args[1]!.getAppFn.isConstOf `etna_consensus_core.schedule.Schedule.derivation_parent_height do
      throwError "refinement left side must call the generated function"
    unless args[2]!.getAppFn.isConstOf ``Aeneas.Std.Result.ok do
      throwError "refinement right side must be outer Result.ok"
-- COM-saturating_val; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.Committee.saturating_val
  unless info.isTheorem do throwError "Etna.Refinement.Rust.Committee.saturating_val is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (h : Aeneas.Std.U64),
  @Eq Nat
    (@Aeneas.Std.UScalar.val Aeneas.Std.UScalarTy.U64
      (Aeneas.Std.core.num.U64.saturating_sub h
        (Aeneas.Std.U64.ofNat (@OfNat.ofNat Nat (nat_lit 1) (instOfNatNat (nat_lit 1)))
          Etna.Refinement.Rust.Committee.saturating_val._proof_1)))
    (@HSub.hSub Nat Nat Nat (@instHSub Nat instSubNat) (@Aeneas.Std.UScalar.val Aeneas.Std.UScalarTy.U64 h)
      (@OfNat.ofNat Nat (nat_lit 1) (instOfNatNat (nat_lit 1))))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Refinement.Rust.Committee.saturating_val: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Refinement.Rust.Committee.saturating_val
-- COM-rust_epoch_refines; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.Committee.rust_epoch_refines
  unless info.isTheorem do throwError "Etna.Refinement.Rust.Committee.rust_epoch_refines is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (s : etna_consensus_core.schedule.Schedule) (h : Aeneas.Std.U64),
  @Eq (Aeneas.Std.Result (Option Aeneas.Std.U64)) (s.epoch_of h)
    (@Aeneas.Std.Result.ok (Option Aeneas.Std.U64)
      (@Option.map Nat Aeneas.Std.U64 Etna.Refinement.Rust.word
        (Etna.Committee.epochOf (Etna.Refinement.Rust.Committee.schedule s)
          (@Aeneas.Std.UScalar.val Aeneas.Std.UScalarTy.U64 h))))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Refinement.Rust.Committee.rust_epoch_refines: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Refinement.Rust.Committee.rust_epoch_refines
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.Committee.rust_epoch_refines
  Lean.Meta.forallTelescopeReducing info.type fun _ body => do
    let body ← Lean.Meta.whnf body
    unless body.isAppOfArity ``Eq 3 do
      throwError "refinement must be an exact total output equality"
    let args := body.getAppArgs
    unless args[1]!.getAppFn.isConstOf `etna_consensus_core.schedule.Schedule.epoch_of do
      throwError "refinement left side must call the generated function"
    unless args[2]!.getAppFn.isConstOf ``Aeneas.Std.Result.ok do
      throwError "refinement right side must be outer Result.ok"
-- COM-sub_bound; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.Committee.sub_bound
  unless info.isTheorem do throwError "Etna.Refinement.Rust.Committee.sub_bound is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ {a b v : Nat},
  @Eq (Option Nat) (Etna.Committee.sub a b) (@Option.some Nat v) →
    @LT.lt Nat instLTNat a
        (@HPow.hPow Nat Nat Nat (@instHPow Nat Nat (@NPow.toPow Nat (@Monoid.toNPow Nat Nat.instMonoid)))
          (@OfNat.ofNat Nat (nat_lit 2) (instOfNatNat (nat_lit 2)))
          (@OfNat.ofNat Nat (nat_lit 64) (instOfNatNat (nat_lit 64)))) →
      @LT.lt Nat instLTNat v
        (@HPow.hPow Nat Nat Nat (@instHPow Nat Nat (@NPow.toPow Nat (@Monoid.toNPow Nat Nat.instMonoid)))
          (@OfNat.ofNat Nat (nat_lit 2) (instOfNatNat (nat_lit 2)))
          (@OfNat.ofNat Nat (nat_lit 64) (instOfNatNat (nat_lit 64))))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Refinement.Rust.Committee.sub_bound: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Refinement.Rust.Committee.sub_bound
-- COM-rust_starting_refines; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.Committee.rust_starting_refines
  unless info.isTheorem do throwError "Etna.Refinement.Rust.Committee.rust_starting_refines is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (s : etna_consensus_core.schedule.Schedule) (h : Aeneas.Std.U64),
  @Eq (Aeneas.Std.Result (Option Aeneas.Std.U64)) (s.epoch_starting_at h)
    (@Aeneas.Std.Result.ok (Option Aeneas.Std.U64)
      (@Option.map Nat Aeneas.Std.U64 Etna.Refinement.Rust.word
        (Etna.Committee.startingAt (Etna.Refinement.Rust.Committee.schedule s)
          (@Aeneas.Std.UScalar.val Aeneas.Std.UScalarTy.U64 h))))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Refinement.Rust.Committee.rust_starting_refines: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Refinement.Rust.Committee.rust_starting_refines
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.Committee.rust_starting_refines
  Lean.Meta.forallTelescopeReducing info.type fun _ body => do
    let body ← Lean.Meta.whnf body
    unless body.isAppOfArity ``Eq 3 do
      throwError "refinement must be an exact total output equality"
    let args := body.getAppArgs
    unless args[1]!.getAppFn.isConstOf `etna_consensus_core.schedule.Schedule.epoch_starting_at do
      throwError "refinement left side must call the generated function"
    unless args[2]!.getAppFn.isConstOf ``Aeneas.Std.Result.ok do
      throwError "refinement right side must be outer Result.ok"
-- COM-starting_bound; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.Committee.starting_bound
  unless info.isTheorem do throwError "Etna.Refinement.Rust.Committee.starting_bound is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ {s : Etna.Committee.Schedule} {h t : Nat},
  @Eq (Option Nat) (Etna.Committee.startingAt s h) (@Option.some Nat t) →
    @LT.lt Nat instLTNat h
        (@HPow.hPow Nat Nat Nat (@instHPow Nat Nat (@NPow.toPow Nat (@Monoid.toNPow Nat Nat.instMonoid)))
          (@OfNat.ofNat Nat (nat_lit 2) (instOfNatNat (nat_lit 2)))
          (@OfNat.ofNat Nat (nat_lit 64) (instOfNatNat (nat_lit 64)))) →
      @LT.lt Nat instLTNat t
        (@HPow.hPow Nat Nat Nat (@instHPow Nat Nat (@NPow.toPow Nat (@Monoid.toNPow Nat Nat.instMonoid)))
          (@OfNat.ofNat Nat (nat_lit 2) (instOfNatNat (nat_lit 2)))
          (@OfNat.ofNat Nat (nat_lit 64) (instOfNatNat (nat_lit 64))))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Refinement.Rust.Committee.starting_bound: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Refinement.Rust.Committee.starting_bound
-- COM-rust_switch_refines; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.Committee.rust_switch_refines
  unless info.isTheorem do throwError "Etna.Refinement.Rust.Committee.rust_switch_refines is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (s : etna_consensus_core.schedule.Schedule) (h : Aeneas.Std.U64),
  @Eq (Aeneas.Std.Result (Option Aeneas.Std.U64)) (s.switch_target h)
    (@Aeneas.Std.Result.ok (Option Aeneas.Std.U64)
      (@Option.map Nat Aeneas.Std.U64 Etna.Refinement.Rust.word
        (Etna.Committee.switchTarget (Etna.Refinement.Rust.Committee.schedule s)
          (@Aeneas.Std.UScalar.val Aeneas.Std.UScalarTy.U64 h))))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Refinement.Rust.Committee.rust_switch_refines: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Refinement.Rust.Committee.rust_switch_refines
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.Committee.rust_switch_refines
  Lean.Meta.forallTelescopeReducing info.type fun _ body => do
    let body ← Lean.Meta.whnf body
    unless body.isAppOfArity ``Eq 3 do
      throwError "refinement must be an exact total output equality"
    let args := body.getAppArgs
    unless args[1]!.getAppFn.isConstOf `etna_consensus_core.schedule.Schedule.switch_target do
      throwError "refinement left side must call the generated function"
    unless args[2]!.getAppFn.isConstOf ``Aeneas.Std.Result.ok do
      throwError "refinement right side must be outer Result.ok"
-- COM-epoch_bound; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.Committee.epoch_bound
  unless info.isTheorem do throwError "Etna.Refinement.Rust.Committee.epoch_bound is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ {s : Etna.Committee.Schedule} {h t : Nat},
  @Eq (Option Nat) (Etna.Committee.epochOf s h) (@Option.some Nat t) →
    @LT.lt Nat instLTNat h
        (@HPow.hPow Nat Nat Nat (@instHPow Nat Nat (@NPow.toPow Nat (@Monoid.toNPow Nat Nat.instMonoid)))
          (@OfNat.ofNat Nat (nat_lit 2) (instOfNatNat (nat_lit 2)))
          (@OfNat.ofNat Nat (nat_lit 64) (instOfNatNat (nat_lit 64)))) →
      @LT.lt Nat instLTNat t
        (@HPow.hPow Nat Nat Nat (@instHPow Nat Nat (@NPow.toPow Nat (@Monoid.toNPow Nat Nat.instMonoid)))
          (@OfNat.ofNat Nat (nat_lit 2) (instOfNatNat (nat_lit 2)))
          (@OfNat.ofNat Nat (nat_lit 64) (instOfNatNat (nat_lit 64))))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Refinement.Rust.Committee.epoch_bound: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Refinement.Rust.Committee.epoch_bound
-- COM-rust_next_refines; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.Committee.rust_next_refines
  unless info.isTheorem do throwError "Etna.Refinement.Rust.Committee.rust_next_refines is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (s : etna_consensus_core.schedule.Schedule) (h : Aeneas.Std.U64),
  @Eq (Aeneas.Std.Result (Option Aeneas.Std.U64)) (s.next_switch_target h)
    (@Aeneas.Std.Result.ok (Option Aeneas.Std.U64)
      (@Option.map Nat Aeneas.Std.U64 Etna.Refinement.Rust.word
        (Etna.Committee.nextSwitch (Etna.Refinement.Rust.Committee.schedule s)
          (@Aeneas.Std.UScalar.val Aeneas.Std.UScalarTy.U64 h))))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Refinement.Rust.Committee.rust_next_refines: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Refinement.Rust.Committee.rust_next_refines
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.Committee.rust_next_refines
  Lean.Meta.forallTelescopeReducing info.type fun _ body => do
    let body ← Lean.Meta.whnf body
    unless body.isAppOfArity ``Eq 3 do
      throwError "refinement must be an exact total output equality"
    let args := body.getAppArgs
    unless args[1]!.getAppFn.isConstOf `etna_consensus_core.schedule.Schedule.next_switch_target do
      throwError "refinement left side must call the generated function"
    unless args[2]!.getAppFn.isConstOf ``Aeneas.Std.Result.ok do
      throwError "refinement right side must be outer Result.ok"
-- COM-rust_quorum_refines; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.Committee.rust_quorum_refines
  unless info.isTheorem do throwError "Etna.Refinement.Rust.Committee.rust_quorum_refines is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (signed total : Aeneas.Std.U128),
  @Eq (Aeneas.Std.Result Bool) (etna_consensus_core.has_strict_quorum signed total)
    (@Aeneas.Std.Result.ok Bool
      (@Decidable.decide
        (@GT.gt Nat instLTNat
          (@HMul.hMul Nat Nat Nat (@instHMul Nat instMulNat) (@OfNat.ofNat Nat (nat_lit 3) (instOfNatNat (nat_lit 3)))
            (@Aeneas.Std.UScalar.val Aeneas.Std.UScalarTy.U128 signed))
          (@HMul.hMul Nat Nat Nat (@instHMul Nat instMulNat) (@OfNat.ofNat Nat (nat_lit 2) (instOfNatNat (nat_lit 2)))
            (@Aeneas.Std.UScalar.val Aeneas.Std.UScalarTy.U128 total)))
        ((@HMul.hMul Nat Nat Nat (@instHMul Nat instMulNat) (@OfNat.ofNat Nat (nat_lit 2) (instOfNatNat (nat_lit 2)))
              (@Aeneas.Std.UScalar.val Aeneas.Std.UScalarTy.U128 total)).decLt
          (@HMul.hMul Nat Nat Nat (@instHMul Nat instMulNat) (@OfNat.ofNat Nat (nat_lit 3) (instOfNatNat (nat_lit 3)))
            (@Aeneas.Std.UScalar.val Aeneas.Std.UScalarTy.U128 signed)))))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Refinement.Rust.Committee.rust_quorum_refines: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Refinement.Rust.Committee.rust_quorum_refines
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.Committee.rust_quorum_refines
  Lean.Meta.forallTelescopeReducing info.type fun _ body => do
    let body ← Lean.Meta.whnf body
    unless body.isAppOfArity ``Eq 3 do
      throwError "refinement must be an exact total output equality"
    let args := body.getAppArgs
    unless args[1]!.getAppFn.isConstOf `etna_consensus_core.has_strict_quorum do
      throwError "refinement left side must call the generated function"
    unless args[2]!.getAppFn.isConstOf ``Aeneas.Std.Result.ok do
      throwError "refinement right side must be outer Result.ok"
-- COM-switch_bound; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.Committee.switch_bound
  unless info.isTheorem do throwError "Etna.Refinement.Rust.Committee.switch_bound is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ {s : Etna.Committee.Schedule} {h t : Nat},
  @Eq (Option Nat) (Etna.Committee.switchTarget s h) (@Option.some Nat t) →
    @LT.lt Nat instLTNat t
      (@HPow.hPow Nat Nat Nat (@instHPow Nat Nat (@NPow.toPow Nat (@Monoid.toNPow Nat Nat.instMonoid)))
        (@OfNat.ofNat Nat (nat_lit 2) (instOfNatNat (nat_lit 2)))
        (@OfNat.ofNat Nat (nat_lit 64) (instOfNatNat (nat_lit 64))))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Refinement.Rust.Committee.switch_bound: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Refinement.Rust.Committee.switch_bound
-- COM-rust_transition_refines; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.Committee.rust_transition_refines
  unless info.isTheorem do throwError "Etna.Refinement.Rust.Committee.rust_transition_refines is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (s : etna_consensus_core.schedule.Schedule) (h : Aeneas.Std.U64) (f : etna_consensus_core.transition.CommitteeFacts),
  @Eq
    (Aeneas.Std.Result
      (Aeneas.Std.core.result.Result etna_consensus_core.transition.CommitteePlan
        etna_consensus_core.transition.CommitteeError))
    (etna_consensus_core.transition.transition_committee s h f)
    (@Aeneas.Std.Result.ok
      (Aeneas.Std.core.result.Result etna_consensus_core.transition.CommitteePlan
        etna_consensus_core.transition.CommitteeError)
      (Etna.Refinement.Rust.Committee.planResult
        (Etna.Committee.plan (Etna.Refinement.Rust.Committee.schedule s)
          (@Aeneas.Std.UScalar.val Aeneas.Std.UScalarTy.U64 h) (Etna.Refinement.Rust.Committee.modelRelation f.derived)
          f.outgoing_known f.incoming_known)))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Refinement.Rust.Committee.rust_transition_refines: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Refinement.Rust.Committee.rust_transition_refines
run_elab do
  let info ← Lean.getConstInfo `Etna.Refinement.Rust.Committee.rust_transition_refines
  Lean.Meta.forallTelescopeReducing info.type fun _ body => do
    let body ← Lean.Meta.whnf body
    unless body.isAppOfArity ``Eq 3 do
      throwError "refinement must be an exact total output equality"
    let args := body.getAppArgs
    unless args[1]!.getAppFn.isConstOf `etna_consensus_core.transition.transition_committee do
      throwError "refinement left side must call the generated function"
    unless args[2]!.getAppFn.isConstOf ``Aeneas.Std.Result.ok do
      throwError "refinement right side must be outer Result.ok"
-- LAND-AUX-01; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.wordAt_encode
  unless info.isTheorem do throwError "Etna.Landing.wordAt_encode is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (s : Etna.Landing.LandStatement) (i : Fin 18), Etna.Landing.wordAt (Etna.Landing.encodeStatement s) i = (Etna.Landing.words s)[↑i]))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.wordAt_encode: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.wordAt_encode
-- LAND-AUX-02; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.decode_encode
  unless info.isTheorem do throwError "Etna.Landing.decode_encode is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (s : Etna.Landing.LandStatement), Etna.Landing.decodeStatement (Etna.Landing.encodeStatement s) = s))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.decode_encode: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.decode_encode
-- LAND-05; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.statement_complete
  unless info.isTheorem do throwError "Etna.Landing.statement_complete is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (a b : Etna.Landing.LandStatement), Etna.Landing.encodeStatement a = Etna.Landing.encodeStatement b ↔ a = b))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.statement_complete: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.statement_complete
-- LAND-AUX-04; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.recipient_word
  unless info.isTheorem do throwError "Etna.Landing.recipient_word is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (s : Etna.Landing.LandStatement), Etna.Landing.wordAt (Etna.Landing.encodeStatement s) 17 = s.recipient))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.recipient_word: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.recipient_word
-- LAND-AUX-05; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.natWord_byte
  unless info.isTheorem do throwError "Etna.Landing.natWord_byte is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (n : Nat) (i : Fin 32), ((Etna.Landing.natWord n)[i.val]).val = n / 256 ^ (31 - i.val) % 256))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.natWord_byte: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.natWord_byte
-- LAND-AUX-06; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.address_padding
  unless info.isTheorem do throwError "Etna.Landing.address_padding is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (n : Nat), n < 2 ^ 160 → ∀ (i : Fin 32), i.val < 12 → ((Etna.Landing.natWord n)[i.val]).val = 0))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.address_padding: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.address_padding
-- LAND-AUX-07; explicit assumptions: ["Trace-local collision separation for the two compared576-byte preimages; no global Keccak injectivity"]
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.hash_binding
  unless info.isTheorem do throwError "Etna.Landing.hash_binding is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (hash : Vector Etna.Landing.Byte 576 → Etna.Word256) (a b : Etna.Landing.LandStatement), Etna.Landing.LocalHashSeparation hash a b → hash (Etna.Landing.encodeStatement a) = hash (Etna.Landing.encodeStatement b) → a = b))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.hash_binding: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.hash_binding
-- LAND-AUX-08; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.encoding_conformance
  unless info.isTheorem do throwError "Etna.Landing.encoding_conformance is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (s : Etna.Landing.LandStatement) (observedWords : Vector Etna.Landing.AbiWord 18), observedWords = Etna.Landing.words s → observedWords.flatten = Etna.Landing.encodeStatement s))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.encoding_conformance: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.encoding_conformance
-- LAND-AUX-09; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.natWord_injective
  unless info.isTheorem do throwError "Etna.Landing.natWord_injective is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (a b : ℕ), a < 2 ^ 256 → b < 2 ^ 256 → Etna.Landing.natWord a = Etna.Landing.natWord b → a = b))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.natWord_injective: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.natWord_injective
-- LAND-AUX-10; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.blob_encoding_injective
  unless info.isTheorem do throwError "Etna.Landing.blob_encoding_injective is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ {n : ℕ} (a b : Vector Etna.Landing.AbiWord n), a.flatten = b.flatten ↔ a = b))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.blob_encoding_injective: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.blob_encoding_injective
-- LAND-AUX-11; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.local_separation_distinct_nonvacuity
  unless info.isTheorem do throwError "Etna.Landing.local_separation_distinct_nonvacuity is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (a b : Etna.Landing.LandStatement), a ≠ b → ∃ hash, Etna.Landing.LocalHashSeparation hash a b))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.local_separation_distinct_nonvacuity: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.local_separation_distinct_nonvacuity
-- LAND-06; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.encoding_byte
  unless info.isTheorem do throwError "Etna.Landing.encoding_byte is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (s : Etna.Landing.LandStatement) (index : Fin 576), (Etna.Landing.encodeStatement s)[↑index] = (Etna.Landing.words s)[↑index / 32][↑index % 32]))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.encoding_byte: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.encoding_byte
-- LAND-AUX-13; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.validate_bounds
  unless info.isTheorem do throwError "Etna.Landing.validate_bounds is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (w : Etna.Landing.World) (i : Etna.Landing.LandInput), Etna.Landing.validate w i = Option.none → Etna.Landing.Bounds w i))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.validate_bounds: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.validate_bounds
-- LAND-AUX-14; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.successful_checks
  unless info.isTheorem do throwError "Etna.Landing.successful_checks is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (w : Etna.Landing.World) (i : Etna.Landing.LandInput) (x : Etna.Landing.ExternalOutcomes), (Etna.Landing.execLandSteps w i x).error = Option.none → Etna.Landing.validate w i = Option.none ∧ Etna.Landing.environmentCheck x.environment i = Option.none))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.successful_checks: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.successful_checks
-- LAND-01; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.bounds_preserved
  unless info.isTheorem do throwError "Etna.Landing.bounds_preserved is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (w : Etna.Landing.World) (i : Etna.Landing.LandInput) (x : Etna.Landing.ExternalOutcomes), (Etna.Landing.execLandSteps w i x).error = Option.none → Etna.Landing.Bounds w i))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.bounds_preserved: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.bounds_preserved
-- LAND-AUX-16; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.fee_sum_bound
  unless info.isTheorem do throwError "Etna.Landing.fee_sum_bound is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (fee : ℕ → Etna.Word64) (before after : ℕ), Etna.Landing.fees fee before after ≤ (after - before) * (2 ^ 64 - 1)))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.fee_sum_bound: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.fee_sum_bound
-- LAND-AUX-17; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.fees_uint256
  unless info.isTheorem do throwError "Etna.Landing.fees_uint256 is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (fee : ℕ → Etna.Word64) (before after : Etna.Word48), Etna.Landing.fees fee ↑before ↑after < 2 ^ 112 ∧ Etna.Landing.fees fee ↑before ↑after * 1000000000 < 2 ^ 142 ∧ Etna.Landing.fees fee ↑before ↑after * 1000000000 < 2 ^ 256))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.fees_uint256: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.fees_uint256
-- LAND-AUX-18; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.intervals_disjoint
  unless info.isTheorem do throwError "Etna.Landing.intervals_disjoint is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (a b c index : ℕ), a ≤ b → b ≤ c → a ≤ index ∧ index < b → ¬(b ≤ index ∧ index < c)))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.intervals_disjoint: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.intervals_disjoint
-- LAND-AUX-19; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.journal_rollback_write
  unless info.isTheorem do throwError "Etna.Landing.journal_rollback_write is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ {α : Type} (j : Etna.Landing.Journal α) (next : α), (j.write next).rollback = j.rollback))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.journal_rollback_write: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.journal_rollback_write
-- LAND-AUX-20; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.checked_journal_root
  unless info.isTheorem do throwError "Etna.Landing.checked_journal_root is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (w : Etna.Landing.World) (i : Etna.Landing.LandInput) (x : Etna.Landing.ExternalOutcomes), (Etna.Landing.execChecked w i x).journal.rollback = w))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.checked_journal_root: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.checked_journal_root
-- LAND-AUX-21; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.execution_journal_root
  unless info.isTheorem do throwError "Etna.Landing.execution_journal_root is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (w : Etna.Landing.World) (i : Etna.Landing.LandInput) (x : Etna.Landing.ExternalOutcomes), (Etna.Landing.execLandSteps w i x).journal.rollback = w))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.execution_journal_root: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.execution_journal_root
-- LAND-AUX-22; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.rollback_atomic
  unless info.isTheorem do throwError "Etna.Landing.rollback_atomic is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (w : Etna.Landing.World) (i : Etna.Landing.LandInput) (x : Etna.Landing.ExternalOutcomes) (e : Etna.Landing.Error), (Etna.Landing.execLandSteps w i x).error = Option.some e → (Etna.Landing.runTransaction w (Etna.Landing.execLandSteps w i x)).world = w))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.rollback_atomic: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.rollback_atomic
-- LAND-AUX-23; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.same_inbox_reentry
  unless info.isTheorem do throwError "Etna.Landing.same_inbox_reentry is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (w : Etna.Landing.World), w.guard = Bool.true → Etna.Landing.nestedGuard w.inbox w = Option.some Etna.Landing.Error.reentrant))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.same_inbox_reentry: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.same_inbox_reentry
-- LAND-AUX-24; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.other_inbox_not_locked
  unless info.isTheorem do throwError "Etna.Landing.other_inbox_not_locked is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (w : Etna.Landing.World) (other : Etna.Landing.Address), other ≠ w.inbox → Etna.Landing.nestedGuard other w = Option.none))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.other_inbox_not_locked: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.other_inbox_not_locked
-- LAND-08; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.reference_and_blobs
  unless info.isTheorem do throwError "Etna.Landing.reference_and_blobs is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (e : Etna.Landing.Environment) (r : Etna.Word64) (route : Etna.Landing.ReferenceRoute) (hash : Etna.Word256), Etna.Landing.referenceHash e r = Except.ok (route, hash) → ↑r < e.blockNumber ∧ e.blockNumber - ↑r ≤ 8191 ∧ hash ≠ 0 ∧ (route = Etna.Landing.ReferenceRoute.blockhash → e.blockNumber - ↑r ≤ 256 ∧ hash = e.blockHash) ∧ (route = Etna.Landing.ReferenceRoute.history → 256 < e.blockNumber - ↑r ∧ e.historySuccess = Bool.true ∧ e.historyLength = 32 ∧ hash = e.historyHash)))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.reference_and_blobs: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.reference_and_blobs
-- LAND-AUX-26; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.blobs_from_environment
  unless info.isTheorem do throwError "Etna.Landing.blobs_from_environment is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (e : Etna.Landing.Environment), Etna.Landing.actualBlobs e = List.takeWhile (fun x => x != 0) e.blobHashes))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.blobs_from_environment: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.blobs_from_environment
-- LAND-AUX-27; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.environment_success_nonempty
  unless info.isTheorem do throwError "Etna.Landing.environment_success_nonempty is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (e : Etna.Landing.Environment) (i : Etna.Landing.LandInput), Etna.Landing.environmentCheck e i = Option.none → Etna.Landing.actualBlobs e ≠ []))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.environment_success_nonempty: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.environment_success_nonempty
-- LAND-AUX-28; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.successful_poststate
  unless info.isTheorem do throwError "Etna.Landing.successful_poststate is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (w : Etna.Landing.World) (i : Etna.Landing.LandInput) (x : Etna.Landing.ExternalOutcomes), (Etna.Landing.execChecked w i x).error = Option.none → (Etna.Landing.execChecked w i x).journal.current.head = i.headAfter ∧ (Etna.Landing.execChecked w i x).journal.current.checkpoint = { height := ↑i.lastHeight, blockHash := i.lastBlockHash } ∧ (Etna.Landing.execChecked w i x).journal.current.guard = Bool.false ∧ (Etna.Landing.execChecked w i x).journal.current.transfers = w.transfers ++ if i.headAfter ≠ w.head ∧ 0 < Etna.Landing.fees w.fee ↑w.head ↑i.headAfter * 1000000000 then [{ recipient := i.recipient, wei := Etna.Landing.fees w.fee ↑w.head ↑i.headAfter * 1000000000 }] else []))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.successful_poststate: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.successful_poststate
-- LAND-03; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.recipient_bound
  unless info.isTheorem do throwError "Etna.Landing.recipient_bound is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (w : Etna.Landing.World) (i : Etna.Landing.LandInput) (x : Etna.Landing.ExternalOutcomes), (Etna.Landing.execLandSteps w i x).error = Option.none → i.recipient ≠ 0 ∧ (Etna.Landing.execLandSteps w i x).journal.current.transfers = w.transfers ++ if i.headAfter ≠ w.head ∧ 0 < Etna.Landing.fees w.fee ↑w.head ↑i.headAfter * 1000000000 then [{ recipient := i.recipient, wei := Etna.Landing.fees w.fee ↑w.head ↑i.headAfter * 1000000000 }] else []))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.recipient_bound: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.recipient_bound
-- LAND-AUX-30; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.committed_head
  unless info.isTheorem do throwError "Etna.Landing.committed_head is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (w : Etna.Landing.World) (i : Etna.Landing.LandInput) (x : Etna.Landing.ExternalOutcomes), (Etna.Landing.execLandSteps w i x).error = Option.none → (Etna.Landing.runTransaction w (Etna.Landing.execLandSteps w i x)).world.head = i.headAfter))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.committed_head: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.committed_head
-- LAND-AUX-31; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.successive_no_double_consumption
  unless info.isTheorem do throwError "Etna.Landing.successive_no_double_consumption is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (w : Etna.Landing.World) (i : Etna.Landing.LandInput) (x : Etna.Landing.ExternalOutcomes) (j : Etna.Landing.LandInput) (y : Etna.Landing.ExternalOutcomes), (Etna.Landing.execLandSteps w i x).error = Option.none → (Etna.Landing.execLandSteps (Etna.Landing.runTransaction w (Etna.Landing.execLandSteps w i x)).world j y).error = Option.none → ∀ (index : ℕ), ↑w.head ≤ index ∧ index < ↑i.headAfter → ¬(↑(Etna.Landing.runTransaction w (Etna.Landing.execLandSteps w i x)).world.head ≤ index ∧ index < ↑j.headAfter)))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.successive_no_double_consumption: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.successive_no_double_consumption
-- LAND-AUX-32; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.copied_calldata_recipient
  unless info.isTheorem do throwError "Etna.Landing.copied_calldata_recipient is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (i : Etna.Landing.LandInput) (caller : Etna.Landing.Address), ({ i with caller := caller } : Etna.Landing.LandInput).recipient = i.recipient))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.copied_calldata_recipient: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.copied_calldata_recipient
-- LAND-AUX-33; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.statement_is_constructed
  unless info.isTheorem do throwError "Etna.Landing.statement_is_constructed is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (w : Etna.Landing.World) (i : Etna.Landing.LandInput) (x : Etna.Landing.ExternalOutcomes), Etna.Landing.validate w i = Option.none → Etna.Landing.environmentCheck x.environment i = Option.none → (Etna.Landing.execLandSteps w i x).statement = Option.some (Etna.Landing.computedStatement w i x)))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.statement_is_constructed: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.statement_is_constructed
-- LAND-AUX-34; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.statement_recipient_from_input
  unless info.isTheorem do throwError "Etna.Landing.statement_recipient_from_input is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (w : Etna.Landing.World) (i : Etna.Landing.LandInput) (x : Etna.Landing.ExternalOutcomes), (Etna.Landing.computedStatement w i x).recipient = Etna.Landing.natWord ↑i.recipient))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.statement_recipient_from_input: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.statement_recipient_from_input
-- LAND-AUX-35; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.statement_copied_caller
  unless info.isTheorem do throwError "Etna.Landing.statement_copied_caller is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (w : Etna.Landing.World) (i : Etna.Landing.LandInput) (x : Etna.Landing.ExternalOutcomes) (caller : Etna.Landing.Address), Etna.Landing.computedStatement w { lastHeight := i.lastHeight, lastBlockHash := i.lastBlockHash, lastStateRoot := i.lastStateRoot, reference := i.reference, headAfter := i.headAfter, recipient := i.recipient, caller := caller } x = Etna.Landing.computedStatement w i x))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.statement_copied_caller: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.statement_copied_caller
-- LAND-AUX-36; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.every_word_independent
  unless info.isTheorem do throwError "Etna.Landing.every_word_independent is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (a b : Etna.Landing.LandStatement) (field : Fin 18), (Etna.Landing.words a)[↑field] ≠ (Etna.Landing.words b)[↑field] → Etna.Landing.encodeStatement a ≠ Etna.Landing.encodeStatement b))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.every_word_independent: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.every_word_independent
-- LAND-AUX-37; explicit assumptions: ["AuthenticEnvironment: explicit currentblock/canonicalhash/transactionblob equalities and successful32byte history content"]
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.authenticated_reference_content
  unless info.isTheorem do throwError "Etna.Landing.authenticated_reference_content is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (e : Etna.Landing.Environment) (r : Etna.Word64) (currentBlock : ℕ) (canonicalBlockHash : ℕ → Etna.Word256) (transactionBlobs : List Etna.Word256), Etna.Landing.AuthenticEnvironment e r currentBlock canonicalBlockHash transactionBlobs → ∀ (route : Etna.Landing.ReferenceRoute) (hash : Etna.Word256), Etna.Landing.referenceHash e r = Except.ok (route, hash) → hash = canonicalBlockHash ↑r))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.authenticated_reference_content: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.authenticated_reference_content
-- LAND-AUX-38; explicit assumptions: ["AuthenticEnvironment: explicit currentblock/canonicalhash/transactionblob equalities and successful32byte history content"]
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.authenticated_blob_prefix
  unless info.isTheorem do throwError "Etna.Landing.authenticated_blob_prefix is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (e : Etna.Landing.Environment) (r : Etna.Word64) (currentBlock : ℕ) (canonicalBlockHash : ℕ → Etna.Word256) (transactionBlobs : List Etna.Word256), Etna.Landing.AuthenticEnvironment e r currentBlock canonicalBlockHash transactionBlobs → Etna.Landing.actualBlobs e = List.takeWhile (fun x => x != 0) transactionBlobs))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.authenticated_blob_prefix: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.authenticated_blob_prefix
-- LAND-AUX-39; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.successful_signal_checkpoint
  unless info.isTheorem do throwError "Etna.Landing.successful_signal_checkpoint is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (w : Etna.Landing.World) (i : Etna.Landing.LandInput) (x : Etna.Landing.ExternalOutcomes), (Etna.Landing.execChecked w i x).error = Option.none → (Etna.Landing.execChecked w i x).journal.current.signal = w.signal ++ [{ height := ↑i.lastHeight, blockHash := i.lastBlockHash, stateRoot := i.lastStateRoot }]))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.successful_signal_checkpoint: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.successful_signal_checkpoint
-- LAND-AUX-40; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.fee_interval_add
  unless info.isTheorem do throwError "Etna.Landing.fee_interval_add is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (fee : ℕ → Etna.Word64) (a b c : ℕ), a ≤ b → b ≤ c → Etna.Landing.fees fee a c = Etna.Landing.fees fee a b + Etna.Landing.fees fee b c))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.fee_interval_add: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.fee_interval_add
-- LAND-AUX-41; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.blob_prefix_nonzero
  unless info.isTheorem do throwError "Etna.Landing.blob_prefix_nonzero is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (e : Etna.Landing.Environment), ∀ hash ∈ Etna.Landing.actualBlobs e, hash ≠ 0))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.blob_prefix_nonzero: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.blob_prefix_nonzero
-- LAND-04; explicit assumptions: ["EvmJournalLaw: generic commit/abort materialization for arbitrary journals, independent of Landing; nonce/gas excluded"]
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.rollback_atomic_evm
  unless info.isTheorem do throwError "Etna.Landing.rollback_atomic_evm is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (materialize : Etna.Landing.Journal Etna.Landing.World → Bool → Etna.Landing.World), Etna.Landing.EvmJournalLaw materialize → ∀ (w : Etna.Landing.World) (i : Etna.Landing.LandInput) (x : Etna.Landing.ExternalOutcomes) (e : Etna.Landing.Error), (Etna.Landing.execLandSteps w i x).error = Option.some e → materialize (Etna.Landing.execLandSteps w i x).journal (Etna.Landing.execLandSteps w i x).error.isNone = w))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.rollback_atomic_evm: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.rollback_atomic_evm
-- LAND-AUX-43; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.evm_journal_nonvacuity
  unless info.isTheorem do throwError "Etna.Landing.evm_journal_nonvacuity is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(Etna.Landing.EvmJournalLaw fun journal committed => if committed = Bool.true then journal.current else journal.rollback))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.evm_journal_nonvacuity: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.evm_journal_nonvacuity
-- LAND-AUX-44; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.consumption_event_exact
  unless info.isTheorem do throwError "Etna.Landing.consumption_event_exact is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (w : Etna.Landing.World) (i : Etna.Landing.LandInput) (x : Etna.Landing.ExternalOutcomes), (Etna.Landing.execChecked w i x).error = Option.none → (Etna.Landing.execChecked w i x).journal.current.logs = w.logs ++ [Etna.Landing.Event.checkpointSaved { height := ↑i.lastHeight, blockHash := i.lastBlockHash, stateRoot := i.lastStateRoot }, Etna.Landing.Event.batchLanded (w.checkpoint.height + 1) (↑i.lastHeight) i.lastBlockHash i.lastStateRoot (↑i.reference) i.caller] ++ if i.headAfter ≠ w.head then [Etna.Landing.Event.consumed (↑w.head) (↑i.headAfter) (Etna.Landing.fees w.fee ↑w.head ↑i.headAfter * 1000000000) i.recipient] else []))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.consumption_event_exact: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.consumption_event_exact
-- LAND-AUX-45; explicit assumptions: ["CallbackFrame: concrete protected Inbox/config/queue equality; forbids authorized malicious upgrade during callback"]
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.callback_frame_preserves_bounds
  unless info.isTheorem do throwError "Etna.Landing.callback_frame_preserves_bounds is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (before after : Etna.Landing.World) (i : Etna.Landing.LandInput), Etna.Landing.CallbackFrame before after → Etna.Landing.Bounds before i → Etna.Landing.Bounds after i))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.callback_frame_preserves_bounds: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.callback_frame_preserves_bounds
-- LAND-AUX-46; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.callback_frame_nonvacuity
  unless info.isTheorem do throwError "Etna.Landing.callback_frame_nonvacuity is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (w : Etna.Landing.World), Etna.Landing.CallbackFrame w w))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.callback_frame_nonvacuity: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.callback_frame_nonvacuity
-- LAND-02; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.fees_exact_once
  unless info.isTheorem do throwError "Etna.Landing.fees_exact_once is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (w : Etna.Landing.World) (i : Etna.Landing.LandInput) (x : Etna.Landing.ExternalOutcomes), (Etna.Landing.execLandSteps w i x).error = Option.none → (Etna.Landing.runTransaction w (Etna.Landing.execLandSteps w i x)).world.head = i.headAfter ∧ ↑w.head ≤ ↑i.headAfter ∧ ((Etna.Landing.execLandSteps w i x).journal.current.transfers = w.transfers ++ if i.headAfter ≠ w.head ∧ 0 < Etna.Landing.fees w.fee ↑w.head ↑i.headAfter * 1000000000 then [{ recipient := i.recipient, wei := Etna.Landing.fees w.fee ↑w.head ↑i.headAfter * 1000000000 }] else []) ∧ Etna.Landing.fees w.fee ↑w.head ↑i.headAfter < 2 ^ 112 ∧ Etna.Landing.fees w.fee ↑w.head ↑i.headAfter * 1000000000 < 2 ^ 256))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.fees_exact_once: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.fees_exact_once
-- LAND-AUX-48; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.locked_land_and_save_reject
  unless info.isTheorem do throwError "Etna.Landing.locked_land_and_save_reject is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (w : Etna.Landing.World) (i : Etna.Landing.LandInput) (x : Etna.Landing.ExternalOutcomes), w.guard = Bool.true → (Etna.Landing.execLandSteps w i x).error = Option.some Etna.Landing.Error.reentrant ∧ (Etna.Landing.execLandSteps w i x).journal.current = w ∧ Etna.Landing.nestedGuard w.inbox w = Option.some Etna.Landing.Error.reentrant))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.locked_land_and_save_reject: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.locked_land_and_save_reject
-- LAND-AUX-49; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.normal_nonvacuity
  unless info.isTheorem do throwError "Etna.Landing.normal_nonvacuity is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `((Etna.Landing.execLandSteps Etna.Landing.exampleWorld Etna.Landing.exampleInput Etna.Landing.exampleExternal).error = Option.none))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.normal_nonvacuity: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.normal_nonvacuity
-- LAND-AUX-50; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.nonzero_payment_nonvacuity
  unless info.isTheorem do throwError "Etna.Landing.nonzero_payment_nonvacuity is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `((Etna.Landing.execLandSteps Etna.Landing.exampleWorld Etna.Landing.exampleInput Etna.Landing.exampleExternal).journal.current.transfers = [{ recipient := 48879, wei := 18000000000 }]))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.nonzero_payment_nonvacuity: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.nonzero_payment_nonvacuity
-- LAND-AUX-51; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.verifier_failure_after_writes
  unless info.isTheorem do throwError "Etna.Landing.verifier_failure_after_writes is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(let r := Etna.Landing.execLandSteps Etna.Landing.exampleWorld Etna.Landing.exampleInput { Etna.Landing.exampleExternal with verifierReturnsNormally := false }; r.error = some .verifier ∧ r.journal.current.head.val = 4 ∧ r.journal.current.checkpoint.height = 13 ∧ r.journal.current.signal.length = 1 ∧ r.journal.current.logs.length = 2))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.verifier_failure_after_writes: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.verifier_failure_after_writes
-- LAND-AUX-52; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.signal_failure_after_writes
  unless info.isTheorem do throwError "Etna.Landing.signal_failure_after_writes is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(let r := Etna.Landing.execLandSteps Etna.Landing.exampleWorld Etna.Landing.exampleInput { Etna.Landing.exampleExternal with signalAuthorized := false }; r.error = some .signalUnauthorized ∧ r.journal.current.head.val = 4 ∧ r.journal.current.checkpoint.height = 13 ∧ r.journal.current.signal = []))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.signal_failure_after_writes: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.signal_failure_after_writes
-- LAND-AUX-53; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.payment_failure_after_verifier
  unless info.isTheorem do throwError "Etna.Landing.payment_failure_after_verifier is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(let r := Etna.Landing.execLandSteps Etna.Landing.exampleWorld Etna.Landing.exampleInput { Etna.Landing.exampleExternal with paymentReturnsNormally := false }; r.error = some .payment ∧ r.journal.current.head.val = 4 ∧ r.journal.current.signal.length = 1 ∧ r.journal.current.logs.length = 2))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.payment_failure_after_verifier: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.payment_failure_after_verifier
-- LAND-AUX-54; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.zero_fee_skips_callback
  unless info.isTheorem do throwError "Etna.Landing.zero_fee_skips_callback is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `((Etna.Landing.execLandSteps (have __src := Etna.Landing.exampleWorld; { inbox := __src.inbox, l1ChainId := __src.l1ChainId, l2ChainId := __src.l2ChainId, registry := __src.registry, generation := __src.generation, config := __src.config, active := __src.active, maxBatchBlocks := __src.maxBatchBlocks, checkpoint := __src.checkpoint, head := __src.head, tail := __src.tail, fee := fun x => 0, signal := __src.signal, inboxBalance := __src.inboxBalance, transfers := __src.transfers, logs := __src.logs, guard := __src.guard }) Etna.Landing.exampleInput (have __src := Etna.Landing.exampleExternal; { environment := __src.environment, signalAuthorized := __src.signalAuthorized, verifierReturnsNormally := __src.verifierReturnsNormally, paymentReturnsNormally := Bool.false, reentry := Etna.Landing.ReentryMode.landUncaught, keccakBlobBytes := __src.keccakBlobBytes })).error = Option.none))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.zero_fee_skips_callback: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.zero_fee_skips_callback
-- LAND-AUX-55; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.caught_reentry_nonvacuity
  unless info.isTheorem do throwError "Etna.Landing.caught_reentry_nonvacuity is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `((Etna.Landing.execLandSteps Etna.Landing.exampleWorld Etna.Landing.exampleInput (have __src := Etna.Landing.exampleExternal; { environment := __src.environment, signalAuthorized := __src.signalAuthorized, verifierReturnsNormally := __src.verifierReturnsNormally, paymentReturnsNormally := __src.paymentReturnsNormally, reentry := Etna.Landing.ReentryMode.landCaught, keccakBlobBytes := __src.keccakBlobBytes })).error = Option.none ∧ Etna.Landing.nestedGuard Etna.Landing.exampleWorld.inbox (have __src := Etna.Landing.exampleWorld; { inbox := __src.inbox, l1ChainId := __src.l1ChainId, l2ChainId := __src.l2ChainId, registry := __src.registry, generation := __src.generation, config := __src.config, active := __src.active, maxBatchBlocks := __src.maxBatchBlocks, checkpoint := __src.checkpoint, head := __src.head, tail := __src.tail, fee := __src.fee, signal := __src.signal, inboxBalance := __src.inboxBalance, transfers := __src.transfers, logs := __src.logs, guard := Bool.true }) = Option.some Etna.Landing.Error.reentrant))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.caught_reentry_nonvacuity: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.caught_reentry_nonvacuity
-- LAND-AUX-56; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.static_verifier_guard_nonvacuity
  unless info.isTheorem do throwError "Etna.Landing.static_verifier_guard_nonvacuity is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `((Etna.Landing.execLandSteps Etna.Landing.exampleWorld Etna.Landing.exampleInput (have __src := Etna.Landing.exampleExternal; { environment := __src.environment, signalAuthorized := __src.signalAuthorized, verifierReturnsNormally := __src.verifierReturnsNormally, paymentReturnsNormally := __src.paymentReturnsNormally, reentry := Etna.Landing.ReentryMode.verifierLand, keccakBlobBytes := __src.keccakBlobBytes })).error = Option.none))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.static_verifier_guard_nonvacuity: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.static_verifier_guard_nonvacuity
-- LAND-AUX-57; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.reference_boundaries_nonvacuity
  unless info.isTheorem do throwError "Etna.Landing.reference_boundaries_nonvacuity is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(Etna.Landing.referenceHash Etna.Landing.exampleEnvironment 19744 = Except.ok (Etna.Landing.ReferenceRoute.blockhash, 2748) ∧ Etna.Landing.referenceHash Etna.Landing.exampleEnvironment 19743 = Except.ok (Etna.Landing.ReferenceRoute.history, 2748) ∧ Etna.Landing.referenceHash Etna.Landing.exampleEnvironment 11809 = Except.ok (Etna.Landing.ReferenceRoute.history, 2748) ∧ Etna.Landing.referenceHash Etna.Landing.exampleEnvironment 11808 = Except.error Etna.Landing.Error.anchorUnavailable ∧ Etna.Landing.referenceHash Etna.Landing.exampleEnvironment 20000 = Except.error Etna.Landing.Error.anchorUnavailable ∧ Etna.Landing.referenceHash Etna.Landing.exampleEnvironment 20001 = Except.error Etna.Landing.Error.anchorUnavailable))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.reference_boundaries_nonvacuity: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.reference_boundaries_nonvacuity
-- LAND-AUX-58; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.malformed_history_nonvacuity
  unless info.isTheorem do throwError "Etna.Landing.malformed_history_nonvacuity is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(Etna.Landing.referenceHash (have __src := Etna.Landing.exampleEnvironment; { blockNumber := __src.blockNumber, blockHash := __src.blockHash, historySuccess := __src.historySuccess, historyLength := 31, historyHash := __src.historyHash, blobHashes := __src.blobHashes }) 19743 = Except.error Etna.Landing.Error.anchorUnavailable ∧ Etna.Landing.referenceHash (have __src := Etna.Landing.exampleEnvironment; { blockNumber := __src.blockNumber, blockHash := __src.blockHash, historySuccess := __src.historySuccess, historyLength := 33, historyHash := __src.historyHash, blobHashes := __src.blobHashes }) 19743 = Except.error Etna.Landing.Error.anchorUnavailable ∧ Etna.Landing.referenceHash (have __src := Etna.Landing.exampleEnvironment; { blockNumber := __src.blockNumber, blockHash := __src.blockHash, historySuccess := __src.historySuccess, historyLength := 0, historyHash := __src.historyHash, blobHashes := __src.blobHashes }) 19743 = Except.error Etna.Landing.Error.anchorUnavailable))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.malformed_history_nonvacuity: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.malformed_history_nonvacuity
-- LAND-AUX-59; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.ordered_blobs_nonvacuity
  unless info.isTheorem do throwError "Etna.Landing.ordered_blobs_nonvacuity is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(Etna.Landing.actualBlobs Etna.Landing.exampleEnvironment = [1, 2] ∧ Etna.Landing.actualBlobs (have __src := Etna.Landing.exampleEnvironment; { blockNumber := __src.blockNumber, blockHash := __src.blockHash, historySuccess := __src.historySuccess, historyLength := __src.historyLength, historyHash := __src.historyHash, blobHashes := [2, 1] }) = [2, 1] ∧ Etna.Landing.actualBlobs (have __src := Etna.Landing.exampleEnvironment; { blockNumber := __src.blockNumber, blockHash := __src.blockHash, historySuccess := __src.historySuccess, historyLength := __src.historyLength, historyHash := __src.historyHash, blobHashes := [1, 0, 2] }) = [1] ∧ Etna.Landing.environmentCheck (have __src := Etna.Landing.exampleEnvironment; { blockNumber := __src.blockNumber, blockHash := __src.blockHash, historySuccess := __src.historySuccess, historyLength := __src.historyLength, historyHash := __src.historyHash, blobHashes := [] }) Etna.Landing.exampleInput = Option.some Etna.Landing.Error.blobsRequired))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.ordered_blobs_nonvacuity: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.ordered_blobs_nonvacuity
-- LAND-AUX-60; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.local_separation_nonvacuity
  unless info.isTheorem do throwError "Etna.Landing.local_separation_nonvacuity is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (s : Etna.Landing.LandStatement), Etna.Landing.LocalHashSeparation (fun x => 0) s s))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.local_separation_nonvacuity: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.local_separation_nonvacuity
-- LAND-BIND-01; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.serializeBlobPrefix_length
  unless info.isTheorem do throwError "Etna.Landing.serializeBlobPrefix_length is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (blobs : List Etna.Word256), (Etna.Landing.serializeBlobPrefix blobs).length = blobs.length * 32))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.serializeBlobPrefix_length: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.serializeBlobPrefix_length
-- LAND-BIND-02; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.serializeBlobPrefix_take
  unless info.isTheorem do throwError "Etna.Landing.serializeBlobPrefix_take is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (hash : Etna.Word256) (tail : List Etna.Word256), List.take 32 (Etna.Landing.serializeBlobPrefix (hash :: tail)) = Vector.toList (Etna.Landing.natWord ↑hash)))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.serializeBlobPrefix_take: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.serializeBlobPrefix_take
-- LAND-BIND-03; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.serializeBlobPrefix_drop
  unless info.isTheorem do throwError "Etna.Landing.serializeBlobPrefix_drop is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (hash : Etna.Word256) (tail : List Etna.Word256), List.drop 32 (Etna.Landing.serializeBlobPrefix (hash :: tail)) = Etna.Landing.serializeBlobPrefix tail))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.serializeBlobPrefix_drop: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.serializeBlobPrefix_drop
-- LAND-BIND-04; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.serializeBlobPrefix_injective
  unless info.isTheorem do throwError "Etna.Landing.serializeBlobPrefix_injective is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (a b : List Etna.Word256), Etna.Landing.serializeBlobPrefix a = Etna.Landing.serializeBlobPrefix b ↔ a = b))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.serializeBlobPrefix_injective: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.serializeBlobPrefix_injective
-- LAND-BIND-05; explicit assumptions: ["Trace-local separation of the two canonical byte serializations under the actual inner byte-hash primitive; matching inner digest"]
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.inner_hash_binding
  unless info.isTheorem do throwError "Etna.Landing.inner_hash_binding is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (hash : List Etna.Landing.Byte → Etna.Word256) (a b : List Etna.Word256), Etna.Landing.LocalInnerHashSeparation hash a b → hash (Etna.Landing.serializeBlobPrefix a) = hash (Etna.Landing.serializeBlobPrefix b) → a = b))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.inner_hash_binding: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.inner_hash_binding
-- LAND-BIND-06; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.inner_separation_nonvacuity
  unless info.isTheorem do throwError "Etna.Landing.inner_separation_nonvacuity is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (a b : List Etna.Word256), ∃ hash, Etna.Landing.LocalInnerHashSeparation hash a b))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.inner_separation_nonvacuity: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.inner_separation_nonvacuity
-- LAND-BIND-07; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.unequal_length_inner_nonvacuity
  unless info.isTheorem do throwError "Etna.Landing.unequal_length_inner_nonvacuity is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(let hash : List Etna.Landing.Byte → Etna.Word256 := fun bytes => if bytes.length = 32 then 1 else 2; Etna.Landing.LocalInnerHashSeparation hash [1] [1,2] ∧ hash (Etna.Landing.serializeBlobPrefix [1]) ≠ hash (Etna.Landing.serializeBlobPrefix [1,2])))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.unequal_length_inner_nonvacuity: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.unequal_length_inner_nonvacuity
-- LAND-BIND-08; explicit assumptions: ["Same actual inner byte-hash primitive in both executions", "Trace-local inner separation on canonical serialized actual prefixes, with no equal-length restriction", "Trace-local outer separation on the two actual576-byte statements and matching outer digest"]
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.composed_statement_blob_binding
  unless info.isTheorem do throwError "Etna.Landing.composed_statement_blob_binding is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (outerHash : Vector Etna.Landing.Byte 576 → Etna.Word256) (w₁ w₂ : Etna.Landing.World) (i₁ i₂ : Etna.Landing.LandInput) (x₁ x₂ : Etna.Landing.ExternalOutcomes), x₁.keccakBlobBytes = x₂.keccakBlobBytes → Etna.Landing.LocalInnerHashSeparation x₁.keccakBlobBytes (Etna.Landing.actualBlobs x₁.environment) (Etna.Landing.actualBlobs x₂.environment) → Etna.Landing.LocalHashSeparation outerHash (Etna.Landing.computedStatement w₁ i₁ x₁) (Etna.Landing.computedStatement w₂ i₂ x₂) → outerHash (Etna.Landing.encodeStatement (Etna.Landing.computedStatement w₁ i₁ x₁)) = outerHash (Etna.Landing.encodeStatement (Etna.Landing.computedStatement w₂ i₂ x₂)) → Etna.Landing.computedStatement w₁ i₁ x₁ = Etna.Landing.computedStatement w₂ i₂ x₂ ∧ Etna.Landing.actualBlobs x₁.environment = Etna.Landing.actualBlobs x₂.environment))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.composed_statement_blob_binding: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.composed_statement_blob_binding
-- LAND-BIND-09; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.composed_unequal_length_nonvacuity
  unless info.isTheorem do throwError "Etna.Landing.composed_unequal_length_nonvacuity is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (w : Etna.Landing.World) (i : Etna.Landing.LandInput) (x : Etna.Landing.ExternalOutcomes), ∃ outerHash, Etna.Landing.LocalInnerHashSeparation Etna.Landing.exampleInnerHash (Etna.Landing.actualBlobs (Etna.Landing.withBlobPrefix x [1]).environment) (Etna.Landing.actualBlobs (Etna.Landing.withBlobPrefix x [1, 2]).environment) ∧ Etna.Landing.LocalHashSeparation outerHash (Etna.Landing.computedStatement w i (Etna.Landing.withBlobPrefix x [1])) (Etna.Landing.computedStatement w i (Etna.Landing.withBlobPrefix x [1, 2])) ∧ outerHash (Etna.Landing.encodeStatement (Etna.Landing.computedStatement w i (Etna.Landing.withBlobPrefix x [1]))) ≠ outerHash (Etna.Landing.encodeStatement (Etna.Landing.computedStatement w i (Etna.Landing.withBlobPrefix x [1, 2])))))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.composed_unequal_length_nonvacuity: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.composed_unequal_length_nonvacuity
-- LAND-BIND-10; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.constant_inner_hash_not_separated
  unless info.isTheorem do throwError "Etna.Landing.constant_inner_hash_not_separated is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(¬Etna.Landing.LocalInnerHashSeparation (fun x => 0) [1] [1, 2]))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.constant_inner_hash_not_separated: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.constant_inner_hash_not_separated
-- LAND-BIND-11; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Landing.composed_binding_success_nonvacuity
  unless info.isTheorem do throwError "Etna.Landing.composed_binding_success_nonvacuity is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (w : Etna.Landing.World) (i : Etna.Landing.LandInput) (x : Etna.Landing.ExternalOutcomes), Etna.Landing.computedStatement w i (Etna.Landing.withBlobPrefix x [1, 2]) = Etna.Landing.computedStatement w i (Etna.Landing.withBlobPrefix x [1, 2, 0, 3]) ∧ Etna.Landing.actualBlobs (Etna.Landing.withBlobPrefix x [1, 2]).environment = Etna.Landing.actualBlobs (Etna.Landing.withBlobPrefix x [1, 2, 0, 3]).environment))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Landing.composed_binding_success_nonvacuity: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Landing.composed_binding_success_nonvacuity
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
-- INT-fi-projection; explicit assumptions: ["JointTrace/contiguous Cuts carry actual successful FI.ValidStep and Committee.step on the same ordered blocks, linked parent/anchor/Inbox/cursor/envelope/execution context and one authenticated view; cryptographic/header/guest implementation bridges remain external."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Integration.fi_projection
  unless info.isTheorem do throwError "Etna.Integration.fi_projection is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ {ctx : Etna.Committee.Context}
  {a : Etna.Integration.Authentication ctx} {before after : Etna.Integration.State}
  {blocks : List (Etna.Integration.Block ctx)} {consumed : List (Option ℕ)} {updates : Etna.Committee.Updates},
  Etna.Integration.JointTrace a before blocks consumed updates after →
    Etna.FI.ValidTrace before.cursor consumed after.cursor))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Integration.fi_projection: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Integration.fi_projection
-- INT-committee-projection; explicit assumptions: ["JointTrace/contiguous Cuts carry actual successful FI.ValidStep and Committee.step on the same ordered blocks, linked parent/anchor/Inbox/cursor/envelope/execution context and one authenticated view; cryptographic/header/guest implementation bridges remain external."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Integration.committee_projection
  unless info.isTheorem do throwError "Etna.Integration.committee_projection is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ {ctx : Etna.Committee.Context}
  {a : Etna.Integration.Authentication ctx} {before after : Etna.Integration.State}
  {blocks : List (Etna.Integration.Block ctx)} {consumed : List (Option ℕ)} {updates : Etna.Committee.Updates},
  Etna.Integration.JointTrace a before blocks consumed updates after →
    Etna.Committee.replay ctx (List.map Etna.Integration.Block.committee blocks) before.committee =
      Except.ok (after.committee, updates)))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Integration.committee_projection: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Integration.committee_projection
-- INT-trace-lengths; explicit assumptions: ["JointTrace/contiguous Cuts carry actual successful FI.ValidStep and Committee.step on the same ordered blocks, linked parent/anchor/Inbox/cursor/envelope/execution context and one authenticated view; cryptographic/header/guest implementation bridges remain external."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Integration.trace_lengths
  unless info.isTheorem do throwError "Etna.Integration.trace_lengths is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ {ctx : Etna.Committee.Context}
  {a : Etna.Integration.Authentication ctx} {before after : Etna.Integration.State}
  {blocks : List (Etna.Integration.Block ctx)} {consumed : List (Option ℕ)} {updates : Etna.Committee.Updates},
  Etna.Integration.JointTrace a before blocks consumed updates after → consumed.length = blocks.length))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Integration.trace_lengths: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Integration.trace_lengths
-- INT-step-height; explicit assumptions: ["Successful checked Committee.step on the supplied authenticated block; bound/height/hash/anchor projections are derived from the reducer."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Integration.step_height
  unless info.isTheorem do throwError "Etna.Integration.step_height is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ {ctx : Etna.Committee.Context}
  {before after : Etna.Committee.CommitteeState} {block : Etna.Committee.AuthenticatedBlockFacts ctx}
  {updates : Etna.Committee.Updates},
  Etna.Committee.step ctx before block = Except.ok (after, updates) →
    after.height = before.height + 1 ∧
      after.blockHash = block.facts.blockHash ∧ after.anchor = block.facts.anchor ∧ after.height ≤ Etna.Committee.max64))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Integration.step_height: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Integration.step_height
-- INT-trace-height; explicit assumptions: ["JointTrace/contiguous Cuts carry actual successful FI.ValidStep and Committee.step on the same ordered blocks, linked parent/anchor/Inbox/cursor/envelope/execution context and one authenticated view; cryptographic/header/guest implementation bridges remain external."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Integration.trace_height
  unless info.isTheorem do throwError "Etna.Integration.trace_height is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ {ctx : Etna.Committee.Context}
  {a : Etna.Integration.Authentication ctx} {before after : Etna.Integration.State}
  {blocks : List (Etna.Integration.Block ctx)} {consumed : List (Option ℕ)} {updates : Etna.Committee.Updates},
  Etna.Integration.JointTrace a before blocks consumed updates after →
    after.committee.height = before.committee.height + blocks.length))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Integration.trace_height: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Integration.trace_height
-- INT-trace-height-bound; explicit assumptions: ["JointTrace/contiguous Cuts carry actual successful FI.ValidStep and Committee.step on the same ordered blocks, linked parent/anchor/Inbox/cursor/envelope/execution context and one authenticated view; cryptographic/header/guest implementation bridges remain external."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Integration.trace_height_bound
  unless info.isTheorem do throwError "Etna.Integration.trace_height_bound is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ {ctx : Etna.Committee.Context}
  {a : Etna.Integration.Authentication ctx} {before after : Etna.Integration.State}
  {blocks : List (Etna.Integration.Block ctx)} {consumed : List (Option ℕ)} {updates : Etna.Committee.Updates},
  Etna.Integration.JointTrace a before blocks consumed updates after →
    before.committee.height ≤ Etna.Committee.max64 → after.committee.height ≤ Etna.Committee.max64))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Integration.trace_height_bound: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Integration.trace_height_bound
-- INT-trace-count; explicit assumptions: ["JointTrace/contiguous Cuts carry actual successful FI.ValidStep and Committee.step on the same ordered blocks, linked parent/anchor/Inbox/cursor/envelope/execution context and one authenticated view; cryptographic/header/guest implementation bridges remain external."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Integration.trace_count
  unless info.isTheorem do throwError "Etna.Integration.trace_count is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ {ctx : Etna.Committee.Context}
  {a : Etna.Integration.Authentication ctx} {before after : Etna.Integration.State}
  {blocks : List (Etna.Integration.Block ctx)} {consumed : List (Option ℕ)} {updates : Etna.Committee.Updates},
  Etna.Integration.JointTrace a before blocks consumed updates after →
    after.cursor = before.cursor + Etna.FI.consumptionCount consumed ∧ Etna.FI.consumptionCount consumed ≤ blocks.length))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Integration.trace_count: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Integration.trace_count
-- INT-trace-append; explicit assumptions: ["JointTrace/contiguous Cuts carry actual successful FI.ValidStep and Committee.step on the same ordered blocks, linked parent/anchor/Inbox/cursor/envelope/execution context and one authenticated view; cryptographic/header/guest implementation bridges remain external."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Integration.trace_append
  unless info.isTheorem do throwError "Etna.Integration.trace_append is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ {ctx : Etna.Committee.Context}
  {a : Etna.Integration.Authentication ctx} {before middle after : Etna.Integration.State}
  {xs ys : List (Etna.Integration.Block ctx)} {cs ds : List (Option ℕ)} {us vs : Etna.Committee.Updates},
  Etna.Integration.JointTrace a before xs cs us middle →
    Etna.Integration.JointTrace a middle ys ds vs after →
      Etna.Integration.JointTrace a before (xs ++ ys) (cs ++ ds) (us ++ vs) after))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Integration.trace_append: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Integration.trace_append
-- INT-arbitrary-cuts; explicit assumptions: ["JointTrace/contiguous Cuts carry actual successful FI.ValidStep and Committee.step on the same ordered blocks, linked parent/anchor/Inbox/cursor/envelope/execution context and one authenticated view; cryptographic/header/guest implementation bridges remain external."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Integration.arbitrary_cuts
  unless info.isTheorem do throwError "Etna.Integration.arbitrary_cuts is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ {ctx : Etna.Committee.Context}
  {a : Etna.Integration.Authentication ctx} {before after : Etna.Integration.State}
  {parts : List (List (Etna.Integration.Block ctx))} {consumed : List (Option ℕ)} {updates : Etna.Committee.Updates},
  Etna.Integration.Cuts a before parts consumed updates after →
    Etna.Integration.JointTrace a before parts.flatten consumed updates after))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Integration.arbitrary_cuts: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Integration.arbitrary_cuts
-- INT-successful-verifier; explicit assumptions: ["Successful staged Landing model execution; actual EVM journal/environment/callback implementation semantics are external bridges."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Integration.successful_verifier
  unless info.isTheorem do throwError "Etna.Integration.successful_verifier is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (w : Etna.Landing.World)
  (i : Etna.Landing.LandInput) (x : Etna.Landing.ExternalOutcomes),
  (Etna.Landing.execLandSteps w i x).error = Option.none → x.verifierReturnsNormally = Bool.true))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Integration.successful_verifier: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Integration.successful_verifier
-- LAND-07; explicit assumptions: ["GuestSoundness for the actual normal-return verifier establishes the concrete ValidBatch relation; no production/Dummy instance exists.", "ValidBatch authenticates exact seed committee/cursor/checkpoint, deployment/genesis configuration, canonical envelope/payload and actual blob-prefix decoding, and per-block L1 ancestry.", "Successful Landing staged model execution; real EVM/environment/crypto/journal/callback frame semantics remain external and bytecode refinement is pending."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Integration.compose_trace_landing
  unless info.isTheorem do throwError "Etna.Integration.compose_trace_landing is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ {ctx : Etna.Committee.Context}
  (a : Etna.Integration.Authentication ctx) (w : Etna.Landing.World) (i : Etna.Landing.LandInput)
  (x : Etna.Landing.ExternalOutcomes),
  Etna.Integration.GuestSoundness a w i x →
    (Etna.Landing.execLandSteps w i x).error = Option.none →
      ∃ batch,
        Etna.Integration.ValidBatch a w i x (Etna.Landing.computedStatement w i x) batch ∧
          ↑(Etna.Landing.runTransaction w (Etna.Landing.execLandSteps w i x)).world.head =
              ↑w.head + Etna.FI.consumptionCount batch.consumed ∧
            Etna.FI.consumptionCount batch.consumed ≤ batch.blockCount ∧
              ↑i.lastHeight = w.checkpoint.height + batch.blockCount ∧
                Etna.Committee.replay ctx (List.map Etna.Integration.Block.committee batch.blocks)
                      batch.parent.committee =
                    Except.ok (batch.terminal.committee, batch.updates) ∧
                  (Etna.Landing.execLandSteps w i x).journal.current.transfers =
                    w.transfers ++
                      if i.headAfter ≠ w.head ∧ 0 < Etna.Landing.fees w.fee ↑w.head ↑i.headAfter * 1000000000 then
                        [{ recipient := i.recipient, wei := Etna.Landing.fees w.fee ↑w.head ↑i.headAfter * 1000000000 }]
                      else []))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Integration.compose_trace_landing: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Integration.compose_trace_landing
-- INT-valid-batch-head; explicit assumptions: ["Each ValidBatch binds the successful joint reducer output to all eighteen actual statement words and authenticates seed/configuration/payload/blob decoding/L1 ancestry.", "For LandedCuts each nonempty piece has successful staged Landing execution; fee entries are proved preserved in this model. Real guest, EVM journal and callback semantics remain external."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Integration.valid_batch_head
  unless info.isTheorem do throwError "Etna.Integration.valid_batch_head is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ {ctx : Etna.Committee.Context}
  {a : Etna.Integration.Authentication ctx} {w : Etna.Landing.World} {i : Etna.Landing.LandInput}
  {x : Etna.Landing.ExternalOutcomes} {batch : Etna.Integration.BatchSummary ctx},
  Etna.Integration.ValidBatch a w i x (Etna.Landing.computedStatement w i x) batch →
    ↑i.headAfter = batch.terminal.cursor))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Integration.valid_batch_head: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Integration.valid_batch_head
-- INT-fee-cuts-exact; explicit assumptions: ["Monotone finite FeeCuts on one retained-entry fee function; each interval amount is computed, not supplied as a conclusion."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Integration.fee_cuts_exact
  unless info.isTheorem do throwError "Etna.Integration.fee_cuts_exact is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ {fee : ℕ → Etna.Word64} {before after : ℕ}
  {heads : List ℕ} {paid : ℕ},
  Etna.Integration.FeeCuts fee before heads after paid → before ≤ after ∧ paid = Etna.Landing.fees fee before after))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Integration.fee_cuts_exact: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Integration.fee_cuts_exact
-- INT-landing-fee-frame; explicit assumptions: ["Successful staged Landing model execution; actual EVM journal/environment/callback implementation semantics are external bridges."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Integration.landing_fee_frame
  unless info.isTheorem do throwError "Etna.Integration.landing_fee_frame is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ (w : Etna.Landing.World)
  (i : Etna.Landing.LandInput) (x : Etna.Landing.ExternalOutcomes),
  (Etna.Landing.execLandSteps w i x).error = Option.none →
    (Etna.Landing.runTransaction w (Etna.Landing.execLandSteps w i x)).world.fee = w.fee))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Integration.landing_fee_frame: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Integration.landing_fee_frame
-- INT-landed-cuts-compose; explicit assumptions: ["Each ValidBatch binds the successful joint reducer output to all eighteen actual statement words and authenticates seed/configuration/payload/blob decoding/L1 ancestry.", "For LandedCuts each nonempty piece has successful staged Landing execution; fee entries are proved preserved in this model. Real guest, EVM journal and callback semantics remain external."]
run_elab do
  let info ← Lean.getConstInfo `Etna.Integration.landed_cuts_compose
  unless info.isTheorem do throwError "Etna.Integration.landed_cuts_compose is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(∀ {ctx : Etna.Committee.Context}
  {a : Etna.Integration.Authentication ctx} {w : Etna.Landing.World} {before : Etna.Integration.State}
  {parts : List (List (Etna.Integration.Block ctx))} {consumed : List (Option ℕ)} {updates : Etna.Committee.Updates}
  {final : Etna.Landing.World} {after : Etna.Integration.State} {paid : ℕ},
  Etna.Integration.LandedCuts a w before parts consumed updates final after paid →
    Etna.Integration.JointTrace a before parts.flatten consumed updates after ∧
      ↑final.head = ↑w.head + Etna.FI.consumptionCount consumed ∧ paid = Etna.Landing.fees w.fee ↑w.head ↑final.head))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Integration.landed_cuts_compose: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Integration.landed_cuts_compose
-- INT-joint-nonvacuity; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Integration.Examples.joint_nonvacuity
  unless info.isTheorem do throwError "Etna.Integration.Examples.joint_nonvacuity is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(Etna.Integration.ValidBatch Etna.Integration.Examples.auth Etna.Integration.Examples.world Etna.Integration.Examples.input Etna.Integration.Examples.external (Etna.Landing.computedStatement Etna.Integration.Examples.world Etna.Integration.Examples.input Etna.Integration.Examples.external) Etna.Integration.Examples.batch ∧
(Etna.Landing.execLandSteps Etna.Integration.Examples.world Etna.Integration.Examples.input Etna.Integration.Examples.external).error = none ∧
(Etna.Landing.runTransaction Etna.Integration.Examples.world (Etna.Landing.execLandSteps Etna.Integration.Examples.world Etna.Integration.Examples.input Etna.Integration.Examples.external)).world.head.val = (1 : Nat) ∧
(Etna.Landing.execLandSteps Etna.Integration.Examples.world Etna.Integration.Examples.input Etna.Integration.Examples.external).journal.current.transfers = [⟨(48879 : Etna.Landing.Address), (1000000000 : Nat)⟩]))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Integration.Examples.joint_nonvacuity: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Integration.Examples.joint_nonvacuity
-- INT-two-cuts-nonvacuity; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Integration.Examples.two_cuts_nonvacuity
  unless info.isTheorem do throwError "Etna.Integration.Examples.two_cuts_nonvacuity is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(Etna.Integration.Cuts
  Etna.Integration.Examples.auth Etna.Integration.Examples.before [[], [Etna.Integration.Examples.block]]
  [Option.some 0] [] Etna.Integration.Examples.after))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Integration.Examples.two_cuts_nonvacuity: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Integration.Examples.two_cuts_nonvacuity
-- INT-fees-nonvacuity; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Integration.Examples.fees_nonvacuity
  unless info.isTheorem do throwError "Etna.Integration.Examples.fees_nonvacuity is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(Etna.Integration.FeeCuts (fun x => 1) 0
  [0, 1, 1] 1 1))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Integration.Examples.fees_nonvacuity: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Integration.Examples.fees_nonvacuity
-- INT-second-valid; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Integration.Examples.second_valid
  unless info.isTheorem do throwError "Etna.Integration.Examples.second_valid is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(Etna.Integration.ValidBatch
  Etna.Integration.Examples.auth Etna.Integration.Examples.middleWorld Etna.Integration.Examples.secondInput
  Etna.Integration.Examples.secondExternal
  (Etna.Landing.computedStatement Etna.Integration.Examples.middleWorld Etna.Integration.Examples.secondInput
    Etna.Integration.Examples.secondExternal)
  Etna.Integration.Examples.secondBatch))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Integration.Examples.second_valid: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Integration.Examples.second_valid
-- INT-landed-multicall-nonvacuity; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Integration.Examples.landed_multicall_nonvacuity
  unless info.isTheorem do throwError "Etna.Integration.Examples.landed_multicall_nonvacuity is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(Etna.Integration.LandedCuts
  Etna.Integration.Examples.auth Etna.Integration.Examples.world Etna.Integration.Examples.before
  [[Etna.Integration.Examples.block], [Etna.Integration.Examples.secondBlock]] [Option.some 0, Option.none] []
  Etna.Integration.Examples.finalWorld Etna.Integration.Examples.secondState 1))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Integration.Examples.landed_multicall_nonvacuity: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Integration.Examples.landed_multicall_nonvacuity
-- INT-forged-head-not-valid; explicit assumptions: []
run_elab do
  let info ← Lean.getConstInfo `Etna.Integration.Examples.forged_head_not_valid
  unless info.isTheorem do throwError "Etna.Integration.Examples.forged_head_not_valid is not a theorem"
  let expected ← Lean.Elab.Term.elabType (← `(¬Etna.Integration.ValidBatch
    Etna.Integration.Examples.auth Etna.Integration.Examples.world
    (have __src := Etna.Integration.Examples.input;
    { lastHeight := __src.lastHeight, lastBlockHash := __src.lastBlockHash, lastStateRoot := __src.lastStateRoot,
      reference := __src.reference, headAfter := 0, recipient := __src.recipient, caller := __src.caller })
    Etna.Integration.Examples.external
    (Etna.Landing.computedStatement Etna.Integration.Examples.world
      (have __src := Etna.Integration.Examples.input;
      { lastHeight := __src.lastHeight, lastBlockHash := __src.lastBlockHash, lastStateRoot := __src.lastStateRoot,
        reference := __src.reference, headAfter := 0, recipient := __src.recipient, caller := __src.caller })
      Etna.Integration.Examples.external)
    Etna.Integration.Examples.batch))
  Lean.Elab.Term.synthesizeSyntheticMVarsNoPostponing
  let expected ← Lean.instantiateMVars expected
  if expected.hasMVar then throwError "manifest type contains unresolved metavariables"
  unless ← Lean.Meta.isDefEq info.type expected do throwError "Etna.Integration.Examples.forged_head_not_valid: full type mismatch"
  Lean.logInfo m!"Full declared type: {info.type}"
#print axioms Etna.Integration.Examples.forged_head_not_valid
