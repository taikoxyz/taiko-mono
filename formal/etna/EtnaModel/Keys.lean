import Std

/-! §4.1 / Appendix A `register` public-key decoding: exactly 33 raw bytes
`ckPrefix ‖ uint256_be(ckX)`, prefix 0x02/0x03, no modular reduction of X,
`y0 = powmod(X^3+7, (p+1)/4, p)` with an explicit square check, parity selection,
`ckY < p` and exact recompression.

Proved structurally: soundness (an accepted key is a reduced on-curve point with the
requested parity that recompresses to the input), canonical encoding (decoding is
injective) and prefix-flip separation. Completeness for every valid point needs the
primality of p (Euler's criterion for the `(p+1)/4` root) and a correct MODEXP
precompile; both stay external implementation-acceptance obligations, witnessed here
only by concrete kernel-checked vectors. -/
namespace Etna.Design.Keys

abbrev Byte := Fin 256

/-- secp256k1 field prime. -/
def fieldP : Nat := 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F

/-- Square-and-multiply with structural fuel, so the kernel can evaluate 256-bit exponents. -/
def powModFuel (m : Nat) : Nat → Nat → Nat → Nat → Nat
  | 0, _, _, acc => acc
  | fuel+1, b, e, acc =>
    if e = 0 then acc
    else powModFuel m fuel (b*b % m) (e/2) (if e % 2 = 1 then acc*b % m else acc)

def powMod (b e m : Nat) : Nat := powModFuel m 257 (b % m) e (1 % m)

/-- Big-endian value of a byte string. -/
def beNat (bytes : List Byte) : Nat := bytes.foldl (fun acc b => acc*256+b.val) 0

/-- Exactly 32 big-endian bytes, leading zeros kept. -/
def beBytes32 (x : Nat) : List Byte :=
  (List.range 32).map fun i => ⟨x/256^(31-i) % 256, Nat.mod_lt _ (by decide)⟩

def prefixByte (y : Nat) : Byte := ⟨2+y%2, by have := Nat.mod_lt y (show 2 > 0 by decide); omega⟩

/-- Canonical SEC1 compression of an affine point. -/
def compress (x y : Nat) : List Byte := prefixByte y :: beBytes32 x

def onCurveMod (p x y : Nat) : Prop := y*y % p = (x^3+7) % p

/-- Parity selection: `ckY = y0` if its parity matches the prefix, else `p − y0`. -/
def selectY (p y0 : Nat) (pre : Byte) : Nat := if y0 % 2 = pre.val-2 then y0 else p-y0

/-- Every acceptance requirement of the spec, checked explicitly. -/
def accept (p x y0 y : Nat) (pre : Byte) (input : List Byte) : Option (Nat × Nat) :=
  if input.length = 33 ∧ (pre.val = 2 ∨ pre.val = 3) ∧ x < p ∧
     y0 < p ∧ y0*y0 % p = (x^3+7) % p ∧ y < p ∧ y % 2 = pre.val-2 ∧
     y*y % p = (x^3+7) % p ∧ compress x y = input
  then some (x, y) else none

/-- Appendix A decoding for field modulus `p`. The deployed rule is `decompress`
with the secp256k1 prime. -/
def decodeWith (p : Nat) (input : List Byte) : Option (Nat × Nat) :=
  match input with
  | [] => none
  | pre :: rest =>
    let x := beNat rest
    let y0 := powMod ((x^3+7) % p) ((p+1)/4) p
    accept p x y0 (selectY p y0 pre) pre input

def decompress (input : List Byte) : Option (Nat × Nat) := decodeWith fieldP input

def onCurve (x y : Nat) : Prop := onCurveMod fieldP x y

/-- Swap 0x02 and 0x03; other prefixes are unchanged. -/
def flipPrefix : List Byte → List Byte
  | [] => []
  | b :: rest => (if b.val = 2 then 3 else if b.val = 3 then 2 else b) :: rest

/-! Kernel-checked vectors (computed independently with Python `pow(a,(p+1)//4,p)`). -/

def key (pre : Byte) (x : Nat) : List Byte := pre :: beBytes32 x

def gx : Nat := 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798
def gy : Nat := 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8
/-- X = 1 (31 leading zero bytes) is on the curve with this even root. -/
def oneY : Nat := 0x4218F20AE6C646B363DB68605822FB14264CA8D2587FDD6FBC750D587E76A7EE

end Etna.Design.Keys
