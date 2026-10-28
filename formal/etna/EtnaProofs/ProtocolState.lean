import EtnaModel.ProtocolState
import EtnaProofs.HistoricalContext
import EtnaProofs.Settlement

/-! Proofs about `EtnaModel.ProtocolState`. -/
namespace Etna.Design.ProtocolState

theorem landing_inbox_valid {s t : State} {i : LandInput} {leaves : List Leaf} {e : LandingEnv}
    (before : InboxValid s) (ok : Etna.Design.land s i leaves e = some t) : InboxValid t := by
  have settled := Settlement.landing_preserves_state before.settled ok
  have bounds := land_fi_bound ok
  obtain ⟨_,rfl⟩ := land_success ok
  refine ⟨settled,before.fees,bounds.2.1,?_⟩
  intro record mem
  simp only [applyLanding,List.mem_cons] at mem
  rcases mem with rfl | old
  · exact bounds.2.1
  · exact before.recordCursors record old

theorem rollback_inbox_valid (s : State) (trusted : Checkpoint) (snapshot : Nat)
    (before : InboxValid s) (retained : recordAt s trusted.height = some trusted) :
    InboxValid (Recovery.rollbackInbox s trusted snapshot) := by
  have mem : trusted ∈ s.records := List.mem_of_find?_eq_some retained
  have grid := Recovery.rollback_preserves_grid s trusted snapshot mem before.settled.2.2.1
  have record := Recovery.find_height_filter trusted s.records retained
  refine ⟨⟨record,rfl,grid,?_,?_⟩,before.fees,before.recordCursors trusted mem,?_⟩
  · exact before.settled.2.2.2.1.sublist (List.Sublist.map Checkpoint.height (List.filter_sublist))
  · intro r member
    exact of_decide_eq_true (List.mem_filter.mp member).2
  · intro r member
    exact before.recordCursors r (List.mem_filter.mp member).1

theorem registration_registry_valid {s t : RegistryHistory.State} {key owner amount now : Nat}
    (before : RegistryValid s now) (ok : RegistryHistory.register s key owner amount now = some t) :
    RegistryValid t now := by
  have keys := RegistryHistory.register_preserves_keys before.keys ok
  have identities := RegistryHistory.register_preserves_identities before.identities ok
  unfold RegistryHistory.register at ok
  split at ok
  · rename_i allowed
    cases ok
    exact ⟨keys,identities,RegistryHistory.finish_preserves_order _ _ _ before.history allowed.1,
      RegistryHistory.finish_current_snapshot _ _ _ before.current,RegistryHistory.finish_block_bound _ _ _ allowed.1⟩
  · contradiction

theorem modification_registry_valid {s t : RegistryHistory.State} {inbox : State} {id now : Nat} {action : RegistryHistory.Edit}
    (before : RegistryValid s now) (ok : RegistryHistory.edit s inbox id now action = some t) : RegistryValid t now := by
  have keys := RegistryHistory.edited_preserves_keys before.keys ok
  have identities := RegistryHistory.edit_preserves_identities before.identities ok
  obtain ⟨_,time,bond,_,rfl⟩ := RegistryHistory.edit_success ok
  exact ⟨keys,identities,RegistryHistory.finish_preserves_order _ _ _ before.history time,
    RegistryHistory.finish_current_snapshot _ _ _ before.current,RegistryHistory.finish_block_bound _ _ _ time⟩

theorem registry_clock_advance {s : RegistryHistory.State} {a b : Nat} (before : RegistryValid s a) (time : a ≤ b) :
    RegistryValid s b := ⟨before.keys,before.identities,before.history,before.current,Nat.le_trans before.clock time⟩

theorem queue_clear_keeps_indices (w : Recovery.World) (indices : List Nat) (emptyHash : Hash) :
    (Recovery.clearedQueue w indices emptyHash).map Prod.fst = w.queue.map Prod.fst := by
  simp only [Recovery.clearedQueue,List.map_map]
  apply List.map_congr_left
  intro pair _
  rfl

