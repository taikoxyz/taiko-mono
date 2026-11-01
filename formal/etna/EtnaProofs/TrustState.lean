import EtnaModel.TrustState
import EtnaProofs.CanonicalHistory
import EtnaProofs.Signer

namespace Etna.Design.TrustState
open SigningBridge

variable {deviceKey : Hash} {deviceEncode : SignMessage → Hash}

private theorem signed_generation {s t : Signer.State} {r : Signer.Request}
    {sig out : Hash} {persisted : Bool} (ok : Signer.sign s r sig persisted = some (t,out)) :
    t.activeGeneration = s.activeGeneration := by
  unfold Signer.sign at ok
  split at ok
  · split at ok
    · split at ok
      · split at ok <;> cases ok; rfl
      · split at ok <;> cases ok; rfl
    · split at ok <;> cases ok; rfl
  · contradiction

private theorem step_replayed {s t : Node} (step : Step deviceKey deviceEncode s t) (prior : Replayed s) : Replayed t := by
  cases step with
  | observeEvent target running =>
    intro m selected
    simp only [observe,close,Option.some.injEq] at selected
    subst m
    exact ⟨True.intro,by simp [nodes,parentPairs,observe,close]⟩
  | progress more selected closed running noExtension valid accepted =>
    intro m chosen
    have eq : _ = m := Option.some.inj (selected.symm.trans chosen)
    subst m
    simpa [Replayed,noExtension] using And.intro valid accepted
  | extend more selected ready running valid accepted =>
    intro m chosen
    have eq : _ = m := Option.some.inj (selected.symm.trans chosen)
    subst m
    exact ⟨valid,accepted⟩
  | matched => exact prior
  | missing => exact prior
  | timeoutEvent => exact prior
  | restartEvent => intro m selected; cases selected
  | rollbackEvent => intro m selected; cases selected
  | recovery target persisted running =>
    intro m selected
    simp only [recover,observe,close,Option.some.injEq] at selected
    subst m
    exact ⟨True.intro,by simp [nodes,parentPairs,observe,close,recover]⟩
  | «open» => exact prior
  | signed => exact prior
  | contradiction => exact prior

/-- Every accepted replay segment satisfies the real block and node checks. -/
theorem reachable_replayed {s : Node} (run : Reachable deviceKey deviceEncode s) : Replayed s := by
  obtain ⟨initial,trace⟩ := run
  induction trace with
  | refl => intro m selected; cases selected
  | step prior event ih => exact step_replayed event ih

private theorem step_matches {s t : Node} (step : Step deviceKey deviceEncode s t)
    (prior : s.trusted = true → MatchesTarget s) : t.trusted = true → MatchesTarget t := by
  intro ready
  cases step with
  | observeEvent => cases ready
  | progress more selected closed => exact False.elim (Bool.noConfusion (closed.symm.trans ready))
  | extend => exact prior ready
  | matched selected running matched covered generation => exact ⟨_,selected,matched,covered,generation⟩
  | missing => cases ready
  | timeoutEvent => cases ready
  | restartEvent => cases ready
  | rollbackEvent => cases ready
  | recovery => cases ready
  | «open» => exact prior ready
  | signed m sig out persisted after result producer =>
    obtain ⟨target,selected,matched,covered,generation⟩ := prior ready
    exact ⟨target,selected,matched,covered,generation.trans (signed_generation result).symm⟩
  | contradiction => cases ready

/-- The grant is an inductive consequence of matching replay against this session's
actual authenticated target, including both hashes and the FI cursor. -/
theorem reachable_matches {s : Node} (run : Reachable deviceKey deviceEncode s) (ready : s.trusted = true) : MatchesTarget s := by
  obtain ⟨initial,trace⟩ := run
  induction trace with
  | refl => cases ready
  | step prior event ih => exact step_matches event ih ready

