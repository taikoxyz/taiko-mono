import TaikoSpec.Derivation.Validate

/-!
# The Rust driver's finalize order

The Rust driver (`prepare_segment_manifest` in `pipeline/payload.rs`) inherits metadata before
validation not only for forced inclusions but also for any manifest that looks exactly like the
default one. The Go driver, like `finalizeSource`, validates such a manifest as is. Theorem 11 in
`Properties.lean` shows the two orders give the same result.
-/

namespace TaikoSpec.Derivation

variable (c : ChainParams) (ctx : ProposalCtx)

/-- Rust's `manifest_is_default`: exactly one block, every field zero, no transactions. -/
def looksLikeDefault : List BlockManifest → Bool
  | [b] =>
    b.timestamp == 0 && b.coinbase == emptyBlock.coinbase && b.anchorBlockNumber == 0 &&
      b.gasLimit == 0 && b.transactions.isEmpty
  | _ => false

/-- `finalizeSource` in the Rust driver's order. -/
def finalizeSourceRust (p : Parent) (src : Source) : Option (List BlockManifest) → SourceOutcome
  | none => .defaulted (defaultBlock c ctx p)
  | some bs =>
    let bs :=
      if src.isForcedInclusion || looksLikeDefault bs then inherit c ctx p p.timestamp bs else bs
    if validate c ctx p src.isForcedInclusion bs then .accepted bs
    else .defaulted (defaultBlock c ctx p)

end TaikoSpec.Derivation
