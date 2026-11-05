import EtnaModel.Consensus
import EtnaProofs.Committee

/-! Proofs about `EtnaModel.Consensus`. -/
namespace Etna.Design.Consensus

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
