import EtnaModel.Consensus
import EtnaProofs.Committee

/-! Proofs about `EtnaModel.Consensus`. -/
namespace Etna.Design.Consensus

/-- Independent unfolded election contract: weakening ElectionValid to True must fail.
This constrains this modeled definition, not its correspondence to every source rule.
Every global name is `_root_`-qualified so a nearer declaration cannot capture it. -/
theorem election_valid_iff (c : _root_.Etna.Design.Consensus.Context)
    (r : _root_.Etna.Design.Committee.Record) :
    _root_.Etna.Design.Consensus.ElectionValid c r ↔
      _root_.Etna.Design.Committee.election c.unit c.minimum r.cutoff c.nMax (c.registry r.cutoff) =
        _root_.Option.some r.members := Iff.rfl

theorem commit_strict_quorum {c : Context} {signature : Vote → Prop}
    {h round block : Nat} {votes : List Vote} (ok : CommitValid c signature h round block votes) :
    2*Committee.totalPower c.unit (activeAt c h).members <
      3*signedPower c (activeAt c h).members (votes.map Vote.key) := ok.2.2.2.2

theorem signed_power_bounded (c : Context) (members : List Committee.Entry) (keys : List Hash) :
    signedPower c members keys ≤ Committee.totalPower c.unit members := by
  induction members with
  | nil => simp [signedPower,Committee.totalPower]
  | cons a rest ih =>
    simp only [signedPower,Committee.totalPower,List.filter_cons,List.map_cons,List.sum_cons] at *
    split <;> simp_all <;> omega

end Etna.Design.Consensus
