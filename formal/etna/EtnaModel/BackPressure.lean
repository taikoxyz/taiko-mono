import EtnaModel.ProtocolState

/-! Section 6.4 back-pressure accounting. A block's anchor proves an L1 checkpoint height,
and the block may be at most `unsettled` (U) blocks above it (3.4 rule 8, `AnchorValid`).
6.4 says this anchor-based count never undercounts the unsettled blocks, except for the
section 8 verifier-failure rollback. `OrdinaryTrace` names the traces without that
exception; it introduces no new transition. -/
namespace Etna.Design.ProtocolState

/-- A refinement with no verifier-failure rollback edge. Every edge is an original `Step`
whose result is not the rollback transformer's result. -/
inductive OrdinaryTrace : World → World → Prop
  | refl (w : World) : OrdinaryTrace w w
  | step {first w t : World} (prior : OrdinaryTrace first w) (change : Step w t)
      (ordinary : ∀ trusted snapshot now, t ≠ applyRollback w trusted snapshot now) :
      OrdinaryTrace first t

end Etna.Design.ProtocolState
