import EtnaModel.SigningBridge
import EtnaProofs.SigningPrefix
import EtnaProofs.SigningEscrow
import EtnaProofs.Deployment

namespace Etna.Design.SigningBridge

/-- Independent contract for the actual message-to-request adapter coordinates. -/
theorem message_request_contract (encode : SignMessage → Hash) (m : SignMessage) (trusted : Bool) :
    _root_.Etna.Design.SigningBridge.messageRequest encode m trusted =
      ⟨m.domain,m.generation,trusted,⟨m.height,m.round,phaseStep m.phase⟩,encode m⟩ := rfl

/-- Both authenticated checkpoint hashes and its cursor are required, not just height. -/
theorem header_matches_contract (cp : Checkpoint) (h : BlockValidity.Header) :
    _root_.Etna.Design.SigningBridge.headerMatches cp h ↔
      h.height = cp.height ∧ h.elHash = cp.elHash ∧ h.cometHash = cp.cometHash ∧ h.cursor = cp.cursor := Iff.rfl

/-- Historical entry updates do not change selection coordinates on one bound archive. -/
theorem same_history_cutoff {a b : Consensus.Context} (same : SameSigningHistory a b) (h : Nat) :
    (Consensus.activeAt a h).cutoff = (Consensus.activeAt b h).cutoff := by
  obtain ⟨_,generation,originHeight,originBlock,genesis,epochLen,anchors⟩ := same
  unfold Consensus.activeAt Consensus.epoch Consensus.switchHeight
  simp only [originHeight,epochLen]
  by_cases ordinary : b.originHeight < (h-1)/b.epochLen*b.epochLen-1
  · simp only [ite_eq_left ordinary]
    simp [Consensus.normal,Consensus.selected,originBlock,epochLen,anchors]
  · simp only [ite_eq_right ordinary]
    simp [Consensus.initial,Consensus.selected,generation,originHeight,originBlock,genesis,epochLen]

/-- Prefix concatenation is derived from actual valid decoded blocks. -/
theorem valid_chain_split {r : BlockValidity.Rules} {origin : BlockValidity.Header}
    {before after : List BlockValidity.Block} (valid : BlockValidity.Chain r origin (before ++ after)) :
    BlockValidity.Chain r origin before ∧
    BlockValidity.Chain r (BlockValidity.terminal origin before) after := by
  induction before generalizing origin with
  | nil => exact ⟨True.intro,valid⟩
  | cons b rest ih =>
    obtain ⟨head,tail⟩ := valid
    obtain ⟨first,last⟩ := ih tail
    exact ⟨⟨head,first⟩,last⟩

/-- The fully validated local prefix has reached its authenticated trust target. -/
theorem prefix_reaches_checkpoint {view : ProtocolState.World} (p : TrustedPrefix view) :
    view.inbox.checkpoint.height ≤ p.tip.height := by
  have ext := BlockValidity.chain_height p.extensionValid
  have checkpoint := p.checkpoint.1
  change view.inbox.checkpoint.height ≤
    (BlockValidity.terminal (BlockValidity.terminal p.origin p.replay) p.extension).height
  omega

/-- Inclusion of a checkpoint supplies height ordering from real prefix decomposition. -/
theorem included_checkpoint_reached {confirmed view : ProtocolState.World} (p : TrustedPrefix view)
    (seen : IncludedCheckpoint confirmed p) : confirmed.inbox.checkpoint.height ≤ p.tip.height := by
  have valid := p.replayValid
  rw [seen.decomposition] at valid
  obtain ⟨_,remaining⟩ := valid_chain_split valid
  have height := BlockValidity.chain_height remaining
  have endHeight := BlockValidity.chain_height p.replayValid
  have beforeHeight := BlockValidity.chain_height (valid_chain_split valid).1
  have ext := BlockValidity.chain_height p.extensionValid
  have lengths := congrArg List.length seen.decomposition
  simp only [List.length_append] at lengths
  have matched := seen.checkpointBinding.1
  change confirmed.inbox.checkpoint.height ≤
    (BlockValidity.terminal (BlockValidity.terminal p.origin p.replay) p.extension).height
  omega

