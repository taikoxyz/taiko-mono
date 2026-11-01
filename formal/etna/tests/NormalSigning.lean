import EtnaWitnesses.Regressions.NormalSigning
import EtnaProofs.Permanence

open Etna.Design

-- Normal provenance must remain connected to the original complete machine.
example {initial finish : ProtocolState.World} (run : NormalSigning.Run initial finish) :
    ProtocolState.Trace initial finish := NormalSigning.run_trace run

-- Confirmation coverage is derived from the whole normal run, not assumed at its end.
example {initial confirmed : ProtocolState.World} (run : NormalSigning.Run initial confirmed)
    (initialCoverage : SigningEscrow.Covered initial) : SigningEscrow.Covered confirmed :=
  NormalSigning.run_covered run initialCoverage

-- Cross-generation provenance derives the actual selected-cutoff bound.
example {confirmed view : ProtocolState.World} (p : SigningBridge.TrustedPrefix view)
    (source : NormalSigning.ConfirmationSource confirmed view p)
    (below : confirmed.inbox.snapshot < confirmed.l1Block)
    (message : SigningBridge.SignMessage) (next : message.height = p.tip.height+1) :
    confirmed.inbox.snapshot ≤ (Consensus.activeAt p.rules.consensus message.height).cutoff :=
  NormalSigning.confirmation_source_bound p source below message next

-- The complete recovery path must be inhabited by an actual fresh signing event.
example : ∃ event : SigningBridge.ObservedCall NormalSigningRegression.trustedPrefix,
    SigningBridge.EngineRequest NormalSigningRegression.trustedPrefix event.device.key event.message ∧
    event.after.log ≠ event.device.state.log ∧ event.message.generation = 1 ∧
    event.message.height = 23 ∧ event.device.key ≠ 7 :=
  NormalSigningRegression.recovery_fresh_signature


-- A recovery before any landing must still provide an authentic stored-snapshot source.
example : SigningBridge.SnapshotSource NormalSigningRegression.earlyWorld.inbox
    NormalSigningRegression.earlyContext :=
  NormalSigningRegression.recovery_before_first_landing_source.1

-- Slot reuse after snapshot selection never rewrites the old committee or revives key 7.
example (phase : SigningBridge.SignPhase) (nil : Bool) :
    ¬ SigningBridge.EngineRequest NormalSigningRegression.trustedPrefix 7
      (NormalSigningRegression.message phase nil) :=
  NormalSigningRegression.old_key_request_rejected phase nil
