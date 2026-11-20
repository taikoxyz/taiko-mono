import EtnaModel.CurrentProtocol

/-! The bridge's read path. The L1 `SignalService` proves an L2 signal against the L2 state
root of a checkpoint it holds (ANCHORLESS section 4). Two paths then use a signal without
checking a checkpoint again: an empty proof for a signal it cached as received, and a retry of
an L1 Bridge message left `RETRIABLE` (RECOV-8-27a). This module keeps both, the derived
authorizations, next to the protocol machine. A verifier-failure rollback revokes all of them
(RECOV-8-27a, vector 27a.k). The Merkle proof check is a fixed decoded adapter; message values,
fees and quotas are not modelled.

It also models the shared `SignalService` on L2. The current block's EIP-4788 root gates
checkpoint writes. Reads prefer a saved checkpoint and otherwise use EIP-4788
(ANCHORLESS sections 4 and 8). -/
namespace Etna.Design.Current.Bridge
open Protocol

/-- A signal proven received against `root`, the L2 state root of the checkpoint at `height`.
The Solidity cache stores only the slot; `height` and `root` are ghost provenance. -/
structure Authorization where
  slot : Hash
  height : Nat
  root : Hash
  deriving DecidableEq, Repr

/-- The L1 `SignalService` and Bridge state the read path writes: signals cached as received,
messages left `RETRIABLE` with the proof that admitted them, and completed messages. -/
structure State where
  cached : List Authorization := []
  retriable : List Authorization := []
  done : List Hash := []
  deriving DecidableEq, Repr

/-- The L2 state root the L1 `SignalService` holds for `height`: an Unzen checkpoint the EtnaInbox
forwarded at or below S, or an Etna landing's checkpoint. -/
def checkpointRoot (w : World) (height : Nat) : Option Hash :=
  ((w.legacySignals ++ w.inbox.signals).find? (·.height == height)).map Signal.stateRoot

/-- A proof of `slot` against the checkpoint at `height`, under the Merkle adapter `verify root
slot proof`. -/
def prove (verify : Hash → Hash → Hash → Bool) (w : World) (slot : Hash) (height : Nat) (proof : Hash) :
    Option Authorization :=
  (checkpointRoot w height).bind fun root =>
    if verify root slot proof = true then some ⟨slot,height,root⟩ else none

inductive Call where
  /-- `proveSignalReceived` with a proof: the signal is cached as received. -/
  | receive (slot : Hash) (height : Nat) (proof : Hash)
  /-- `processMessage` with a proof. `delivered` is whether the message call succeeds; a failed
  one is left `RETRIABLE`. -/
  | process (slot : Hash) (height : Nat) (proof : Hash) (delivered : Bool)
  /-- `processMessage` with an empty proof, for a signal cached as received. -/
  | processCached (slot : Hash) (delivered : Bool)
  /-- `retryMessage` for a message left `RETRIABLE`, with no proof. -/
  | retry (slot : Hash) (delivered : Bool)
  deriving DecidableEq, Repr

/-- A message that is neither done nor `RETRIABLE` (`NEW`) settles under `a`. -/
def settle (b : State) (a : Authorization) (delivered : Bool) : Option State :=
  if a.slot ∈ b.done ∨ b.retriable.any (·.slot == a.slot) then none
  else if delivered then some { b with done := a.slot :: b.done }
  else some { b with retriable := a :: b.retriable }

def execute (verify : Hash → Hash → Hash → Bool) (w : World) (b : State) : Call → Option State
  | .receive slot height proof =>
      (prove verify w slot height proof).map fun a => { b with cached := a :: b.cached }
  | .process slot height proof delivered =>
      (prove verify w slot height proof).bind fun a => settle b a delivered
  | .processCached slot delivered =>
      (b.cached.find? (·.slot == slot)).bind fun a => settle b a delivered
  | .retry slot delivered =>
      (b.retriable.find? (·.slot == slot)).map fun a =>
        if delivered then { b with retriable := b.retriable.erase a, done := slot :: b.done } else b

/-- RECOV-8-27a: the rollback's upgrade makes every cached signal and every `RETRIABLE` message
unusable until it is proven again. It revokes all of them, which vector 27a.k allows; a revoked
message is `NEW` again, so `process` with a fresh proof completes it. -/
def revoke (b : State) : State := { b with cached := [], retriable := [] }

/-- Whether `call` is a verifier-failure rollback that the Inbox accepts. -/
def rolledBack (env : Environment) (w : World) : Protocol.Call → Bool
  | .rollback caller trusted snapshot => (rollback env w caller trusted snapshot).isSome
  | _ => false

