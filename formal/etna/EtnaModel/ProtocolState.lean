import EtnaModel.HistoricalContext
import EtnaModel.Settlement

/-! Combined initialized L1 specification machine. Step models transaction boundaries,
including exceptional rollback; environment time ordering is not an added contract check.
Core is structural safety, not whole-protocol cryptographic/economic safety. Rollback's
trusted target/snapshot remains a governance trust boundary; nonce invalidation is enforced. -/
namespace Etna.Design.ProtocolState

/-- The deployment's fixed abstract hash adapters: Keccak over the seven config words and
over committee records, and the two Keccak constants recovery uses (keccak256("") for
blanked FI entries and the released-slot entryKey). Function-valued ghost data lives in the
World (State keeps decidable equality for kernel regressions); every transition preserves it
(`step_preserves_immutables`) and no transaction input chooses it. Real hashing and its
separation remain external. -/
structure Adapters where
  configHash : List Encoding.Word → Hash
  recordHash : Committee.Record → Hash
  recovery : Recovery.Config

structure World where
  inbox : State
  registry : RegistryHistory.State
  queue : List (Nat × Forced.Entry)
  schedule : Committee.Schedule
  l1Block : Nat
  adapters : Adapters

def recoveryView (w : World) : Recovery.World :=
  ⟨w.inbox,RegistryHistory.registryView w.registry,w.queue,w.schedule⟩

def landed (w : World) (s : State) (block : Nat) : World := { w with inbox := s,l1Block := block }

def land (w : World) (i : LandInput) (leaves : List Leaf) (e : LandingEnv) : Option World :=
  (Etna.Design.land w.inbox i leaves e).map (fun s => landed w s e.blockNumber)

def registered (w : World) (s : RegistryHistory.State) (now : Nat) : World :=
  { w with registry := s,l1Block := now }

/-- Force-exit and confirmation re-check are internal recovery/rollback operations. -/
def publicEdit : RegistryHistory.Edit → Bool
  | .forceExit | .recheck _ => false
  | _ => true

def enqueued (w : World) (s : State) (hash timestamp now : Nat) : World :=
  { w with inbox := s,queue := w.queue ++ [(w.inbox.tail,⟨hash,timestamp,now⟩)],l1Block := now }

def recovered (w : World) (a : Recovery.Request) (r : Origin) (s : Recovery.World) : World :=
  ⟨s.inbox,RegistryHistory.forceExclusions w.registry a.exclusions r.l1Block,s.queue,s.schedule,r.l1Block,w.adapters⟩

/-- `recover` reads the fixed Keccak constants from the World's adapters. -/
def recover (w : World) (a : Recovery.Request) (r : Origin) (owner externalOK : Bool) : Option World :=
  (Recovery.recover (recoveryView w) a w.adapters.recovery r owner externalOK).map (recovered w a r)

def applyRollback (w : World) (trusted : Checkpoint) (snapshot now : Nat) : World :=
  { w with inbox := Recovery.rollbackInbox w.inbox trusted snapshot, registry := RegistryHistory.recheckAll w.registry snapshot,l1Block := now }

/-- Checked verifier-replacement rollback. `applyRollback` is its success transformer. -/
def rollback (w : World) (trusted : Checkpoint) (snapshot now : Nat) : Option World :=
  if Recovery.NonceMutable w.inbox then some (applyRollback w trusted snapshot now) else none

/-- Owner invalidation changes no settlement or registry data. -/
def invalidateRecoveryNonce (w : World) (expected now : Nat) (owner : Bool) : Option World :=
  (Recovery.invalidateRecoveryNonce w.inbox expected owner).map (fun s => landed w s now)

structure InboxValid (s : State) : Prop where
  settled : Settlement.StateValid s
  fees : FeeConserved s
  headBound : s.head ≤ s.tail
  recordCursors : ∀ record ∈ s.records, record.cursor ≤ s.tail

structure RegistryValid (s : RegistryHistory.State) (block : Nat) : Prop where
  keys : RegistryHistory.KeysValid s
  identities : RegistryHistory.IdentitiesValid s
  history : RegistryHistory.Ordered s.history
  current : RegistryHistory.CurrentSnapshot s
  clock : RegistryHistory.lastBlock s ≤ block

structure Core (w : World) : Prop where
  inbox : InboxValid w.inbox
  registry : RegistryValid w.registry w.l1Block
  queue : w.queue.map Prod.fst = List.range w.inbox.tail

