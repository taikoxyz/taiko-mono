/-!
# Byte helpers

Big-endian integer conversion and hex encoding over `ByteArray`, shared by the codecs and
the vector runner.
-/

namespace TaikoSpec

/-- The big-endian unsigned integer encoded by `b` (zero for the empty string). -/
def beNat (b : ByteArray) : Nat :=
  b.toList.foldl (fun acc x => acc * 256 + x.toNat) 0

/-- The minimal big-endian encoding of `n`: no leading zero bytes, empty for zero. -/
def natToMinimalBytes (n : Nat) : ByteArray :=
  (go n []).toByteArray
where
  go (n : Nat) (acc : List UInt8) : List UInt8 :=
    if n = 0 then acc else go (n / 256) ((n % 256).toUInt8 :: acc)
  termination_by n
  decreasing_by omega

/-- The value of one hex digit, if `c` is a hex digit. -/
def hexDigit? (c : Char) : Option Nat :=
  if '0' ≤ c ∧ c ≤ '9' then some (c.toNat - '0'.toNat)
  else if 'a' ≤ c ∧ c ≤ 'f' then some (c.toNat - 'a'.toNat + 10)
  else if 'A' ≤ c ∧ c ≤ 'F' then some (c.toNat - 'A'.toNat + 10)
  else none

/-- Decodes a hex string without a `0x` prefix; fails on odd length or a non-hex character. -/
def fromHex? (s : String) : Option ByteArray :=
  go s.toList ByteArray.empty
where
  go : List Char → ByteArray → Option ByteArray
    | [], acc => some acc
    | hi :: lo :: rest, acc => do
      let h ← hexDigit? hi
      let l ← hexDigit? lo
      go rest (acc.push (h * 16 + l).toUInt8)
    | [_], _ => none

/-- Lowercase hex encoding without a `0x` prefix. -/
def toHex (b : ByteArray) : String :=
  b.toList.foldl (fun s x => s ++ digit (x.toNat / 16) ++ digit (x.toNat % 16)) ""
where
  digit (n : Nat) : String := String.ofList (Nat.toDigits 16 n)

end TaikoSpec
