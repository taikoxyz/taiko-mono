import EtnaModel.CurrentProtocol
import EtnaModel.CurrentFinality

/-! Vocabulary of the recoverability claim (H4): call-restricted traces, the plain-recovery
path, live ruleset definitions, a live committee and the L1 time a recovery block must reach.
Definitions only; the claim itself is in `EtnaStatements.Current`. -/
namespace Etna.Design.Current.Protocol

/-- Traces whose every call satisfies `allowed`; no node events. -/
inductive CallTrace (env : Environment) (allowed : Call → Prop) : World → World → Prop
  | refl (w : World) : CallTrace env allowed w w
  | call {first w : World} (prior : CallTrace env allowed first w) (call : Call)
      (ok : allowed call) : CallTrace env allowed first (transact env w call)

def NoRollback : Call → Prop
  | .rollback .. => False
  | _ => True

/-- H4's path: no `rollback` (RECOV-8-28, RECOV-8-58) and only plain recoveries, with no
exclusions, no forced-inclusion blanking (RECOV-8-45) and no structural upgrade. -/
def RecoveryCall : Call → Prop
  | .rollback .. => False
  | .recover request => request.exclusions = [] ∧ request.clear = [] ∧ request.upgrade = none
  | _ => True

abbrev RecoveryTrace (env : Environment) : World → World → Prop := CallTrace env RecoveryCall

/-- `h` is a child of `parent` for these producer inputs and transaction list: hash-bound,
physically linked, and accepted by execution and payload checks for every body carrying it. -/
def Executes (env : Environment) (d : Blocks.Definition) (parent : Header) (cursor timestamp : Nat)
    (anchor : BlockValidity.Anchor) (txs : List Blocks.Bytes) (h : Header) : Prop :=
  h.height = parent.height+1 ∧ h.cursor = cursor ∧ h.timestamp = timestamp ∧ h.anchor = anchor ∧
  HashBound env h ∧ env.headerParent h.elHash = parent.elHash ∧
  ∀ (body : BlockValidity.Block) (raw : Blocks.Bytes), body.header = h →
    body.parentHash = parent.elHash →
    d.executionValid parent body = true ∧ d.payloadValid body raw txs = true

/-- A live ruleset definition (MODEL-1-1 on the EL side, 7.2 single-transaction trial):
for every producer choice some child exists for the empty list, and every canonical
forced transaction is either executable at position zero or its trial completes empty. -/
def ExecutionLive (env : Environment) (d : Blocks.Definition) : Prop :=
  ∀ (parent : Header) (cursor timestamp : Nat) (anchor : BlockValidity.Anchor),
    ∃ quiet, Executes env d parent cursor timestamp anchor [] quiet ∧
      ∀ raw : Blocks.Bytes, d.bytes.canonical raw = true → raw.length ≤ 8192 →
        (∃ h, Executes env d parent cursor timestamp anchor [raw] h) ∨
        d.bytes.buildSingleton parent quiet raw = .completedEmpty

def RulesetLive (env : Environment) (m : Nat) : Prop :=
  ∃ d, env.catalogue m = some d ∧ ExecutionLive env d

/-- LIMIT-12-6, RECOV-8-17..21: `keys` sign every vote and hold more than 2/3 of the
power elected at `cutoff` from `w`'s registry under `w`'s committee configuration. -/
def CommitteeLive (env : Environment) (w : World) (cutoff : Nat) (keys : List Hash) : Prop :=
  (∀ v : Consensus.Vote, v.key ∈ keys → env.signature v) ∧
  ∃ members, Committee.election w.inbox.configuration.unit w.inbox.configuration.minimum cutoff
      w.inbox.configuration.nMax (Finality.registryAt w.registry.registry cutoff) = some members ∧
    2*Committee.totalPower w.inbox.configuration.unit members <
      3*Committee.totalPower w.inbox.configuration.unit (members.filter fun e => keys.contains e.key)

def maxAges (w : World) : Nat := (w.configurations.map fun x => x.2.maxAnchorAge).foldr max 0

/-- L1 time the recovery block must reach: past every bound on the batch parent's timestamp
(a landed checkpoint's anchor age, `forkTime`, the genesis timestamp) by more than K. -/
def WindowBound (env : Environment) (w : World) : Nat :=
  max (env.time w.number+maxAges w) (max env.core.forkTime env.genesisHeader.timestamp)+w.inbox.gridK+1

end Etna.Design.Current.Protocol
