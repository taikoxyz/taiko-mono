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

end Etna.Design.BlockValidity
