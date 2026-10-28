import EtnaModel.Consensus
import EtnaModel.Landing
import EtnaModel.Forced
import EtnaModel.Encoding

/-! Decoded guest-side block validity (sections 3, 4, 6.2, 7). Named input relations
cover L1/MPT authentication, byte/hash bindings, signatures and complete EL/singleton
execution. They are not proved by this model. The node-only local checkpoint comparison
is a separate relation; it must not silently strengthen the guest's acceptance rules. -/
namespace Etna.Design.BlockValidity
open Consensus

structure Anchor where
  number : Nat
  timestamp : Nat
  stateRoot : Hash
  checkpointHeight : Nat
  checkpointHash : Hash
  generation : Nat
  tail : Nat
  deriving DecidableEq, Repr

structure Header where
  height : Nat
  elHash : Hash
  stateRoot : Hash
  cometHash : Hash
  cursor : Nat
  timestamp : Nat
  anchor : Anchor
  deriving DecidableEq, Repr

def Header.cut (h : Header) : Cut := ⟨h.elHash,h.cometHash,h.cursor⟩

structure CommitteeWitness where
  record : Committee.Record
  root : Hash
  deriving DecidableEq, Repr

structure Block where
  header : Header
  parentHash : Hash
  lastBlockId : Option Hash
  domain : Domain
  generation : Nat
  bftTime : Nat
  feeShare : Nat
  blockBytes : Nat
  anchorWitness : Bool
  committeeWitness : Option CommitteeWitness
  validatorsHash : Hash
  nextValidatorsHash : Hash
  parentBeaconRoot : Hash
  round : Nat
  votes : List Vote
  forced : Option Forced.Witness
  singleton : Forced.Singleton
  deriving DecidableEq, Repr

structure Rules where
  consensus : Context
  gridK : Nat
  committeeConfig : Hash
  maxAnchorAge : Nat
  forcedDelay : Nat
  unsettled : Nat
  referenceNumber : Nat
  referenceHash : Hash
  committeeHash : Committee.Record → Hash
  signature : Vote → Prop
  /-- Header/storage authentication on the ancestry ending at this reference. -/
  anchorAuthenticated : Anchor → Bool
  /-- Complete latest-at-cutoff registry opening under the switch block's own root. -/
  committeeAuthenticated : Hash → Committee.Record → Bool
  /-- All EL header/body/zk-gas rules not separately decoded below. -/
  executionValid : Header → Block → Bool
  /-- Envelope/data_hash/blob equality, FI tx0/raw parsing and singleton context/result. -/
  payloadValid : Block → Bool
  /-- Entry storage is authenticated under this block's anchor, not another root. -/
  forcedAuthenticated : Anchor → Forced.Witness → Bool
  /-- Full-range payload decodes from exactly these statement blob hashes. -/
  batchPayloadValid : List Hash → List Block → Bool
  /-- Abstract hash of the exact seven config words; real hashing remains external. -/
  configHash : List Encoding.Word → Hash
  /-- Authenticated fixed origin, genesis schedule and historical registry/anchor lookup. -/
  historyAuthenticated : Context → Nat → Bool

/-- Parent links and the generation's first empty Comet LastBlockID. -/
def HeaderValid (r : Rules) (p : Header) (b : Block) : Prop :=
  b.header.height = p.height+1 ∧ b.parentHash = p.elHash ∧
  b.lastBlockId = (if p.height = r.consensus.originHeight then none else some p.cometHash) ∧
  b.domain = r.consensus.domain ∧ b.generation = r.consensus.generation ∧
  b.header.height < limit48 ∧ b.header.timestamp < limit256 ∧
  b.header.timestamp = max (max (p.timestamp+1) b.bftTime) b.header.anchor.timestamp ∧
  b.feeShare = 100 ∧ b.blockBytes ≤ 124000 ∧
  b.parentBeaconRoot = b.header.anchor.stateRoot ∧
  b.validatorsHash = r.committeeHash (activeAt r.consensus b.header.height) ∧
  b.nextValidatorsHash = r.committeeHash (activeAt r.consensus (b.header.height+1))

/-- The parent's anchor is the authenticated history value at its height (`anchorAt` is the
anchor-number archive of authenticated EL headers), including the batch's proof origin p:
otherwise a prover could pick p's anchor to drop the next block's witness or its floor. -/
def AnchorValid (r : Rules) (p : Header) (b : Block) : Prop :=
  p.anchor.number ≤ b.header.anchor.number ∧ r.consensus.originBlock ≤ b.header.anchor.number ∧
  b.header.anchor.number ≤ r.referenceNumber ∧ b.header.anchor.number < limit48 ∧
  b.header.anchor.generation = r.consensus.generation ∧
  b.header.anchor.timestamp ≤ b.header.timestamp ∧
  b.header.timestamp-b.header.anchor.timestamp ≤ r.maxAnchorAge ∧
  b.header.height-b.header.anchor.checkpointHeight ≤ r.unsettled ∧
  r.consensus.anchorAt b.header.height = b.header.anchor.number ∧
  r.consensus.anchorAt p.height = p.anchor.number ∧
  b.anchorWitness = decide (p.height = r.consensus.originHeight ∨ p.anchor.number ≠ b.header.anchor.number) ∧
  (p.anchor.number = b.header.anchor.number → p.anchor = b.header.anchor) ∧
  r.anchorAuthenticated b.header.anchor = true

