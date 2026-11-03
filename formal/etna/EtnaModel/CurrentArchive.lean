import EtnaModel.CurrentFinality

/-! The ordinary committee lookback archive is the actual EL ancestry through the
batch, not a separately selectable list of anchor numbers. The fixed physical-parent
projection is keyed by EL hash, so independent Comet/FI metadata cannot change it. -/
namespace Etna.Design.Current.Archive

abbrev Header := Blocks.Header
abbrev Block := Blocks.Block

/-- Physical EL ancestry, including every intermediate height. -/
def Linked (parentOf : Hash → Hash) : Header → List Header → Prop
  | _, [] => True
  | p, h :: rest => h.height = p.height+1 ∧ parentOf h.elHash = p.elHash ∧ Linked parentOf h rest

/-- The last decoded header of a possibly empty archive prefix. -/
def terminal : Header → List Header → Header
  | p, [] => p
  | _, h :: rest => terminal h rest

/-- All historical headers are hash-bound and linked from the authenticated generation
origin to the exact batch parent; the rest are the batch's actual headers. No archive
anchor or generation origin may be taken from beyond the closed L1 reference. -/
def Authenticated (hash : Header → Hash) (parentOf : Hash → Hash)
    (cfg : Finality.Config) (origin : Cut) (reference : Nat)
    (archive : List Header) (p : Header) (bs : List Block) : Prop :=
  ∃ root prior, root.height = cfg.originHeight ∧ root.cut = origin ∧ hash root = root.elHash ∧
    archive = prior ++ bs.map Blocks.Block.header ∧ terminal root prior = p ∧
    Linked parentOf root archive ∧ (∀ h ∈ archive, hash h = h.elHash) ∧
    (∀ b ∈ bs, parentOf b.header.elHash = b.body.parentHash) ∧
    cfg.originBlock ≤ reference ∧ (∀ h ∈ archive, h.anchor.number ≤ reference)

end Etna.Design.Current.Archive