/-- One step of the protocol machine with the bridge alongside. A protocol call moves the world,
and an accepted rollback also revokes, in the same DAO upgrade (RECOV-8-26). A bridge call reads
the world and changes only the bridge's state. -/
inductive Step (env : Environment) (verify : Hash → Hash → Hash → Bool) : World × State → World × State → Prop
  | call (w : World) (b : State) (call : Protocol.Call) :
      Step env verify (w,b) (transact env w call,if rolledBack env w call then revoke b else b)
  | node {w : World} (b : State) (after : Node) (validated : NodeEvent env w after) :
      Step env verify (w,b) ({ w with node := after },b)
  | bridge (w : World) {b c : State} (call : Call) (ok : execute verify w b call = some c) :
      Step env verify (w,b) (w,c)

inductive Run (env : Environment) (verify : Hash → Hash → Hash → Bool) :
    World × State → World × State → Prop
  | refl (x : World × State) : Run env verify x x
  | step {first x y : World × State} (prior : Run env verify first x) (change : Step env verify x y) :
      Run env verify first y

/-- RECOV-8-27/8-27a's goal for the read path: every signal a call may use without a checkpoint
was proven, under the adapter, against the root of a checkpoint the L1 `SignalService` still
holds. -/
def Backed (verify : Hash → Hash → Hash → Bool) (w : World) (b : State) : Prop :=
  ∀ a ∈ b.cached ++ b.retriable, (∃ s ∈ w.legacySignals ++ w.inbox.signals,
    s.height = a.height ∧ s.stateRoot = a.root) ∧ ∃ proof, verify a.root a.slot proof = true

/-! ### The L2 `SignalService` -/

/-- Its immutables (ANCHORLESS section 4): the authorized syncer and the flag enabling
EIP-4788 on L2. -/
structure L2Config where
  syncer : Nat
  usesBeaconRoots : Bool
  deriving DecidableEq, Repr

/-- A saved checkpoint: its L1 block id and state root, and, as ghost provenance, the caller
and the L2 block timestamp of the call that saved it. -/
structure Saved where
  blockId : Nat
  root : Hash
  caller : Nat
  savedAt : Nat
  deriving DecidableEq, Repr

/-- On L2, a checkpoint write requires a successful read of a zero root for this block. -/
def checkpointsOpen (c : L2Config) (currentBeaconRoot : Option Hash) : Bool :=
  !c.usesBeaconRoots || currentBeaconRoot == some 0

/-- `saveCheckpoint` in an L2 block at `timestamp`: only the syncer, only while the store is
open, and no zero root. -/
def save (c : L2Config) (currentBeaconRoot : Option Hash) (store : List Saved)
    (caller timestamp blockId : Nat) (root : Hash) : Option (List Saved) :=
  if caller = c.syncer ∧ checkpointsOpen c currentBeaconRoot = true ∧ root ≠ 0 then
    some (⟨blockId,root,caller,timestamp⟩ :: store)
  else none

/-- The newest checkpoint root for a uint48 block id, if present and nonzero. -/
def checkpointStateRoot (store : List Saved) (blockId : Nat) : Option Hash :=
  if blockId < limit48 then
    ((store.find? (·.blockId == blockId)).map Saved.root).filter (· != 0)
  else none

/-- Resolve a proof id independently of the current block's timestamp. A missing checkpoint
can fall back to a nonzero beacon root on L2. A missing or overwritten entry reads as none. -/
def stateRoot (c : L2Config) (beacon : Nat → Option Hash) (store : List Saved)
    (blockId : Nat) : Option Hash :=
  (checkpointStateRoot store blockId).orElse fun _ =>
    if c.usesBeaconRoots then (beacon blockId).filter (· != 0) else none

/-- L2 blocks in timestamp order, each running `saveCheckpoint` calls; timestamps never decrease. -/
inductive L2Run (c : L2Config) (blockRoot : Nat → Option Hash) :
    Nat × List Saved → Nat × List Saved → Prop
  | refl (x : Nat × List Saved) : L2Run c blockRoot x x
  | call {first : Nat × List Saved} {now : Nat} {store next : List Saved} {timestamp : Nat}
      (prior : L2Run c blockRoot first (now,store)) (later : now ≤ timestamp)
      (caller blockId : Nat) (root : Hash)
      (ok : save c (blockRoot timestamp) store caller timestamp blockId root = some next) :
      L2Run c blockRoot first (timestamp,next)
  | skip {first : Nat × List Saved} {now : Nat} {store : List Saved} {timestamp : Nat}
      (prior : L2Run c blockRoot first (now,store)) (later : now ≤ timestamp) :
      L2Run c blockRoot first (timestamp,store)

end Etna.Design.Current.Bridge
