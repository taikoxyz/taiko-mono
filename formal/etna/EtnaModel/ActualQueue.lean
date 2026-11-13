import EtnaModel.SigningBridge
import EtnaModel.RegistryHistory
import EtnaModel.Consensus
import EtnaModel.BlockValidity

/-! Semantic L1 time and end-block openings supplement the original decoded transition
machine. `states` retains transaction order, including multiple calls in one L1 block.
An opening splits that same journal after every transaction at its block. The primitive
hash/parser/singleton functions below are ideal interfaces, not implementation proofs. -/
namespace Etna.Design.ActualQueue

abbrev Bytes := List UInt8

/-- Ideal complete decoding and deterministic singleton EL execution. The singleton
context is the actual parent/header, without a caller-chosen execution-result field. -/
structure Primitives where
  hashBytes : Bytes → Hash
  canonical : Bytes → Bool
  buildSingleton : BlockValidity.Header → BlockValidity.Header → Bytes → Forced.Singleton

/-- Actual byte decoding and deterministic EL result under the exact local context. -/
def PayloadFields (primitive : Primitives) (parent : BlockValidity.Header)
    (block : BlockValidity.Block) (witness : Forced.Witness) (raw : Bytes) (first : Option Bytes) : Prop :=
  witness.rawBytes = raw.length ∧ witness.rawHash = primitive.hashBytes raw ∧
  witness.canonical = primitive.canonical raw ∧
  witness.firstHash = first.map primitive.hashBytes ∧
  witness.firstCanonical = (first.map primitive.canonical).getD false ∧
  witness.firstBytes = (first.map List.length).getD 0 ∧
  block.singleton = primitive.buildSingleton parent block.header raw

/-- Included canonical position-zero bytes, or hash-bound raw bytes whose canonical parse
fails or whose completed singleton is empty. A timeout/retained singleton is not a skip. -/
def ByteAction (primitive : Primitives) (parent : BlockValidity.Header)
    (block : BlockValidity.Block) (entry : Forced.Entry) (raw : Bytes) (first : Option Bytes) : Prop :=
  (∃ tx, first = some tx ∧ primitive.hashBytes tx = entry.txHash ∧
    primitive.canonical tx = true ∧ tx.length ≤ 8192) ∨
  (primitive.hashBytes raw = entry.txHash ∧ raw.length ≤ 8192 ∧
    (primitive.canonical raw = false ∨ primitive.buildSingleton parent block.header raw = .completedEmpty))

end Etna.Design.ActualQueue
