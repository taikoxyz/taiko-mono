import EtnaStatements.Premises
import EtnaProofs.TrustedSnapshot
import EtnaProofs.Deployment

/-! The verifier-failure rollback of section 8, done as the spec says, keeps slot 284 trusted.
8 "Verifier failure" (spec L487): the Inbox restores lastCheckpoint, the FI head and
activeCommitteeSnapshot "to the values written by the last trusted landing ... if there is
none, restore the initialization values", and the registry re-checks every exit confirmation
against the restored snapshot. The model's rollback step accepts any retained record and any
snapshot (`UntrustedRollback`). Here the restored values are the ones a trusted landing wrote,
that is a landing whose certificate is the statement computed under rules the deployment builds
on a guest's view of its World (as every `Certifies` landing's is; 6.2 item 7, spec L366: the
statement's activeCommitteeSnapshot is the selection snapshot of the committee governing its
last height), or the initialization values. No governance recovery may run between that landing
and the rollback; a rollback across a recovery is not covered. Then slot 284 equals (or, for initialization, is at most) the
cutoff of the committee active at the restored lastCheckpoint (`SnapshotTrusted`), and with the
registry's recheck every confirmed exit's key is absent from every committee active at or above
that checkpoint. Only the restored landing is assumed trusted: later landings may be forged, so
`Premises.verifierSound` is not used. -/
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

/-- The restored World's active cutoff at the restored checkpoint is the one the landing wrote,
when the World keeps the landing's origin, generation, genesisCutoff and L and the archives
agree below the checkpoint. -/
private theorem restored_cutoff {w : World} {cp : Checkpoint} {snap now : Nat} {cfg cfg0 : CommitteeConfig}
    {archive archive' : List Nat} {gv : State}
    (written : snap = HistoricalContext.cutoff gv (Deployment.parameters gv cfg0) archive cp.height)
    (origin : w.inbox.origin = gv.origin) (generation : w.inbox.generation = gv.generation)
    (genesis : w.inbox.genesisCutoff = gv.genesisCutoff) (epoch : w.inbox.epochLen = gv.epochLen)
    (agree : ∀ k < cp.height, HistoricalContext.anchorAt archive' k = HistoricalContext.anchorAt archive k) :
    (applyRollback w cp snap now).inbox.snapshot =
      (Consensus.activeAt (HistoricalContext.derive (applyRollback w cp snap now).inbox
        (applyRollback w cp snap now).registry (Deployment.parameters (applyRollback w cp snap now).inbox cfg) archive')
        (applyRollback w cp snap now).inbox.checkpoint.height).cutoff := by
  rw [HistoricalContext.derived_cutoff]
  exact written.trans (cutoff_congr (t := Recovery.rollbackInbox w.inbox cp snap) origin generation genesis epoch agree).symm

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
  -- The restored World keeps the landing's origin, generation, genesisCutoff and L.
  obtain ⟨extra,archived⟩ := trace_keeps_origin_archive later
  have immutable := trace_preserves_immutables later
  rw [landing] at archived immutable
  have origin : w.inbox.origin = w1.inbox.origin :=
    fixed_origin_extends (s := w1.inbox) (t := w.inbox) archived same ready.1 ready'.1
  have equal := restored_cutoff (now := now) (cfg := cfg) written origin same immutable.2.2.2.2.1
    immutable.2.2.2.1 agree
  exact ⟨Nat.le_of_eq equal,equal⟩

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

/-- After a rollback that restores what a trusted landing wrote, within its generation, every
confirmed exit's key is absent from every committee active at or above the restored
lastCheckpoint, for every context built on the restored World from an archive that agrees with
the trusted landing's below that checkpoint (`trusted_rollback_snapshot_trusted`'s trust). This composes `trusted_rollback_snapshot_trusted`,
the registry's recheck against the restored snapshot (`rollback_covered`) and
`confirmed_key_absent_above_checkpoint`; `UntrustedRollback` shows it fails when the restored
snapshot is not the trusted landing's. -/
theorem trusted_rollback_excludes_confirmed_keys {initial w1 w : World} {s : State} {i : LandInput}
    {leaves : List Leaf} {e : LandingEnv} {now : Nat} {cfg0 : CommitteeConfig} {zero : Committee.Record}
    {archive : List Nat} {template r : BlockValidity.Rules} {p : BlockValidity.Header}
    {bs : List BlockValidity.Block} {blobs : List Hash}
    (before : Trace initial w1) (core : Core initial) (keys : KeysWellFormed initial.registry)
    (visible : ExitVisible initial.registry) (time : w1.l1Block ≤ e.blockNumber)
    (landedOK : Etna.Design.land w1.inbox i leaves e = some s)
    (construction : Deployment.build (Statements.guestView w1 cfg0 zero) cfg0 archive template = some r)
    (binding : e.certificate = Settlement.statement r p bs blobs)
    (later : Trace (landed w1 s e.blockNumber) w) (same : w.inbox.generation = w1.inbox.generation)
    (rollback : Step w (applyRollback w s.checkpoint s.snapshot now)) :
    ∀ (cfg : CommitteeConfig) (archive' : List Nat) (ctx : Consensus.Context),
      (∀ k < s.checkpoint.height, HistoricalContext.anchorAt archive' k = HistoricalContext.anchorAt archive k) →
      HistoricalContext.build (applyRollback w s.checkpoint s.snapshot now).inbox
        (applyRollback w s.checkpoint s.snapshot now).registry
        (Deployment.parameters (applyRollback w s.checkpoint s.snapshot now).inbox cfg) archive' = some ctx →
      ∀ id c h, id < (applyRollback w s.checkpoint s.snapshot now).registry.nextId →
        ((applyRollback w s.checkpoint s.snapshot now).registry.slots id).confirmedAt = some c →
        ((applyRollback w s.checkpoint s.snapshot now).registry.slots id).key ≠ 0 →
        ((applyRollback w s.checkpoint s.snapshot now).registry.slots id).exitAt ≠ Staking.noExit →
        s.checkpoint.height ≤ h →
        ∀ m ∈ (Consensus.activeAt ctx h).members,
          m.key ≠ ((applyRollback w s.checkpoint s.snapshot now).registry.slots id).key := by
  intro cfg archive' ctx agree built id c h range confirmed nonzero finite above
  have prior : Trace initial (applyRollback w s.checkpoint s.snapshot now) :=
    .step (trace_join (.step before (.landing time landedOK)) later) rollback
  exact confirmed_key_absent_above_checkpoint prior core keys visible range confirmed
    (rollback_covered w s.checkpoint s.snapshot now) nonzero finite built
    (trusted_rollback_snapshot_trusted landedOK construction binding later same cfg archive' ctx agree built).1 above

end Etna.Design.SigningEscrow
