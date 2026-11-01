import EtnaModel.NormalSigning
import EtnaProofs.SigningBridge
import EtnaProofs.Permanence

namespace Etna.Design.NormalSigning
open ProtocolState SigningBridge

/-- The ordinary provenance relation composes without omitting any operation. -/
theorem ordinary_append {a b c : World} (first : OrdinaryTrace a b) (last : OrdinaryTrace b c) :
    OrdinaryTrace a c := by
  induction last with
  | refl => exact first
  | step _ change ih => exact .step ih change

/-- Every ordinary edge is an original protocol edge with identical inputs. -/
theorem ordinary_trace {w t : World} (trace : OrdinaryTrace w t) : Trace w t := by
  induction trace with
  | refl => exact .refl _
  | step _ change ih => exact .step ih (ordinary_step_is_step change)

/-- Projection keeps all ordinary transactions, including recovery and invalidation. -/
theorem run_ordinary {w t : World} (run : Run w t) : OrdinaryTrace w t := by
  induction run with
  | refl => exact .refl _
  | landing _ time accepted _ _ _ _ _ ih => exact .step ih (.landing time accepted)
  | other _ change _ ih => exact .step ih change

/-- No replacement transition machine is substituted for the original trace. -/
theorem run_trace {w t : World} (run : Run w t) : Trace w t := ordinary_trace (run_ordinary run)

private theorem ordinary_nonlanding_snapshot {w t : World} (change : OrdinaryStep w t)
    (settled : t.inbox.checkpoint.height ≤ w.inbox.checkpoint.height) :
    t.inbox.snapshot = w.inbox.snapshot := by
  cases change with
  | landing _ accepted =>
    have advance := (land_extends_checkpoint accepted).1
    dsimp only [landed] at settled
    omega
  | registration => rfl
  | modification => rfl
  | enqueue _ _ _ accepted =>
    unfold Forced.enqueue at accepted
    dsimp only at accepted
    split at accepted <;> cases accepted
    rfl
  | sweep _ accepted => unfold Forced.sweep at accepted; split at accepted <;> cases accepted; rfl
  | recovery _ accepted => exact (Recovery.recovery_preserves_settled_prefix accepted).2.2.2.2.2.1
  | invalidation _ accepted => obtain ⟨_,rfl⟩ := Recovery.invalidation_success accepted; rfl

/-- Accepted source provenance derives snapshot monotonicity; it is not an edge premise. -/
theorem landing_snapshot_monotone {w : World} {s : State} {i : LandInput} {leaves : List Leaf}
    {e : LandingEnv} {r template : BlockValidity.Rules} {archive : List Nat}
    {parent : BlockValidity.Header} {blocks : List BlockValidity.Block} {blobs : List Hash}
    (accepted : Etna.Design.land w.inbox i leaves e = some s)
    (built : Deployment.build w w.inbox.configuration archive template = some r)
    (valid : Settlement.BatchValid r parent blocks blobs)
    (binding : e.certificate = Settlement.statement r parent blocks blobs)
    (source : SnapshotSource w.inbox r.consensus) : w.inbox.snapshot ≤ s.snapshot := by
  obtain ⟨_,_,_,_,_,_,_,ctx,constructed,equal⟩ := Deployment.build_success built
  have context : HistoricalContext.build w.inbox w.registry
      (Deployment.parameters w.inbox w.inbox.configuration) archive = some r.consensus := by
    rw [equal]
    exact constructed
  have endpoint := Settlement.accepted_terminal_from_valid_chain accepted valid binding
  have advance := (land_extends_checkpoint accepted).1
  rw [endpoint.2.2.2.2.1]
  apply source_snapshot_bound source context
  rw [← endpoint.1]
  exact Nat.le_of_lt advance

/-- The snapshot discipline previously required by trace_covered follows from normal
landing provenance and exact ordinary nonlanding operations, including normal recovery. -/
theorem run_snapshot_trace {w t : World} (run : Run w t) : SigningEscrow.SnapshotTrace w t := by
  induction run with
  | refl => exact .refl _
  | landing _ time accepted built valid binding source _ ih =>
    exact .step ih (.landing time accepted)
      (.inl (landing_snapshot_monotone accepted built valid binding source))
  | other _ change settled ih =>
    exact .step ih (ordinary_step_is_step change)
      (.inl (Nat.le_of_eq (ordinary_nonlanding_snapshot change settled).symm))

/-- Confirmation coverage is a derived whole-run invariant, not a final-state premise. -/
theorem run_covered {w t : World} (run : Run w t) (initial : SigningEscrow.Covered w) :
    SigningEscrow.Covered t := SigningEscrow.trace_covered (run_snapshot_trace run) initial

