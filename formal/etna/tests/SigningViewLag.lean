import EtnaWitnesses.Counterexamples.SigningViewLag

open Etna.Design

-- A valid old local prefix authenticates its own checkpoint, not a newer World.
example :
    BlockValidity.Chain HistoricalEscrow.rules NonVacuity.genesisHeader SigningViewLag.localPrefix ∧
    SigningViewLag.request.position.height = SigningViewLag.tip.height+1 ∧
    SigningViewLag.view.inbox.snapshot < SigningViewLag.current.inbox.snapshot := by
  exact ⟨SigningViewLag.old_view_and_local_height.1,by decide +kernel⟩

example : ProtocolState.Trace NonVacuity.world0 SigningViewLag.view :=
  SigningViewLag.view_reachable

-- A higher-round nil precommit is a new durable signing event after withdrawal.
example :
    (SigningViewLag.current.registry.slots 0).balance = 0 ∧
    Signer.sign SigningViewLag.session SigningViewLag.request 777 true =
      some (SigningViewLag.after,777) ∧
    SigningViewLag.after.log.length = SigningViewLag.session.log.length+1 := by
  decide +kernel

-- Different rounds do not constitute the registry's same-round double sign.
example : Staking.doubleSign FirstBatch.deployment SigningViewLag.current.inbox.generation
    (Accountability.evidence SigningViewLag.previousVote)
    (Accountability.evidence SigningViewLag.nilVote) = false := by
  decide +kernel

-- The full typed refinement admits the stale-view fresh nil event, while the
-- newer withdrawal checkpoint cannot be included in that validated local prefix.
example :
    SigningBridge.EngineRequest SigningViewLag.typedPrefix
      SigningViewLag.typedCall.device.key SigningViewLag.typedCall.message ∧
    SigningViewLag.typedCall.after.log ≠ SigningViewLag.typedCall.device.state.log ∧
    ¬Nonempty (SigningBridge.IncludedCheckpoint SigningViewLag.current SigningViewLag.typedPrefix) :=
  ⟨SigningViewLag.typed_engine_request,SigningViewLag.typed_call_fresh,
    SigningViewLag.current_checkpoint_not_included⟩

example :
    SigningViewLag.typedCall.returned = SigningViewLag.typedCall.supplied ∧
    SigningViewLag.typedCall.after.log =
      ⟨SigningViewLag.typedCall.message.generation,SigningViewLag.typedCall.request.position,
        SigningViewLag.typedCall.request.bytes,SigningViewLag.typedCall.supplied⟩ ::
      SigningViewLag.typedCall.device.state.log :=
  SigningBridge.fresh_return_binds_message SigningViewLag.typedCall SigningViewLag.typed_call_fresh