/-- A stored snapshot bound follows from its source and the actual built selector. -/
theorem source_snapshot_bound {s : State} {ctx : Consensus.Context} {registry : RegistryHistory.State}
    {cfg : HistoricalContext.Parameters} {archive : List Nat} {view : State} {h : Nat}
    (source : SnapshotSource s ctx) (built : HistoricalContext.build view registry cfg archive = some ctx)
    (later : s.checkpoint.height ≤ h) : s.snapshot ≤ (Consensus.activeAt ctx h).cutoff := by
  cases source with
  | atFloor stored =>
    have mono := SigningPrefix.built_active_cutoff_monotone built (Nat.zero_le h)
    have floor : (Consensus.activeAt ctx 0).cutoff = Settlement.floor ctx := by
      simp [Consensus.activeAt,Consensus.epoch,Consensus.switchHeight,Consensus.initial,
        Consensus.selected,Settlement.floor]
    rw [floor,← stored] at mono
    exact mono
  | acceptedBatch accepted valid binding sameHistory =>
    have endpoint := Settlement.accepted_terminal_from_valid_chain accepted valid binding
    rw [endpoint.2.2.2.2.1,same_history_cutoff sameHistory]
    exact SigningPrefix.built_active_cutoff_monotone built (by omega)
  | carriedBatch accepted valid binding sameHistory checkpointKept snapshotKept =>
    have endpoint := Settlement.accepted_terminal_from_valid_chain accepted valid binding
    rw [snapshotKept,endpoint.2.2.2.2.1,same_history_cutoff sameHistory]
    have height := congrArg Checkpoint.height checkpointKept
    exact SigningPrefix.built_active_cutoff_monotone built (by omega)
  | extendedArchive accepted valid binding oldHistory newHistory covered checkpointKept snapshotKept =>
    have endpoint := Settlement.accepted_terminal_from_valid_chain accepted valid binding
    rw [snapshotKept,endpoint.2.2.2.2.1,oldHistory]
    rw [SigningPrefix.extended_archive_cutoff _ _ _ _ _ _ _ (by omega),← newHistory]
    have height := congrArg Checkpoint.height checkpointKept
    exact SigningPrefix.built_active_cutoff_monotone built (by omega)
  | beforeRecovery accepted _ _ referenceBound newGeneration precedesOrigin _ snapshotKept =>
    have below := land_snapshot_below_block accepted referenceBound
    obtain ⟨ready,context⟩ := HistoricalContext.build_success built
    have floor := Settlement.floor_le_active ctx (by rw [context]; exact ready.2.2.2.2.2.2.2) h
    have bound : s.snapshot ≤ Settlement.floor ctx := by
      rw [Settlement.floor]
      simp only [newGeneration,↓reduceIte]
      omega
    exact Nat.le_trans bound floor

/-- The actual next-height request derives the stored snapshot bound; no cutoff bound is
an input. Node authentication and request discipline remain the named typed inputs. -/
theorem request_snapshot_bound {view : ProtocolState.World} (p : TrustedPrefix view) (m : SignMessage)
    (next : m.height = p.tip.height+1) :
    view.inbox.snapshot ≤ (Consensus.activeAt p.rules.consensus m.height).cutoff := by
  apply source_snapshot_bound p.snapshotSource p.constructed
  have reached := prefix_reaches_checkpoint p
  omega

/-- A confirmation truly included in the authenticated replay has its snapshot covered
by every actual next-height request, even if the node has since extended beyond target. -/
theorem included_snapshot_bound {confirmed view : ProtocolState.World} (p : TrustedPrefix view)
    (seen : IncludedCheckpoint confirmed p) (m : SignMessage) (next : m.height = p.tip.height+1) :
    confirmed.inbox.snapshot ≤ (Consensus.activeAt p.rules.consensus m.height).cutoff := by
  apply source_snapshot_bound seen.source p.constructed
  have reached := included_checkpoint_reached p seen
  omega