theorem step_preserves_core {w t : World} (before : Core w) (change : Step w t) : Core t := by
  cases change with
  | landing time ok =>
    have fields := (land_success ok).2
    refine ⟨landing_inbox_valid before.inbox ok,registry_clock_advance before.registry time,?_⟩
    simpa only [landed,fields,applyLanding] using before.queue
  | registration time ok =>
    exact ⟨before.inbox,registration_registry_valid (registry_clock_advance before.registry time) ok,before.queue⟩
  | modification time _ ok =>
    exact ⟨before.inbox,modification_registry_valid (registry_clock_advance before.registry time) ok,before.queue⟩
  | enqueue time _ _ ok =>
    have fee := Forced.enqueue_conserves ok before.inbox.fees
    unfold Forced.enqueue at ok
    dsimp only at ok
    split at ok
    · cases ok
      refine ⟨⟨before.inbox.settled,fee,by change w.inbox.head ≤ w.inbox.tail+1; have := before.inbox.headBound; omega,?_⟩,
        registry_clock_advance before.registry time,?_⟩
      · intro r mem
        have bound := before.inbox.recordCursors r mem
        change r.cursor ≤ w.inbox.tail+1
        omega
      · simp only [enqueued,List.map_append,List.map_cons,List.map_nil]
        rw [before.queue,List.range_succ]
    · contradiction
  | sweep time ok =>
    have fee := (Forced.sweep_conserves ok before.inbox.fees).1
    unfold Forced.sweep at ok
    split at ok
    · cases ok
      exact ⟨⟨before.inbox.settled,fee,before.inbox.headBound,before.inbox.recordCursors⟩,
        registry_clock_advance before.registry time,before.queue⟩
    · contradiction
  | @recovery s a r owner externalOK time ok =>
    have info := Recovery.recover_success ok
    have clock := Nat.le_trans before.registry.clock time
    have registry := RegistryHistory.exclusions_preserve_registry w.registry a.exclusions r.l1Block before.registry.keys
      before.registry.identities before.registry.history clock
    rw [info.2]
    refine ⟨⟨before.inbox.settled,before.inbox.fees,before.inbox.headBound,before.inbox.recordCursors⟩,
      ⟨registry.1,registry.2.1,registry.2.2,RegistryHistory.finish_current_snapshot _ _ _ before.registry.current,
        RegistryHistory.finish_block_bound _ _ _ clock⟩,?_⟩
    simpa only [recovered,Recovery.applyRecovery,recoveryView,queue_clear_keeps_indices] using before.queue
  | rollback trusted snapshot now time retained =>
    refine ⟨rollback_inbox_valid _ trusted snapshot before.inbox retained,
      ⟨before.registry.keys,RegistryHistory.recheck_preserves_identities _ snapshot before.registry.identities,
        before.registry.history,RegistryHistory.recheck_current_snapshot _ snapshot before.registry.current,
        Nat.le_trans before.registry.clock time⟩,before.queue⟩

theorem trace_preserves_core {first last : World} (before : Core first) (trace : Trace first last) : Core last := by
  induction trace with
  | refl => exact before
  | step _ change ih => exact step_preserves_core ih change

theorem rollback_rechecks_confirmations (w : World) (trusted : Checkpoint) (snapshot now id atL1 : Nat)
    (kept : ((rollback w trusted snapshot now).registry.slots id).confirmedAt = some atL1) :
    (w.registry.slots id).exitAt ≤ snapshot := by
  apply Staking.rollbackBySnapshot_keeps_only_covered snapshot atL1 (w.registry.slots id)
  simpa only [rollback,RegistryHistory.recheckAll] using kept

theorem rollback_origin_blocks_landing (w : World) (trusted : Checkpoint) (snapshot now : Nat)
    (i : LandInput) (leaves : List Leaf) (e : LandingEnv) (below : trusted.height < w.inbox.origin.height) :
    Etna.Design.land (rollback w trusted snapshot now).inbox i leaves e = none :=
  Recovery.origin_above_rollback_blocks_landing _ _ _ i leaves e below

theorem rollback_keeps_lifetime_keys_and_history (w : World) (trusted : Checkpoint) (snapshot now : Nat) :
    (rollback w trusted snapshot now).registry.usedKeys = w.registry.usedKeys ∧
    (rollback w trusted snapshot now).registry.history = w.registry.history ∧
    (rollback w trusted snapshot now).inbox.generation = w.inbox.generation ∧
    (rollback w trusted snapshot now).inbox.origins = w.inbox.origins ∧
    (rollback w trusted snapshot now).queue = w.queue := ⟨rfl,rfl,rfl,rfl,rfl⟩