/-- Canonical provenance is derived generally, not assumed in Target or in promotion.
For a trusted canonical target this assembles the pre-existing TrustedPrefix interface. -/
theorem canonical_trusted_prefix {s : Node} {target : Target}
    (run : Reachable deviceKey deviceEncode s) (ready : s.trusted = true) (selected : s.target = some target)
    {initial : ProtocolState.World} {old more : List Nat} {template : BlockValidity.Rules}
    (history : CanonicalHistory.Run initial target.view old)
    (archive : target.archive = old ++ more)
    (built : Deployment.build target.view target.view.inbox.configuration target.archive template = some target.rules)
    (extensionCovered : (BlockValidity.terminal (BlockValidity.terminal target.origin s.replay) s.extension).height < target.archive.length) :
    ∃ p : TrustedPrefix target.view,
      p.origin = target.origin ∧ p.replay = s.replay ∧ p.extension = s.extension ∧ p.rules = target.rules := by
  obtain ⟨m,chosen,matched,_,_⟩ := reachable_matches run ready
  have eq : m = target := Option.some.inj (chosen.symm.trans selected)
  subst m
  obtain ⟨valid,accepted⟩ := reachable_replayed run target selected
  obtain ⟨replayValid,extensionValid⟩ := SigningBridge.valid_chain_split valid
  have source := CanonicalHistory.prior_snapshot_source history (archive ▸ built)
  refine ⟨{
    cfg := target.cfg, archive := target.archive, rules := target.rules
    fixedConfiguration := target.fixedConfiguration, constructed := target.constructed
    referenceFinalized := target.referenceFinalized, origin := target.origin
    replay := s.replay, extension := s.extension, originHeight := target.originHeight
    originRecord := target.originRecord, replayValid := replayValid, extensionValid := extensionValid
    checkpoint := matched, archiveCovered := extensionCovered, snapshotSource := source
    ownFinalized := target.ownFinalized, nodeAccepted := ?_ },rfl,rfl,rfl,rfl⟩
  simpa [nodes] using accepted

theorem untrusted_cannot_sign (s : Node) (encode : SignMessage → Hash) (m : SignMessage)
    (sig : Hash) (persisted : Bool) (closed : s.trusted = false) :
    sign s encode m sig persisted = none :=
  Signer.untrusted_cannot_sign _ _ _ _ (by simp [messageRequest,closed])

/-- Regaining app trust after a timed-out request still requires the supervisor's new
session before WAL may retry; a local re-open cannot skip that restart. -/
theorem pending_restart_cannot_sign (s : Node) (encode : SignMessage → Hash) (m : SignMessage)
    (sig : Hash) (persisted : Bool) (pending : s.restartNeeded = true) :
    sign s encode m sig persisted = none :=
  Signer.untrusted_cannot_sign _ _ _ _ (by simp [messageRequest,pending])

theorem untrusted_cannot_serve (s : Node) (closed : s.trusted = false) : serve s = false := by
  simp [serve,closed]

/-- Clearing trust is real for absent data, timeout, restart, rollback and every target
observation, even equal-height observations; new session authentication is not retained. -/
theorem invalidations_close (s : Node) (target : Target) (persisted : Bool) :
    (close s).trusted = false ∧ (timeout s).trusted = false ∧
    (restart s).trusted = false ∧ (restart s).target = none ∧
    (rollback s).trusted = false ∧ (rollback s).target = none ∧
    (observe s target).trusted = false ∧ (recover s target persisted).trusted = false :=
  ⟨rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl⟩

/-- After restart, the exact-match rule cannot apply until another authentication event
supplies a target. This is session freshness, not global L1 freshness. -/
theorem restart_has_no_target (s : Node) (target : Target) : (restart s).target ≠ some target := by
  intro impossible
  cases impossible

/-- A newly authenticated generation cannot be bypassed by re-opening the old signer. -/
theorem superseded_rejects {s : Node} {target : Target} (run : Reachable deviceKey deviceEncode s)
    (selected : s.target = some target) (superseded : s.signer.activeGeneration < target.view.inbox.generation)
    (encode : SignMessage → Hash) (m : SignMessage) (sig : Hash) (persisted : Bool) :
    sign s encode m sig persisted = none := by
  apply untrusted_cannot_sign
  cases h : s.trusted with
  | false => rfl
  | true =>
    obtain ⟨other,chosen,_,_,generation⟩ := reachable_matches run h
    have eq : other = target := Option.some.inj (chosen.symm.trans selected)
    subst other
    omega

theorem retired_generation_rejects (s : Node) (encode : SignMessage → Hash) (m : SignMessage)
    (sig : Hash) (persisted : Bool) (retired : m.generation ∈ s.signer.retired) :
    sign s encode m sig persisted = none := Signer.retired_cannot_sign _ _ _ _ retired

