import DerivationModel.Derivation.Header
import DerivationWitnesses.Tests.Helpers

/-!
# Header plan tests

Exact extra-data bytes and the planned transaction order of an Unzen block.
-/

open TaikoSpec TaikoSpec.Derivation Tests

namespace HeaderTests

-- Exact bytes distinguish endianness, field order and the six-byte width.
example : encodeExtraData 50 7 = [0x32, 0, 0, 0, 0, 0, 7] := by decide
example : encodeExtraData 100 281474976710655 = 100 :: List.replicate 6 255 := by decide
-- Proposal IDs above uint48 keep their low six bytes.
example : encodeExtraData 50 281474976710656 = [0x32, 0, 0, 0, 0, 0, 0] := by decide
example : decodeExtraDataProposal [0x32, 0, 0, 0, 1, 0xe2, 0x40] = some 123456 := by decide
example : decodeExtraDataProposal [0x32, 0, 0, 0, 0, 0, 7, 0] = none := by decide

def context : HeaderContext := { baseFeeSharing := 100, proposalId := 7 }

def child : DerivedBlock :=
  { number := 11, timestamp := 2001, coinbase := addr 0, anchorBlockNumber := 400,
    gasLimit := 30_000_000, transactions := [], isForcedInclusion := false }

-- The header adds the anchor reserve; the next parent recovers the manifest gas from it.
example : (buildHeader context child).gasLimit = 31_000_000 := rfl
example : effectiveGasLimit (headerParent (buildHeader context child)) = 30_000_000 := by decide
example : (buildHeader context child).extraData = [100, 0, 0, 0, 0, 0, 7] := by decide
-- The anchor comes first, for the block's own anchor number.
example : ((buildHeader context child).transactions.map fun
    | .anchor n => some n
    | .manifest _ => none) = [some 400] := rfl
-- `anchorV4` keeps the recorded anchor when the checkpoint is not greater.
example : recordedAnchors 400 [400, 450, 450, 460] = [400, 450, 450, 460] := by decide
example : recordedAnchors 400 [399, 450] = [400, 450] := by decide

end HeaderTests