/-- Successful stock signing can append exactly one decoded record or return the cached
original. A fresh append returns the supplied signature, not an unrelated cached one. -/
theorem fresh_return_binds_message {view : ProtocolState.World} {p : TrustedPrefix view}
    (call : ObservedCall p) (fresh : call.after.log ≠ call.device.state.log) :
    call.returned = call.supplied ∧
    call.after.log = ⟨call.message.generation,call.request.position,call.request.bytes,call.supplied⟩ ::
      call.device.state.log := by
  have result := call.result
  have generation : call.request.generation = call.message.generation := by
    rw [call.decoded]
    rfl
  unfold Signer.sign at result
  split at result
  · split at result
    · split at result
      · split at result
        · have same := congrArg Signer.State.log (congrArg Prod.fst (Option.some.inj result))
          exact False.elim (fresh same.symm)
        · contradiction
      · split at result
        · have pair := Option.some.inj result
          refine ⟨(congrArg Prod.snd pair).symm,?_⟩
          have logs := (congrArg Signer.State.log (congrArg Prod.fst pair)).symm
          simpa only [generation] using logs
        · contradiction
    · split at result
      · have pair := Option.some.inj result
        refine ⟨(congrArg Prod.snd pair).symm,?_⟩
        have logs := (congrArg Signer.State.log (congrArg Prod.fst pair)).symm
        simpa only [generation] using logs
      · contradiction
  · contradiction

/-- Every successful stock return still passes both the session and per-request trust
bits. The typed checkpoint proof is separate from these necessary boolean guards. -/
theorem successful_call_requires_trust {view : ProtocolState.World} {p : TrustedPrefix view}
    (call : ObservedCall p) : call.device.state.ready = true ∧ call.request.trusted = true := by
  have result := call.result
  have allow : Signer.authorized call.device.state call.request = true := by
    cases found : Signer.authorized call.device.state call.request with
    | false => simp [Signer.sign,found] at result
    | true => rfl
  simp only [Signer.authorized,Bool.and_eq_true] at allow
  exact ⟨allow.1.1,allow.1.2⟩

/-- The full lifetime exclusion bridge. The actual confirmation is on the same trusted
prefix, the request is for that prefix's next height and the producer uses its real
committee. A later observed call cannot authorize the exited lifetime key. No live-bond,
positive-escrow or cutoff/exclusion premise is assumed. -/
theorem event_excludes_visible_key {initial confirmed view : ProtocolState.World}
    {id c : Nat} (prior : ProtocolState.Trace initial confirmed) (core : ProtocolState.Core initial)
    (initialKeys : SigningEscrow.KeysWellFormed initial.registry)
    (initialVisible : SigningEscrow.ExitVisible initial.registry) (toView : ProtocolState.Trace confirmed view)
    (p : TrustedPrefix view) (seen : IncludedCheckpoint confirmed p) (call : ObservedCall p)
    (engine : EngineRequest p call.device.key call.message) (range : id < confirmed.registry.nextId)
    (recorded : (confirmed.registry.slots id).confirmedAt = some c) (covered : SigningEscrow.Covered confirmed)
    (nonzero : (confirmed.registry.slots id).key ≠ 0)
    (finite : (confirmed.registry.slots id).exitAt ≠ Staking.noExit) :
    call.device.key ≠ (confirmed.registry.slots id).key := by
  have keys := SigningEscrow.trace_keys_well_formed prior initialKeys
  have visible := SigningEscrow.trace_exit_visible prior core initialKeys initialVisible
  have excludedNow : SigningEscrow.Excluded (confirmed.registry.slots id).key
      (confirmed.registry.slots id).exitAt confirmed.registry := by
    intro j bound equal
    have unique := keys.unique _ nonzero id range j bound rfl equal
    subst j
    exact Nat.le_refl _
  have barrier := SigningEscrow.trace_history_excluded toView nonzero (keys.allocated id range nonzero)
    excludedNow (visible id range nonzero finite)
  have cutoff := included_snapshot_bound p seen call.message engine.2.2.1
  have excluded := SigningEscrow.selected_excludes_confirmed_key p.constructed barrier
    (Nat.le_trans (covered id c recorded) cutoff)
  obtain ⟨entry,member,key⟩ := engine.2.2.2
  exact key ▸ excluded entry member

