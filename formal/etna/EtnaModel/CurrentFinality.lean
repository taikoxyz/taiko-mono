import EtnaModel.CurrentBlocks
import EtnaModel.CurrentRegistry
import EtnaModel.Locking
import EtnaModel.Accountability

/-! Current committee construction from permanent-registry slot history and authenticated
post-origin EL headers. Fixed L1/crypto/Comet refinements are explicit input contracts;
neither agreement nor slashability is an input. -/
namespace Etna.Design.Current.Finality

structure Config where
  domain : Domain
  generation : Nat
  originHeight : Nat
  originBlock : Nat
  genesisCutoff : Nat
  epochLen : Nat
  unit : Nat
  minimum : Nat
  nMax : Nat
  deriving DecidableEq, Repr

/-- The current registry records snapshots of its 4096 slots, not permanent bond ids. -/
def registryAt (registry : RegistryMachine.State) (cutoff : Nat) : List Committee.Entry :=
  ((RegistryHistory.latestSnapshot registry.history cutoff).map RegistryHistory.Snapshot.entries).getD []

/-- Archive index zero is height S+1. Pre-origin Unzen/old-generation anchors are ignored.
Missing later material gets a total default, but `Ready` requires every queried index. -/
def anchorAt (cfg : Config) (archive : List Blocks.Header) (h : Nat) : Nat :=
  if h ≤ cfg.originHeight then cfg.originBlock
  else ((archive[h-cfg.originHeight-1]?).map (fun header => header.anchor.number)).getD cfg.originBlock

def derive (cfg : Config) (registry : RegistryMachine.State) (archive : List Blocks.Header) : Consensus.Context :=
  ⟨cfg.domain,cfg.generation,cfg.originHeight,cfg.originBlock,cfg.genesisCutoff,cfg.epochLen,
    cfg.unit,cfg.minimum,cfg.nMax,registryAt registry,anchorAt cfg archive⟩

def epoch (cfg : Config) (h : Nat) : Nat := (h-1)/cfg.epochLen

def decisionLookback (cfg : Config) (h : Nat) : Nat := epoch cfg h*cfg.epochLen-2

def initialCutoff (cfg : Config) : Nat := if cfg.generation = 0 then cfg.genesisCutoff else cfg.originBlock

/-- Only post-origin lookbacks need archived headers. S(t) occurring at S+1 with D(t)=S
uses the origin floor, including the first ordinary rotation after an Unzen start. -/
def requiredPrefix (cfg : Config) (h : Nat) : Nat :=
  if cfg.originHeight < epoch cfg h*cfg.epochLen-1 then decisionLookback cfg h-cfg.originHeight else 0

def cutoff (cfg : Config) (archive : List Blocks.Header) (h : Nat) : Nat :=
  if cfg.originHeight < epoch cfg h*cfg.epochLen-1 then
    max (anchorAt cfg archive (decisionLookback cfg h)) cfg.originBlock
  else initialCutoff cfg

/-- Fixed adapters authenticate raw origin/config, EL headers and registry checkpoint data. -/
structure Adapters where
  config : Config → Bool
  header : Blocks.Header → Bool
  snapshot : RegistryHistory.Snapshot → Bool

def Authentic (adapters : Adapters) (cfg : Config) (registry : RegistryMachine.State)
    (archive : List Blocks.Header) : Prop :=
  adapters.config cfg = true ∧ (∀ header ∈ archive, adapters.header header = true) ∧
    (∀ snapshot ∈ registry.history, adapters.snapshot snapshot = true)

/-- Completeness for the exact decision height plus raw current-generation archive shape. -/
def Ready (cfg : Config) (registry : RegistryMachine.State) (archive : List Blocks.Header) (h : Nat) : Prop :=
  3 ≤ cfg.epochLen ∧ cfg.genesisCutoff ≤ cfg.originBlock ∧
  archive.map BlockValidity.Header.height = List.range' (cfg.originHeight+1) archive.length ∧
  (∀ header ∈ archive, header.anchor.generation = cfg.generation ∧ cfg.originBlock ≤ header.anchor.number) ∧
  (archive.map (fun header => header.anchor.number)).Pairwise (· ≤ ·) ∧
  RegistryHistory.Ordered registry.history ∧ requiredPrefix cfg h ≤ archive.length ∧
  (RegistryHistory.latestSnapshot registry.history (initialCutoff cfg)).isSome = true

instance (a : Adapters) (c : Config) (r : RegistryMachine.State) (archive : List Blocks.Header) :
    Decidable (Authentic a c r archive) := inferInstanceAs (Decidable (_ ∧ _))
instance (c : Config) (r : RegistryMachine.State) (archive : List Blocks.Header) (h : Nat) :
    Decidable (Ready c r archive h) := inferInstanceAs (Decidable (_ ∧ _))

