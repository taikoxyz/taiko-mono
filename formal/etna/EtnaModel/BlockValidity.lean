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
  /-- Validator-state hash after committing this height (appendix A valStateHash), an opaque
  atom. At a generation's origin the model reads it as the origin record's stored value: the
  record there need not hold this generation's validator state (PROOF-6.2-40, SYNC-9-5), and
  without CometBFT's state-update arithmetic (PROOF-6.2-41a, deferred) the origin's own
  validator state is never an input to a later block. -/
  valStateHash : Hash
  deriving DecidableEq, Repr

def Header.cut (h : Header) : Cut := ⟨h.elHash,h.cometHash,h.cursor,h.valStateHash⟩

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