/-- These constructors compose the real decoded transition functions. Environmental L1
clock order and retained rollback targets are logical assumptions, not new on-chain guards.
Deployment immutables (maxBatchBlocks, FI fee/threshold, fee recipient, registry minimum and
delays, recovery Keccak constants) are read from the World, never chosen per step. -/
inductive Step : World → World → Prop
  | landing {w : World} {s : State} {i : LandInput} {leaves : List Leaf} {e : LandingEnv}
      (time : w.l1Block ≤ e.blockNumber) (ok : Etna.Design.land w.inbox i leaves e = some s) :
      Step w (landed w s e.blockNumber)
  | registration {w : World} {s : RegistryHistory.State} {key owner amount now : Nat}
      (time : w.l1Block ≤ now) (ok : RegistryHistory.register w.registry key owner amount now = some s) :
      Step w (registered w s now)
  | modification {w : World} {s : RegistryHistory.State} {id now : Nat} {action : RegistryHistory.Edit}
      (time : w.l1Block ≤ now) (callable : publicEdit action = true)
      (ok : RegistryHistory.edit w.registry w.inbox id now action = some s) : Step w (registered w s now)
  | enqueue {w : World} {s : State} {hash timestamp now raw paid : Nat} {refund : Bool}
      (time : w.l1Block ≤ now) (blockRange : now < limit48) (timestampRange : timestamp < limit48)
      (ok : Forced.enqueue w.inbox raw paid refund = some s) : Step w (enqueued w s hash timestamp now)
  | sweep {w : World} {s : State} {now : Nat} {transfer : Bool}
      (time : w.l1Block ≤ now) (ok : Forced.sweep w.inbox transfer = some s) : Step w (landed w s now)
  | recovery {w : World} {s : Recovery.World} {a : Recovery.Request} {r : Origin}
      {owner externalOK : Bool} (time : w.l1Block ≤ r.l1Block)
      (ok : Recovery.recover (recoveryView w) a w.adapters.recovery r owner externalOK = some s) :
      Step w (recovered w a r s)
  | invalidation {w : World} {s : State} {expected now : Nat} {owner : Bool}
      (time : w.l1Block ≤ now)
      (ok : Recovery.invalidateRecoveryNonce w.inbox expected owner = some s) : Step w (landed w s now)
  | rollback {w : World} (trusted : Checkpoint) (snapshot now : Nat)
      (time : w.l1Block ≤ now) (retained : recordAt w.inbox trusted.height = some trusted)
      (authorized : Recovery.NonceMutable w.inbox) :
      Step w (applyRollback w trusted snapshot now)

inductive Trace : World → World → Prop
  | refl (w : World) : Trace w w
  | step {first w t : World} (prior : Trace first w) (change : Step w t) : Trace first t

/-- Steps under a sound environment for slot 284: a landing whose proof certifies its snapshot
at or below its reference block (§6.1, the premise of `land_snapshot_below_block`), a rollback
restoring any snapshot strictly below the rollback's own L1 block (the only premise is
`snapshot < now`; that the DAO restores the value an earlier trusted landing or initialization
wrote is rollback's governance trust boundary, not checked here), and any other step that
leaves slot 284 untouched (registration, edits, FI, recovery). -/
inductive SoundStep : World → World → Prop
  | landing {w : World} {s : State} {i : LandInput} {leaves : List Leaf} {e : LandingEnv}
      (time : w.l1Block ≤ e.blockNumber) (ok : Etna.Design.land w.inbox i leaves e = some s)
      (certified : i.activeCommitteeSnapshot ≤ i.l1ReferenceBlockNumber) : SoundStep w (landed w s e.blockNumber)
  | rollback {w : World} (trusted : Checkpoint) (snapshot now : Nat)
      (time : w.l1Block ≤ now) (retained : recordAt w.inbox trusted.height = some trusted) (written : snapshot < now)
      (authorized : Recovery.NonceMutable w.inbox) :
      SoundStep w (applyRollback w trusted snapshot now)
  | framed {w t : World} (change : Step w t) (same : t.inbox.snapshot = w.inbox.snapshot) : SoundStep w t

inductive SoundTrace : World → World → Prop
  | refl (w : World) : SoundTrace w w
  | step {first w t : World} (prior : SoundTrace first w) (change : SoundStep w t) : SoundTrace first t

end Etna.Design.ProtocolState
