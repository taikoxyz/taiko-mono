import EtnaModel.Consensus

/-! Cross-round safety. 3.1 uses stock CometBFT, whose locking rules are not modelled here.
This file states CometBFT's cross-round accountability as a predicate that theorems take as an
explicit hypothesis. Cross-round faults are not slashable under 4.1 (section 12 item 3). -/
namespace Etna.Design.Consensus

/-- Two valid commits for different blocks at one height in different rounds imply that members
holding more than 1/3 of the active committee's power broke CometBFT's locking rules; `violates`
marks those members. -/
def CrossRoundAccountable (c : Context) (signature : Vote → Prop) (violates : Hash → Bool) : Prop :=
  ∀ h ra rb a b votesA votesB, CommitValid c signature h ra a votesA → CommitValid c signature h rb b votesB →
    ra ≠ rb → a ≠ b →
    Committee.totalPower c.unit (activeAt c h).members <
      3*Committee.totalPower c.unit ((activeAt c h).members.filter fun m => violates m.key)

end Etna.Design.Consensus
