import EtnaModel.CurrentEconomics

/-! Normal-execution stake retention. Exceptional verifier-failure rollback is
deliberately outside this trace: RECOV-8-35 does not recover paid withdrawals. -/
namespace Etna.Design.Current.StakeRisk
open RegistryMachine

/-- Public calls and the recovery exclusion at its actual execution block. The
confirmation recheck belongs to exceptional rollback, not normal execution. -/
def NormalAction (now : Nat) : Action → Prop
  | .exclude _ cutoff _ => cutoff = now
  | .recheck _ _ => False
  | _ => True

/-- Actual registry executions with ordinary nondecreasing landed snapshots. No
stake, confirmation, balance, or committee conclusion is supplied by this provenance. -/
inductive NormalTrace : RegistryMachine.World → RegistryMachine.World → Prop
  | refl (w : RegistryMachine.World) : NormalTrace w w
  | call {first : RegistryMachine.World} {s t : RegistryMachine.State}
      {v : InboxView} {now : Nat} (prior : NormalTrace first ⟨s,v,now⟩)
      (action : Action) (normal : NormalAction now action)
      (ok : execute s v now action = some t) : NormalTrace first ⟨t,v,now⟩
  | frame {first : RegistryMachine.World} {s : RegistryMachine.State}
      {v w : InboxView} {now later : Nat} (prior : NormalTrace first ⟨s,v,now⟩)
      (domain : w.domain = v.domain) (generation : v.generation ≤ w.generation)
      (initialized : v.initialized = true → w.initialized = true)
      (time : now ≤ later) (timestamp : v.timestamp ≤ w.timestamp)
      (snapshot : v.snapshot ≤ w.snapshot) : NormalTrace first ⟨s,w,later⟩

/-- Metadata consistency needed by selection, proved from raw Genesis below. -/
def BondMetadata (snapshot : Nat) (b : Staking.Bond) : Prop :=
  (b.released = true → b.balance = 0) ∧
  ((b.released = true ∨ b.confirmedAt ≠ none) → b.exitAt ≤ snapshot)

def Metadata (s : RegistryMachine.State) (snapshot : Nat) : Prop :=
  ∀ id b, s.ledger.bonds id = some b → BondMetadata snapshot b.value

/-- The newest checkpoint is the complete present slot view, when one exists. -/
def HeadCurrent (s : RegistryMachine.State) : Prop :=
  ∀ cp rest, s.history = cp :: rest → cp.entries = entries s

def Retained (s : RegistryMachine.State) (cutoff id : Nat) (key : Hash) : Prop :=
  ∃ b, id < s.ledger.nextId ∧ s.ledger.bonds id = some b ∧ b.value.key = key ∧
    b.value.released = false ∧ b.value.confirmedAt = none ∧ cutoff < b.value.exitAt

/-- Actual overlap identities are still inside a fresh evidence window at the current
checkpoint. Later use derives release status and distinguishes consumed principal from
an executable funded slash; it does not assume a positive original amount forever. -/
def AccountableAtRisk (env : Protocol.Environment) (w : Protocol.World)
    (c : Consensus.Context) (h : Nat) (votesA votesB : List Consensus.Vote) : Prop :=
  Committee.totalPower c.unit (Consensus.activeAt c h).members <
    3*Committee.totalPower c.unit (Finality.overlap c h votesA votesB) ∧
  ∀ entry ∈ Finality.overlap c h votesA votesB, ∃ id bond,
    id < w.registry.registry.ledger.nextId ∧ w.registry.registry.ledger.bonds id = some bond ∧
    bond.value.key = entry.key ∧ bond.value.released = false ∧ bond.value.confirmedAt = none ∧
    ∃ va ∈ votesA, ∃ vb ∈ votesB, va.key = entry.key ∧ vb.key = entry.key ∧ ∃ sa sb,
      RegistryMachine.Evidence w.registry.registry (Protocol.registryView env w) entry.key
        (Accountability.evidence va) (Accountability.evidence vb) sa sb ∧
      Economics.RetainedWindowLiability env w id entry.key
        (Accountability.evidence va) (Accountability.evidence vb) sa sb

end Etna.Design.Current.StakeRisk
