import EtnaWitnesses.Regressions.CanonicalHistory

open Etna.Design

-- The lift derives every stronger per-landing source/reference obligation from raw history.
example {initial w : ProtocolState.World} {archive : List Nat}
    (run : CanonicalHistory.Run initial w archive) : NormalSigning.Run initial w :=
  CanonicalHistory.run_normal run

-- A recovery is consumed by a real accepted landing and a fresh stock next-height signature.
example :
    CanonicalHistory.Run NonVacuity.world0 CanonicalHistoryRegression.finish NormalSigningRegression.archive1 ∧
    NormalSigning.Run NonVacuity.world0 CanonicalHistoryRegression.finish ∧
    CanonicalHistoryRegression.finish.inbox.generation = 1 ∧
    CanonicalHistoryRegression.finish.inbox.checkpoint.height = 22 ∧
    SigningBridge.EngineRequest CanonicalHistoryRegression.signingPrefix
      CanonicalHistoryRegression.event.device.key CanonicalHistoryRegression.event.message ∧
    CanonicalHistoryRegression.event.after.log ≠ CanonicalHistoryRegression.event.device.state.log ∧
    CanonicalHistoryRegression.event.message.height = 23 ∧ CanonicalHistoryRegression.event.device.key ≠ 7 :=
  CanonicalHistoryRegression.post_recovery_landing_signs

-- Clock and confirmation coverage are consequences for every raw canonical history.
example {initial w : ProtocolState.World} {archive : List Nat}
    (run : CanonicalHistory.Run initial w archive) (covered : SigningEscrow.Covered initial) :
    SigningEscrow.Covered w := NormalSigning.run_covered (CanonicalHistory.run_normal run) covered

example : Etna.Design.land NormalSigningRegression.view.inbox CanonicalHistoryRegression.statement.input
    CanonicalHistoryRegression.leaves CanonicalHistoryRegression.landing = some CanonicalHistoryRegression.finish.inbox :=
  CanonicalHistoryRegression.landing_accepted

example : SigningBridge.SnapshotSource NormalSigningRegression.view.inbox NormalSigningRegression.rules1.consensus :=
  CanonicalHistoryRegression.actual_recovery_source

-- The separate submission annotation projects to the original run without changing edges.
example {env : Etna.Statements.Environment} {initial w : ProtocolState.World} {archive : List Nat}
    (run : CanonicalHistory.Run initial w archive) (submitted : CanonicalHistory.Submitted env.submits run) :
    Etna.Statements.Run env initial w := CanonicalHistory.run_statements run submitted
