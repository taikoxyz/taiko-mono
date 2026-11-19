import EtnaStatements

/-! H4 statement surface: which calls `RecoveryCall` admits (no rollback; plain recoveries with
any exclusions and no blanking; every other call), the trace class
`RecoveryTrace`, the conclusion `RecoverableAt`, the claim `Recoverability`, the predicate
`LiveRules`, and the field names, types and order of `LiveAt` and `RecoveryPremises`. -/
namespace Etna.CurrentRecoveryRegression
open Etna.Design Etna.Design.Current Etna.Design.Current.Protocol Etna.Statements.Current

-- RecoveryCall, whatever the state: rollback, recoveries with clears and recoveries with an
-- upgrade are out; a plain recovery with any exclusions and the catch-all arm are in.
example (caller : Nat) (trusted : Checkpoint) (snapshot : Nat) :
    ¬ RecoveryCall (.rollback caller trusted snapshot) := id
example (r : RecoveryRequest) (i : Nat) :
    ¬ RecoveryCall (.recover { r with clear := [i] }) := fun h => nomatch h.1
example (r : RecoveryRequest) (xs : List (Nat × Hash)) (h2 : r.clear = []) (h3 : r.upgrade = none) :
    RecoveryCall (.recover { r with exclusions := xs }) := ⟨h2,h3⟩
-- Any upgrade, even one that reinstalls the current parameters, is out.
example (w : World) (r : RecoveryRequest) :
    ¬ RecoveryCall (.recover { r with upgrade := some (parametersOf w.inbox) }) := by
  rintro ⟨-,absent⟩
  cases absent
example (a : Landing) : RecoveryCall (.land a) := trivial

-- Pin the trace class and the conclusion.
example (env : Environment) : RecoveryTrace env = CallTrace env RecoveryCall := rfl
example (env : Environment) (w : World) :
    RecoverableAt env w = ∃ u a t, RecoveryTrace env w u ∧ land env u a = some t ∧
      (w.everLanded = true → w.inbox.checkpoint.height < t.inbox.checkpoint.height) := rfl
example : Recoverability = ∀ env registry, RecoveryPremises env registry → ∀ w,
    Trace env (empty env registry) w → w.initialized = true → LiveAt env w →
    RecoverableAt env w := rfl

-- Pin LiveRules: the first case keeps the current rulesets; the second installs ruleset
-- nextRules + 1.
example (env : Environment) (w : World) : LiveRules env w =
    ((RulesetLive env w.schedule.active ∧ RulesetLive env w.schedule.next ∧
        ∃ image, w.schedule.active ∈ env.imageRules image ∧ w.schedule.next ∈ env.imageRules image) ∨
      (RulesetLive env (w.schedule.next+1) ∧ ∃ image, w.schedule.next+1 ∈ env.imageRules image)) := rfl

-- Pin LiveAt's exact fields: types and order, then names.
example (env : Environment) (w : World)
    (a : w.inbox.generation+2 < limit48) (b : w.inbox.recoveryNonce+1 < limit256)
    (c : w.schedule.next+1 < limit48) (d : w.inbox.checkpoint.height+1 < limit48)
    (e : ∃ n keys exclusions, w.number < n ∧ n+4 < limit48 ∧ WindowBound env w ≤ env.time n ∧
      env.time n+8 < limit256 ∧ exclusions.Pairwise (fun x y => x.1 < y.1) ∧
      RegistryMachine.exclusionsValid w.registry.registry exclusions = true ∧
      CommitteeLive env (excluded w n exclusions) n keys)
    (f : LiveRules env w) (g : UnzenLaneLive env w) :
    LiveAt env w := ⟨a,b,c,d,e,f,g⟩
example (env : Environment) (w : World)
    (a : w.inbox.generation+2 < limit48) (b : w.inbox.recoveryNonce+1 < limit256)
    (c : w.schedule.next+1 < limit48) (d : w.inbox.checkpoint.height+1 < limit48)
    (e : ∃ n keys exclusions, w.number < n ∧ n+4 < limit48 ∧ WindowBound env w ≤ env.time n ∧
      env.time n+8 < limit256 ∧ exclusions.Pairwise (fun x y => x.1 < y.1) ∧
      RegistryMachine.exclusionsValid w.registry.registry exclusions = true ∧
      CommitteeLive env (excluded w n exclusions) n keys)
    (f : LiveRules env w) (g : UnzenLaneLive env w) : LiveAt env w :=
  { generation := a, nonce := b, rules := c, height := d, window := e, ruleset := f, unzen := g }

-- Pin RecoveryPremises: it extends FundPremises with exactly these six fields.
example (env : Environment) (registry : RegistryMachine.State) (f : FundPremises env registry)
    (a : ∀ m n, m < n → env.time m < env.time n) (b : CatalogueHash env)
    (c : ProofComplete env) (d : PayloadLive env) (e : UnzenStartUsable env)
    (readable : ∀ history n, history.map Snapshot.number = List.range (n+1) → env.blockHash history n ≠ 0) :
    RecoveryPremises env registry := ⟨f,a,b,c,d,e,readable⟩
example (env : Environment) (registry : RegistryMachine.State) (f : FundPremises env registry)
    (a : ∀ m n, m < n → env.time m < env.time n) (b : CatalogueHash env)
    (c : ProofComplete env) (d : PayloadLive env) (e : UnzenStartUsable env)
    (readable : ∀ history n, history.map Snapshot.number = List.range (n+1) → env.blockHash history n ≠ 0) :
    RecoveryPremises env registry :=
  { toFundPremises := f, recoveryClock := a, recoveryCatalogueHash := b, proofComplete := c,
    payloadLive := d, unzenStart := e, referenceReadable := readable }

end Etna.CurrentRecoveryRegression