/-- A switch witness is required exactly at S(t), with the D(t) cutoff and S(t) root. -/
def WitnessValid (r : Rules) (b : Block) : Prop :=
  if (b.header.height+1) % r.consensus.epochLen = 0 then
    match b.committeeWitness with
    | none => False
    | some w => w.record = normal r.consensus ((b.header.height+1)/r.consensus.epochLen) ∧
        w.root = b.header.anchor.stateRoot ∧ w.record.cutoff ≤ b.header.anchor.number ∧
        r.committeeAuthenticated w.root w.record = true ∧
        ElectionValid r.consensus w.record
  else b.committeeWitness = none

def ExternalValid (r : Rules) (p : Header) (b : Block) : Prop :=
  r.executionValid p b = true ∧ r.payloadValid b = true ∧
  (match b.forced with | none => True | some w => r.forcedAuthenticated b.header.anchor w = true) ∧
  r.committeeConfig = r.configHash (Encoding.configWords r.consensus.domain.l2ChainId
    r.consensus.domain.registry r.consensus.unit r.consensus.minimum r.consensus.nMax r.unsettled) ∧
  r.historyAuthenticated r.consensus r.referenceNumber = true

/-- Configuration, decoded rules, scheduled commit, per-block FI consumption and the
named external relations must all hold; a resource timeout is not an accepted block. -/
def Valid (r : Rules) (p : Header) (b : Block) : Prop :=
  Committee.configOK r.gridK r.consensus.epochLen r.unsettled = true ∧
  r.consensus.originHeight ≤ p.height ∧ HeaderValid r p b ∧ AnchorValid r p b ∧
  WitnessValid r b ∧ Consensus.CommitValid r.consensus r.signature b.header.height b.round b.header.cometHash b.votes ∧
  Forced.step p.cursor b.header.anchor.tail b.header.anchor.timestamp r.forcedDelay b.forced b.singleton =
    .accepted b.header.cursor ∧ ExternalValid r p b

instance (r : Rules) (p : Header) (b : Block) : Decidable (HeaderValid r p b) :=
  inferInstanceAs (Decidable (_ ∧ _))
instance (r : Rules) (p : Header) (b : Block) : Decidable (AnchorValid r p b) :=
  inferInstanceAs (Decidable (_ ∧ _))
instance (r : Rules) (b : Block) : Decidable (WitnessValid r b) := by
  unfold WitnessValid
  split
  · cases b.committeeWitness <;> dsimp <;> infer_instance
  · infer_instance
instance (r : Rules) (p : Header) (b : Block) : Decidable (ExternalValid r p b) := by
  unfold ExternalValid
  cases b.forced <;> dsimp <;> infer_instance
instance (r : Rules) [DecidablePred r.signature] (p : Header) (b : Block) : Decidable (Valid r p b) :=
  inferInstanceAs (Decidable (_ ∧ _))

/-- Local node checks add own-finalized-L1 authentication and the local checkpoint fence.
They are deliberately not an assumption of guest cut-table composition. -/
def NodeValid (r : Rules) (localHash : Nat → Hash) (ownFinalized : Anchor → Prop)
    (p : Header) (b : Block) : Prop :=
  Valid r p b ∧ ownFinalized b.header.anchor ∧ b.header.anchor.checkpointHeight ≤ p.height ∧
  b.header.anchor.checkpointHash = localHash b.header.anchor.checkpointHeight

def Chain (r : Rules) : Header → List Block → Prop
  | _, [] => True
  | p, b :: rest => Valid r p b ∧ Chain r b.header rest

def chainDecidable (r : Rules) [DecidablePred r.signature] (p : Header) :
    (bs : List Block) → Decidable (Chain r p bs)
  | [] => isTrue True.intro
  | b :: rest => @instDecidableAnd _ _ (inferInstance) (chainDecidable r b.header rest)

instance (r : Rules) [DecidablePred r.signature] (p : Header) (bs : List Block) : Decidable (Chain r p bs) :=
  chainDecidable r p bs

def terminal : Header → List Block → Header
  | p, [] => p
  | _, b :: rest => terminal b.header rest

def cuts (p : Header) (bs : List Block) : List Cut := p.cut :: bs.map (fun b => b.header.cut)

end Etna.Design.BlockValidity
