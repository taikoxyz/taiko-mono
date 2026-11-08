import EtnaProofs.Headline.Current

/-! Public current theorem contracts, specialized with explicit primitive premises.
The exact declaration-type checks and negative audit probes live in the Python companion. -/
namespace Etna.CurrentHeadlineRegression
open Etna.Design Etna.Design.Current Etna.Design.Current.Protocol
open Etna.Statements.Current

example : Claims = (FundSafety ∧ AccountableFinality ∧ ForcedInclusionIntegrity ∧ Recoverability) := rfl
example : FundSafety := Headlines.fund_safety
example : AccountableFinality := Headlines.accountable_finality
example : Recoverability := Headlines.recoverability

-- H4 is stated over its own record `RecoveryPremises` and the per-state hypothesis `LiveAt`,
-- with no engine and no H2/H3 premise.
example : Recoverability =
    (∀ env registry, RecoveryPremises env registry → ∀ w,
      Trace env (empty env registry) w → w.initialized = true → LiveAt env w →
      RecoverableAt env w) := rfl
example (env : Environment) (registry : RegistryMachine.State) (premises : RecoveryPremises env registry) :
    FundPremises env registry :=
  premises.toFundPremises

-- H1 is stated over the five fund premises alone, with no engine and no consensus premise;
-- the full record supplies them.
example : FundSafety =
    (∀ env registry, FundPremises env registry → ∀ w,
      Trace env (empty env registry) w → FundSafetyAt env registry w) := rfl
example (env : Environment) (registry : RegistryMachine.State) (engine : Finality.Engine)
    (premises : Premises env registry engine) : FundPremises env registry :=
  premises.toFundPremises

-- Honest execution is an explicit antecedent of cross-round agreement only.
example : AccountableFinality =
    (∀ env registry engine, Premises env registry engine → ∀ w,
      Trace env (empty env registry) w → w.initialized = true →
      EconomicAccountability env w ∧ Economics.Safety env w ∧
      Economics.HistoricalStakeFunded env w ∧ TemporalAuthority env w ∧
        (ProtocolFinality.HonestExecutions engine env w →
          ProtocolFinality.CurrentAgreement env w) ∧ NormalAccountability env registry w ∧ NormalCommitteeRetention env registry w) := rfl
example : ForcedInclusionIntegrity := Headlines.forced_inclusion_integrity

-- All universally quantified public claims compose under the same primitive record.
example : Claims := by
  refine ⟨?_,?_,?_,?_⟩
  · intro env registry premises w trace
    exact Headlines.fund_safety env registry premises w trace
  · intro env registry engine premises w trace initialized
    exact Headlines.accountable_finality env registry engine premises w trace initialized
  · intro env registry engine premises w trace
    exact Headlines.forced_inclusion_integrity env registry engine premises w trace
  · intro env registry premises w trace initialized live
    exact Headlines.recoverability env registry premises w trace initialized live

-- The existential map precedes the universal signal binder: every retained signal is
-- authorized by the SAME retained header/parent chain, with an explicit waiting case.
example (env : Environment) (registry : RegistryMachine.State) (engine : Finality.Engine)
    (premises : Premises env registry engine) (w : World)
    (run : Trace env (empty env registry) w) :
    Custody.Waiting env w ∨ ∃ H : Checkpoint → Header,
      w.activeRecords.head? = some w.inbox.checkpoint ∧
      (∀ cp ∈ w.activeRecords, Custody.HeaderOf cp (H cp) ∧ HashBound env (H cp)) ∧
      Custody.Linked env (empty env registry) w.start H w.activeRecords ∧
      ∀ signal ∈ w.inbox.signals, ∃ cp ∈ w.activeRecords,
        cp.height = signal.height ∧ cp.elHash = signal.hash ∧ (H cp).stateRoot = signal.stateRoot :=
  (Headlines.claims.1 env registry premises.toFundPremises w run).1

example (env : Environment) (registry : RegistryMachine.State) (engine : Finality.Engine)
    (premises : Premises env registry engine) (w other : World)
    (run : Trace env (empty env registry) w) (a : Landing)
    (same : statement env other a = statement env w a) :
    referencePrefix other a.input.l1ReferenceBlockNumber = referencePrefix w a.input.l1ReferenceBlockNumber :=
  (Headlines.claims.1 env registry premises.toFundPremises w run).2.2.2.2.1 other a same

-- The full15 primitive profile also rejects start rewriting and prevents a legacy
-- checkpoint from reaching any Etna checkpoint on a switching deployment.
example (env : Environment) (registry : RegistryMachine.State) (engine : Finality.Engine)
    (premises : Premises env registry engine) (w : World)
    (run : Trace env (empty env registry) w) (start : StartData) (written : w.start = some start)
    (caller height hash root : Nat) : setOrigin env w caller height hash root = none :=
  (Headlines.fund_safety env registry premises.toFundPremises w run).2.2.2.2.2.2.1
    start written caller height hash root

