import TaikoSpec.Bytes

/-!
# DEFLATE (RFC 1951)

A reference decoder that accepts and rejects exactly what Go 1.26 `compress/flate` does. Go is
the reference decoder for Taiko manifests. The rules that matter for consensus:

* block type 3 is invalid;
* a stored block's `NLEN` must be the one's complement of `LEN`;
* a dynamic block declares at most 286 literal/length codes and at most 30 distance codes;
* the code-length repeat code 16 cannot come first, and no repeat may run past the declared
  number of code lengths;
* every Huffman code is complete, except that an empty code and a code with a single symbol of
  length 1 are allowed (reading an unused bit pattern then fails);
* literal/length symbols 286 and 287 and distance symbols 30 and 31 are invalid;
* a distance never reaches before the start of the output;
* running out of input anywhere is a failure.

Codes are decoded one bit at a time, as in zlib's `puff.c`. For a valid stream this consumes
exactly the bits Go consumes, so the stream ends on the same byte.
-/

namespace TaikoSpec.Deflate

/-- A read position in the input, counted in bits. Bits are taken least-significant first. -/
structure Bits where
  data : ByteArray
  pos : Nat

namespace Bits

/-- Reads one bit. -/
def bit (s : Bits) : Option (Nat × Bits) :=
  if s.pos / 8 < s.data.size then
    some ((s.data.get! (s.pos / 8)).toNat / 2 ^ (s.pos % 8) % 2, { s with pos := s.pos + 1 })
  else none

/-- Reads an `n`-bit field whose first bit is the least significant. -/
def read : Bits → Nat → Option (Nat × Bits)
  | s, 0 => some (0, s)
  | s, n + 1 => do
    let (b, s) ← s.bit
    let (rest, s) ← read s n
    pure (b + 2 * rest, s)

/-- The index of the first byte not touched yet, i.e. the next byte boundary. -/
def nextByte (s : Bits) : Nat := (s.pos + 7) / 8

end Bits

/-- A canonical Huffman code in the form `puff.c` uses: the number of codes of each length
(`counts[len]` for `len` in `1..15`) and the symbols ordered by code length, then by symbol. -/
structure Huffman where
  counts : Array Nat
  symbols : Array Nat

namespace Huffman

/-- Builds the canonical code for per-symbol code lengths (0 marks an unused symbol). The code
must be complete, i.e. `Σ counts[len] · 2^(15 - len) = 2^15`, except that an empty code and a
single code of length 1 are accepted, as in Go's `huffmanDecoder.init`. -/
def build (lengths : Array Nat) : Option Huffman :=
  let counts := (List.range 16).map fun len => (lengths.toList.filter (· == len)).length
  let maxLen := lengths.foldl max 0
  let kraft := (List.range 16).foldl
    (fun acc len => if len = 0 then acc else acc + counts[len]! * 2 ^ (15 - len)) 0
  if maxLen = 0 ∨ kraft = 2 ^ 15 ∨ (maxLen = 1 ∧ counts[1]! = 1) then
    let symbols := (List.range 16).flatMap fun len =>
      if len = 0 then [] else (List.range lengths.size).filter fun sym => lengths[sym]! == len
    some ⟨counts.toArray, symbols.toArray⟩
  else none

/-- Decodes one symbol. Huffman codes are read most-significant bit first (RFC 1951 §3.1.1). -/
def decode (h : Huffman) (s : Bits) : Option (Nat × Bits) :=
  go 1 0 0 0 s
where
  /-- `code` holds the bits read so far, `first` is the first code of length `len` and `index`
  is the position of that code's symbol in `symbols`. -/
  go (len code first index : Nat) (s : Bits) : Option (Nat × Bits) :=
    if _h : len ≤ 15 then
      match s.bit with
      | none => none
      | some (b, s) =>
        let code := code + b
        let count := h.counts[len]!
        if code < first + count then some (h.symbols[index + (code - first)]!, s)
        else go (len + 1) (2 * code) (2 * (first + count)) (index + count) s
    else none
  termination_by 16 - len

end Huffman

/-- Base lengths for literal/length symbols 257..285 (RFC 1951 §3.2.5). -/
def lengthBase : Array Nat :=
  #[3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115,
    131, 163, 195, 227, 258]

/-- Extra bits for literal/length symbols 257..285. -/
def lengthExtra : Array Nat :=
  #[0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0]

/-- Base distances for distance symbols 0..29. -/
def distBase : Array Nat :=
  #[1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537,
    2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577]

/-- Extra bits for distance symbols 0..29. -/
def distExtra : Array Nat :=
  #[0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12,
    13, 13]

/-- Code lengths of the fixed literal/length code (RFC 1951 §3.2.6), including the invalid
symbols 286 and 287. -/
def fixedLitLengths : Array Nat :=
  Array.replicate 144 8 ++ Array.replicate 112 9 ++ Array.replicate 24 7 ++ Array.replicate 8 8

/-- The fixed distance code: 32 five-bit codes, of which 30 and 31 are invalid symbols. -/
def fixedDistLengths : Array Nat := Array.replicate 32 5

/-- Appends `len` bytes copied from `dist` bytes back; the copy may overlap its own output. -/
def copyBack (out : ByteArray) (dist : Nat) : Nat → ByteArray
  | 0 => out
  | n + 1 => copyBack (out.push (out.get! (out.size - dist))) dist n

