import EtnaModel.Landing
import EtnaModel.Staking
import EtnaModel.Forced

namespace Etna.Design.Recovery

/-- Inbox, registry and FI queue as `recover` sees them. `recover` is an owner call on an
initialized Inbox, and the registry's Inbox address is fixed at deployment. -/
structure World where
  inbox : State
  registry : List (Nat × Committee.Entry)
  queue : List (Nat × Forced.Entry)
  schedule : Committee.Schedule
  deriving DecidableEq, Repr

structure Exclusion where
  bondId : Nat
  entryKey : Hash
  deriving DecidableEq, Repr

/-- Recovery authorization: deployment-bound expected generation, checkpoint, nonce and expiry. -/
structure Request where
  generation : Nat
  checkpoint : Nat
  exclusions : List Exclusion
  fiToClear : List Nat
  nonce : Nat := 0
  validUntil : Nat := limit256-1
  deriving DecidableEq, Repr

/-- Fixed Keccak constants only: keccak256("") and the released-slot entryKey. The combined
machine reads them from the World's fixed adapters (`ProtocolState.Adapters.recovery`), so no
recovery call chooses them. L, vp_unit, s_min and n_max are the initialized deployment values
stored in the Inbox (`State.epochLen`, ghost `State.configuration`), never call inputs. -/
structure Config where
  emptyHash : Hash
  /-- entryKey of a released (all-zero) slot, keccak256(abi.encode(0, 0)). -/
  releasedKey : Hash
  deriving DecidableEq, Repr

def exclusionApplies (xs : List Exclusion) (id key : Nat) : Bool :=
  xs.any (fun x => x.bondId == id && x.entryKey == key)

/-- Step 2: listed entries exit at min(old, R); the principal is untouched. -/
def excludedRegistry (w : World) (xs : List Exclusion) (r : Nat) : List (Nat × Committee.Entry) :=
  w.registry.map fun (id,e) =>
    (id,if exclusionApplies xs id e.key then { e with exitAt := min e.exitAt r } else e)

def clearedQueue (w : World) (indices : List Nat) (emptyHash : Hash) : List (Nat × Forced.Entry) :=
  w.queue.map fun (id,e) => (id,if indices.contains id then Forced.clear emptyHash e else e)

/-- Step 5: the new generation's starting committee, elected at R's registry snapshot under
the stored deployment configuration. It is not an Inbox precondition (8.1 makes
non-emptiness a DAO pre-authorization check). -/
def selection (w : World) (a : Request) (r : Origin) : Option (List Committee.Entry) :=
  Committee.election w.inbox.configuration.unit w.inbox.configuration.minimum r.l1Block w.inbox.configuration.nMax
    ((excludedRegistry w a.exclusions r.l1Block).map Prod.snd)

/-- §8.3 initialization, nonce and timestamp checks. There is no minimum stall duration. -/
def AuthorizationAllowed (s : State) (a : Request) (timestamp : Nat) : Prop :=
  Staking.inboxInitialized s = true ∧ a.nonce = s.recoveryNonce ∧
  s.recoveryNonce+1 < limit256 ∧ a.validUntil < limit256 ∧ timestamp ≤ a.validUntil

instance (s : State) (a : Request) (timestamp : Nat) : Decidable (AuthorizationAllowed s a timestamp) :=
  inferInstanceAs (Decidable (_ ∧ _))

/-- Execution-time checks (8.3): owner, expected state/nonce, expiry and atomic list validity. -/
def Allowed (w : World) (a : Request) (cfg : Config) (r : Origin) (owner : Bool) : Prop :=
  owner = true ∧ w.inbox.entered = false ∧
  a.generation = w.inbox.generation ∧ a.checkpoint = w.inbox.checkpoint.height ∧
  w.inbox.generation+1 < limit48 ∧
  r.height = w.inbox.checkpoint.height ∧ r.l1Block < limit48 ∧ r.timestamp < limit256 ∧ 3 ≤ w.inbox.epochLen ∧
  ¬ (w.inbox.origins.map Prod.fst).contains (w.inbox.generation+1) ∧
  a.exclusions.Pairwise (fun x y => x.bondId < y.bondId) ∧
  (a.exclusions.all (fun x => w.registry.any (fun (id,e) => id == x.bondId && e.key == x.entryKey)) = true) ∧
  (a.exclusions.all (fun x => x.entryKey != cfg.releasedKey) = true) ∧
  a.fiToClear.Pairwise (· < ·) ∧
  (∀ i ∈ a.fiToClear, w.inbox.head ≤ i ∧ i < w.inbox.tail ∧ (w.queue.map Prod.fst).contains i = true) ∧
  AuthorizationAllowed w.inbox a r.timestamp