/-- The stronger endpoint result now consumes a context built from actual typed registry
history and the fixed origin; the caller cannot substitute an arbitrary registry oracle. -/
theorem accepted_snapshot_from_history {w : World} {t : State} {i : LandInput} {leaves : List Leaf} {e : LandingEnv}
    {r : BlockValidity.Rules} {p : BlockValidity.Header} {bs : List BlockValidity.Block} {blobs : List Hash}
    {cfg : HistoricalContext.Parameters} {archive : List Nat}
    (accepted : Etna.Design.land w.inbox i leaves e = some t)
    (valid : Settlement.BatchValid r p bs blobs)
    (binding : e.certificate = Settlement.statement r p bs blobs)
    (context : HistoricalContext.build w.inbox w.registry cfg archive = some r.consensus)
    (covered : (BlockValidity.terminal p bs).height < archive.length) :
    t.snapshot = HistoricalContext.cutoff w.inbox cfg archive (BlockValidity.terminal p bs).height ∧
    ∀ h, h ≤ (BlockValidity.terminal p bs).height → ∃ value, archive[h]? = some value ∧ r.consensus.anchorAt h = value := by
  have endpoint := (Settlement.accepted_terminal_from_valid_chain accepted valid binding).2.2.2.2.1
  refine ⟨?_,?_⟩
  · rw [endpoint,(HistoricalContext.build_success context).2]
    exact HistoricalContext.derived_cutoff _ _ _ _ _
  · intro h bound
    exact HistoricalContext.covered_context_header context h (by omega)

theorem step_clock_monotone {w t : World} (change : Step w t) : w.l1Block ≤ t.l1Block := by
  cases change <;> assumption

theorem trace_clock_monotone {w t : World} (trace : Trace w t) : w.l1Block ≤ t.l1Block := by
  induction trace with
  | refl => exact Nat.le_refl _
  | step _ change ih => exact Nat.le_trans ih (step_clock_monotone change)

theorem step_generation_monotone {w t : World} (change : Step w t) : w.inbox.generation ≤ t.inbox.generation := by
  cases change with
  | landing _ ok => obtain ⟨_,rfl⟩ := land_success ok; exact Nat.le_refl _
  | registration => exact Nat.le_refl _
  | modification => exact Nat.le_refl _
  | enqueue _ _ _ ok =>
    unfold Forced.enqueue at ok
    dsimp only at ok
    split at ok <;> cases ok
    exact Nat.le_refl _
  | sweep _ ok => unfold Forced.sweep at ok; split at ok <;> cases ok; exact Nat.le_refl _
  | @recovery s a r owner externalOK _ ok =>
    change w.inbox.generation ≤ s.inbox.generation
    rw [(Recovery.recovery_fixes_origin ok).1]
    exact Nat.le_succ _
  | rollback => exact Nat.le_refl _

theorem trace_generation_monotone {w t : World} (trace : Trace w t) : w.inbox.generation ≤ t.inbox.generation := by
  induction trace with
  | refl => exact Nat.le_refl _
  | step _ change ih => exact Nat.le_trans ih (step_generation_monotone change)

theorem step_keeps_origin_archive {w t : World} (change : Step w t) :
    ∃ extra, t.inbox.origins = w.inbox.origins ++ extra := by
  cases change with
  | landing _ ok => obtain ⟨_,rfl⟩ := land_success ok; exact ⟨[],by simp [landed,applyLanding]⟩
  | registration => exact ⟨[],by simp [registered]⟩
  | modification => exact ⟨[],by simp [registered]⟩
  | enqueue _ _ _ ok =>
    unfold Forced.enqueue at ok
    dsimp only at ok
    split at ok <;> cases ok
    exact ⟨[],by simp [enqueued]⟩
  | sweep _ ok =>
    unfold Forced.sweep at ok
    split at ok <;> cases ok
    exact ⟨[],by simp [landed]⟩
  | @recovery s a r owner externalOK _ ok =>
    exact ⟨[(s.inbox.generation,r)],(Recovery.recovery_fixes_origin ok).2.2.2⟩
  | rollback => exact ⟨[],by simp [rollback,Recovery.rollbackInbox]⟩

theorem trace_keeps_origin_archive {w t : World} (trace : Trace w t) :
    ∃ extra, t.inbox.origins = w.inbox.origins ++ extra := by
  induction trace with
  | refl => exact ⟨[],by simp⟩
  | step _ change ih =>
    obtain ⟨old,previous⟩ := ih
    obtain ⟨new,current⟩ := step_keeps_origin_archive change
    exact ⟨old ++ new,by rw [current,previous,List.append_assoc]⟩

