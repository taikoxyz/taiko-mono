import EtnaStatements.Premises
import EtnaProofs.TrustedSnapshot
import EtnaProofs.Deployment
import EtnaProofs.CanonicalHistory
import EtnaProofs.TrustState

/-! Verifier-failure rollback of section 8 restores an exact trusted checkpoint/snapshot
and rechecks confirmations. The original same-generation contracts below remain unchanged.
The additional cross-generation contracts use CanonicalHistory.Run only for the source:
its decoded valid batches and raw reference ancestry derive snapshot < source L1 clock.
Arbitrary later actual protocol steps, including forged landings and any number of
recoveries, put every later generation's origin at or above that clock. Their cutoff floor
therefore covers the restored source snapshot without verifier soundness for that suffix.
Rollback below the preserved origin also removes its record and forbids landing until a
new actual recovery; session trust must then be revalidated. No irreversible payout,
withdrawn stake, timely governance action or production persistence is recovered/proved. -/
namespace Etna.Design.SigningEscrow
open ProtocolState

/-- Trace composition. -/
private theorem trace_join {a b c : World} (first : Trace a b) (second : Trace b c) : Trace a c := by
  induction second with
  | refl => exact first
  | step _ change ih => exact .step ih change

/-- The active cutoff reads only the origin, generation, genesisCutoff, L and the anchors below
the height. -/
private theorem cutoff_congr {s t : State} {cfg cfg' : CommitteeConfig} {a a' : List Nat} {h : Nat}
    (origin : t.origin = s.origin) (generation : t.generation = s.generation)
    (genesis : t.genesisCutoff = s.genesisCutoff) (epoch : t.epochLen = s.epochLen)
    (agree : ∀ k < h, HistoricalContext.anchorAt a' k = HistoricalContext.anchorAt a k) :
    HistoricalContext.cutoff t (Deployment.parameters t cfg') a' h =
      HistoricalContext.cutoff s (Deployment.parameters s cfg) a h := by
  unfold HistoricalContext.cutoff Deployment.parameters
  dsimp only
  rw [origin,generation,genesis,epoch]
  by_cases switched : s.origin.height < (h-1)/s.epochLen*s.epochLen-1
  · rw [ite_eq_left switched,ite_eq_left switched]
    have div := Nat.div_mul_le_self (h-1) s.epochLen
    rw [agree _ (by omega)]
  · rw [ite_eq_right switched,ite_eq_right switched]

/-- A World whose origin archive extends another's, at the same generation, has the same fixed
origin. -/
private theorem fixed_origin_extends {s t : State} {extra : List (Nat × Origin)}
    (origins : t.origins = s.origins ++ extra) (generation : t.generation = s.generation)
    (old : HistoricalContext.fixedOrigin s = some s.origin) (new : HistoricalContext.fixedOrigin t = some t.origin) :
    t.origin = s.origin := by
  unfold HistoricalContext.fixedOrigin at old new
  rw [origins,generation,List.find?_append] at new
  cases found : s.origins.find? (fun pair => pair.1 == s.generation) with
  | none => rw [found] at old; contradiction
  | some x =>
    rw [found] at old new
    simp only [Option.some_or,Option.map_some,Option.some.injEq] at old new
    exact new.symm.trans old

/-- A World that shows the checkpoint and slot 284 a landing wrote, and keeps the landing's
origin, generation, genesisCutoff and L, has as active cutoff at that checkpoint the one the
landing wrote, when the archives agree below the checkpoint. -/
private theorem kept_cutoff {u : World} {cp : Checkpoint} {snap : Nat} {cfg cfg0 : CommitteeConfig}
    {archive archive' : List Nat} {gv : State}
    (written : snap = HistoricalContext.cutoff gv (Deployment.parameters gv cfg0) archive cp.height)
    (snapshot : u.inbox.snapshot = snap) (checkpoint : u.inbox.checkpoint = cp)
    (origin : u.inbox.origin = gv.origin) (generation : u.inbox.generation = gv.generation)
    (genesis : u.inbox.genesisCutoff = gv.genesisCutoff) (epoch : u.inbox.epochLen = gv.epochLen)
    (agree : ∀ k < cp.height, HistoricalContext.anchorAt archive' k = HistoricalContext.anchorAt archive k) :
    u.inbox.snapshot = (Consensus.activeAt (HistoricalContext.derive u.inbox u.registry
      (Deployment.parameters u.inbox cfg) archive') u.inbox.checkpoint.height).cutoff := by
  rw [HistoricalContext.derived_cutoff,snapshot,checkpoint]
  exact written.trans (cutoff_congr (t := u.inbox) origin generation genesis epoch agree).symm

/-- The core of the trusted-rollback results: what a trusted landing wrote, read on any World
`u` that shows it, extends the landing's origin archive and keeps its generation, genesisCutoff
and L. -/
private theorem written_snapshot_trusted {w1 u : World} {s : State} {i : LandInput} {leaves : List Leaf}
    {e : LandingEnv} {cfg0 : CommitteeConfig} {zero : Committee.Record} {archive : List Nat}
    {template r : BlockValidity.Rules} {p : BlockValidity.Header} {bs : List BlockValidity.Block} {blobs : List Hash}
    (landedOK : Etna.Design.land w1.inbox i leaves e = some s)
    (construction : Deployment.build (Statements.guestView w1 cfg0 zero) cfg0 archive template = some r)
    (binding : e.certificate = Settlement.statement r p bs blobs)
    (origins : ∃ extra, u.inbox.origins = w1.inbox.origins ++ extra)
    (same : u.inbox.generation = w1.inbox.generation) (genesis : u.inbox.genesisCutoff = w1.inbox.genesisCutoff)
    (epoch : u.inbox.epochLen = w1.inbox.epochLen) (snapshot : u.inbox.snapshot = s.snapshot)
    (checkpoint : u.inbox.checkpoint = s.checkpoint) :
    ∀ (cfg : CommitteeConfig) (archive' : List Nat) (ctx : Consensus.Context),
      (∀ k < s.checkpoint.height, HistoricalContext.anchorAt archive' k = HistoricalContext.anchorAt archive k) →
      HistoricalContext.build u.inbox u.registry (Deployment.parameters u.inbox cfg) archive' = some ctx →
      SnapshotTrusted ctx u ∧ u.inbox.snapshot = (Consensus.activeAt ctx u.inbox.checkpoint.height).cutoff := by
  intro cfg archive' ctx agree built
  have input := Settlement.accepted_input landedOK binding
  obtain ⟨_,landing⟩ := land_success landedOK
  -- What the trusted landing wrote: the cutoff of the committee its rules make active at the
  -- batch's last height, derived on the guest's view of `w1` (same origin, generation, L and
  -- genesisCutoff as `w1`).
  obtain ⟨_,_,_,_,_,_,_,c,context,rules⟩ := Deployment.build_success construction
  obtain ⟨ready,derived⟩ := HistoricalContext.build_success context
  obtain ⟨ready',rfl⟩ := HistoricalContext.build_success built
  have consensus : r.consensus = HistoricalContext.derive (Statements.guestView w1 cfg0 zero).inbox
      (Statements.guestView w1 cfg0 zero).registry
      (Deployment.parameters (Statements.guestView w1 cfg0 zero).inbox cfg0) archive := by
    rw [rules,derived]
  have written : s.snapshot =
      HistoricalContext.cutoff w1.inbox (Deployment.parameters w1.inbox cfg0) archive s.checkpoint.height := by
    rw [landing,input]
    show (Consensus.activeAt r.consensus (BlockValidity.terminal p bs).height).cutoff = _
    rw [consensus,HistoricalContext.derived_cutoff]
    rfl
  obtain ⟨extra,archived⟩ := origins
  have origin : u.inbox.origin = w1.inbox.origin :=
    fixed_origin_extends (s := w1.inbox) (t := u.inbox) archived same ready.1 ready'.1
  have equal := kept_cutoff (cfg := cfg) written snapshot checkpoint origin same genesis epoch agree
  exact ⟨Nat.le_of_eq equal,equal⟩

/-- A rollback that restores the checkpoint and slot 284 a trusted landing wrote, within that
landing's generation, keeps slot 284 trusted. The landing on World `w1` is trusted in the sense
the slot needs: its certificate is the statement (6.2, Appendix A) computed under rules the
deployment builds on a guest's view of `w1` from anchor archive `archive`. Every `Certifies`
landing has such rules (with a valid batch, which the slot does not need). For every context
built on the restored World from an archive that agrees with `archive` below the restored
checkpoint's height, slot 284 equals the cutoff of the committee active at the restored
lastCheckpoint, so `SnapshotTrusted` holds. Later landings may be forged. -/
theorem trusted_rollback_snapshot_trusted {w1 w : World} {s : State} {i : LandInput} {leaves : List Leaf}
    {e : LandingEnv} {now : Nat} {cfg0 : CommitteeConfig} {zero : Committee.Record} {archive : List Nat}
    {template r : BlockValidity.Rules} {p : BlockValidity.Header} {bs : List BlockValidity.Block} {blobs : List Hash}
    (landedOK : Etna.Design.land w1.inbox i leaves e = some s)
    (construction : Deployment.build (Statements.guestView w1 cfg0 zero) cfg0 archive template = some r)
    (binding : e.certificate = Settlement.statement r p bs blobs)
    (later : Trace (landed w1 s e.blockNumber) w) (same : w.inbox.generation = w1.inbox.generation) :
    ∀ (cfg : CommitteeConfig) (archive' : List Nat) (ctx : Consensus.Context),
      (∀ k < s.checkpoint.height, HistoricalContext.anchorAt archive' k = HistoricalContext.anchorAt archive k) →
      HistoricalContext.build (applyRollback w s.checkpoint s.snapshot now).inbox
        (applyRollback w s.checkpoint s.snapshot now).registry
        (Deployment.parameters (applyRollback w s.checkpoint s.snapshot now).inbox cfg) archive' = some ctx →
      SnapshotTrusted ctx (applyRollback w s.checkpoint s.snapshot now) ∧
      (applyRollback w s.checkpoint s.snapshot now).inbox.snapshot =
        (Consensus.activeAt ctx (applyRollback w s.checkpoint s.snapshot now).inbox.checkpoint.height).cutoff := by
  -- The restored World keeps the landing's origin archive, generation, genesisCutoff and L.
  obtain ⟨_,landing⟩ := land_success landedOK
  obtain ⟨extra,archived⟩ := trace_keeps_origin_archive later
  have immutable := trace_preserves_immutables later
  rw [landing] at archived immutable
  exact written_snapshot_trusted landedOK construction binding ⟨extra,archived⟩ same immutable.2.2.2.2.1
    immutable.2.2.2.1 rfl rfl

/-- What a trusted landing wrote stays trusted on every later World that still shows it. Let
World `u` be reached from the landing by any protocol steps (rollbacks, forged landings, registry
edits and FI steps included) and show the landing's checkpoint and slot 284 in the landing's
generation. Then, for every context built on `u` from an archive that agrees with the landing's
below that checkpoint, slot 284 equals the active cutoff at lastCheckpoint (`SnapshotTrusted`).
This covers the World right after a rollback that restores those values and every World after it
until slot 284, lastCheckpoint or the generation changes. -/
theorem trusted_landing_values_stay_trusted {w1 u : World} {s : State} {i : LandInput} {leaves : List Leaf}
    {e : LandingEnv} {cfg0 : CommitteeConfig} {zero : Committee.Record} {archive : List Nat}
    {template r : BlockValidity.Rules} {p : BlockValidity.Header} {bs : List BlockValidity.Block} {blobs : List Hash}
    (landedOK : Etna.Design.land w1.inbox i leaves e = some s)
    (construction : Deployment.build (Statements.guestView w1 cfg0 zero) cfg0 archive template = some r)
    (binding : e.certificate = Settlement.statement r p bs blobs)
    (reached : Trace (landed w1 s e.blockNumber) u) (snapshot : u.inbox.snapshot = s.snapshot)
    (checkpoint : u.inbox.checkpoint = s.checkpoint) (same : u.inbox.generation = w1.inbox.generation) :
    ∀ (cfg : CommitteeConfig) (archive' : List Nat) (ctx : Consensus.Context),
      (∀ k < s.checkpoint.height, HistoricalContext.anchorAt archive' k = HistoricalContext.anchorAt archive k) →
      HistoricalContext.build u.inbox u.registry (Deployment.parameters u.inbox cfg) archive' = some ctx →
      SnapshotTrusted ctx u ∧ u.inbox.snapshot = (Consensus.activeAt ctx u.inbox.checkpoint.height).cutoff := by
  obtain ⟨_,landing⟩ := land_success landedOK
  obtain ⟨extra,archived⟩ := trace_keeps_origin_archive reached
  have immutable := trace_preserves_immutables reached
  rw [landing] at archived immutable
  exact written_snapshot_trusted landedOK construction binding ⟨extra,archived⟩ same immutable.2.2.2.2.1
    immutable.2.2.2.1 snapshot checkpoint

/-- Block 0 is never above a switch height, so its active cutoff is the generation's initial
one: genesisCutoff in generation 0, otherwise the origin block, which is not earlier. -/
private theorem cutoff_at_zero (s : State) (cfg : HistoricalContext.Parameters) (a : List Nat)
    (floor : cfg.genesisCutoff ≤ s.origin.l1Block) : cfg.genesisCutoff ≤ HistoricalContext.cutoff s cfg a 0 := by
  unfold HistoricalContext.cutoff
  simp only [Nat.zero_sub,Nat.zero_div,Nat.zero_mul,Nat.not_lt_zero,↓reduceIte]
  split <;> omega

/-- A rollback that restores the initialization values (no trusted landing) keeps slot 284
trusted: slot 284 is genesisCutoff, and the committee active at block 0 has cutoff genesisCutoff
in generation 0 or the generation's origin block, which is not earlier. -/
theorem initial_rollback_snapshot_trusted {w0 w : World} {hash root : Hash} {now : Nat}
    (init : Deployment.Genesis w0 hash root) (trace : Trace w0 w) :
    ∀ (cfg : CommitteeConfig) (archive : List Nat) (ctx : Consensus.Context),
      HistoricalContext.build (applyRollback w w0.inbox.checkpoint w0.inbox.snapshot now).inbox
        (applyRollback w w0.inbox.checkpoint w0.inbox.snapshot now).registry
        (Deployment.parameters (applyRollback w w0.inbox.checkpoint w0.inbox.snapshot now).inbox cfg) archive =
        some ctx →
      SnapshotTrusted ctx (applyRollback w w0.inbox.checkpoint w0.inbox.snapshot now) := by
  intro cfg archive ctx built
  obtain ⟨ready,rfl⟩ := HistoricalContext.build_success built
  have genesis := (trace_preserves_immutables trace).2.2.2.2.1
  obtain ⟨_,checkpoint,_,_,_,_,_,snapshot,_⟩ := init
  unfold SnapshotTrusted
  rw [HistoricalContext.derived_cutoff]
  have zero : (applyRollback w w0.inbox.checkpoint w0.inbox.snapshot now).inbox.checkpoint.height = 0 := by
    show w0.inbox.checkpoint.height = 0
    rw [checkpoint]
  rw [zero]
  show w0.inbox.snapshot ≤ _
  rw [snapshot,← genesis]
  exact cutoff_at_zero _ _ _ ready.2.2.2.2.2.2.2

/-- After a rollback that restores what a trusted landing wrote, every confirmed exit's key is
absent from every committee active at or above the restored lastCheckpoint, also for exits
confirmed after the rollback. World `u` is reached from the restored World by steps that never
lower slot 284 except by rollback (`SnapshotTrace`: registry edits such as confirmations and
withdrawals, FI steps, invalidation), and still shows the restored checkpoint and slot 284 in the
trusted landing's generation; `u` may be the restored World itself. For every context built on
`u` from an archive that agrees with the trusted landing's below that checkpoint, every
confirmation `u` holds is excluded. This composes `trusted_landing_values_stay_trusted`, the
registry's recheck (`rollback_covered`) carried along the suffix (`trace_covered`) and
`confirmed_key_absent_above_checkpoint`; `UntrustedRollback` shows it fails when the restored
snapshot is not the trusted landing's. -/
theorem trusted_rollback_excludes_confirmed_keys {initial w1 w u : World} {s : State} {i : LandInput}
    {leaves : List Leaf} {e : LandingEnv} {now : Nat} {cfg0 : CommitteeConfig} {zero : Committee.Record}
    {archive : List Nat} {template r : BlockValidity.Rules} {p : BlockValidity.Header}
    {bs : List BlockValidity.Block} {blobs : List Hash}
    (before : Trace initial w1) (core : Core initial) (keys : KeysWellFormed initial.registry)
    (visible : ExitVisible initial.registry) (time : w1.l1Block ≤ e.blockNumber)
    (landedOK : Etna.Design.land w1.inbox i leaves e = some s)
    (construction : Deployment.build (Statements.guestView w1 cfg0 zero) cfg0 archive template = some r)
    (binding : e.certificate = Settlement.statement r p bs blobs)
    (later : Trace (landed w1 s e.blockNumber) w) (rollback : Step w (applyRollback w s.checkpoint s.snapshot now))
    (after : SnapshotTrace (applyRollback w s.checkpoint s.snapshot now) u)
    (snapshot : u.inbox.snapshot = s.snapshot) (checkpoint : u.inbox.checkpoint = s.checkpoint)
    (same : u.inbox.generation = w1.inbox.generation) :
    ∀ (cfg : CommitteeConfig) (archive' : List Nat) (ctx : Consensus.Context),
      (∀ k < s.checkpoint.height, HistoricalContext.anchorAt archive' k = HistoricalContext.anchorAt archive k) →
      HistoricalContext.build u.inbox u.registry (Deployment.parameters u.inbox cfg) archive' = some ctx →
      ∀ id c h, id < u.registry.nextId → (u.registry.slots id).confirmedAt = some c →
        (u.registry.slots id).key ≠ 0 → (u.registry.slots id).exitAt ≠ Staking.noExit →
        s.checkpoint.height ≤ h → ∀ m ∈ (Consensus.activeAt ctx h).members, m.key ≠ (u.registry.slots id).key := by
  intro cfg archive' ctx agree built id c h range confirmed nonzero finite above
  have suffix : Trace (landed w1 s e.blockNumber) u := trace_join (.step later rollback) (snapshot_trace_projects after)
  have prior : Trace initial u := trace_join (.step before (.landing time landedOK)) suffix
  have trusted := (trusted_landing_values_stay_trusted landedOK construction binding suffix snapshot checkpoint same
    cfg archive' ctx agree built).1
  exact confirmed_key_absent_above_checkpoint prior core keys visible range confirmed
    (trace_covered after (rollback_covered w s.checkpoint s.snapshot now)) nonzero finite built trusted
    (checkpoint ▸ above)

/-- A strictly later generation in any actual protocol trace was installed by recovery.
Its origin block cannot precede the source's L1 clock; forged landings and additional
recoveries require no verifier soundness. -/
theorem later_generation_origin {source u : World} (trace : Trace source u)
    (changed : source.inbox.generation < u.inbox.generation) :
    source.l1Block ≤ u.inbox.origin.l1Block := by
  induction trace with
  | refl => omega
  | @step w t prior change ih =>
    cases change with
    | landing _ ok => obtain ⟨_,rfl⟩ := land_success ok; exact ih changed
    | registration => exact ih changed
    | modification => exact ih changed
    | enqueue _ _ _ ok =>
      unfold Forced.enqueue at ok
      dsimp only at ok
      split at ok <;> cases ok
      exact ih changed
    | sweep _ ok =>
      unfold Forced.sweep at ok
      split at ok <;> cases ok
      exact ih changed
    | recovery time ok =>
      have clock := trace_clock_monotone prior
      obtain ⟨_,rfl⟩ := Recovery.recover_success ok
      exact Nat.le_trans clock time
    | invalidation _ ok => obtain ⟨_,rfl⟩ := Recovery.invalidation_success ok; exact ih changed
    | rollback => exact ih changed

/-- A genuinely canonical trusted source lies below every later actual recovery's
origin. The source relation includes valid accepted batches, decoded header/archive
binding and raw origin/reference bounds. The suffix is unrestricted ProtocolState.Trace. -/
theorem certified_snapshot_below_later_origin {initial source u : World} {archive : List Nat}
    (certified : CanonicalHistory.Run initial source archive) (suffix : Trace source u)
    (changed : source.inbox.generation < u.inbox.generation) :
    source.inbox.snapshot < u.inbox.origin.l1Block :=
  Nat.lt_of_lt_of_le (CanonicalHistory.run_snapshot_below certified) (later_generation_origin suffix changed)

private theorem recovery_cutoff_floor (s : State) (cfg : HistoricalContext.Parameters)
    (archive : List Nat) (h : Nat) (generation : s.generation ≠ 0) :
    s.origin.l1Block ≤ HistoricalContext.cutoff s cfg archive h := by
  simp only [HistoricalContext.cutoff,generation,↓reduceIte]
  split
  · exact Nat.le_max_right _ _
  · exact Nat.le_refl _

/-- Restoring the exact checkpoint and snapshot of a canonical source is safe in every
strictly later generation, even after arbitrarily many forged landings and recoveries.
Unlike the old same-generation contract, no agreement with the old archive is needed:
the preserved recovery origin supplies a floor at every height. -/
theorem certified_values_trusted_across_recoveries {initial source u : World} {archive : List Nat}
    (certified : CanonicalHistory.Run initial source archive) (suffix : Trace source u)
    (changed : source.inbox.generation < u.inbox.generation)
    (snapshot : u.inbox.snapshot = source.inbox.snapshot)
    (checkpoint : u.inbox.checkpoint = source.inbox.checkpoint)
    (cfg : CommitteeConfig) (archive' : List Nat) (ctx : Consensus.Context)
    (built : HistoricalContext.build u.inbox u.registry (Deployment.parameters u.inbox cfg) archive' = some ctx) :
    SnapshotTrusted ctx u ∧ u.inbox.checkpoint = source.inbox.checkpoint := by
  obtain ⟨_,rfl⟩ := HistoricalContext.build_success built
  refine ⟨?_,checkpoint⟩
  unfold SnapshotTrusted
  rw [HistoricalContext.derived_cutoff,snapshot]
  exact Nat.le_trans (Nat.le_of_lt (certified_snapshot_below_later_origin certified suffix changed))
    (recovery_cutoff_floor _ _ _ _ (by omega))

/-- Registry recheck covers both retained confirmations and confirmations first made
after rollback. The later confirming World still shows the exact source values; its
suffix carries the existing snapshot discipline, not verifier soundness. -/
theorem certified_rollback_excludes_confirmed_keys {initial source w u : World}
    {archive : List Nat} {now : Nat}
    (certified : CanonicalHistory.Run initial source archive)
    (core : Core initial) (keys : KeysWellFormed initial.registry) (visible : ExitVisible initial.registry)
    (later : Trace source w)
    (rollback : Step w (applyRollback w source.inbox.checkpoint source.inbox.snapshot now))
    (after : SnapshotTrace (applyRollback w source.inbox.checkpoint source.inbox.snapshot now) u)
    (changed : source.inbox.generation < u.inbox.generation)
    (snapshot : u.inbox.snapshot = source.inbox.snapshot) (checkpoint : u.inbox.checkpoint = source.inbox.checkpoint)
    (cfg : CommitteeConfig) (archive' : List Nat) (ctx : Consensus.Context)
    (built : HistoricalContext.build u.inbox u.registry (Deployment.parameters u.inbox cfg) archive' = some ctx) :
    ∀ id c h, id < u.registry.nextId → (u.registry.slots id).confirmedAt = some c →
      (u.registry.slots id).key ≠ 0 → (u.registry.slots id).exitAt ≠ Staking.noExit →
      source.inbox.checkpoint.height ≤ h →
      ∀ m ∈ (Consensus.activeAt ctx h).members, m.key ≠ (u.registry.slots id).key := by
  intro id c h range confirmed nonzero finite above
  have suffix := trace_join (.step later rollback) (snapshot_trace_projects after)
  have trusted := (certified_values_trusted_across_recoveries certified suffix changed snapshot checkpoint cfg archive' ctx built).1
  exact confirmed_key_absent_above_checkpoint (trace_join (CanonicalHistory.run_trace certified) suffix)
    core keys visible range confirmed (trace_covered after (rollback_covered _ _ _ _)) nonzero finite built trusted
    (checkpoint ▸ above)

/-- Initialization is also a trusted source at any later confirming World, independently
of whether a recovery happened. Only the exact initialized checkpoint/snapshot are restored. -/
theorem initial_values_stay_trusted {initial u : World} {hash root : Hash}
    (init : Deployment.Genesis initial hash root) (trace : Trace initial u)
    (snapshot : u.inbox.snapshot = initial.inbox.snapshot)
    (checkpoint : u.inbox.checkpoint = initial.inbox.checkpoint)
    (cfg : CommitteeConfig) (archive : List Nat) (ctx : Consensus.Context)
    (built : HistoricalContext.build u.inbox u.registry (Deployment.parameters u.inbox cfg) archive = some ctx) :
    SnapshotTrusted ctx u := by
  obtain ⟨ready,rfl⟩ := HistoricalContext.build_success built
  have genesis := (trace_preserves_immutables trace).2.2.2.2.1
  obtain ⟨_,cp,_,_,_,_,_,snap,_⟩ := init
  unfold SnapshotTrusted
  rw [HistoricalContext.derived_cutoff,checkpoint,cp]
  change u.inbox.snapshot ≤ HistoricalContext.cutoff _ _ _ 0
  rw [snapshot,snap,← genesis]
  exact cutoff_at_zero _ _ _ ready.2.2.2.2.2.2.2

/-- The actual confirmExit guard prevents an exit cleared by snapshot recheck from
being reconfirmed before the snapshot advances to its effective exit block. -/
theorem cleared_exit_cannot_reconfirm (s : State) (b : Staking.Bond) (restored now : Nat)
    (cleared : restored < b.exitAt) (snapshot : s.snapshot = restored) :
    Staking.confirmExit s (Staking.rollbackBySnapshot restored b) now = none := by
  have same : (Staking.rollbackBySnapshot restored b).exitAt = b.exitAt := by
    unfold Staking.rollbackBySnapshot
    split <;> simp_all
  unfold Staking.confirmExit
  rw [ite_eq_right]
  intro allowed
  have covered := allowed.2.2.2.2
  rw [same,snapshot] at covered
  omega

/-- Filtering rollback records removes an origin above the restored checkpoint. This
also prevents fabricating a TrustState.Target for that World before a new recovery. -/
theorem rollback_origin_record_absent (w : World) (cp : Checkpoint) (snapshot now : Nat)
    (above : cp.height < w.inbox.origin.height) :
    recordAt (applyRollback w cp snapshot now).inbox w.inbox.origin.height = none := by
  apply List.find?_eq_none.mpr
  intro record member
  have bound := (Recovery.rollback_voids_later w.inbox cp snapshot).1 record member
  simp only [beq_iff_eq]
  omega

theorem rollback_has_no_target (w : World) (cp : Checkpoint) (snapshot now : Nat)
    (above : cp.height < w.inbox.origin.height) :
    ¬ ∃ target : TrustState.Target, target.view = applyRollback w cp snapshot now := by
  rintro ⟨target,equal⟩
  obtain ⟨record,present,_⟩ := target.originRecord
  rw [equal] at present
  change recordAt (applyRollback w cp snapshot now).inbox w.inbox.origin.height = some record at present
  rw [rollback_origin_record_absent w cp snapshot now above] at present
  contradiction

private theorem same_generation_gap {start u : World} (trace : Trace start u)
    (same : u.inbox.generation = start.inbox.generation)
    (gap : start.inbox.checkpoint.height < start.inbox.origin.height)
    (records : ∀ cp ∈ start.inbox.records, cp.height < start.inbox.origin.height) :
    u.inbox.checkpoint.height < u.inbox.origin.height ∧
    ∀ cp ∈ u.inbox.records, cp.height < u.inbox.origin.height := by
  induction trace with
  | refl => exact ⟨gap,records⟩
  | @step w t prior change ih =>
    have before := trace_generation_monotone prior
    have after := step_generation_monotone change
    have prev : w.inbox.generation = start.inbox.generation := by omega
    obtain ⟨gap',records'⟩ := ih prev
    cases change with
    | landing _ ok =>
      have allowed := (land_success ok).1.1.1
      have a := allowed.2.1
      have b := allowed.2.2.1
      omega
    | registration => exact ⟨gap',records'⟩
    | modification => exact ⟨gap',records'⟩
    | enqueue _ _ _ ok =>
      unfold Forced.enqueue at ok
      dsimp only at ok
      split at ok <;> cases ok
      exact ⟨gap',records'⟩
    | sweep _ ok =>
      unfold Forced.sweep at ok
      split at ok <;> cases ok
      exact ⟨gap',records'⟩
    | recovery _ ok =>
      have generation := (Recovery.recovery_fixes_origin ok).1
      simp only [recovered,recoveryView] at generation same
      omega
    | invalidation _ ok => obtain ⟨_,rfl⟩ := Recovery.invalidation_success ok; exact ⟨gap',records'⟩
    | rollback cp snapshot now _ retained _ =>
      refine ⟨records' cp (List.mem_of_find?_eq_some retained),?_⟩
      intro record member
      exact records' record (List.mem_filter.mp member).1

private theorem origin_gap_rejects_landing (s : State) (i : LandInput) (leaves : List Leaf) (e : LandingEnv)
    (gap : s.checkpoint.height < s.origin.height) : Etna.Design.land s i leaves e = none := by
  apply ite_eq_right
  intro accepted
  have a := accepted.1.1.2.1
  have b := accepted.1.1.2.2.1
  omega

/-- No successful landing is possible throughout the interval after a rollback below
the preserved origin and before a subsequent actual recovery. Rollbacks in the interval
can only choose retained records, all below that origin. Registry/FI/nonce edits are allowed. -/
theorem rollback_interval_rejects_landing {w u : World} {cp : Checkpoint} {snapshot now : Nat}
    (above : cp.height < w.inbox.origin.height)
    (trace : Trace (applyRollback w cp snapshot now) u)
    (same : u.inbox.generation = w.inbox.generation)
    (i : LandInput) (leaves : List Leaf) (e : LandingEnv) :
    Etna.Design.land u.inbox i leaves e = none := by
  have initial : ∀ record ∈ (applyRollback w cp snapshot now).inbox.records,
      record.height < (applyRollback w cp snapshot now).inbox.origin.height := by
    intro record member
    have bound := (Recovery.rollback_voids_later w.inbox cp snapshot).1 record member
    exact Nat.lt_of_le_of_lt bound above
  exact origin_gap_rejects_landing _ i leaves e (same_generation_gap trace same above initial).1

/-- Every checked rollback invalidates every previously issued authorization at the
same generation/checkpoint by consuming the nonce; it cannot rewind that authority. -/
theorem rollback_consumes_nonce (s : State) (cp : Checkpoint) (snapshot : Nat) :
    (Recovery.rollbackInbox s cp snapshot).recoveryNonce = s.recoveryNonce+1 := rfl

/-- Checkpoint rollback is distinct from key authority: it closes session trust while
retaining deployment, active/retired domains, durable HRS bytes and supersession knowledge. -/
theorem rollback_retains_signer_authority (node : TrustState.Node) (encode : SigningBridge.SignMessage → Hash)
    (message : SigningBridge.SignMessage) (signature : Hash) (persisted : Bool) :
    (TrustState.rollback node).signer.domain = node.signer.domain ∧
    (TrustState.rollback node).signer.activeGeneration = node.signer.activeGeneration ∧
    (TrustState.rollback node).signer.retired = node.signer.retired ∧
    (TrustState.rollback node).signer.log = node.signer.log ∧
    (TrustState.rollback node).authenticatedGeneration = node.authenticatedGeneration ∧
    TrustState.sign (TrustState.rollback node) encode message signature persisted = none := by
  exact ⟨rfl,rfl,rfl,rfl,rfl,TrustState.untrusted_cannot_sign _ _ _ _ _ rfl⟩

end Etna.Design.SigningEscrow