/-- Configured zero-slot histories establish the general theorem's identity and initial
exit-history premises, without requiring them as additional user hypotheses. -/
theorem event_excludes_confirmed_key {initial confirmed view : ProtocolState.World}
    {id c : Nat} (prior : ProtocolState.Trace initial confirmed) (core : ProtocolState.Core initial)
    (empty : initial.registry.nextId = 0) (toView : ProtocolState.Trace confirmed view)
    (p : TrustedPrefix view) (seen : IncludedCheckpoint confirmed p) (call : ObservedCall p)
    (engine : EngineRequest p call.device.key call.message) (range : id < confirmed.registry.nextId)
    (recorded : (confirmed.registry.slots id).confirmedAt = some c) (covered : SigningEscrow.Covered confirmed)
    (nonzero : (confirmed.registry.slots id).key ≠ 0)
    (finite : (confirmed.registry.slots id).exitAt ≠ Staking.noExit) :
    call.device.key ≠ (confirmed.registry.slots id).key := by
  have visible : SigningEscrow.ExitVisible initial.registry := by
    intro id range
    omega
  exact event_excludes_visible_key prior core
    (SigningEscrow.unallocated_keys_well_formed _ empty) visible toView
    p seen call engine range recorded covered nonzero finite

/-- Genuine initialization supplies the exact generation-0 source floor. -/
theorem genesis_snapshot_source {w : ProtocolState.World} {hash root : Hash} {cfg : Deployment.Config}
    {archive : List Nat} {template r : BlockValidity.Rules} (init : Deployment.Genesis w hash root)
    (built : Deployment.build w cfg archive template = some r) : SnapshotSource w.inbox r.consensus := by
  have floor := (Deployment.genesis_snapshot_fits init built).1
  exact .atFloor (init.2.2.2.2.2.2.2.1.trans floor.symm)

/-- The assembled signing connection reads the real successful transition, binds a fresh
returned signature and log entry to the exact message, and derives snapshot coverage and
lifetime exclusion from its authenticated prefix. This is conditional on the adapter and
engine refinements, not on Request.trusted alone. -/
theorem fresh_signing_connection {initial confirmed view : ProtocolState.World} {id c : Nat}
    (prior : ProtocolState.Trace initial confirmed) (core : ProtocolState.Core initial)
    (keys : SigningEscrow.KeysWellFormed initial.registry) (visible : SigningEscrow.ExitVisible initial.registry)
    (toView : ProtocolState.Trace confirmed view) (p : TrustedPrefix view)
    (seen : IncludedCheckpoint confirmed p) (call : ObservedCall p)
    (engine : EngineRequest p call.device.key call.message) (fresh : call.after.log ≠ call.device.state.log)
    (range : id < confirmed.registry.nextId) (recorded : (confirmed.registry.slots id).confirmedAt = some c)
    (covered : SigningEscrow.Covered confirmed) (nonzero : (confirmed.registry.slots id).key ≠ 0)
    (finite : (confirmed.registry.slots id).exitAt ≠ Staking.noExit) :
    call.device.state.ready = true ∧ call.request.trusted = true ∧
    call.request.position.height = p.tip.height+1 ∧
    confirmed.inbox.snapshot ≤ (Consensus.activeAt p.rules.consensus call.request.position.height).cutoff ∧
    call.returned = call.supplied ∧
    call.after.log = ⟨call.message.generation,call.request.position,call.request.bytes,call.supplied⟩ :: call.device.state.log ∧
    call.device.key ≠ (confirmed.registry.slots id).key := by
  have height : call.request.position.height = call.message.height := by rw [call.decoded]; rfl
  obtain ⟨ready,trusted⟩ := successful_call_requires_trust call
  obtain ⟨returned,log⟩ := fresh_return_binds_message call fresh
  refine ⟨ready,trusted,height.trans engine.2.2.1,?_,returned,log,?_⟩
  · rw [height]
    exact included_snapshot_bound p seen call.message engine.2.2.1
  · exact event_excludes_visible_key prior core keys visible toView p seen call engine range recorded covered nonzero finite

end Etna.Design.SigningBridge
