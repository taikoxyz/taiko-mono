import TaikoSpec.Rlp

/-!
# Transaction grammar

Which transaction encodings a manifest block may carry. The grammar is go-ethereum's
structural decoding plus the width checks of the Go driver's `validateTransactionEncoding`,
which together equal alloy's grammar. Signer recovery and chain-ID correctness are deliberately
not checked; the execution engine decides those.

A transaction item is either

* an RLP list, which is decoded only as a legacy transaction, or
* an RLP string holding one typed transaction: a type byte in `1..4` followed by exactly one
  RLP list of that type's fields.
-/

namespace TaikoSpec.Tx

open TaikoSpec.Rlp

/-- A field schema accepts or rejects one RLP item. -/
abbrev Field := Item → Bool

/-- A canonical unsigned integer below `2 ^ bits`. -/
def uint (bits : Nat) : Field := fun i => (i.uint? bits).isSome

/-- Any byte string. -/
def bytes : Field := fun i => i.bytes?.isSome

/-- A byte string of exactly `n` bytes. -/
def bytesN (n : Nat) : Field := fun i => (i.bytesN? n).isSome

/-- A 20-byte address. -/
def address : Field := bytesN 20

/-- A recipient: an address, or the empty string for contract creation. -/
def optAddress : Field := fun i => bytesN 0 i || address i

/-- A list whose every element satisfies `f`. -/
def listOf (f : Field) : Field
  | .list items => items.all f
  | .bytes _ => false

/-- A list with exactly one element per schema, each satisfying its schema. -/
def tuple (fs : List Field) : Field
  | .list items => items.length == fs.length && (fs.zip items).all fun (f, i) => f i
  | .bytes _ => false

/-- EIP-2930 access list: `[[address, [storageKey₃₂, …]], …]`. -/
def accessList : Field := listOf (tuple [address, listOf (bytesN 32)])

/-- EIP-7702 authorization list: `[[chainId, address, nonce, yParity, r, s], …]`. -/
def authorizationList : Field :=
  listOf (tuple [uint 256, address, uint 64, uint 8, uint 256, uint 256])

/-- Legacy `v`: 27 or 28, or an EIP-155 value `35 + 2 · chainId + parity` with `chainId < 2^64`. -/
def legacyV : Field := fun i =>
  match i.uint? 256 with
  | some v => v = 27 || v = 28 || (35 ≤ v && (v - 35) / 2 < 2 ^ 64)
  | none => false

/-- Legacy: `[nonce, gasPrice, gas, to, value, data, v, r, s]`. -/
def legacy : Field :=
  tuple [uint 64, uint 128, uint 64, optAddress, uint 256, bytes, legacyV, uint 256, uint 256]

/-- EIP-2930 (type 1):
`[chainId, nonce, gasPrice, gas, to, value, data, accessList, yParity, r, s]`. -/
def accessListTx : Field :=
  tuple [uint 64, uint 64, uint 128, uint 64, optAddress, uint 256, bytes, accessList,
    uint 1, uint 256, uint 256]

/-- EIP-1559 (type 2): `[chainId, nonce, maxPriorityFeePerGas, maxFeePerGas, gas, to, value,
data, accessList, yParity, r, s]`. -/
def dynamicFeeTx : Field :=
  tuple [uint 64, uint 64, uint 128, uint 128, uint 64, optAddress, uint 256, bytes, accessList,
    uint 1, uint 256, uint 256]

/-- EIP-4844 (type 3), canonical form only: `[chainId, nonce, maxPriorityFeePerGas,
maxFeePerGas, gas, to, value, data, accessList, maxFeePerBlobGas, blobVersionedHashes, yParity,
r, s]`. The network form wraps this list in another list, so its first field is a list and it
fails here. -/
def blobTx : Field :=
  tuple [uint 64, uint 64, uint 128, uint 128, uint 64, address, uint 256, bytes, accessList,
    uint 128, listOf (bytesN 32), uint 1, uint 256, uint 256]

/-- EIP-7702 (type 4): `[chainId, nonce, maxPriorityFeePerGas, maxFeePerGas, gas, to, value,
data, accessList, authorizationList, yParity, r, s]`. -/
def setCodeTx : Field :=
  tuple [uint 64, uint 64, uint 128, uint 128, uint 64, address, uint 256, bytes, accessList,
    authorizationList, uint 1, uint 256, uint 256]

/-- The field schema for a typed transaction's type byte. -/
def typedSchema : Nat → Option Field
  | 1 => some accessListTx
  | 2 => some dynamicFeeTx
  | 3 => some blobTx
  | 4 => some setCodeTx
  | _ => none

/-- Whether one transaction item inside a manifest block is well formed. -/
def wellFormed : Item → Bool
  | .list items => legacy (.list items)
  | .bytes b =>
    2 ≤ b.size &&
      match typedSchema (b.get! 0).toNat, Rlp.decode (b.extract 1 b.size) with
      | some schema, some payload => schema payload
      | _, _ => false

end TaikoSpec.Tx
