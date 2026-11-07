import EtnaModel.Common

/-! 8.2 recovery signer: stock HRS state kept per full chain_id (which includes the
generation), persisted before a signature is returned, never reset or rolled back; a new
generation signs only after its recovery is authenticated from finalized L1. Primary/backup
fencing is operational practice and not part of the model. -/
namespace Etna.Design.Signer

structure HRS where
  height : Nat
  round : Nat
  step : Nat
  deriving DecidableEq, Repr

def before (a b : HRS) : Bool := decide
  (a.height < b.height ∨ (a.height = b.height ∧ a.round < b.round) ∨
    (a.height = b.height ∧ a.round = b.round ∧ a.step < b.step))

structure Signed where
  generation : Nat
  position : HRS
  bytes : Hash
  signature : Hash
  deriving DecidableEq, Repr

structure State where
  domain : Domain
  activeGeneration : Nat
  startHeight : Nat
  retired : List Nat
  ready : Bool
  log : List Signed
  deriving DecidableEq, Repr

structure Request where
  domain : Domain
  generation : Nat
  trusted : Bool
  position : HRS
  bytes : Hash
  deriving DecidableEq, Repr

def latest (s : State) (generation : Nat) : Option Signed :=
  s.log.find? (fun r => r.generation == generation)

def authorized (s : State) (r : Request) : Bool :=
  s.ready && r.trusted && decide (r.domain = s.domain ∧ r.generation = s.activeGeneration ∧
    r.generation ∉ s.retired ∧ s.startHeight ≤ r.position.height)

/-- The persistence flag represents a committed linearizable log write before a signature
is returned. Stock timestamp-equivalent retries are normalized by the signing adapter. -/
def sign (s : State) (r : Request) (signature : Hash) (persisted : Bool) : Option (State × Hash) :=
  if authorized s r then
    match latest s r.generation with
    | some old =>
      if old.position = r.position then
        if old.bytes = r.bytes then some (s,old.signature) else none
      else if before old.position r.position && persisted then
        some ({ s with log := ⟨r.generation,r.position,r.bytes,signature⟩ :: s.log },signature)
      else none
    | none => if persisted then
        some ({ s with log := ⟨r.generation,r.position,r.bytes,signature⟩ :: s.log },signature)
      else none
  else none

/-- Only an authenticated finalized-L1 recovery decision can retire/install a domain.
An uncertain persistence result closes signing; no local FilePV fallback exists. -/
def switchDomain (s : State) (domain : Domain) (generation start : Nat)
    (finalizedAuthenticated persisted : Bool) : State :=
  if finalizedAuthenticated && persisted && decide (domain = s.domain ∧
    s.activeGeneration < generation ∧ generation < limit48 ∧ generation ∉ s.retired) then
    { s with
      activeGeneration := generation,startHeight := start,
      retired := s.activeGeneration :: s.retired,ready := false }
  else { s with ready := false }

/-- Session opening requires fresh current-generation trust and an authoritative durable log. -/
def openSession (s : State) (currentGeneration : Nat) (checkpointTrusted logAuthoritative : Bool) : State :=
  { s with
    ready := checkpointTrusted && logAuthoritative && decide
      (currentGeneration = s.activeGeneration ∧ s.activeGeneration ∉ s.retired) }

end Etna.Design.Signer
