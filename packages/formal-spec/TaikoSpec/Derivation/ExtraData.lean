/-!
# Fixed-width extra data

The byte codec uses big endian order. Legacy proposal IDs retain their low six bytes;
Etna rejects values outside uint48 before producing its thirteen-byte layout.
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

/-- Checked fields of Etna extra data. -/
inductive ExtraDataError where
  | proposalOverflow
  | anchorOverflow
  deriving DecidableEq, BEq, Repr

/-- The existing seven-byte layout keeps the proposal's low six bytes. -/
def encodeLegacyExtraData (sharing : UInt8) (proposal : Nat) : List UInt8 :=
  sharing :: encodeBE 6 proposal

/-- Etna appends a six-byte anchor number, checking both integer fields. -/
def encodeEtnaExtraData (sharing : UInt8) (proposal anchor : Nat) :
    Except ExtraDataError (List UInt8) :=
  if proposal < uint48Limit then
    if anchor < uint48Limit then .ok (encodeLegacyExtraData sharing proposal ++ encodeBE 6 anchor)
    else .error .anchorOverflow
  else .error .proposalOverflow

/-- Genesis has anchor zero; non-genesis Etna requires exactly thirteen bytes. -/
def decodeEtnaAnchorBlockNumber (number : Nat) (bs : List UInt8) : Option Nat :=
  if number = 0 then some 0
  else if bs.length = 13 then some (decodeBE (bs.drop 7)) else none

/-- Decode the proposal field of either supported layout. -/
def decodeExtraDataProposal (bs : List UInt8) : Option Nat :=
  if bs.length = 7 ∨ bs.length = 13 then some (decodeBE ((bs.drop 1).take 6)) else none

end TaikoSpec.Derivation
