import TaikoSpec.Bytes

/-!
# RLP

Canonical, exact RLP decoding and the matching encoder. The rules are go-ethereum's `rlp`
package, which alloy-rlp also follows:

* a single byte below `0x80` is its own encoding, so `0x81 0x05` is rejected;
* a long-form length has no leading zero byte and is at least 56;
* a payload never extends past its enclosing list (or the input);
* `decode` rejects bytes left after the top-level item.
-/

namespace TaikoSpec.Rlp

/-- An RLP item: a byte string or a list of items. -/
inductive Item where
  | bytes (b : ByteArray)
  | list (items : List Item)
  deriving Inhabited

/-- Where an item's payload lives: `[start, start + length)`. -/
structure Header where
  isList : Bool
  start : Nat
  length : Nat

/-- A long-form length field of `n` bytes at `pos`: no leading zero byte and at least 56. -/
def longLength (b : ByteArray) (pos n : Nat) : Option Nat :=
  if pos + n ≤ b.size ∧ b.get! pos ≠ 0 then
    let len := beNat (b.extract pos (pos + n))
    if 56 ≤ len then some len else none
  else none

/-- The header of the item whose first byte is at `pos`. -/
def header (b : ByteArray) (pos : Nat) : Option Header :=
  if pos < b.size then
    let p := (b.get! pos).toNat
    if p < 0x80 then some ⟨false, pos, 1⟩
    else if p < 0xb8 then
      -- A one-byte string whose byte is below 0x80 must use the single-byte form.
      if p = 0x81 ∧ pos + 1 < b.size ∧ (b.get! (pos + 1)).toNat < 0x80 then none
      else some ⟨false, pos + 1, p - 0x80⟩
    else if p < 0xc0 then
      (longLength b (pos + 1) (p - 0xb7)).map fun len => ⟨false, pos + 1 + (p - 0xb7), len⟩
    else if p < 0xf8 then some ⟨true, pos + 1, p - 0xc0⟩
    else
      (longLength b (pos + 1) (p - 0xf7)).map fun len => ⟨true, pos + 1 + (p - 0xf7), len⟩
  else none

mutual
/-- Decodes the item at `pos`, which must end at or before `limit`, and returns it with the
position just after it. `fuel` bounds the call depth; `decode` supplies enough of it. -/
def decodeItem (b : ByteArray) : Nat → Nat → Nat → Option (Item × Nat)
  | 0, _, _ => none
  | fuel + 1, pos, limit =>
    if pos < limit then
      match header b pos with
      | none => none
      | some h =>
        if h.start + h.length ≤ limit then
          if h.isList then
            (decodeItems b fuel h.start (h.start + h.length)).map
              fun items => (.list items, h.start + h.length)
          else some (.bytes (b.extract h.start (h.start + h.length)), h.start + h.length)
        else none
    else none

/-- Decodes consecutive items that exactly fill `[pos, stop)`. -/
def decodeItems (b : ByteArray) : Nat → Nat → Nat → Option (List Item)
  | 0, _, _ => none
  | fuel + 1, pos, stop =>
    if pos = stop then some []
    else
      match decodeItem b fuel pos stop with
      | none => none
      | some (item, next) => (decodeItems b fuel next stop).map (item :: ·)
end

/-- Decodes exactly one item that spans all of `b`. Each call on a decoding path advances by at
least one byte every two calls, so `2 * b.size + 2` fuel never runs out on its own. -/
def decode (b : ByteArray) : Option Item :=
  match decodeItem b (2 * b.size + 2) 0 b.size with
  | some (item, next) => if next = b.size then some item else none
  | none => none

/-- The length prefix of a payload of `len` bytes: `offset` is `0x80` for strings, `0xc0` for
lists. -/
def lengthPrefix (offset len : Nat) : ByteArray :=
  if len < 56 then ⟨#[(offset + len).toUInt8]⟩
  else
    let lenBytes := natToMinimalBytes len
    ⟨#[(offset + 55 + lenBytes.size).toUInt8]⟩ ++ lenBytes

mutual
/-- The canonical encoding of an item. -/
def encode : Item → ByteArray
  | .bytes b => if b.size = 1 ∧ (b.get! 0).toNat < 0x80 then b else lengthPrefix 0x80 b.size ++ b
  | .list items =>
    let payload := encodeItems items
    lengthPrefix 0xc0 payload.size ++ payload

/-- The concatenated encodings of a list's items. -/
def encodeItems : List Item → ByteArray
  | [] => ByteArray.empty
  | item :: rest => encode item ++ encodeItems rest
end

namespace Item

/-- A canonical unsigned integer below `2 ^ bits`. The encoding has no leading zero byte, so
zero is the empty string and a lone `0x00` is rejected. -/
def uint? (bits : Nat) : Item → Option Nat
  | .bytes b =>
    if b.size > 0 ∧ b.get! 0 = 0 then none
    else
      let v := beNat b
      if v < 2 ^ bits then some v else none
  | .list _ => none

/-- Any byte string. -/
def bytes? : Item → Option ByteArray
  | .bytes b => some b
  | .list _ => none

/-- A byte string of exactly `n` bytes. -/
def bytesN? (n : Nat) : Item → Option ByteArray
  | .bytes b => if b.size = n then some b else none
  | .list _ => none

end Item

end TaikoSpec.Rlp
