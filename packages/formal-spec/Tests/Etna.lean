import Tests.Header
import Tests.Derive

open TaikoSpec TaikoSpec.Derivation Tests HeaderTests
namespace EtnaHeaderTests

/-- Exact observable header fields, including candidate kind and serialized manifest items. -/
def txSummary (h : HeaderPlan) : List (Bool × String) := h.transactions.map fun
  | .systemAnchor => (true, "")
  | .manifest item => (false, toHex (Rlp.encode item))

def headerSummary (hs : List HeaderPlan) :
    List (Nat × Nat × Nat × Nat × Nat × Option Root × Nat × List (Bool × String)) :=
  hs.map fun h => (h.block.number, h.block.timestamp, h.block.anchorBlockNumber,
    h.block.gasLimit, h.gasLimit, h.beaconRoot, h.extraData.length, txSummary h)

def unzenParent : HeaderParent :=
  { HeaderTests.parent with core.timestamp := 1999, core.gasLimit := 31000000 }

def preBoundaryParent : HeaderParent :=
  { unzenParent with core.timestamp := 1998 }

def proposal : ProposalCtx :=
  { proposer := addr 0x99, timestamp := 2001, originBlockNumber := 500 }

def otherRoot : HeaderContext := { context with l1StateRoot := fun _ => some rootB }

-- First Etna and genesis Etna fetch the L1 root, even when a different parent root exists.
#guard (buildHeader chain otherRoot unzenParent child).map (·.beaconRoot) == .ok (some rootB)
#guard (buildHeader chain otherRoot { HeaderTests.parent with core.number := 0 } { child with number := 1 }).map
  (·.beaconRoot) == .ok (some rootB)
#guard (buildHeader chain noRoots { HeaderTests.parent with core.number := 0 } { child with number := 1 }).map
  (·.beaconRoot) == .error (.missingL1Root 400)
-- Changed anchors fetch; an unavailable changed anchor cannot reuse the parent's root.
#guard (buildHeader chain noRoots HeaderTests.parent { child with anchorBlockNumber := 450 }).map
  (·.beaconRoot) == .error (.missingL1Root 450)
-- Missing/zero parents cannot fall back to an available L1 root on the reuse branch.
#guard (buildHeader chain context { HeaderTests.parent with beaconRoot := none } child).map
  (·.beaconRoot) == .error .missingParentRoot
#guard (buildHeader chain context { HeaderTests.parent with beaconRoot := some 0 } child).map
  (·.beaconRoot) == .error .zeroParentRoot

-- Header fork choice uses each child's timestamp, including the exact activation second.
#guard (buildHeader chain noRoots preBoundaryParent { child with timestamp := 1999 }).map
  (fun h => (h.beaconRoot, h.gasLimit, h.extraData.length, txSummary h)) ==
  .ok (some 0, 31000000, 7, [(true, "")])
#guard (buildHeader chain context unzenParent { child with timestamp := 2000 }).map
  (fun h => (h.beaconRoot, h.gasLimit, h.extraData.length, txSummary h)) ==
  .ok (some rootA, 30000000, 13, [])
#guard (buildHeader { chain with unzenForkTime := none } noRoots preBoundaryParent
  { child with timestamp := 1999 }).map (·.beaconRoot) == .ok none

/-- A second syntactically valid legacy candidate, with a distinct gas price. -/
def transfer2 : Rlp.Item :=
  .list [.bytes ⟨#[]⟩, .bytes ⟨#[2]⟩, .bytes ⟨#[0x52, 0x08]⟩, .bytes (addr 0x42), .bytes ⟨#[]⟩,
    .bytes ⟨#[]⟩, .bytes ⟨#[27]⟩, .bytes ⟨#[1]⟩, .bytes ⟨#[1]⟩]
#guard Tx.wellFormed transfer && Tx.wellFormed transfer2

-- Etna preserves empty and nonempty manifest candidates without a system anchor.
-- RLP items carry no authenticated sender; sender authentication/execution is outside this model.
#guard (buildHeader chain noRoots HeaderTests.parent child).map txSummary == .ok []
#guard (buildHeader chain noRoots HeaderTests.parent
  { child with transactions := [transfer, transfer2, transfer] }).map txSummary ==
  .ok [(false, toHex (Rlp.encode transfer)), (false, toHex (Rlp.encode transfer2)),
    (false, toHex (Rlp.encode transfer))]
#guard (buildHeader chain noRoots preBoundaryParent
  { child with timestamp := 1999, transactions := [transfer] }).map txSummary ==
  .ok [(true, ""), (false, toHex (Rlp.encode transfer))]

-- Metadata overflows are checked after root selection and propagate unchanged.
#guard (buildHeader chain { context with proposalId := 281474976710656 }
  HeaderTests.parent child).map (·.extraData) == .error (.extraData .proposalOverflow)
