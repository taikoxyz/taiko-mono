module
public import Etna.Common.Words
public import Etna.Landing.Statement
public import Mathlib.Tactic
public section
namespace Etna.Landing
abbrev Address := Fin (2 ^ 160)
structure Checkpoint where
  height : Nat
  blockHash : Word256
  deriving DecidableEq, Repr
structure SignalCheckpoint where
  height : Nat
  blockHash : Word256
  stateRoot : Word256
  deriving DecidableEq, Repr
inductive Event where
  | checkpointSaved (checkpoint : SignalCheckpoint)
  | batchLanded (first last : Nat) (blockHash stateRoot : Word256) (reference : Nat) (caller : Address)
  | consumed (before after wei : Nat) (recipient : Address)
  deriving DecidableEq, Repr
structure Transfer where
  recipient : Address
  wei : Nat
  deriving DecidableEq, Repr
/-- Journaled business state. Transaction sender nonce and gas fees are deliberately outside it.
The pinned callback frame excludes authorized upgrades/configuration changes. Arbitrary recipient
balance changes are not equated with payment: only transfer instructions are recorded here. -/
structure World where
  inbox : Address
  l1ChainId : Word256 := 1
  l2ChainId : Word64 := 167001
  registry : Address := 2
  generation : Word64 := 0
  config : Word256 := 1
  active : Bool
  maxBatchBlocks : Nat
  checkpoint : Checkpoint
  head : Word48
  tail : Word48
  fee : Nat → Word64
  signal : List SignalCheckpoint
  inboxBalance : Nat
  transfers : List Transfer
  logs : List Event
  guard : Bool
structure LandInput where
  lastHeight : Word64
  lastBlockHash : Word256
  lastStateRoot : Word256
  reference : Word64
  headAfter : Word48
  recipient : Address
  caller : Address
  deriving DecidableEq, Repr
inductive Error where
  | reentrant | inactive | noProgress | batchTooLarge | heightOverflow | zeroRecipient
  | invalidHead | anchorUnavailable | blobsRequired | environmentError
  | signalUnauthorized | signalInvalid | verifier | payment
  deriving DecidableEq, Repr
/-- Concrete environment read results. Authenticity is a named EVM/environment assumption;
branch selection and length/nonzero checks are executable, not assumptions. -/
structure Environment where
  blockNumber : Nat
  blockHash : Word256
  historySuccess : Bool
  historyLength : Nat
  historyHash : Word256
  blobHashes : List Word256
  deriving DecidableEq, Repr
inductive ReferenceRoute where | blockhash | history deriving DecidableEq, Repr

@[expose] def referenceHash (e : Environment) (r : Word64) : Except Error (ReferenceRoute × Word256) :=
  if r.val ≥ e.blockNumber then .error .anchorUnavailable
  else if e.blockNumber - r.val ≤ 256 then
    if e.blockHash = 0 then .error .anchorUnavailable else .ok (.blockhash, e.blockHash)
  else if e.blockNumber - r.val > 8191 then .error .anchorUnavailable
  else if !e.historySuccess || e.historyLength != 32 then .error .anchorUnavailable
  else if e.historyHash = 0 then .error .anchorUnavailable else .ok (.history, e.historyHash)

@[expose] def actualBlobs (e : Environment) : List Word256 := e.blobHashes.takeWhile (· != 0)
/-- Both sibling checks happen before statement construction. When both fail, this returns
an unordered combined classification instead of inventing source-level evaluation precedence. -/
@[expose] def environmentCheck (e : Environment) (i : LandInput) : Option Error :=
  match referenceHash e i.reference, actualBlobs e with
  | .error _, [] => some .environmentError
  | .error _, _ => some .anchorUnavailable
  | .ok _, [] => some .blobsRequired
  | .ok _, _ => none

/-- Checks in exactly the source order. Typed ABI widths are the dispatcher boundary. -/
@[expose] def validate (w : World) (i : LandInput) : Option Error :=
  if w.guard then some .reentrant
  else if !w.active then some .inactive
  else if i.lastHeight.val ≤ w.checkpoint.height then some .noProgress
  else if i.lastHeight.val - w.checkpoint.height > w.maxBatchBlocks then some .batchTooLarge
  else if i.lastHeight.val ≥ 2 ^ 48 then some .heightOverflow
  else if i.recipient = 0 then some .zeroRecipient
  else if w.head.val > i.headAfter.val || i.headAfter.val > w.tail.val ||
      i.headAfter.val - w.head.val > i.lastHeight.val - w.checkpoint.height then some .invalidHead
  else none

@[expose] def fees (fee : Nat → Word64) (before after : Nat) : Nat :=
  ((List.range (after - before)).map fun offset => (fee (before + offset)).val).sum

inductive ReentryMode where
  | none | landCaught | saveCaught | landUncaught | saveUncaught | verifierLand | verifierSave
  deriving DecidableEq, Repr
structure ExternalOutcomes where
  environment : Environment
  signalAuthorized : Bool
  verifierReturnsNormally : Bool
  paymentReturnsNormally : Bool
  reentry : ReentryMode
  /-- Cryptographic primitive over the actual ordered transaction prefix. Authenticity of this
  primitive is an explicit EVM crypto boundary, not a proof of collision freedom. -/
  keccakBlobWords : List Word256 → Word256 := fun _ => 0


