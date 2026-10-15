import TaikoSpec.Deflate

/-!
# zlib (RFC 1950)

The zlib container around DEFLATE, as Go 1.26 `zlib.NewReader` reads it: the first complete
stream counts and anything after its Adler-32 trailer is ignored.
-/

namespace TaikoSpec.Zlib

/-- Adler-32 (RFC 1950 §8.2). -/
def adler32 (b : ByteArray) : Nat :=
  let (a, s) := b.foldl (fun (a, s) x =>
    let a := (a + x.toNat) % 65521
    (a, (s + a) % 65521)) (1, 0)
  s * 65536 + a

/-- Decompresses the first zlib stream in `input`:

* the header has CM = 8, CINFO ≤ 7, and `CMF · 256 + FLG` divisible by 31;
* if FDICT is set, the dictionary must be the empty one, whose Adler-32 (DICTID) is 1;
* the DEFLATE data must end with a final block;
* the next four bytes are the big-endian Adler-32 of the output.

A stream cut short anywhere fails. Bytes after the trailer are ignored. -/
def decompress (input : ByteArray) : Option ByteArray := do
  guard (2 ≤ input.size)
  let cmf := (input.get! 0).toNat
  let flg := (input.get! 1).toNat
  guard (cmf % 16 = 8 ∧ cmf / 16 ≤ 7 ∧ (cmf * 256 + flg) % 31 = 0)
  let start ← if flg / 32 % 2 = 1 then
      if 6 ≤ input.size ∧ beNat (input.extract 2 6) = 1 then some 6 else none
    else some 2
  let (out, next) ← Deflate.inflate input start
  guard (next + 4 ≤ input.size ∧ beNat (input.extract next (next + 4)) = adler32 out)
  pure out

end TaikoSpec.Zlib