def build (adapters : Adapters) (cfg : Config) (registry : RegistryMachine.State)
    (archive : List Blocks.Header) (h : Nat) : Option Consensus.Context :=
  if Ready cfg registry archive h ∧ Authentic adapters cfg registry archive then
    some (derive cfg registry archive) else none

/-- Signed consensus bytes refine to the registry's fixed signature verification adapter.
This says nothing about conflicting values, quorums, or successful slash execution. -/
def SignatureRefinement (registry : RegistryMachine.State) (signature : Consensus.Vote → Prop) : Prop :=
  ∀ vote, signature vote → ∃ sig, registry.verify vote.key (Accountability.evidence vote) sig = true

def overlap (c : Consensus.Context) (h : Nat) (votesA votesB : List Consensus.Vote) : List Committee.Entry :=
  (Consensus.activeAt c h).members.filter fun entry =>
    (votesA.map Consensus.Vote.key).contains entry.key && (votesB.map Consensus.Vote.key).contains entry.key

/-- Derived liability result quantified over all future closed registry transitions.
Newly issued ids are covered too; positivity and nonwithdrawal are checked only at use. -/
def FutureLiability (first : RegistryMachine.World) (key : Hash) (a b : Staking.Vote) (sa sb : Hash) : Prop :=
  ∀ later, RegistryMachine.Trace first later → ∀ id current,
    id < later.registry.ledger.nextId → later.registry.ledger.bonds id = some current →
    current.value.key = key → current.value.released = false → 0 < current.value.balance →
    later.inbox.entered = false →
    ∃ next, RegistryMachine.execute later.registry later.inbox later.now (.slash id a b sa sb) = some next

/-- Same-round H2 conclusion: strict accountable power and executable future liabilities. -/
def Accountable (first : RegistryMachine.World) (c : Consensus.Context) (h : Nat)
    (votesA votesB : List Consensus.Vote) : Prop :=
  Committee.totalPower c.unit (Consensus.activeAt c h).members <
    3*Committee.totalPower c.unit (overlap c h votesA votesB) ∧
  ∀ entry ∈ overlap c h votesA votesB, ∃ va ∈ votesA, ∃ vb ∈ votesB,
    va.key = entry.key ∧ vb.key = entry.key ∧ ∃ sa sb,
    RegistryMachine.Evidence first.registry first.inbox entry.key
      (Accountability.evidence va) (Accountability.evidence vb) sa sb ∧
    FutureLiability first entry.key (Accountability.evidence va) (Accountability.evidence vb) sa sb

/-- One fixed honest engine archive per generation and height. Mode is globally fixed,
not selected by an individual signer or a particular candidate block. -/
structure Engine where
  execution : Nat → Nat → Locking.Execution
  honest : Nat → Nat → Hash → Bool
  mode : Bool

def HonestAt (engine : Engine) (cfg : Config) (context : Consensus.Context) (h : Nat) : Prop :=
  Locking.HonestRules context.unit (Consensus.activeAt context h).members
    (engine.honest cfg.generation h) engine.mode (engine.execution cfg.generation h) ∧
  Locking.Minority context.unit (Consensus.activeAt context h).members (engine.honest cfg.generation h)

/-- Honest local rules and minority bounds at the concrete heights checked by a chain. -/
def ChainHonesty (engine : Engine) (cfg : Config) (policy : Blocks.GenerationPolicy)
    (p : Blocks.Header) (bs : List Blocks.Block) : Prop :=
  ∀ pair ∈ Blocks.pairs p bs, HonestAt engine cfg policy.consensus pair.2.header.height

/-- Nonnil authentication applies to every concrete accepted certificate in this chain. -/
def ChainAttribution (engine : Engine) (cfg : Config) (p : Blocks.Header) (bs : List Blocks.Block) : Prop :=
  ∀ pair ∈ Blocks.pairs p bs, Locking.CommitAttribution
    (engine.execution cfg.generation pair.2.header.height)
    pair.2.body.round pair.2.header.cometHash pair.2.body.votes

/-- Canonical Comet envelope/hash decoding and deterministic EL execution on one complete
parent bind the resulting full header. This contract is only for individually validated
bodies under these fixed policies. It does not equate bodies or own-commit vote lists:
those votes need not be committed by their block's own Comet hash. -/
def CometHeaderBinding (a b : Blocks.GenerationPolicy) : Prop :=
  ∀ parent x y, Blocks.Valid a parent x → Blocks.Valid b parent y →
    x.header.cometHash = y.header.cometHash → x.header = y.header

/-- Equality at every overlapping position; one chain may extend the other. -/
def HeaderAgreement : List Blocks.Header → List Blocks.Header → Prop
  | [], _ => True
  | _, [] => True
  | a :: as, b :: bs => a = b ∧ HeaderAgreement as bs

end Etna.Design.Current.Finality
