import DerivationModel

namespace TaikoSpec.Derivation

/-- Available lookups agree with a total canonical L1 history. -/
def LookupsSound (ctx : HeaderContext) (history : Nat → Root) : Prop :=
  ∀ a r, ctx.l1StateRoot a = some r → r = history a

/-- A non-genesis Etna parent commits to its anchor's canonical L1 root. -/
def ParentCommits (c : ChainParams) (history : Nat → Root) (p : HeaderParent) : Prop :=
  isEtna c p.core.timestamp = true → p.core.number ≠ 0 →
    p.beaconRoot = some (history p.core.anchorBlockNumber)

/-- An Etna header commits to its anchor's canonical L1 root. -/
def HeaderCommits (c : ChainParams) (history : Nat → Root) (h : HeaderPlan) : Prop :=
  isEtna c h.block.timestamp = true → h.beaconRoot = some (history h.block.anchorBlockNumber)

end TaikoSpec.Derivation
