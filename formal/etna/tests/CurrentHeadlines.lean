import EtnaProofs.Headline.Current

/-! Public current theorem contracts, specialized with explicit primitive premises.
The exact declaration-type checks and negative audit probes live in the Python companion. -/
namespace Etna.CurrentHeadlineRegression
open Etna.Design Etna.Design.Current Etna.Design.Current.Protocol
open Etna.Statements.Current

example : Claims = (FundSafety ∧ AccountableFinality ∧ ForcedInclusionIntegrity) := rfl
example : FundSafety := Headlines.fund_safety
example : AccountableFinality := Headlines.accountable_finality

-- Only cross-round agreement is conditional on honest execution. Same-round
-- accountability, H1 and H3 remain available without that assumption.
example : AccountableFinality =
    (∀ env registry engine, Premises env registry engine → ∀ w,
      Trace env (empty env registry) w → w.initialized = true →
      ProtocolFinality.CurrentAccountability env w ∧
        (ProtocolFinality.HonestExecutions engine env w →
          ProtocolFinality.CurrentAgreement env w)) := rfl
example : ForcedInclusionIntegrity := Headlines.forced_inclusion_integrity

-- All three universally quantified claims compose under the actual explicit Premises.
example : Claims := by
  refine ⟨?_,?_,?_⟩
  · intro env registry engine premises w trace
    exact Headlines.fund_safety env registry engine premises w trace
  · intro env registry engine premises w trace initialized
    exact Headlines.accountable_finality env registry engine premises w trace initialized
  · intro env registry engine premises w trace
    exact Headlines.forced_inclusion_integrity env registry engine premises w trace

example (env : Environment) (registry : RegistryMachine.State) (engine : Finality.Engine)
    (premises : Premises env registry engine) (w : World)
    (run : Trace env (empty env registry) w) (initialized : w.initialized = true) :
    ProtocolFinality.CurrentAccountability env w :=
  (Headlines.claims.2.1 env registry engine premises w run initialized).1

example (env : Environment) (registry : RegistryMachine.State) (engine : Finality.Engine)
    (premises : Premises env registry engine) (w : World)
    (run : Trace env (empty env registry) w) (initialized : w.initialized = true)
    (honesty : ProtocolFinality.HonestExecutions engine env w) :
    ProtocolFinality.H2 env w :=
  let result := Headlines.claims.2.1 env registry engine premises w run initialized
  ⟨result.1,result.2 honesty⟩

example (env : Environment) (registry : RegistryMachine.State) (engine : Finality.Engine)
    (premises : Premises env registry engine) (w : World)
    (run : Trace env (empty env registry) w) (a : Landing) (t : World)
    (accepted : land env w a = some t) :
    (∃ segment : Suffix env w a, Custody.Path env (empty env registry) segment.parent ∧
      Custody.Path env (empty env registry) (Blocks.terminal segment.parent segment.blocks)) ∧
    LandingService env w t a :=
  ⟨(Headlines.claims.1 env registry engine premises w run).2 a t accepted,
    (Headlines.claims.2.2 env registry engine premises w run).2.1 a t accepted⟩

-- The public H3 action uses the environment's admitted transaction hash, not an unrelated
-- interpreter hash; both direct-anchor and age-adjusted inclusive deadlines are exposed.
example (env : Environment) (registry : RegistryMachine.State) (engine : Finality.Engine)
    (premises : Premises env registry engine) (w : World)
    (run : Trace env (empty env registry) w) (archive : List Header) (reference : Nat)
    (parent : Header) (block : Block) (entry : Forced.Entry)
    (valid : Blocks.Valid (policy env w archive reference) parent block)
    (queued : (parent.cursor,entry) ∈ w.queue)
    (due : entry.timestamp+w.inbox.forcedDelay ≤ block.header.anchor.timestamp ∨
      entry.timestamp+w.inbox.forcedDelay+w.inbox.maxAnchorAge ≤ block.header.timestamp) :
    block.header.cursor = parent.cursor+1 ∧
      ActualQueue.ByteAction (bytes env (Blocks.definition (policy env w archive reference) block))
        parent block.body entry block.raw block.first :=
  (Headlines.claims.2.2 env registry engine premises w run).2.2.1
    archive reference parent block entry valid queued due

example (env : Environment) (registry : RegistryMachine.State) (engine : Finality.Engine)
    (premises : Premises env registry engine) (w : World) (archive : List Header)
    (reference : Nat) (parent : Header) (block : Block)
    (valid : Blocks.Valid (policy env w archive reference) parent block) :
    bytes env (Blocks.definition (policy env w archive reference) block) =
      (Blocks.definition (policy env w archive reference) block).bytes :=
  Headlines.catalogue_bytes premises.currentCatalogueHash valid

def mismatchedDefinition : Blocks.Definition :=
  ⟨fun _ _ => true,fun _ _ _ => true,⟨fun _ => 7,fun _ => false,fun _ _ _ => .unavailable⟩⟩

-- Dropping CatalogueHash changes the mathematical result: normalization is not free.
example (env : Environment) :
    bytes {env with txHash := fun _ => 8} mismatchedDefinition ≠ mismatchedDefinition.bytes := by
  intro equal
  have wrong := congrArg (fun primitive : ActualQueue.Primitives => primitive.hashBytes []) equal
  change (8 : Nat) = 7 at wrong
  cases wrong

example (env : Environment) :
    ¬ CatalogueHash {env with txHash := fun _ => 8,catalogue := fun _ => some mismatchedDefinition} := by
  intro hashes
  have same := congrFun (hashes 0 mismatchedDefinition rfl) []
  change (7 : Nat) = 8 at same
  cases same

end Etna.CurrentHeadlineRegression