/-- The stored snapshot stays strictly before the L1 clock, including same-block
normal recoveries. Only the established landing reference contract is needed. -/
theorem run_snapshot_below {w t : World} (run : Run w t) (initial : w.inbox.snapshot < w.l1Block) :
    t.inbox.snapshot < t.l1Block := by
  induction run with
  | refl => exact initial
  | landing _ _ accepted _ _ _ _ reference _ => exact land_snapshot_below_block accepted reference
  | other _ change settled ih =>
    rw [ordinary_nonlanding_snapshot change settled]
    exact Nat.lt_of_lt_of_le ih (step_clock_monotone (ordinary_step_is_step change))

/-- Both provenance alternatives establish actual ordinary causality to the signing view. -/
theorem source_ordinary {confirmed view : World} {p : TrustedPrefix view}
    (source : ConfirmationSource confirmed view p) : OrdinaryTrace confirmed view := by
  cases source with
  | replay later _ => exact later
  | recovery before time accepted after _ _ => exact ordinary_append (.step before (.recovery time accepted)) after

/-- A confirmation checkpoint below a recovery origin remains the same complete stored
record; its height alone is not substituted for authentic retained history. -/
theorem source_retains_checkpoint {confirmed view : World} {p : TrustedPrefix view}
    (source : ConfirmationSource confirmed view p) :
    recordAt view.inbox confirmed.inbox.checkpoint.height =
      recordAt confirmed.inbox confirmed.inbox.checkpoint.height :=
  ordinary_trace_preserves_settled_records (source_ordinary source) _ (Nat.le_refl _)

/-- Replay inclusion or actual normal recovery derives coverage by the current selector.
No selected-cutoff inequality is assumed; a recovery source may predate the fixed origin. -/
theorem confirmation_source_bound {confirmed view : World} (p : TrustedPrefix view)
    (source : ConfirmationSource confirmed view p)
    (below : confirmed.inbox.snapshot < confirmed.l1Block)
    (message : SignMessage) (next : message.height = p.tip.height+1) :
    confirmed.inbox.snapshot ≤ (Consensus.activeAt p.rules.consensus message.height).cutoff := by
  cases source with
  | replay _ seen => exact included_snapshot_bound p seen message next
  | @recovery before s a origin owner externalOK prior time accepted after generation originKept =>
    have clock := trace_clock_monotone (ordinary_trace prior)
    obtain ⟨ready,context⟩ := HistoricalContext.build_success p.constructed
    have genesis : p.rules.consensus.genesisCutoff ≤ p.rules.consensus.originBlock := by
      rw [context]
      exact ready.2.2.2.2.2.2.2
    have currentGeneration : p.rules.consensus.generation = before.inbox.generation+1 := by
      rw [context]
      exact generation
    have currentOrigin : p.rules.consensus.originBlock = origin.l1Block := by
      rw [context]
      exact congrArg Origin.l1Block originKept
    have floor : Settlement.floor p.rules.consensus = origin.l1Block := by
      simp [Settlement.floor,currentGeneration,currentOrigin]
    have bound := Settlement.floor_le_active p.rules.consensus genesis message.height
    rw [floor] at bound
    omega

/-- A confirmed lifetime key stays excluded from the actual next-height committee through
normal rotation/recovery, withdrawal and reuse, with the original trace history preserved. -/
theorem confirmed_key_excluded {initial confirmed view : World} {id c : Nat}
    (prior : Run initial confirmed) (core : Core initial)
    (keys : SigningEscrow.KeysWellFormed initial.registry)
    (visible : SigningEscrow.ExitVisible initial.registry)
    (coverage : SigningEscrow.Covered initial) (below : initial.inbox.snapshot < initial.l1Block)
    (p : TrustedPrefix view) (source : ConfirmationSource confirmed view p)
    (message : SignMessage) (next : message.height = p.tip.height+1)
    (range : id < confirmed.registry.nextId) (recorded : (confirmed.registry.slots id).confirmedAt = some c)
    (nonzero : (confirmed.registry.slots id).key ≠ 0)
    (finite : (confirmed.registry.slots id).exitAt ≠ Staking.noExit) :
    ∀ entry ∈ (Consensus.activeAt p.rules.consensus message.height).members,
      entry.key ≠ (confirmed.registry.slots id).key := by
  have history := run_trace prior
  have currentKeys := SigningEscrow.trace_keys_well_formed history keys
  have exitHistory := SigningEscrow.trace_exit_visible history core keys visible id range nonzero finite
  have excluded : SigningEscrow.Excluded (confirmed.registry.slots id).key
      (confirmed.registry.slots id).exitAt confirmed.registry := by
    intro j bound same
    have unique := currentKeys.unique _ nonzero id range j bound rfl same
    subst j
    exact Nat.le_refl _
  have retained := SigningEscrow.trace_history_excluded (ordinary_trace (source_ordinary source)) nonzero
    (currentKeys.allocated id range nonzero) excluded exitHistory
  exact SigningEscrow.selected_excludes_confirmed_key p.constructed retained
    (Nat.le_trans (run_covered prior coverage id c recorded)
      (confirmation_source_bound p source (run_snapshot_below prior below) message next))