/-- Exact source statement builder. Proxy identity is `w.inbox`; caller is deliberately absent. -/
@[expose] def makeStatement (w : World) (i : LandInput) (reference blobCommitment : Word256) : LandStatement :=
  ⟨landDomain,
   natWord w.l1ChainId.val, natWord w.l2ChainId.val, natWord w.inbox.val,
   natWord w.registry.val, natWord w.generation.val, natWord w.checkpoint.height,
   natWord w.checkpoint.blockHash.val, natWord w.config.val, natWord i.lastHeight.val,
   natWord i.lastBlockHash.val, natWord i.lastStateRoot.val, natWord i.reference.val,
   natWord reference.val, natWord blobCommitment.val, natWord w.head.val,
   natWord i.headAfter.val, natWord i.recipient.val⟩

@[expose] def computedStatement (w : World) (i : LandInput) (x : ExternalOutcomes) : LandStatement :=
  makeStatement w i
    (match referenceHash x.environment i.reference with | .ok (_, hash) => hash | .error _ => 0)
    (x.keccakBlobWords (actualBlobs x.environment))

/-- Generic nested EVM business-state journal. `write` retains its parent frame: undoing an
external call also undoes its nested checkpoint/log/transfer effects, not merely Inbox storage.
Connection of these abstract journal operations to EVM transaction execution is explicit. -/
inductive Journal (α : Type) where
  | begin (initial : α)
  | write (parent : Journal α) (current : α)
@[expose] def Journal.current : Journal α → α | .begin w => w | .write _ w => w
@[expose] def Journal.rollback : Journal α → α | .begin w => w | .write parent _ => parent.rollback
@[expose] def Journal.update (j : Journal α) (f : α → α) : Journal α := .write j (f j.current)
inductive Stage where
  | entry | checked | statement | head | checkpoint | signal | batchEvent | verifier | payment
  | consumed | unlock
  deriving DecidableEq, Repr
structure TentativeResult where
  journal : Journal World
  error : Option Error
  stage : Stage
  trace : List Stage
  statement : Option LandStatement := none
structure TransactionResult where
  world : World
  error : Option Error
  tentative : TentativeResult

@[expose] def runTransaction (_initial : World) (r : TentativeResult) : TransactionResult :=
  ⟨if r.error.isSome then r.journal.rollback else r.journal.current, r.error, r⟩

@[expose] def nestedGuard (executionAccount : Address) (w : World) : Option Error :=
  if executionAccount = w.inbox && w.guard then some .reentrant else none

@[expose] def finish (j : Journal World) (e : Option Error) (s : Stage) (trace : List Stage) (statement : Option LandStatement := none) : TentativeResult :=
  ⟨j, e, s, trace, statement⟩

/-- Explicit late path. SignalService concretely checks authorization, root and block hash;
verifier is a void STATICCALL and cannot directly write business state. Recipient callbacks
may try either shared-guard entrypoint; caught errors allow the outer payment to finish. -/
@[expose] def execChecked (w : World) (i : LandInput) (x : ExternalOutcomes) : TentativeResult := Id.run do
  let j := (Journal.begin w).update fun s => { s with guard := true }
  let statement := some (computedStatement w i x)
  let amount := fees w.fee w.head.val i.headAfter.val * 1000000000
  let j := if i.headAfter != w.head then j.update fun s => { s with head := i.headAfter } else j
  let j := j.update fun s => { s with checkpoint := ⟨i.lastHeight.val, i.lastBlockHash⟩ }
  let stages := [Stage.entry, .checked, .statement, .head, .checkpoint]
  if !x.signalAuthorized then return finish j (some .signalUnauthorized) .signal (stages ++ [.signal]) statement
  if i.lastStateRoot = 0 || i.lastBlockHash = 0 then
    return finish j (some .signalInvalid) .signal (stages ++ [.signal]) statement
  let cp : SignalCheckpoint := ⟨i.lastHeight.val, i.lastBlockHash, i.lastStateRoot⟩
  let j := j.update fun s => { s with signal := s.signal ++ [cp], logs := s.logs ++ [.checkpointSaved cp] }
  let j := j.update fun s => { s with logs := s.logs ++
    [.batchLanded (w.checkpoint.height + 1) i.lastHeight.val i.lastBlockHash i.lastStateRoot i.reference.val i.caller] }
  let stages := stages ++ [.signal, .batchEvent, .verifier]
  if !x.verifierReturnsNormally then
    return finish j (some .verifier) .verifier stages statement
  let moved := i.headAfter != w.head
  if moved && amount > 0 && (!x.paymentReturnsNormally || w.inboxBalance < amount ||
      x.reentry = .landUncaught || x.reentry = .saveUncaught) then
    return finish j (some .payment) .payment (stages ++ [.payment]) statement
  let j := if moved && amount > 0 then j.update fun s =>
    { s with inboxBalance := s.inboxBalance - amount, transfers := s.transfers ++ [⟨i.recipient, amount⟩] } else j
  let j := if moved then j.update fun s =>
    { s with logs := s.logs ++ [.consumed w.head.val i.headAfter.val amount i.recipient] } else j
  let j := j.update fun s => { s with guard := false }
  return finish j none .unlock (stages ++ (if moved && amount > 0 then [.payment] else []) ++
    (if moved then [.consumed] else []) ++ [.unlock]) statement

@[expose] def execLandSteps (w : World) (i : LandInput) (x : ExternalOutcomes) : TentativeResult :=
  match validate w i with
  | some error => finish (if w.guard then .begin w else
      (Journal.begin w).update fun s => { s with guard := true }) (some error) .entry [.entry]
  | none => match environmentCheck x.environment i with
    | some error => finish ((Journal.begin w).update fun s => { s with guard := true })
        (some error) .checked [.entry, .checked]
    | none => execChecked w i x
end Etna.Landing