/-- Retry is the actual stock cache path: no persistence write, new bytes, next-height
check or fresh committee selection is inserted around an already signed message. -/
theorem cached_retry (s : Node) (encode : SignMessage → Hash) (m : SignMessage) (old : Signer.Signed)
    (sig : Hash) (persisted : Bool)
    (allow : Signer.authorized s.signer (messageRequest encode m (s.trusted && !s.restartNeeded)) = true)
    (found : Signer.latest s.signer m.generation = some old)
    (position : old.position = ⟨m.height,m.round,phaseStep m.phase⟩) (bytes : old.bytes = encode m) :
    sign s encode m sig persisted = some (s.signer,old.signature) :=
  Signer.retry_returns_original _ _ _ _ _ allow found position bytes

theorem conflicting_retry_rejected (s : Node) (encode : SignMessage → Hash) (m : SignMessage)
    (old : Signer.Signed) (sig : Hash) (persisted : Bool)
    (found : Signer.latest s.signer m.generation = some old)
    (position : old.position = ⟨m.height,m.round,phaseStep m.phase⟩) (different : old.bytes ≠ encode m) :
    sign s encode m sig persisted = none :=
  Signer.same_position_different_bytes_rejected _ _ _ _ _ found position different

/-- A log-changing transition uses this trace's immutable device key and encoder.
Neither a different selected key nor a replacement encoding can justify the operation. -/
theorem fresh_transition_uses_device {s t : Node} (event : Step deviceKey deviceEncode s t)
    (fresh : t.signer.log ≠ s.signer.log) :
    ∃ m sig out persisted, sign s deviceEncode m sig persisted = some (t.signer,out) ∧
      EngineRequest s deviceKey m := by
  cases event with
  | signed m sig out persisted after result producer => exact ⟨m,sig,out,persisted,result,producer fresh⟩
  | recovery => exact False.elim (fresh (Signer.switching_stays_closed _ _ _ _ _ _).2)
  | _ => exact False.elim (fresh rfl)

private theorem step_log {s t : Node} (event : Step deviceKey deviceEncode s t) : ∃ extra, t.signer.log = extra ++ s.signer.log := by
  cases event with
  | signed m sig out persisted after ok => exact Signer.sign_never_drops_log ok
  | recovery => exact ⟨[],(Signer.switching_stays_closed _ _ _ _ _ _).2⟩
  | _ => exact ⟨[],rfl⟩

/-- Every app event, including restart and rollback, retains the authoritative HRS log. -/
theorem trace_keeps_log {s t : Node} (trace : Trace deviceKey deviceEncode s t) : ∃ extra, t.signer.log = extra ++ s.signer.log := by
  induction trace with
  | refl => exact ⟨[],rfl⟩
  | step prior event ih =>
    obtain ⟨a,ha⟩ := ih
    obtain ⟨b,hb⟩ := step_log event
    exact ⟨b ++ a,by rw [hb,ha,List.append_assoc]⟩

/-- If reauthentication/replay/session reopening made no new signatures, the exact old
cache entry still rejects different bytes after restart. -/
theorem restart_conflicting_retry (s t : Node) (encode : SignMessage → Hash) (m : SignMessage)
    (old : Signer.Signed) (sig : Hash) (persisted : Bool)
    (kept : t.signer.log = (restart s).signer.log)
    (found : Signer.latest s.signer m.generation = some old)
    (position : old.position = ⟨m.height,m.round,phaseStep m.phase⟩) (different : old.bytes ≠ encode m) :
    sign t encode m sig persisted = none := by
  apply conflicting_retry_rejected t encode m old sig persisted _ position different
  simpa only [Signer.latest,kept,restart,startup] using found

private theorem before_trans {a b c : Signer.HRS}
    (ab : Signer.before a b = true) (bc : Signer.before b c = true) :
    Signer.before a c = true := by
  simp only [Signer.before,decide_eq_true_eq] at *
  omega

private theorem before_asymm {a b : Signer.HRS} (ab : Signer.before a b = true) :
    a ≠ b ∧ Signer.before b a = false := by
  simp only [Signer.before,decide_eq_true_eq] at ab
  constructor
  · intro eq; subst b; omega
  · simp only [Signer.before,decide_eq_false_iff_not]
    omega