theorem step_keeps_used_keys {w t : World} (change : Step w t) : ∀ key ∈ w.registry.usedKeys, key ∈ t.registry.usedKeys := by
  cases change with
  | landing => exact fun _ h => h
  | registration _ ok =>
    intro key mem
    simp only [registered]
    rw [(RegistryHistory.registered_identity ok).2.1]
    exact List.mem_cons_of_mem _ mem
  | modification _ _ ok => simp only [registered]; rw [(RegistryHistory.edited_keys_unchanged ok).1]; exact fun _ h => h
  | enqueue => exact fun _ h => h
  | sweep => exact fun _ h => h
  | recovery => exact fun _ h => h
  | rollback => exact fun _ h => h

theorem trace_keeps_used_keys {w t : World} (trace : Trace w t) : ∀ key ∈ w.registry.usedKeys, key ∈ t.registry.usedKeys := by
  induction trace with
  | refl => exact fun _ h => h
  | step _ change ih => exact fun key mem => step_keeps_used_keys change key (ih key mem)

private def frozen (w : World) :=
  (w.inbox.domain,w.inbox.committeeConfig,w.inbox.gridK,w.inbox.epochLen,w.inbox.genesisCutoff,w.inbox.committeeZero,
    w.inbox.configuration,w.inbox.committeeZeroRecord,w.inbox.maxAnchorAge,w.inbox.forcedDelay,
    w.inbox.maxBatchBlocks,w.inbox.forcedFee,w.inbox.forcedThreshold,w.inbox.protocolFeeRecipient,w.adapters,
    w.registry.verify,w.registry.slashBountyBps,w.registry.minStake,w.registry.activationDelay,w.registry.exitDelay,
    w.registry.withdrawalDelay)

private theorem step_frozen {w t : World} (change : Step w t) : frozen t = frozen w := by
  cases change with
  | landing _ ok => obtain ⟨_,rfl⟩ := land_success ok; rfl
  | registration _ ok =>
    unfold RegistryHistory.register at ok
    split at ok
    · cases ok; rfl
    · contradiction
  | modification _ _ ok => obtain ⟨_,_,_,_,rfl⟩ := RegistryHistory.edit_success ok; rfl
  | enqueue _ _ _ ok =>
    unfold Forced.enqueue at ok
    dsimp only at ok
    split at ok
    · cases ok; rfl
    · contradiction
  | sweep _ ok =>
    unfold Forced.sweep at ok
    split at ok
    · cases ok; rfl
    · contradiction
  | recovery _ ok => obtain ⟨_,rfl⟩ := Recovery.recover_success ok; rfl
  | rollback => rfl

/-- Initialized deployment values (domain, config/committee-0 commitments, K, L,
genesisCutoff, slot-282 values, the §11 Inbox immutables maxBatchBlocks, FI fee/threshold and
fee recipient), their ghost openings, the fixed hash adapters and recovery Keccak constants, and
the registry immutables (signature adapter, slashBountyBps, minStake and the three delays) are
never written by any landing, registry, FI, recovery or rollback transition, including the
internal recovery exclusions. -/
theorem step_preserves_immutables {w t : World} (change : Step w t) :
    t.inbox.domain = w.inbox.domain ∧ t.inbox.committeeConfig = w.inbox.committeeConfig ∧
    t.inbox.gridK = w.inbox.gridK ∧ t.inbox.epochLen = w.inbox.epochLen ∧
    t.inbox.genesisCutoff = w.inbox.genesisCutoff ∧ t.inbox.committeeZero = w.inbox.committeeZero ∧
    t.inbox.configuration = w.inbox.configuration ∧ t.inbox.committeeZeroRecord = w.inbox.committeeZeroRecord ∧
    t.inbox.maxAnchorAge = w.inbox.maxAnchorAge ∧ t.inbox.forcedDelay = w.inbox.forcedDelay ∧
    t.inbox.maxBatchBlocks = w.inbox.maxBatchBlocks ∧ t.inbox.forcedFee = w.inbox.forcedFee ∧
    t.inbox.forcedThreshold = w.inbox.forcedThreshold ∧ t.inbox.protocolFeeRecipient = w.inbox.protocolFeeRecipient ∧
    t.adapters = w.adapters ∧ t.registry.verify = w.registry.verify ∧
    t.registry.slashBountyBps = w.registry.slashBountyBps ∧ t.registry.minStake = w.registry.minStake ∧
    t.registry.activationDelay = w.registry.activationDelay ∧ t.registry.exitDelay = w.registry.exitDelay ∧
    t.registry.withdrawalDelay = w.registry.withdrawalDelay := by
  simpa only [frozen,Prod.mk.injEq] using step_frozen change