instance (w : World) (a : Request) (cfg : Config) (r : Origin) (owner : Bool) :
    Decidable (Allowed w a cfg r owner) := inferInstanceAs (Decidable (_ ∧ _))

/-- Steps 2-5 in one transaction. Settled state (c, its record, FI head, snapshot,
SignalService) is untouched; old pending updates are void. -/
def applyRecovery (w : World) (a : Request) (cfg : Config) (r : Origin) : World :=
  { inbox := { w.inbox with
      generation := w.inbox.generation+1,recoveryNonce := w.inbox.recoveryNonce+1,
      origin := r,origins := w.inbox.origins ++ [(w.inbox.generation+1,r)] },
    registry := excludedRegistry w a.exclusions r.l1Block,
    queue := clearedQueue w a.fiToClear cfg.emptyHash,
    schedule := Committee.recoverySchedule
      ⟨w.inbox.checkpoint.height/w.inbox.epochLen,r.l1Block,(selection w a r).getD []⟩ }

/-- Model the whole journaled transaction, including failures after external calls. -/
def recover (w : World) (a : Request) (cfg : Config) (r : Origin) (owner externalOK : Bool) : Option World :=
  if Allowed w a cfg r owner ∧ externalOK = true then some (applyRecovery w a cfg r) else none

/-- §8 verifier-failure rollback, Inbox side (shipped in the DAO upgrade that replaces the
verifier): set lastCheckpoint (270/271) and the FI head lane of 281 from the record `trusted`
and slot 284 to `trustedSnapshot`, and void later landing records and SignalService
checkpoints. The DAO supplies the last trusted landing's record and snapshot (the block 0
record and genesisCutoff if there is none); `rollback_record_consistent` needs `trusted` to be
the retained record at its height. Generation, origins and the FI tail are untouched. -/
def rollbackInbox (s : State) (trusted : Checkpoint) (trustedSnapshot : Nat) : State :=
  { s with
    recoveryNonce := s.recoveryNonce+1,
    checkpoint := trusted,head := trusted.cursor,snapshot := trustedSnapshot,
    records := s.records.filter (fun r => r.height ≤ trusted.height),
    signals := s.signals.filter (fun g => g.height ≤ trusted.height) }

/-- Common authorization-counter guard; overflow rejects rather than wrapping. -/
def NonceMutable (s : State) : Prop :=
  Staking.inboxInitialized s = true ∧ s.entered = false ∧ s.recoveryNonce+1 < limit256

instance (s : State) : Decidable (NonceMutable s) := inferInstanceAs (Decidable (_ ∧ _))

/-- Success-state transformer only. It changes no settlement or committee data. -/
def applyInvalidation (s : State) : State := { s with recoveryNonce := s.recoveryNonce+1 }

/-- Owner-only invalidation of all outstanding authorizations at the expected nonce. -/
def invalidateRecoveryNonce (s : State) (expected : Nat) (owner : Bool) : Option State :=
  if owner = true ∧ expected = s.recoveryNonce ∧ NonceMutable s then some (applyInvalidation s) else none

/-- Certified fixed genesis; the latest L1 trust checkpoint is a separate input. -/
structure Bootstrap where
  chainGeneration : Nat
  initialHeight : Nat
  genesisTime : Nat
  appHash : Hash
  firstLastBlockId : Option Hash
  firstLastCommit : Option Hash
  committee : Committee.Record
  deriving DecidableEq, Repr

def bootstrap (s : State) (r : Committee.Record) : Option Bootstrap :=
  match recordAt s s.origin.height with
  | none => none
  | some origin => some ⟨s.generation,s.origin.height+1,s.origin.timestamp,origin.elHash,none,none,r⟩

end Etna.Design.Recovery
