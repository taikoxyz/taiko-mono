import EtnaWitnesses.Regressions.ActualQueue
import EtnaWitnesses.NonVacuity.Premises

-- A real current-cursor entry is due at the inclusive block-time bound; this regression
-- must be discharged by the semantic-history/local-block composition, not an implication
-- with an impossible deadline as in the earlier AnchorHonesty fixture.
example : ∃ (w : Etna.Design.ProtocolState.World) (entry : Etna.Design.Forced.Entry)
    (p : Etna.Design.BlockValidity.Header) (b : Etna.Design.BlockValidity.Block)
    (r : Etna.Design.BlockValidity.Rules),
    (p.cursor,entry) ∈ w.queue ∧ Etna.Design.BlockValidity.Valid r p b ∧
    b.header.timestamp = entry.timestamp+r.forcedDelay+r.maxAnchorAge ∧
    b.header.cursor = p.cursor+1 := by
  exact Etna.Design.ActualQueueRegression.exact_deadline_nonvacuous

example := Etna.Design.ActualQueueRegression.local_byte_actions .included
example := Etna.Design.ActualQueueRegression.local_byte_actions .empty
example := Etna.Design.ActualQueueRegression.local_byte_actions .invalid
example := Etna.Design.ActualQueueRegression.canonical_admissions
example := Etna.Design.ActualQueueRegression.incomplete_same_block_cut_rejected
example := Etna.Design.ActualQueueRegression.nonempty_skip_rejected
example := Etna.Design.ActualQueueRegression.recovery_and_resubmission
example := Etna.Design.ActualQueueRegression.recovered_exact_service
example := Etna.Design.ActualQueueRegression.recovered_byte_actions