theorem trace_preserves_immutables {w t : World} (trace : Trace w t) :
    t.inbox.domain = w.inbox.domain ∧ t.inbox.committeeConfig = w.inbox.committeeConfig ∧
    t.inbox.gridK = w.inbox.gridK ∧ t.inbox.epochLen = w.inbox.epochLen ∧
    t.inbox.genesisCutoff = w.inbox.genesisCutoff ∧ t.inbox.committeeZero = w.inbox.committeeZero ∧
    t.inbox.configuration = w.inbox.configuration ∧ t.inbox.committeeZeroRecord = w.inbox.committeeZeroRecord ∧
    t.inbox.maxAnchorAge = w.inbox.maxAnchorAge ∧ t.inbox.forcedDelay = w.inbox.forcedDelay ∧
    t.inbox.maxBatchBlocks = w.inbox.maxBatchBlocks ∧ t.inbox.forcedFee = w.inbox.forcedFee ∧
    t.inbox.forcedThreshold = w.inbox.forcedThreshold ∧ t.inbox.protocolFeeRecipient = w.inbox.protocolFeeRecipient ∧
    t.adapters = w.adapters ∧ t.registry.verify = w.registry.verify ∧
    t.registry.slashBountyBps = w.registry.slashBountyBps ∧ t.registry.minStake = w.registry.minStake ∧
    t.registry.activationDelay = w.registry.activationDelay ∧ t.registry.exitDelay = w.registry.exitDelay ∧
    t.registry.withdrawalDelay = w.registry.withdrawalDelay := by
  have frozenTrace : frozen t = frozen w := by
    induction trace with
    | refl => rfl
    | step _ change ih => exact (step_frozen change).trans ih
  simpa only [frozen,Prod.mk.injEq] using frozenTrace

theorem step_preserves_old_snapshot {w t : World} (change : Step w t) (cutoff : Nat) (past : cutoff < w.l1Block) :
    RegistryHistory.latestSnapshot t.registry.history cutoff = RegistryHistory.latestSnapshot w.registry.history cutoff := by
  cases change with
  | landing => rfl
  | registration time ok => exact RegistryHistory.register_preserves_past ok (by omega)
  | modification time _ ok => exact RegistryHistory.edit_preserves_past ok (by omega)
  | enqueue => rfl
  | sweep => rfl
  | recovery time _ => exact RegistryHistory.finish_preserves_past _ _ _ _ (by omega)
  | rollback => rfl

theorem trace_preserves_old_snapshot {w t : World} (trace : Trace w t) (cutoff : Nat) (past : cutoff < w.l1Block) :
    RegistryHistory.latestSnapshot t.registry.history cutoff = RegistryHistory.latestSnapshot w.registry.history cutoff := by
  induction trace with
  | refl => rfl
  | step prior change ih =>
    have clock := trace_clock_monotone prior
    exact (step_preserves_old_snapshot change cutoff (by omega)).trans ih

theorem recovery_registry_matches (w : World) (a : Recovery.Request) (r : Origin)
    (owner externalOK : Bool) (t : Recovery.World)
    (ok : Recovery.recover (recoveryView w) a w.adapters.recovery r owner externalOK = some t) :
    RegistryHistory.registryView (recovered w a r t).registry = t.registry := by
  rw [(Recovery.recover_success ok).2]
  exact RegistryHistory.exclusions_match_registry_view _ _ _

