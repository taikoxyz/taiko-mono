/-!
# Fixed-width extra data

Unzen headers carry seven bytes of extra data: the base-fee sharing percentage, then the
proposal ID as six big-endian bytes. Proposal IDs keep their low six bytes.
-/
namespace TaikoSpec.Derivation

/-- Exclusive upper bound of a uint48. -/
def uint48Limit : Nat := 256 ^ 6

/-- Least-significant bytes first, truncated to the requested width. -/
def encodeLE : Nat → Nat → List UInt8
  | 0, _ => []
  | w + 1, n => UInt8.ofNat n :: encodeLE w (n / 256)

/-- Fixed-width big-endian bytes, including leading zeroes. -/
def encodeBE (width n : Nat) : List UInt8 := (encodeLE width n).reverse

/-- Decode least-significant bytes first. -/
def decodeLE : List UInt8 → Nat
  | [] => 0
  | b :: bs => b.toNat + 256 * decodeLE bs

/-- Decode big-endian bytes. -/
def decodeBE (bs : List UInt8) : Nat := decodeLE bs.reverse

/-- The seven-byte layout: sharing percentage, then the proposal's low six bytes. -/
def encodeExtraData (sharing : UInt8) (proposal : Nat) : List UInt8 :=
  sharing :: encodeBE 6 proposal

/-- The proposal field of seven-byte extra data. -/
def decodeExtraDataProposal (bs : List UInt8) : Option Nat :=
  if bs.length = 7 then some (decodeBE (bs.drop 1)) else none

end TaikoSpec.Derivation
