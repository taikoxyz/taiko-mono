import DerivationProofs

namespace TaikoSpec.Derivation
open TaikoSpec Proofs

/-! ## Witnesses -/

namespace Witness

/-- A devnet proposal at timestamp 2000 whose origin block is 500. -/
def proposal : ProposalCtx :=
  { proposer := ⟨Array.replicate 20 0x99⟩, timestamp := 2000, originBlockNumber := 500 }

/-- Block 10 at timestamp 1900, 31M header gas limit (30M effective), anchor 400. -/
def parent : Parent :=
  { number := 10, timestamp := 1900, gasLimit := 31_000_000, anchorBlockNumber := 400 }

/-- A source with blobs. -/
def source (forced : Bool) : Source :=
  { isForcedInclusion := forced, hasBlobs := true, offset := 0 }

/-- A block without transactions. -/
def block (timestamp anchor gasLimit : Nat) : BlockManifest :=
  { timestamp, coinbase := ⟨Array.replicate 20 0⟩, anchorBlockNumber := anchor, gasLimit,
    transactions := [] }

/-- Theorems 6 and 7: the parent's anchor and gas limit satisfy the preconditions. -/
example : parent.anchorBlockNumber ≤ proposal.originBlockNumber ∧
    MIN_BLOCK_GAS_LIMIT ≤ effectiveGasLimit devnet parent ∧
    effectiveGasLimit devnet parent ≤ MAX_BLOCK_GAS_LIMIT := by decide

/-- Theorems 5 and 8: a proposer's source can keep its own blocks. -/
example : (finalizeSource devnet proposal parent (source false)
    (some [block 1950 450 30_000_000])).isAccepted = true := by decide

/-- Theorem 9: this forced inclusion is kept, and the same one is dropped once the origin block
is 129 blocks past the parent's anchor. -/
example : (finalizeSource devnet proposal parent (source true) (some [block 0 0 0])).isAccepted =
    true := by decide
example : (finalizeSource devnet { proposal with originBlockNumber := 529 } parent (source true)
    (some [block 0 0 0])).isAccepted = false := by decide

/-- Theorem 5: a default block can be later than the proposal timestamp. -/
example : (defaultBlock devnet { proposal with timestamp := 1900 } parent).timestamp > 1900 := by
  decide

/-- A scheduled Etna fork supplies witnesses on both sides of activation. -/
def etnaChain : ChainParams := { devnet with etnaForkTime := some 2000 }

def etnaParent : Parent :=
  { parent with number := 11, timestamp := 2000, gasLimit := 30_000_000 }

example : MIN_BLOCK_GAS_LIMIT ≤ effectiveGasLimit etnaChain parent ∧
    effectiveGasLimit etnaChain parent ≤ MAX_BLOCK_GAS_LIMIT ∧
    MIN_BLOCK_GAS_LIMIT ≤ effectiveGasLimit etnaChain etnaParent ∧
    effectiveGasLimit etnaChain etnaParent ≤ MAX_BLOCK_GAS_LIMIT := by decide

example : (advance etnaChain parent (block 1999 450 30_000_000)).gasLimit = 31_000_000 ∧
    (advance etnaChain parent (block 2000 450 30_000_000)).gasLimit = 30_000_000 := by decide

example : (finalizeSource etnaChain { proposal with timestamp := 2001 } etnaParent
    (source true) (some [block 0 0 0])).isAccepted = true := by decide

/-- Checked header witnesses use a nonzero canonical root with no available lookup. -/
def headerContext : HeaderContext :=
  { baseFeeSharing := 50, proposalId := 7, l1StateRoot := fun _ => none }

def canonicalHistory (_ : Nat) : Root := 17

def headerParent : HeaderParent := { core := etnaParent, beaconRoot := some 17 }

def derivedHeaderBlock : DerivedBlock :=
  { number := 12, timestamp := 2001, coinbase := ⟨Array.replicate 20 0x99⟩,
    anchorBlockNumber := 400, gasLimit := 30_000_000, transactions := [], isForcedInclusion := false }

def headerPlan : HeaderPlan :=
  { block := derivedHeaderBlock, gasLimit := 30_000_000, beaconRoot := some 17,
    extraData := [50, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 1, 144], transactions := [] }

example : LookupsSound headerContext canonicalHistory := by
  intro a r lookup
  cases lookup

example : ParentCommits etnaChain canonicalHistory headerParent := by
  intro _ _
  rfl

example : buildHeader etnaChain headerContext headerParent derivedHeaderBlock = .ok headerPlan := rfl

example : derivedHeaderBlock.number ≠ 0 ∧ isEtna etnaChain derivedHeaderBlock.timestamp = true ∧
    7 < uint48Limit ∧ 123456 < uint48Limit := by decide

example : (encodeEtnaExtraData 50 7 123456).toOption.bind (decodeEtnaAnchorBlockNumber 12) =
    some 123456 := by decide

/-- Two finalized defaults inherit the authenticated commitment without any lookup. -/
def headerProposal : ProposalCtx := { proposal with timestamp := 2002 }

def nextHeaderPlan : HeaderPlan :=
  { headerPlan with block := { derivedHeaderBlock with number := 13, timestamp := 2002 } }

example : deriveHeaders etnaChain headerProposal headerContext headerParent
    [(source false, none), (source false, none)] = .ok [headerPlan, nextHeaderPlan] := rfl

example : HeaderCommits etnaChain canonicalHistory headerPlan := by
  intro _
  rfl

example : uint48Limit ≤ 281474976710656 ∧ 7 < uint48Limit ∧
    isEtna etnaChain 1999 = false := by decide

example : buildHeader etnaChain headerContext
    { headerParent with core.timestamp := 1998, core.gasLimit := 31_000_000 }
    { derivedHeaderBlock with timestamp := 1999 } = .ok
    { headerPlan with
      block := { derivedHeaderBlock with timestamp := 1999 }
      gasLimit := 31_000_000
      beaconRoot := some 0
      extraData := [50, 0, 0, 0, 0, 0, 7]
      transactions := [.systemAnchor] } := rfl

/-- Etna at genesis admits a zero-root parent and a child authenticated by an L1 block-zero lookup. -/
example :
    let c : ChainParams := { devnet with etnaForkTime := some 0 }
    let hp : HeaderParent :=
      { core := { number := 0, timestamp := 0, anchorBlockNumber := 0, gasLimit := 30_000_000 },
        beaconRoot := some 0 }
    let b : DerivedBlock :=
      { derivedHeaderBlock with number := 1, timestamp := 1, anchorBlockNumber := 0 }
    let hc : HeaderContext :=
      { headerContext with l1StateRoot := fun a => if a == 0 then some 17 else none }
    let h : HeaderPlan :=
      { headerPlan with block := b, extraData := [50, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0] }
    isEtna c hp.core.timestamp = true ∧
    LookupsSound hc canonicalHistory ∧ ParentCommits c canonicalHistory hp ∧
    hc.l1StateRoot 0 = some (canonicalHistory 0) ∧
    buildHeader c hc hp b = .ok h ∧ HeaderCommits c canonicalHistory h := by
  dsimp only
  refine ⟨by decide, ?_, ?_, rfl, rfl, ?_⟩
  · intro a r lookup
    change (if a == 0 then some 17 else none) = some r at lookup
    split at lookup <;> cases lookup <;> rfl
  · intro _ nonGenesis
    exact (nonGenesis rfl).elim
  · intro _
    rfl

end Witness

end TaikoSpec.Derivation