/-- A recovery leaves slot 284 untouched, and any context built on the recovered Inbox has
generation ≥ 1 and floor R. Given the old snapshot is below R (true after any certified
landing, `land_snapshot_below_block`, since R's block is later), the new generation starts
with a snapshot fitting its context. -/
theorem recovered_snapshot_fits {w t : World} {a : Recovery.Request} {r : Origin}
    {owner externalOK : Bool} (ok : recover w a r owner externalOK = some t) (below : w.inbox.snapshot < r.l1Block)
    {registry : RegistryHistory.State} {params : HistoricalContext.Parameters} {archive : List Nat}
    {c : Consensus.Context} (built : HistoricalContext.build t.inbox registry params archive = some c) :
    t.inbox.snapshot = w.inbox.snapshot ∧ Settlement.floor c = r.l1Block ∧ Settlement.SnapshotFits c t.inbox := by
  unfold recover at ok
  cases found : Recovery.recover (recoveryView w) a w.adapters.recovery r owner externalOK with
  | none => simp [found] at ok
  | some s =>
    simp only [found,Option.map_some,Option.some.injEq] at ok
    subst ok
    obtain ⟨_,rfl⟩ := Recovery.recover_success found
    have floor : Settlement.floor c = r.l1Block := by
      rw [(HistoricalContext.build_success built).2]
      simp [Settlement.floor,HistoricalContext.derive,recovered,Recovery.applyRecovery,recoveryView]
    exact ⟨rfl,floor,Or.inr (by rw [floor]; exact Nat.le_of_lt below)⟩

/-- Slot 284 across a recovery: from the old generation's last value through every certified
landing of the new generation under its built context, the snapshot never decreases and keeps
fitting that context. With `Settlement.certified_trace_snapshot_monotone` per generation this
covers recovery boundaries; rollback deliberately restores an older trusted snapshot. -/
theorem snapshot_monotone_across_recovery {w t : World} {a : Recovery.Request} {r : Origin}
    {owner externalOK : Bool} (ok : recover w a r owner externalOK = some t) (below : w.inbox.snapshot < r.l1Block)
    {registry : RegistryHistory.State} {params : HistoricalContext.Parameters} {archive : List Nat}
    {c : Consensus.Context} (built : HistoricalContext.build t.inbox registry params archive = some c)
    {finish : State} (trace : Settlement.CertifiedTrace c t.inbox finish) :
    w.inbox.snapshot ≤ finish.snapshot ∧ Settlement.SnapshotFits c finish := by
  have start := recovered_snapshot_fits ok below built
  have info := HistoricalContext.build_success built
  have genesis : c.genesisCutoff ≤ c.originBlock := by
    rw [info.2]
    exact info.1.2.2.2.2.2.2.2
  have anchors : ∀ x y, x ≤ y → c.anchorAt x ≤ c.anchorAt y := by
    intro x y order
    rw [info.2]
    exact HistoricalContext.derived_anchors_monotone _ _ _ _ order
  have result := Settlement.certified_trace_snapshot_monotone genesis anchors start.2.2 trace
  exact ⟨by rw [← start.1]; exact result.1,result.2⟩

theorem sound_step_is_step {w t : World} (change : SoundStep w t) : Step w t := by
  cases change with
  | landing time ok => exact .landing time ok
  | rollback trusted snapshot now time retained => exact .rollback trusted snapshot now time retained
  | framed change => exact change

theorem sound_trace_is_trace {w t : World} (trace : SoundTrace w t) : Trace w t := by
  induction trace with
  | refl => exact .refl _
  | step _ change ih => exact .step ih (sound_step_is_step change)

/-- Every step other than landing and rollback leaves slot 284 untouched, so it is sound. -/
theorem step_keeps_snapshot {w t : World} (change : Step w t) :
    t.inbox.snapshot = w.inbox.snapshot ∨
    (∃ s i leaves e, Etna.Design.land w.inbox i leaves e = some s ∧ t = landed w s e.blockNumber) ∨
    (∃ trusted snapshot now, t = rollback w trusted snapshot now) := by
  cases change with
  | landing _ ok => exact Or.inr (Or.inl ⟨_,_,_,_,ok,rfl⟩)
  | registration => exact Or.inl rfl
  | modification => exact Or.inl rfl
  | enqueue _ _ _ ok =>
    unfold Forced.enqueue at ok
    dsimp only at ok
    split at ok <;> cases ok
    exact Or.inl rfl
  | sweep _ ok => unfold Forced.sweep at ok; split at ok <;> cases ok; exact Or.inl rfl
  | recovery _ ok => exact Or.inl (Recovery.recovery_preserves_settled_prefix ok).2.2.2.2.2.1
  | rollback trusted snapshot now => exact Or.inr (Or.inr ⟨trusted,snapshot,now,rfl⟩)

/-- Slot 284 stays below the World's L1 clock along every sound trace that starts below it.
From an initialized World (`Deployment.genesis_snapshot_below`) this discharges the `below`
premise of `recovered_snapshot_fits`/`snapshot_monotone_across_recovery`. -/
theorem sound_trace_snapshot_below {w t : World} (trace : SoundTrace w t) (below : w.inbox.snapshot < w.l1Block) :
    t.inbox.snapshot < t.l1Block := by
  induction trace with
  | refl => exact below
  | step _ change ih =>
    cases change with
    | landing time ok certified => exact land_snapshot_below_block ok certified
    | rollback trusted snapshot now _ _ written => exact written
    | framed change same =>
      rw [same]
      exact Nat.lt_of_lt_of_le ih (step_clock_monotone change)

end Etna.Design.ProtocolState
