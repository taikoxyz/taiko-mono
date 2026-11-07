import EtnaModel.CurrentProtocolFinality

/-! Economic and temporal obligations derived from actual closed calls. -/
namespace Etna.Design.Current.Economics
open Protocol

/-- Outstanding permanent-bond liabilities include displaced bonds and pending top-ups. -/
def reserve (s : Registry.State) : Nat :=
  RegistryMachine.reserve s

/-- A snapshot becomes available only when its entire L1 block has closed. -/
def ClosedRegistryHistory (w : World) : Prop :=
  ∀ s ∈ w.history, s.number < w.number ∧
    w.registry.registry.history.filter (fun cp => decide (cp.block ≤ s.number)) =
      s.registryHistory.filter (fun cp => decide (cp.block ≤ s.number))

/-- Each retained registry checkpoint was produced by an actual funded protocol World,
not a supplied election list. Both surrounding trace segments are retained as evidence. -/
def HistoricalOrigin (env : Environment) (initial w : World) : Prop :=
  ∀ cp ∈ w.registry.registry.history, ∃ past,
    Trace env initial past ∧ Trace env past w ∧ past.number = cp.block ∧ cp.entries = RegistryMachine.entries past.registry.registry

def HistoricalStakeFunded (env : Environment) (w : World) : Prop :=
  ∀ cp ∈ w.registry.registry.history, ∀ entry ∈ cp.entries, entry.stake ≠ 0 →
    ∃ past id bond, Trace env past w ∧ past.number = cp.block ∧ id < past.registry.registry.ledger.nextId ∧
      past.registry.registry.ledger.bonds id = some bond ∧ Staking.toEntry bond.value = entry ∧
      RegistryPayments.Backed env.token past.registry ∧
      entry.stake ≤ past.registry.token.balances env.token.registryAddress

/-- Future paid slashing needs no caller-supplied future token funding premise. -/
def FundedFutureLiability (env : Environment) (first : World) (key : Hash)
    (a b : Staking.Vote) (sa sb : Hash) : Prop :=
  ∀ later, Trace env first later → ∀ id current caller,
    id < later.registry.registry.ledger.nextId → later.registry.registry.ledger.bonds id = some current →
    current.value.key = key → current.value.released = false → 0 < current.value.balance →
    later.inbox.entered = false →
    ∃ next, registryCall env later caller (.slash id a b sa sb) = some next ∧
      next.receipts = later.receipts ++ ProtocolFinality.slashReceipts env later caller current

/-- Once an actual bond is unconfirmed, its entire deployment evidence window retains
the lifetime identity and unreleased principal. At use, neither release status nor a
positive balance is an input: exhausted principal is reported explicitly, and every
positive remainder has an executable funded slash. This does not assert that a
historical committee is still unconfirmed at the current checkpoint. -/
def RetainedWindowLiability (env : Environment) (first : World) (id : Nat) (key : Hash)
    (a b : Staking.Vote) (sa sb : Hash) : Prop :=
  ∀ later, Trace env first later → later.number < first.number+env.evidenceWindow →
    ∃ current, id < later.registry.registry.ledger.nextId ∧
      later.registry.registry.ledger.bonds id = some current ∧
      current.value.key = key ∧ current.value.released = false ∧
      (current.value.balance = 0 ∨ ∀ caller, later.inbox.entered = false →
        ∃ next, registryCall env later caller (.slash id a b sa sb) = some next ∧
          next.receipts = later.receipts ++ ProtocolFinality.slashReceipts env later caller current)

/-- Accountable identities have real lifetime bonds, authentic conflicting evidence and
unconditionally funded future slash transactions whenever principal remains unreleased. -/
def EconomicallyAccountable (env : Environment) (w : World) (c : Consensus.Context) (h : Nat)
    (votesA votesB : List Consensus.Vote) : Prop :=
  Committee.totalPower c.unit (Consensus.activeAt c h).members <
    3*Committee.totalPower c.unit (Finality.overlap c h votesA votesB) ∧
  ∀ entry ∈ Finality.overlap c h votesA votesB, ∃ id bond,
    id < w.registry.registry.ledger.nextId ∧ w.registry.registry.ledger.bonds id = some bond ∧
    bond.value.key = entry.key ∧ ∃ va ∈ votesA, ∃ vb ∈ votesB,
    va.key = entry.key ∧ vb.key = entry.key ∧ ∃ sa sb,
    RegistryMachine.Evidence w.registry.registry (registryView env w) entry.key
      (Accountability.evidence va) (Accountability.evidence vb) sa sb ∧
    FundedFutureLiability env w entry.key (Accountability.evidence va) (Accountability.evidence vb) sa sb

def NoFalseSlash (env : Environment) (w : World) : Prop :=
  ∀ caller id a b sa sb next, registryCall env w caller (.slash id a b sa sb) = some next →
    ∃ bond, id < w.registry.registry.ledger.nextId ∧ w.registry.registry.ledger.bonds id = some bond ∧
      env.signature (Finality.signedVote bond.value.key a) ∧
      env.signature (Finality.signedVote bond.value.key b) ∧
      Staking.doubleSign w.inbox.domain w.inbox.generation a b = true

def WindowRetention (env : Environment) (first : World) : Prop :=
  ∀ later, Trace env first later → ∀ id window bond,
    id < first.registry.registry.ledger.nextId → first.registry.registry.ledger.bonds id = some bond →
    bond.value.released = false → bond.value.confirmedAt = none →
    window ≤ first.registry.registry.config.withdrawalDelay → later.number < first.number+window →
    RegistryMachine.EvidenceClock later.registry.registry id first.number

/-- Economic lifecycle safety at a reachable World. This profile does not assert that
already withdrawn historical committees remain slashable after their legitimate window. -/
def Safety (env : Environment) (w : World) : Prop :=
  RegistryPayments.Backed env.token w.registry ∧ NoFalseSlash env w ∧
    WindowRetention env w ∧ ClosedRegistryHistory w

end Etna.Design.Current.Economics
