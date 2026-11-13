import EtnaModel.RegistryHistory
import EtnaModel.Consensus
import EtnaModel.BlockValidity
import EtnaModel.Signer

/-! Typed refinement of the existing signer and node inputs. No signer/contract guard is
changed. A verified adapter must bind these fields to actual L1/EL data, Comet requests,
canonical sign bytes and the immutable device key. In particular, own-finalized truth
and the request engine's membership/next-height discipline are explicit boundaries.
No key exclusion, positive collateral or selected-cutoff inequality is a field. -/
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
