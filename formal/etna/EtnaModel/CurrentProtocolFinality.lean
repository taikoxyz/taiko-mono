import EtnaModel.CurrentProtocol

/-! Current H2 over the actual protocol transaction machine and its atomic payment wrapper.
Token refinement and available token balance remain primitive conditions, not successful
principal slashing or a supplied registry frame invariant. -/
namespace Etna.Design.Current.ProtocolFinality
open Protocol

def StandardToken (env : Environment) : Prop :=
  env.token.transfer = RegistryPayments.standardTransfer env.token.registryAddress

def slashReceipts (env : Environment) (w : World) (caller : Nat) (bond : Registry.Bond) :
    List RegistryPayments.Payment :=
  [⟨env.token.registryAddress,caller,
      Staking.fraction bond.value.balance w.registry.registry.config.slashBountyBps,false⟩,
   ⟨env.token.registryAddress,env.token.slashSink,
      bond.value.balance-Staking.fraction bond.value.balance w.registry.registry.config.slashBountyBps,false⟩]

/-- Executable outer transactions, including token transfers and concrete receipt append.
Every issued positive unwithdrawn bond of the evidenced key is quantified at the future
state, even if displaced or in a later generation. -/
def PaidFutureLiability (env : Environment) (first : World) (key : Hash)
    (a b : Staking.Vote) (sa sb : Hash) : Prop :=
  ∀ later, Trace env first later → ∀ id current caller,
    id < later.registry.registry.ledger.nextId → later.registry.registry.ledger.bonds id = some current →
    current.value.key = key → current.value.released = false → 0 < current.value.balance →
    later.inbox.entered = false → current.value.balance ≤ later.registry.token.balances env.token.registryAddress →
    ∃ next, registryCall env later caller (.slash id a b sa sb) = some next ∧
      next.receipts = later.receipts ++ slashReceipts env later caller current

/-- Same-round accountable power with actual future paid protocol transactions. -/
def PaidAccountable (env : Environment) (w : World) (c : Consensus.Context) (h : Nat)
    (votesA votesB : List Consensus.Vote) : Prop :=
  Committee.totalPower c.unit (Consensus.activeAt c h).members <
    3*Committee.totalPower c.unit (Finality.overlap c h votesA votesB) ∧
  ∀ entry ∈ Finality.overlap c h votesA votesB, ∃ va ∈ votesA, ∃ vb ∈ votesB,
    va.key = entry.key ∧ vb.key = entry.key ∧ ∃ sa sb,
    RegistryMachine.Evidence w.registry.registry (registryView env w) entry.key
      (Accountability.evidence va) (Accountability.evidence vb) sa sb ∧
    PaidFutureLiability env w entry.key (Accountability.evidence va) (Accountability.evidence vb) sa sb

/-- Canonical codec/deterministic EL binding for the fixed current environment interpreters. -/
def CodecSound (env : Environment) (w : World) : Prop :=
  ∀ archiveA archiveB referenceA referenceB,
    Finality.CometHeaderBinding (policy env w archiveA referenceA) (policy env w archiveB referenceB)

/-- Actual honest local RoundStep rules and strict Byzantine minority at each checked
height. The engine is fixed; the premise is about execution events, never agreement. -/
def HonestExecutions (engine : Finality.Engine) (env : Environment) (w : World) : Prop :=
  ∀ origin blocks reference, origin.height = w.inbox.origin.height →
    Blocks.Chain (policy env w (blocks.map Blocks.Block.header) reference) origin blocks →
    Finality.ChainHonesty engine (config w)
      (policy env w (blocks.map Blocks.Block.header) reference) origin blocks

/-- Fixed signature/stock-Comet refinement attributes every concrete nonnil commit. -/
def VoteAttribution (engine : Finality.Engine) (env : Environment) (w : World) : Prop :=
  ∀ origin blocks reference, origin.height = w.inbox.origin.height →
    Blocks.Chain (policy env w (blocks.map Blocks.Block.header) reference) origin blocks →
    Finality.ChainAttribution engine (config w) origin blocks

def CurrentAccountability (env : Environment) (w : World) : Prop :=
  ∀ common moreA moreB referenceA referenceB h round a b votesA votesB,
    Finality.requiredPrefix (config w) h ≤ common.length →
    Consensus.CommitValid (policy env w (common ++ moreA) referenceA).consensus env.signature h round a votesA →
    Consensus.CommitValid (policy env w (common ++ moreB) referenceB).consensus env.signature h round b votesB →
    a ≠ b → PaidAccountable env w (policy env w (common ++ moreA) referenceA).consensus h votesA votesB

/-- Complete chains use their own actual header arrays and the actual current registry
history. No equality of derived contexts or full archives is assumed. -/
def CurrentAgreement (env : Environment) (w : World) : Prop :=
  ∀ origin as bs referenceA referenceB, origin.height = w.inbox.origin.height →
    Blocks.Chain (policy env w (as.map Blocks.Block.header) referenceA) origin as →
    Blocks.Chain (policy env w (bs.map Blocks.Block.header) referenceB) origin bs →
    Finality.HeaderAgreement (as.map Blocks.Block.header) (bs.map Blocks.Block.header)

def H2 (env : Environment) (w : World) : Prop := CurrentAccountability env w ∧ CurrentAgreement env w

end Etna.Design.Current.ProtocolFinality
