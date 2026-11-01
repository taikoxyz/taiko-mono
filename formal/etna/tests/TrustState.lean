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

namespace Etna.Design.TrustStateFixRegression
open TrustState SigningBridge TrustStateRegression

def otherDomain : Domain := { FirstBatch.deployment with inbox := FirstBatch.deployment.inbox + 1 }
def otherMessage : SignMessage := { message0 .precommitMsg false with domain := otherDomain }
def otherInitial : Signer.State := ⟨otherDomain,0,1,[],false,[⟨0,⟨13,0,3⟩,bytes0 otherMessage,888⟩]⟩
def otherSession := activate (startup otherInitial) target0 HistoricalEscrow.blocks

-- I1: a real cached byte sequence for Inbox 11 must not be authorized by Inbox 10 trust.
example : TrustState.sign otherSession bytes0 otherMessage 999 false = none :=
  foreign_session_cannot_sign _ target0 rfl (by decide +kernel) true bytes0 otherMessage 999 false


-- I2: later stale data cannot erase already authenticated generation-1 supersession.
def superseded := observe session0 target1
def oldAgain := activate superseded target0 HistoricalEscrow.blocks
example : TrustState.sign oldAgain bytes0 (message0 .precommitMsg false) 999 true = none := by decide +kernel

end Etna.Design.TrustStateFixRegression


example := Etna.Design.TrustStateRegression.foreign_deployment_cache_rejected
example := Etna.Design.TrustStateRegression.observed_supersession_rejects_old_material
example := Etna.Design.TrustStateRegression.supersession_survives_failed_recovery_and_restart

example {s : TrustState.Node} (trace : TrustStateRegression.DeviceTrace TrustStateRegression.supersededNode s)
    (phase : SigningBridge.SignPhase) (nil : Bool) :
    TrustState.sign s TrustStateRegression.bytes0 (TrustStateRegression.message0 phase nil) 999 true = none :=
  TrustStateRegression.all_later_old_generation_requests_rejected trace phase nil