private theorem sign_protects {s : Node} {after : Signer.State} {r : Signer.Request}
    {sig out : Hash} {persisted : Bool} {old : Signer.Signed}
    (safe : Protected s old) (ok : Signer.sign s.signer r sig persisted = some (after,out)) :
    Protected { s with signer := after } old := by
  obtain ⟨current,found,ahead⟩ := safe
  unfold Signer.sign at ok
  split at ok
  · split at ok
    · rename_i previous lookup
      split at ok
      · split at ok
        · cases ok; exact ⟨current,found,ahead⟩
        · contradiction
      · split at ok
        · rename_i advanced
          cases ok
          by_cases same : r.generation = old.generation
          · have equal : previous = current := Option.some.inj ((same ▸ lookup).symm.trans found)
            subst previous
            refine ⟨⟨r.generation,r.position,r.bytes,sig⟩,by simp [Signer.latest,same],Or.inr ?_⟩
            have newer := (Bool.and_eq_true_iff.mp advanced).1
            rcases ahead with ⟨position,_⟩ | earlier
            · exact position ▸ newer
            · exact before_trans earlier newer
          · refine ⟨current,?_,ahead⟩
            simpa [Signer.latest,same] using found
        · contradiction
    · rename_i lookup
      split at ok
      · cases ok
        by_cases same : r.generation = old.generation
        · have impossible := (same ▸ lookup).symm.trans found
          cases impossible
        · refine ⟨current,?_,ahead⟩
          simpa [Signer.latest,same] using found
      · contradiction
  · contradiction

/-- Persisted positions remain protected across arbitrary node/session events, including
intervening fresh signatures, target changes, rollback and recovery. -/
theorem trace_protects_signed_position {s t : Node} {old : Signer.Signed}
    (trace : Trace deviceKey deviceEncode s t) (safe : Protected s old) : Protected t old := by
  induction trace with
  | refl => exact safe
  | step prior event ih =>
    cases event with
    | signed m sig out persisted after ok => exact sign_protects ih ok
    | recovery =>
      obtain ⟨current,found,ahead⟩ := ih
      refine ⟨current,?_,ahead⟩
      simp only [Signer.latest,recover]
      rw [(Signer.switching_stays_closed _ _ _ _ _ _).2]
      exact found
    | _ => exact ih

/-- Every successful stock call establishes protection for the exact returned bytes/HRS;
a cache return establishes the same protection as a fresh persisted write. -/
theorem successful_call_protected {s : Node} {after : Signer.State} {encode : SignMessage → Hash}
    {m : SignMessage} {sig out : Hash} {persisted : Bool}
    (ok : sign s encode m sig persisted = some (after,out)) :
    Protected { s with signer := after }
      ⟨m.generation,⟨m.height,m.round,phaseStep m.phase⟩,encode m,out⟩ := by
  unfold sign Signer.sign at ok
  split at ok
  · split at ok
    · rename_i previous found
      split at ok
      · rename_i position
        split at ok
        · rename_i bytes
          cases ok
          exact ⟨previous,found,Or.inl ⟨position,bytes⟩⟩
        · contradiction
      · split at ok
        · cases ok
          exact ⟨_,by simp [Signer.latest,messageRequest],Or.inl ⟨rfl,rfl⟩⟩
        · contradiction
    · split at ok
      · cases ok
        exact ⟨_,by simp [Signer.latest,messageRequest],Or.inl ⟨rfl,rfl⟩⟩
      · contradiction
  · contradiction

/-- Arbitrarily many restarts and later signatures cannot return different bytes for a
previously signed generation/HRS. Encoding injectivity and exclusive key authority stay
outside this theorem; it compares the exact bytes fed to the real stock signer. -/
theorem protected_conflicting_call_rejected {s : Node} {old : Signer.Signed}
    (safe : Protected s old) (encode : SignMessage → Hash) (m : SignMessage)
    (sig : Hash) (persisted : Bool) (generation : m.generation = old.generation)
    (position : old.position = ⟨m.height,m.round,phaseStep m.phase⟩) (different : old.bytes ≠ encode m) :
    sign s encode m sig persisted = none := by
  obtain ⟨current,found,ahead⟩ := safe
  have lookup : Signer.latest s.signer m.generation = some current := generation ▸ found
  rcases ahead with ⟨same,bytes⟩ | later
  · exact conflicting_retry_rejected s encode m current sig persisted lookup (same.trans position)
      (bytes ▸ different)
  · obtain ⟨ne,backwards⟩ := before_asymm later
    have unequal : current.position ≠ ⟨m.height,m.round,phaseStep m.phase⟩ := by
      intro equal
      exact ne (position.trans equal.symm)
    have lower : Signer.before current.position ⟨m.height,m.round,phaseStep m.phase⟩ = false :=
      position ▸ backwards
    simp [sign,Signer.sign,messageRequest,lookup,unequal,lower]

end Etna.Design.TrustState
