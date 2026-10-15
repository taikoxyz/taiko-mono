import TaikoSpec.Derivation.Header
import Tests.Helpers

open TaikoSpec TaikoSpec.Derivation Tests
deriving instance BEq for Except

namespace HeaderTests

-- Exact bytes distinguish endianness, field order, and six-byte widths.
#guard encodeEtnaExtraData 50 7 123456 ==
  .ok [0x32, 0, 0, 0, 0, 0, 7, 0, 0, 0, 1, 0xe2, 0x40]
#guard encodeLegacyExtraData 50 7 == [0x32, 0, 0, 0, 0, 0, 7]
#guard encodeEtnaExtraData 50 281474976710655 281474976710655 ==
  .ok (50 :: List.replicate 12 255)
#guard encodeEtnaExtraData 50 281474976710656 0 == .error .proposalOverflow
#guard encodeEtnaExtraData 50 0 281474976710656 == .error .anchorOverflow
#guard decodeEtnaAnchorBlockNumber 0 [] == some 0
#guard decodeEtnaAnchorBlockNumber 1 [] == none
#guard decodeEtnaAnchorBlockNumber 1 [0x32, 0, 0, 0, 0, 0, 7, 0, 0, 0, 1, 0xe2, 0x40] == some 123456

def chain : ChainParams := { devnet with etnaForkTime := some 2000 }
def rootA : Root := 17
def rootB : Root := 29
def context : HeaderContext :=
  { baseFeeSharing := 50, proposalId := 7,
    l1StateRoot := fun n => if n == 400 then some rootA else if n == 450 then some rootB else none }
def noRoots : HeaderContext := { context with l1StateRoot := fun _ => none }
def parent : HeaderParent :=
  { core := { number := 10, timestamp := 2000, gasLimit := 30000000, anchorBlockNumber := 400 },
    beaconRoot := some rootA }
def child : DerivedBlock :=
  { number := 11, timestamp := 2001, coinbase := addr 0, anchorBlockNumber := 400,
    gasLimit := 30000000, transactions := [], isForcedInclusion := false }

#guard (buildHeader chain noRoots parent child).map (·.beaconRoot) == .ok (some rootA)
#guard (buildHeader chain context parent { child with anchorBlockNumber := 450 }).map
  (·.beaconRoot) == .ok (some rootB)
#guard (buildHeader chain noRoots { parent with core.timestamp := 1999 } child).map
  (·.beaconRoot) == .error (.missingL1Root 400)
#guard (buildHeader chain noRoots { parent with beaconRoot := none } child).map
  (·.beaconRoot) == .error .missingParentRoot
#guard (buildHeader chain noRoots { parent with beaconRoot := some 0 } child).map
  (·.beaconRoot) == .error .zeroParentRoot
#guard (buildHeader chain { context with l1StateRoot := fun _ => some 0 }
  { parent with core.timestamp := 1999 } child).map (·.beaconRoot) == .error (.zeroL1Root 400)
end HeaderTests
