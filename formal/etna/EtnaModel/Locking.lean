import EtnaModel.Consensus
import EtnaModel.RegistryHistory

/-! A fixed-height, fixed-committee interface to the pinned CometBFT v0.40.0 rules.
`nilUnlock = true` is the markdown reading: locked prevotes stay on their block and
nil PoLC may unlock at precommit. `false` is the paper reading: locked nil prevotes
are allowed but nil PoLC never clears a lock. The mode is a global proof abstraction,
not an Etna configuration or a per-validator choice. Combining the two permissions
would be unsound. `some 0` is a block; `none` is nil.

A round-indexed local execution is the normalization of each key's monotone H/R/phase
history. Missing phases/rounds are allowed. Prevote precedes precommit for each key;
a nil unlock at precommit cannot authorize another prevote in that round. There is
no network-wide round order: different keys can concurrently occupy different rounds.
Certificates refer to the whole authenticated vote archive. We conservatively do not
require delivery before use; strict prior-round justification is still checked.
Signature unforgeability, truthful event attribution and refinement of actual Comet
execution to this decoded interface are primitive boundaries, not proved here. -/
namespace Etna.Design.Locking

abbrev Value := Option Hash
abbrev Lock := Option (Nat × Hash)

def power (unit : Nat) (members : List Committee.Entry) (keys : List Hash) : Nat :=
  Committee.totalPower unit (members.filter fun m => keys.contains m.key)

def Quorum (unit : Nat) (members : List Committee.Entry) (keys : List Hash) : Prop :=
  2 * Committee.totalPower unit members < 3 * power unit members keys

structure RoundAction where
  prevote : Option Value := none
  precommit : Option Value := none
  justification : Option (Nat × Value) := none
  nilCertificate : Bool := false
  deriving DecidableEq, Repr

structure Execution where
  prevotes : Hash → Nat → Value → Prop
  precommits : Hash → Nat → Value → Prop
  actions : Hash → Nat → RoundAction
  locks : Hash → Nat → Lock

def PoLC (unit : Nat) (members : List Committee.Entry) (e : Execution) (r : Nat) (v : Value) : Prop :=
  ∃ keys, Quorum unit members keys ∧ ∀ k ∈ keys, e.prevotes k r v

def Commit (unit : Nat) (members : List Committee.Entry) (e : Execution) (r : Nat) (b : Hash) : Prop :=
  ∃ keys, Quorum unit members keys ∧ ∀ k ∈ keys, e.precommits k r (some b)

/-- Equality in the lower bound safely over-approximates markdown's strict lower bound
and includes the paper's non-strict bound; certificate uniqueness handles equality. -/
def UnlockAllowed (nilUnlock : Bool) (cert : Nat → Value → Prop) (r : Nat)
    (lock : Lock) (justification : Option (Nat × Value)) : Prop :=
  match justification with
  | none => True
  | some (q,v) => ∃ lr b, lock = some (lr,b) ∧ lr ≤ q ∧ q < r ∧ cert q v ∧
      v ≠ some b ∧ (nilUnlock = true ∨ v ≠ none)

def afterPrevote (lock : Lock) (action : RoundAction) : Lock :=
  if action.justification.isSome then none else lock

def VoteAllowed (nilUnlock : Bool) (lock : Lock) (v : Value) : Prop :=
  match lock with
  | none => True
  | some (_,b) => v = some b ∨ (nilUnlock = false ∧ v = none)

/-- The only lock acquisition is a current-round nonnil PoLC. Nil precommit alone
never clears a lock; nil-certificate unlock is after this round's prevote. -/
def RoundStep (nilUnlock : Bool) (cert : Nat → Value → Prop) (r : Nat)
    (before : Lock) (action : RoundAction) (after : Lock) : Prop :=
  UnlockAllowed nilUnlock cert r before action.justification ∧
  (∀ v, action.prevote = some v → VoteAllowed nilUnlock (afterPrevote before action) v) ∧
  match action.precommit with
  | none => after = afterPrevote before action
  | some (some b) => cert r (some b) ∧ after = some (r,b)
  | some none => (action.nilCertificate = true → cert r none) ∧
      after = if nilUnlock && action.nilCertificate then none else afterPrevote before action

/-- Only honest keys are attributed to one local phase event. Byzantine keys may
sign multiple values at any phase and round in the authenticated archive. -/
structure HonestRules (unit : Nat) (members : List Committee.Entry) (honest : Hash → Bool)
    (nilUnlock : Bool) (e : Execution) : Prop where
  initial : ∀ k, honest k = true → e.locks k 0 = none
  steps : ∀ k, honest k = true → ∀ r,
    RoundStep nilUnlock (PoLC unit members e) r (e.locks k r) (e.actions k r) (e.locks k (r+1))
  prevote : ∀ k, honest k = true → ∀ r v, e.prevotes k r v → (e.actions k r).prevote = some v
  precommit : ∀ k, honest k = true → ∀ r v, e.precommits k r v → (e.actions k r).precommit = some v

def Minority (unit : Nat) (members : List Committee.Entry) (honest : Hash → Bool) : Prop :=
  3 * Committee.totalPower unit (members.filter fun m => !honest m.key) < Committee.totalPower unit members

/-- In the paper reading a nil certificate does not release a lock. -/
def Compatible (nilUnlock : Bool) (block : Hash) (value : Value) : Prop :=
  value = some block ∨ (nilUnlock = false ∧ value = none)

/-- Per-certificate nonnil event attribution, including signature/encoding truthfulness.
Decoded CommitValid alone has no nil discriminator. This contract applies only to the
concrete certificate being bridged; unrelated authentic nil precommits remain permitted.
`some 0` is a block, never an implicit nil sentinel. No agreement/locking premise occurs. -/
def CommitAttribution (e : Execution) (r b : Nat) (votes : List Consensus.Vote) : Prop :=
  ∀ v ∈ votes, e.precommits v.key r (some b)

end Etna.Design.Locking