example (env : Environment) (registry : RegistryMachine.State) (engine : Finality.Engine)
    (premises : Premises env registry engine) (w : World)
    (run : Trace env (empty env registry) w) (switching : env.core.unzenInbox ≠ 0) :
    Custody.LegacyEtnaDisjoint w :=
  ((Headlines.fund_safety env registry premises.toFundPremises w run).2.2.2.2.2.2.2 switching).1

example (env : Environment) (registry : RegistryMachine.State) (engine : Finality.Engine)
    (premises : Premises env registry engine) (w : World)
    (history : Governance.DeployedTrace env (empty env registry) w)
    (authorization : Governance.AuthorizedUpgrades history) (initialized : w.initialized = true) :
    FundSafetyAt env registry w ∧ AccountableFinalityAt env registry engine w ∧ ForcedInclusionAt env w :=
  Headlines.deployed_claims premises history authorization initialized

-- H4 on an actual raw DAO history, under the same per-upgrade authorization.
example (env : Environment) (registry : RegistryMachine.State) (premises : RecoveryPremises env registry)
    (w : World) (history : Governance.DeployedTrace env (empty env registry) w)
    (authorization : Governance.AuthorizedUpgrades history) (initialized : w.initialized = true)
    (live : LiveAt env w) : RecoverableAt env w :=
  Headlines.deployed_recoverability premises history authorization initialized live

-- H4 is the fourth conjunct of the claims.
example (env : Environment) (registry : RegistryMachine.State) (premises : RecoveryPremises env registry)
    (w : World) (trace : Trace env (empty env registry) w) (initialized : w.initialized = true)
    (live : LiveAt env w) :
    ∃ u a t, RecoveryTrace env w u ∧ land env u a = some t ∧
      (w.everLanded = true → w.inbox.checkpoint.height < t.inbox.checkpoint.height) :=
  Headlines.claims.2.2.2 env registry premises w trace initialized live

-- Economic accountability, reserve/clock safety, historical stake provenance and
-- temporal authority are all usable before supplying the agreement honesty condition.
example (env : Environment) (registry : RegistryMachine.State) (engine : Finality.Engine)
    (premises : Premises env registry engine) (w : World)
    (run : Trace env (empty env registry) w) (initialized : w.initialized = true) :
    EconomicAccountability env w ∧ Economics.Safety env w ∧
      Economics.HistoricalStakeFunded env w ∧ TemporalAuthority env w := by
  obtain ⟨economic,safe,historical,temporal,_⟩ :=
    Headlines.claims.2.1 env registry engine premises w run initialized
  exact ⟨economic,safe,historical,temporal⟩

example (env : Environment) (registry : RegistryMachine.State) (engine : Finality.Engine)
    (premises : Premises env registry engine) (w : World)
    (run : Trace env (empty env registry) w) (initialized : w.initialized = true)
    (honesty : ProtocolFinality.HonestExecutions engine env w) :
    ProtocolFinality.CurrentAgreement env w :=
  (Headlines.claims.2.1 env registry engine premises w run initialized).2.2.2.2.1 honesty

example (env : Environment) (registry : RegistryMachine.State) (engine : Finality.Engine)
    (premises : Premises env registry engine) (w : World)
    (run : Trace env (empty env registry) w) (a : Landing) (t : World)
    (accepted : land env w a = some t) :
    (∃ segment : Suffix env w a, Custody.Path env (empty env registry) segment.parent ∧
      Custody.Path env (empty env registry) (Blocks.terminal segment.parent segment.blocks)) ∧
    LandingService env w t a :=
  ⟨(Headlines.claims.1 env registry premises.toFundPremises w run).2.2.1 a t accepted,
    (Headlines.claims.2.2.1 env registry engine premises w run).2.2.1 a t accepted⟩

example (env : Environment) (registry : RegistryMachine.State) (engine : Finality.Engine)
    (premises : Premises env registry engine) (w : World)
    (trace : Trace env (empty env registry) w) (initialized : w.initialized = true) :
    NormalAccountability env registry w :=
  (Headlines.accountable_finality env registry engine premises w trace initialized).2.2.2.2.2.1

-- Every consumed segment exposes complete-payload position zero and a due-qualified
-- skip, using the admission hash normalized by the selected interpreter refinement.
example (env : Environment) (registry : RegistryMachine.State) (engine : Finality.Engine)
    (premises : Premises env registry engine) (w : World)
    (run : Trace env (empty env registry) w) (a : Landing) (t : World)
    (accepted : land env w a = some t) :
    ∃ segment : Suffix env w a,
      (Blocks.consumingPairs segment.parent segment.blocks).map (fun x => x.1.cursor) =
        List.range' w.inbox.head (t.inbox.head-w.inbox.head) ∧
      (∀ x ∈ Blocks.consumingPairs segment.parent segment.blocks,
        ∃ entry, (x.1.cursor,entry) ∈ w.queue ∧ x.2.first = x.2.transactions.head? ∧
          (Blocks.Included (bytes env (Blocks.definition
            (policy env w segment.archive a.input.l1ReferenceBlockNumber) x.2)) entry x.2.first ∨
           (entry.timestamp+w.inbox.forcedDelay ≤ x.2.body.header.anchor.timestamp ∧
            Blocks.Skipped (bytes env (Blocks.definition
              (policy env w segment.archive a.input.l1ReferenceBlockNumber) x.2))
              x.1 x.2.body entry x.2.raw))) ∧ t.queue = w.queue :=
  (Headlines.claims.2.2.1 env registry engine premises w run).2.2.1 a t accepted

