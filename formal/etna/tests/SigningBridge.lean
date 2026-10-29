import EtnaWitnesses.Regressions.SigningBridge

open Etna.Design SigningBridge

-- Request height and the accepted checkpoint source must imply the cutoff bound.
example {w : ProtocolState.World} (p : TrustedPrefix w) (m : SignMessage)
    (next : m.height = p.tip.height+1) :
    w.inbox.snapshot ≤ (Consensus.activeAt p.rules.consensus m.height).cutoff := by
  exact request_snapshot_bound p m next

-- A newly appended signature must be for the decoded request, not a cached return.
example {w : ProtocolState.World} {p : TrustedPrefix w} (call : ObservedCall p)
    (fresh : call.after.log ≠ call.device.state.log) :
    call.returned = call.supplied ∧
    call.after.log = ⟨call.message.generation,call.request.position,call.request.bytes,call.supplied⟩ ::
      call.device.state.log := by
  exact fresh_return_binds_message call fresh

-- A genuine initialized deployment inhabits the entire bridge and all three phases.
example (phase : SignPhase) (nil : Bool) :
    (SigningBridgeRegression.call phase nil).device.key ≠ (HistoricalEscrow.worldD.registry.slots 0).key :=
  SigningBridgeRegression.actual_event_excludes_old_key phase nil

example : ∃ event : ObservedCall SigningBridgeRegression.trustedPrefix,
    EngineRequest SigningBridgeRegression.trustedPrefix event.device.key event.message ∧
    event.after.log ≠ event.device.state.log ∧ event.message.phase = .precommitMsg ∧
    event.message.blockId = 113 ∧ event.device.key ≠ (HistoricalEscrow.worldD.registry.slots 0).key :=
  SigningBridgeRegression.successful_fresh_signing_event