/-- Full composition with the real successful signer call: retained checkpoint, current
request height, derived cutoff, exact fresh signature/log and exclusion of the old key. -/
theorem fresh_signing_connection {initial confirmed view : World} {id c : Nat}
    (prior : Run initial confirmed) (core : Core initial)
    (keys : SigningEscrow.KeysWellFormed initial.registry)
    (visible : SigningEscrow.ExitVisible initial.registry)
    (coverage : SigningEscrow.Covered initial) (below : initial.inbox.snapshot < initial.l1Block)
    (p : TrustedPrefix view) (source : ConfirmationSource confirmed view p) (call : ObservedCall p)
    (engine : EngineRequest p call.device.key call.message) (fresh : call.after.log ≠ call.device.state.log)
    (range : id < confirmed.registry.nextId) (recorded : (confirmed.registry.slots id).confirmedAt = some c)
    (nonzero : (confirmed.registry.slots id).key ≠ 0)
    (finite : (confirmed.registry.slots id).exitAt ≠ Staking.noExit) :
    recordAt view.inbox confirmed.inbox.checkpoint.height =
      recordAt confirmed.inbox confirmed.inbox.checkpoint.height ∧
    call.device.state.ready = true ∧ call.request.trusted = true ∧
    call.request.position.height = p.tip.height+1 ∧
    confirmed.inbox.snapshot ≤ (Consensus.activeAt p.rules.consensus call.request.position.height).cutoff ∧
    call.returned = call.supplied ∧
    call.after.log = ⟨call.message.generation,call.request.position,call.request.bytes,call.supplied⟩ :: call.device.state.log ∧
    call.device.key ≠ (confirmed.registry.slots id).key := by
  have height : call.request.position.height = call.message.height := by rw [call.decoded]; rfl
  obtain ⟨ready,trusted⟩ := successful_call_requires_trust call
  obtain ⟨returned,log⟩ := fresh_return_binds_message call fresh
  refine ⟨source_retains_checkpoint source,ready,trusted,height.trans engine.2.2.1,?_,returned,log,?_⟩
  · rw [height]
    exact confirmation_source_bound p source (run_snapshot_below prior below) call.message engine.2.2.1
  · obtain ⟨entry,member,key⟩ := engine.2.2.2
    exact key ▸ confirmed_key_excluded prior core keys visible coverage below p source call.message
      engine.2.2.1 range recorded nonzero finite entry member

/-- Genuine initialization supplies the structural core and clock bound; the initially
registered keys and absence of confirmations remain explicit deployment-state obligations. -/
theorem initialized_fresh_signing_connection {initial confirmed view : World} {id c hash root : Nat}
    (init : Deployment.Genesis initial hash root) (prior : Run initial confirmed)
    (keys : SigningEscrow.KeysWellFormed initial.registry)
    (visible : SigningEscrow.ExitVisible initial.registry)
    (unconfirmed : ∀ id, (initial.registry.slots id).confirmedAt = none)
    (p : TrustedPrefix view) (source : ConfirmationSource confirmed view p) (call : ObservedCall p)
    (engine : EngineRequest p call.device.key call.message) (fresh : call.after.log ≠ call.device.state.log)
    (range : id < confirmed.registry.nextId) (recorded : (confirmed.registry.slots id).confirmedAt = some c)
    (nonzero : (confirmed.registry.slots id).key ≠ 0)
    (finite : (confirmed.registry.slots id).exitAt ≠ Staking.noExit) :
    call.device.key ≠ (confirmed.registry.slots id).key := by
  have coverage : SigningEscrow.Covered initial := by
    intro id c present
    rw [unconfirmed id] at present
    contradiction
  obtain ⟨_,_,_,_,_,_,_,excluded⟩ := fresh_signing_connection prior (Deployment.genesis_core init)
    keys visible coverage (Deployment.genesis_snapshot_below init) p source call engine fresh range recorded nonzero finite
  exact excluded

end Etna.Design.NormalSigning