#guard (buildHeader chain otherRoot HeaderTests.parent
  { child with anchorBlockNumber := 281474976710656 }).map (·.extraData) ==
  .error (.extraData .anchorOverflow)
#guard encodeLegacyExtraData 50 281474976710663 == encodeLegacyExtraData 50 7
#guard decodeExtraDataProposal (encodeLegacyExtraData 50 7) == some 7
#guard decodeEtnaAnchorBlockNumber 0 (List.replicate 14 255) == some 0
#guard decodeEtnaAnchorBlockNumber 1 (List.replicate 12 0) == none
#guard decodeEtnaAnchorBlockNumber 1 (List.replicate 14 0) == none
#guard decodeExtraDataProposal (List.replicate 8 0) == none

-- One source crosses activation; the following forced source inherits its final commitment.
def crossingSource : Source × Option ByteArray :=
  (src, some (payloadOf [blk 1999 450 30000000, blk 2000 460 30000000]))
def only460 : HeaderContext :=
  { context with l1StateRoot := fun a => if a == 460 then some rootB else none }
#guard (deriveHeaders chain proposal only460 preBoundaryParent
  [crossingSource, forcedSource]).map headerSummary == .ok
  [(11, 1999, 450, 30000000, 31000000, some 0, 7, [(true, "")]),
   (12, 2000, 460, 30000000, 30000000, some rootB, 13, []),
   (13, 2001, 460, 30000000, 30000000, some rootB, 13, [])]
-- Two Etna blocks within one source thread the newly fetched commitment, not the initial one.
def repeatedEtnaSource : Source × Option ByteArray :=
  (src, some (payloadOf [blk 2000 450 30000000, blk 2001 450 30000000]))
def only450 : HeaderContext :=
  { context with l1StateRoot := fun a => if a == 450 then some rootB else none }
#guard (deriveHeaders chain proposal only450 unzenParent [repeatedEtnaSource]).map
  headerSummary == .ok
  [(11, 2000, 450, 30000000, 30000000, some rootB, 13, []),
   (12, 2001, 450, 30000000, 30000000, some rootB, 13, [])]
-- The initial Etna commitment is reusable across multiple sources with no lookups available.
#guard (deriveHeaders chain { proposal with timestamp := 2002 } noRoots HeaderTests.parent
  [forcedTransfer, forcedSource]).map headerSummary == .ok
  [(11, 2001, 400, 30000000, 30000000, some rootA, 13, [(false, toHex (Rlp.encode transfer))]),
   (12, 2002, 400, 30000000, 30000000, some rootA, 13, [])]
-- Defaults cross activation even when proposal time remains before Etna.
#guard (deriveHeaders chain { proposal with timestamp := 1999 } context unzenParent
  [(src, none), (src, none)]).map headerSummary == .ok
  [(11, 2000, 400, 30000000, 30000000, some rootA, 13, []),
   (12, 2001, 400, 30000000, 30000000, some rootA, 13, [])]
-- A first Etna forced block fetches; its successor inherits the resulting commitment.
#guard (deriveHeaders chain proposal context unzenParent [forcedSource, forcedSource]).map
  headerSummary == .ok
  [(11, 2000, 400, 30000000, 30000000, some rootA, 13, []),
   (12, 2001, 400, 30000000, 30000000, some rootA, 13, [])]

-- Whole-proposal errors retain the exact failing anchor and do not return a successful prefix.
#guard (deriveHeaders chain proposal noRoots unzenParent [forcedSource, forcedSource]).map
  headerSummary == .error (.missingL1Root 400)
#guard (deriveHeaders chain proposal context preBoundaryParent
  [crossingSource, forcedSource]).map headerSummary == .error (.missingL1Root 460)
#guard (deriveHeaders chain proposal { only460 with proposalId := 281474976710656 }
  preBoundaryParent [crossingSource, forcedSource]).map headerSummary ==
  .error (.extraData .proposalOverflow)
-- A malformed source is defaulted before headers are built, preserving the inherited anchor.
#guard (deriveHeaders chain { proposal with timestamp := 2002 } noRoots HeaderTests.parent
  [(src, some ⟨#[0xff]⟩)]).map headerSummary == .ok
  [(11, 2001, 400, 30000000, 30000000, some rootA, 13, [])]

-- Limits are selected from proposal time, independently of Etna and child time.
def limitsChain : ChainParams := { chain with unzenForkTime := some 2000 }
#guard (checkLimits limitsChain { proposal with timestamp := 1999 } src
  (List.replicate 193 (blk 2000 450 30000000))).map List.length == none
#guard (checkLimits limitsChain { proposal with timestamp := 2000 } src
  (List.replicate 193 (blk 2000 450 30000000))).map List.length == some 193
#guard (checkLimits limitsChain proposal src (List.replicate 768 emptyBlock)).map List.length == some 768
#guard (checkLimits limitsChain proposal src (List.replicate 769 emptyBlock)).map List.length == none

end EtnaHeaderTests