-- Both direct-anchor and age-adjusted inclusive deadlines remain public.
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
  (Headlines.claims.2.2.1 env registry engine premises w run).2.2.2.1
    archive reference parent block entry valid queued due

example (env : Environment) (registry : RegistryMachine.State) (engine : Finality.Engine)
    (premises : Premises env registry engine) (w : World)
    (run : Trace env (empty env registry) w) (archive : List Header) (reference : Nat)
    (parent : Header) (block : Block) (entry : Forced.Entry)
    (valid : Blocks.Valid (policy env w archive reference) parent block)
    (consumed : block.header.cursor = parent.cursor+1) (queued : (parent.cursor,entry) ∈ w.queue)
    (early : block.header.anchor.timestamp < entry.timestamp+w.inbox.forcedDelay) :
    Blocks.Included (bytes env (Blocks.definition (policy env w archive reference) block)) entry block.transactions.head? :=
  (Headlines.claims.2.2.1 env registry engine premises w run).2.2.2.2.1
    archive reference parent block entry valid consumed queued early

example (env : Environment) (registry : RegistryMachine.State) (engine : Finality.Engine)
    (premises : Premises env registry engine) (w : World)
    (run : Trace env (empty env registry) w) (request : RecoveryRequest) (t : World)
    (accepted : recover env w request = some t) :
    t.inbox.head = w.inbox.head ∧ t.queue = w.queue.map (fun (i,e) =>
      (i,if i ∈ request.clear then Forced.clear (emptyHash env) e else e)) ∧
    request.clear.Pairwise (· < ·) ∧ ∀ i ∈ request.clear, w.inbox.head ≤ i ∧ i < w.inbox.tail :=
  (Headlines.claims.2.2.1 env registry engine premises w run).2.2.2.2.2.2.2.1 request t accepted

example (env : Environment) (registry : RegistryMachine.State) (engine : Finality.Engine)
    (premises : Premises env registry engine) (w : World)
    (run : Trace env (empty env registry) w) (a : Landing) (t : World)
    (accepted : land env w a = some t) :
    ∃ proof ∈ a.proofs, ∃ archive parent blocks,
      BatchCertificate env w (statement env w a) archive parent blocks ∧
        ∀ block ∈ blocks, Blocks.selectedRules block ∈ env.imageRules proof.image :=
  (Headlines.claims.2.2.1 env registry engine premises w run).2.2.2.2.2.2.2.2.1 a t accepted

example (env : Environment) (registry : RegistryMachine.State) (engine : Finality.Engine)
    (premises : Premises env registry engine) (w : World)
    (run : Trace env (empty env registry) w) (raw : Blocks.Bytes) (paid : Nat) (refund : Bool) (t : World)
    (accepted : enqueue env w raw paid refund = some t) :
    QueueIntegrity.AdmissionAccounting w.inbox t.inbox raw.length paid refund :=
  (Headlines.claims.2.2.1 env registry engine premises w run).2.2.2.2.2.2.2.2.2.1 raw paid refund t accepted

example (env : Environment) (registry : RegistryMachine.State) (engine : Finality.Engine)
    (premises : Premises env registry engine) (w : World)
    (run : Trace env (empty env registry) w) (candidate : Import.Candidate) (durable : Bool) (t : World)
    (accepted : nodeImport env w candidate durable = some t) :
    t.node.trusted = false ∧ t.node.signer = {w.node.signer with ready := false} ∧
      ∀ n, n ∈ t.node.importedHeaders ↔ w.inbox.origin.height ≤ n ∧
        candidate.height+1 ≤ n+w.inbox.configuration.unsettled ∧ n ≤ candidate.height :=
  (Headlines.claims.2.2.1 env registry engine premises w run).2.2.2.2.2.2.2.2.2.2 candidate durable t accepted

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


-- Both sides of S are exported; this is stronger than pairwise lane disjointness.
example (env : Environment) (registry : RegistryMachine.State) (engine : Finality.Engine)
    (premises : Premises env registry engine) (w : World)
    (run : Trace env (empty env registry) w) (switching : env.core.unzenInbox ≠ 0) :
    Custody.SwitchingFence env w :=
  ((Headlines.fund_safety env registry premises.toFundPremises w run).2.2.2.2.2.2.2 switching).2

end Etna.CurrentHeadlineRegression
