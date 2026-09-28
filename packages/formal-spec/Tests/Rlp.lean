import TaikoSpec.Rlp

/-!
# RLP tests

Canonical round trips, and the non-canonical encodings RLP decoding rejects.
-/

open TaikoSpec

/-- `Rlp.decode` applied to a hex string, re-encoded as hex (`none` if it does not decode). -/
def rlpRoundTrip (s : String) : Option String :=
  ((fromHex? s).bind Rlp.decode).map (toHex ∘ Rlp.encode)

/-- The unsigned integer an RLP hex string encodes, with at most 64 bits. -/
def uint64Hex (s : String) : Option Nat :=
  ((fromHex? s).bind Rlp.decode).bind (Rlp.Item.uint? 64)

-- RLP: canonical items round-trip.
#guard rlpRoundTrip "05" == some "05"
#guard rlpRoundTrip "80" == some "80"
#guard rlpRoundTrip "8180" == some "8180"
#guard rlpRoundTrip "c0" == some "c0"
#guard rlpRoundTrip "c3c180c0" == some "c3c180c0"
#guard rlpRoundTrip "c20505" == some "c20505"
-- RLP: non-canonical encodings and trailing bytes are rejected.
#guard rlpRoundTrip "8105" == none
#guard rlpRoundTrip "b80105" == none
#guard rlpRoundTrip "0505" == none
#guard rlpRoundTrip "82" == none
#guard rlpRoundTrip "c105c0" == none
-- RLP integers: no leading zero byte, and a lone 0x00 is not an integer.
#guard uint64Hex "00" == none
#guard uint64Hex "820001" == none
#guard uint64Hex "80" == some 0
#guard uint64Hex "88ffffffffffffffff" == some (2 ^ 64 - 1)
#guard uint64Hex "89010000000000000000" == none