/-- A stored block: skip to the next byte boundary, read `LEN` and `NLEN` (little-endian) and
copy `LEN` raw bytes. -/
def stored (s : Bits) (out : ByteArray) : Option (ByteArray × Bits) :=
  let p := s.nextByte
  if p + 4 ≤ s.data.size then
    let len := (s.data.get! p).toNat + 256 * (s.data.get! (p + 1)).toNat
    let nlen := (s.data.get! (p + 2)).toNat + 256 * (s.data.get! (p + 3)).toNat
    if nlen = 65535 - len ∧ p + 4 + len ≤ s.data.size then
      some (out ++ s.data.extract (p + 4) (p + 4 + len), { s with pos := 8 * (p + 4 + len) })
    else none
  else none

/-- Decodes literal/length and distance symbols until the end-of-block symbol 256. Every symbol
consumes at least one bit, so `fuel` of one per input bit never runs out on its own. -/
def codes (lit dist : Huffman) : Nat → Bits → ByteArray → Option (ByteArray × Bits)
  | 0, _, _ => none
  | fuel + 1, s, out => do
    let (sym, s) ← lit.decode s
    if sym < 256 then codes lit dist fuel s (out.push sym.toUInt8)
    else if sym = 256 then pure (out, s)
    else
      guard (sym < 286)
      let (extra, s) ← s.read lengthExtra[sym - 257]!
      let (dsym, s) ← dist.decode s
      guard (dsym < 30)
      let (dextra, s) ← s.read distExtra[dsym]!
      let d := distBase[dsym]! + dextra
      guard (d ≤ out.size)
      codes lit dist fuel s (copyBack out d (lengthBase[sym - 257]! + extra))

/-- The order in which a dynamic block stores the code-length code's lengths
(RFC 1951 §3.2.7). -/
def codeLengthOrder : List Nat :=
  [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]

/-- Reads the 3-bit lengths of the code-length code for the first `count` symbols in
`codeLengthOrder`; the remaining symbols get length 0. -/
def readCodeLengthLengths (count : Nat) (s : Bits) : Option (Array Nat × Bits) :=
  go (codeLengthOrder.take count) s (Array.replicate 19 0)
where
  go : List Nat → Bits → Array Nat → Option (Array Nat × Bits)
    | [], s, acc => some (acc, s)
    | sym :: rest, s, acc => do
      let (len, s) ← s.read 3
      go rest s (acc.set! sym len)

/-- Reads `n` literal/length and distance code lengths with the code-length code `clc`,
expanding the repeat codes 16 (previous length), 17 and 18 (zeros). -/
def readLengths (clc : Huffman) (n : Nat) : Nat → Bits → Array Nat → Option (Array Nat × Bits)
  | 0, _, _ => none
  | fuel + 1, s, acc =>
    if acc.size = n then some (acc, s)
    else do
      let (sym, s) ← clc.decode s
      if sym < 16 then readLengths clc n fuel s (acc.push sym)
      else
        let (value, rep, s) ← match sym with
          | 16 => do
            guard (0 < acc.size)
            let (r, s) ← s.read 2
            pure (acc.back!, 3 + r, s)
          | 17 => do
            let (r, s) ← s.read 3
            pure (0, 3 + r, s)
          | _ => do
            let (r, s) ← s.read 7
            pure (0, 11 + r, s)
        guard (acc.size + rep ≤ n)
        readLengths clc n fuel s (acc ++ Array.replicate rep value)

/-- The header of a dynamic block: the literal/length code and the distance code. -/
def dynamic (s : Bits) : Option (Huffman × Huffman × Bits) := do
  let (hlit, s) ← s.read 5
  let (hdist, s) ← s.read 5
  let (hclen, s) ← s.read 4
  let nlit := hlit + 257
  let ndist := hdist + 1
  guard (nlit ≤ 286 ∧ ndist ≤ 30)
  let (codeLengthLengths, s) ← readCodeLengthLengths (hclen + 4) s
  let clc ← Huffman.build codeLengthLengths
  let (lens, s) ← readLengths clc (nlit + ndist) (nlit + ndist + 1) s #[]
  let lit ← Huffman.build (lens.extract 0 nlit)
  let dist ← Huffman.build (lens.extract nlit (nlit + ndist))
  pure (lit, dist, s)

/-- Decodes blocks until the one marked final. -/
def blocks : Nat → Bits → ByteArray → Option (ByteArray × Bits)
  | 0, _, _ => none
  | fuel + 1, s, out => do
    let (final, s) ← s.read 1
    let (type, s) ← s.read 2
    let symbolFuel := 8 * s.data.size + 1
    let (out, s) ← match type with
      | 0 => stored s out
      | 1 => do
        let lit ← Huffman.build fixedLitLengths
        let dist ← Huffman.build fixedDistLengths
        codes lit dist symbolFuel s out
      | 2 => do
        let (lit, dist, s) ← dynamic s
        codes lit dist symbolFuel s out
      | _ => none
    if final = 1 then pure (out, s) else blocks fuel s out

/-- Inflates the DEFLATE stream that starts at byte `start`. Returns the output and the index of
the first byte after the stream. -/
def inflate (data : ByteArray) (start : Nat) : Option (ByteArray × Nat) :=
  (blocks (8 * data.size + 1) ⟨data, 8 * start⟩ ByteArray.empty).map
    fun (out, s) => (out, s.nextByte)

end TaikoSpec.Deflate
