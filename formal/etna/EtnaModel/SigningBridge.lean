import EtnaModel.RegistryHistory
import EtnaModel.Consensus
import EtnaModel.BlockValidity
import EtnaModel.Signer

/-! Typed signer inputs. The adapters bind these fields to actual L1/EL data, Comet requests,
canonical sign bytes and the immutable device key. Own-finalized truth and the request
engine's membership discipline remain adapter obligations. `Protocol.execute` checks the
requested height against the durable application boundary. -/
namespace Etna.Design.SigningBridge

inductive SignPhase | proposalMsg | prevoteMsg | precommitMsg
  deriving DecidableEq, Repr

def phaseStep : SignPhase → Nat
  | .proposalMsg => 1
  | .prevoteMsg => 2
  | .precommitMsg => 3

/-- blockId zero represents a nil vote. Retained candidates use their original block id;
all phases are bound to the same domain/generation/height/round as the actual request. -/
structure SignMessage where
  domain : Domain
  generation : Nat
  height : Nat
  round : Nat
  phase : SignPhase
  blockId : Hash
  deriving DecidableEq, Repr

def messageRequest (encode : SignMessage → Hash) (m : SignMessage) (trusted : Bool) : Signer.Request :=
  ⟨m.domain,m.generation,trusted,⟨m.height,m.round,phaseStep m.phase⟩,encode m⟩

end Etna.Design.SigningBridge
