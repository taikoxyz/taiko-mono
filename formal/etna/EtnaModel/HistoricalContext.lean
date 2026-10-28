import EtnaModel.RegistryHistory
import EtnaModel.Consensus

/-! Typed decoded historical input. The Inbox origin mapping and registry checkpoint
history must themselves be authenticated under L1 roots; this module derives their
selection/ordering consequences rather than assuming a free context-authentication bit.
Archive element h is the anchor number of authenticated EL header h; byte/header/MPT
verification and availability of the complete archived headers remain external. -/
namespace Etna.Design.HistoricalContext

structure Parameters where
  genesisCutoff : Nat
  epochLen : Nat
  unit : Nat
  minimum : Nat
  nMax : Nat
  deriving DecidableEq, Repr

/-- Prefix maximum is total and saturates after the archive ends. build requires archive
coverage through the checkpoint; actual queried historical headers need explicit coverage.
On a sorted archive it equals the actual anchor at every present height. -/
def prefixAnchor (floor : Nat) : List Nat → Nat → Nat
  | [], _ => floor
  | a :: _, 0 => max floor a
  | a :: rest, h+1 => prefixAnchor (max floor a) rest h

def anchorAt (archive : List Nat) (h : Nat) : Nat := prefixAnchor 0 archive h

def registryAt (s : RegistryHistory.State) (cutoff : Nat) : List Committee.Entry :=
  ((RegistryHistory.latestSnapshot s.history cutoff).map RegistryHistory.Snapshot.entries).getD []

def derive (s : State) (registry : RegistryHistory.State) (cfg : Parameters) (archive : List Nat) : Consensus.Context :=
  ⟨s.domain,s.generation,s.origin.height,s.origin.l1Block,cfg.genesisCutoff,cfg.epochLen,
    cfg.unit,cfg.minimum,cfg.nMax,registryAt registry,anchorAt archive⟩

def fixedOrigin (s : State) : Option Origin :=
  (s.origins.find? (fun pair => pair.1 == s.generation)).map Prod.snd

/-- A missing origin or initial election snapshot is never replaced by a mapping default
or latest checkpoint. Cryptographic source authentication is a separate boundary. -/
def Ready (s : State) (registry : RegistryHistory.State) (cfg : Parameters) (archive : List Nat) : Prop :=
  fixedOrigin s = some s.origin ∧ s.checkpoint.height < archive.length ∧
  archive.Pairwise (· ≤ ·) ∧ RegistryHistory.Ordered registry.history ∧
  (RegistryHistory.latestSnapshot registry.history
    (if s.generation = 0 then cfg.genesisCutoff else s.origin.l1Block)).isSome = true ∧
  (Committee.election cfg.unit cfg.minimum
    (if s.generation = 0 then cfg.genesisCutoff else s.origin.l1Block) cfg.nMax
    (registryAt registry (if s.generation = 0 then cfg.genesisCutoff else s.origin.l1Block))).isSome = true ∧
  3 ≤ cfg.epochLen ∧ cfg.genesisCutoff ≤ s.origin.l1Block

instance (s : State) (registry : RegistryHistory.State) (cfg : Parameters) (archive : List Nat) :
    Decidable (Ready s registry cfg archive) := inferInstanceAs (Decidable (_ ∧ _))

def build (s : State) (registry : RegistryHistory.State) (cfg : Parameters) (archive : List Nat) : Option Consensus.Context :=
  if Ready s registry cfg archive then some (derive s registry cfg archive) else none

/-- The active cutoff depends on origin and anchor history, not on mutable current slots. -/
def cutoff (s : State) (cfg : Parameters) (archive : List Nat) (h : Nat) : Nat :=
  let t := (h-1)/cfg.epochLen
  if s.origin.height < t*cfg.epochLen-1 then max (anchorAt archive (t*cfg.epochLen-2)) s.origin.l1Block
  else if s.generation = 0 then cfg.genesisCutoff else s.origin.l1Block

end Etna.Design.HistoricalContext
