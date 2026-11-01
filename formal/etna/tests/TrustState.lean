import EtnaWitnesses.Regressions.TrustState

open Etna.Design

-- Missing reachable app/session contracts before Task 2.
example (s : TrustState.Node) (encode : SigningBridge.SignMessage → Hash)
    (m : SigningBridge.SignMessage) (sig : Hash) (persisted : Bool)
    (closed : s.trusted = false) : TrustState.sign s encode m sig persisted = none :=
  TrustState.untrusted_cannot_sign s encode m sig persisted closed

example {s : TrustState.Node} {key : Hash} {encode : SigningBridge.SignMessage → Hash}
    (run : TrustState.Reachable key encode s)
    (ready : s.trusted = true) : TrustState.MatchesTarget s :=
  TrustState.reachable_matches run ready

-- The actual state machine permits every phase/nil choice and preserves cached bytes.
example (phase : SigningBridge.SignPhase) (nil : Bool) :=
  TrustStateRegression.all_phases_sign phase nil
example (phase : SigningBridge.SignPhase) (nil : Bool) :=
  TrustStateRegression.timeout_restart_retry phase nil
example := TrustStateRegression.target_advancement_revalidates
example := TrustStateRegression.recovery_revalidates
example := TrustStateRegression.rollback_revalidates
example := TrustStateRegression.stale_own_view_still_signs
example := TrustStateRegression.historical_cache_has_no_new_engine_veto

-- Trace-wide protection still holds through intervening signatures and restarts.
example {s t : TrustState.Node} {key : Hash} {encode : SigningBridge.SignMessage → Hash}
    {old : Signer.Signed} (trace : TrustState.Trace key encode s t) (safe : TrustState.Protected s old)
    (m : SigningBridge.SignMessage) (sig : Hash) (persisted : Bool)
    (generation : m.generation = old.generation)
    (position : old.position = ⟨m.height,m.round,SigningBridge.phaseStep m.phase⟩)
    (different : old.bytes ≠ encode m) : TrustState.sign t encode m sig persisted = none :=
  TrustState.protected_conflicting_call_rejected (TrustState.trace_protects_signed_position trace safe)
    encode m sig persisted generation position different
