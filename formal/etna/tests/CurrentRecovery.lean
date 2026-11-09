import EtnaStatements

/-! H4 statement surface: which calls `RecoveryCall` admits in a state (no rollback; recoveries
with no exclusions and no blanking that are plain or change only K; every other call), the
trace class `RecoveryTrace`, the conclusion `RecoverableAt`, the claim `Recoverability`, the
predicates `OnGrid` and `LiveRules`, and the field names, types and order of `LiveAt` and
`RecoveryPremises`. -/
namespace Etna.CurrentRecoveryRegression
open Etna.Design Etna.Design.Current Etna.Design.Current.Protocol Etna.Statements.Current

-- RecoveryCall, in the state `w` the call applies to: rollback and recoveries with exclusions or
-- clears are out, and so is an upgrade that changes anything but K; a plain recovery, a
-- structural recovery that installs `w`'s parameters with a new K, and the catch-all arm are in.
example (w : World) (caller : Nat) (trusted : Checkpoint) (snapshot : Nat) :
    ¬ RecoveryCall w (.rollback caller trusted snapshot) := id
example (w : World) (r : RecoveryRequest) (x : Nat × Hash) :
    ¬ RecoveryCall w (.recover { r with exclusions := [x] }) := fun h => nomatch h.1
example (w : World) (r : RecoveryRequest) (i : Nat) :
    ¬ RecoveryCall w (.recover { r with clear := [i] }) := fun h => nomatch h.2.1
example (w : World) (r : RecoveryRequest) (h1 : r.exclusions = []) (h2 : r.clear = []) (h3 : r.upgrade = none) :
    RecoveryCall w (.recover r) := ⟨h1,h2,.inl h3⟩
example (w : World) (r : RecoveryRequest) (k : Nat) (h1 : r.exclusions = []) (h2 : r.clear = []) :
    RecoveryCall w (.recover { r with upgrade := some { parametersOf w.inbox with gridK := k } }) :=
  ⟨h1,h2,.inr ⟨k,rfl⟩⟩
-- An upgrade that changes another parameter, here the forced-inclusion delay, is out.
example (w : World) (r : RecoveryRequest) :
    ¬ RecoveryCall w (.recover { r with upgrade := some { parametersOf w.inbox with forcedDelay := w.inbox.forcedDelay+1 } }) := by
  rintro ⟨-,-,absent | ⟨k,same⟩⟩
  · cases absent
  · have delay := congrArg Parameters.forcedDelay (Option.some.inj same)
    change w.inbox.forcedDelay+1 = w.inbox.forcedDelay at delay
    omega
example (w : World) (a : Landing) : RecoveryCall w (.land a) := trivial

-- Pin the trace class and the conclusion.
example (env : Environment) : RecoveryTrace env = CallTrace env RecoveryCall := rfl
example (env : Environment) (w : World) :
    RecoverableAt env w = ∃ u a t, RecoveryTrace env w u ∧ land env u a = some t ∧
      (w.everLanded = true → w.inbox.checkpoint.height < t.inbox.checkpoint.height) := rfl
example : Recoverability = ∀ env registry, RecoveryPremises env registry → ∀ w,
    Trace env (empty env registry) w → w.initialized = true → LiveAt env w →
    RecoverableAt env w := rfl

-- Pin OnGrid and LiveRules: the first case keeps the current rulesets and needs c on the grid;
-- the second installs ruleset nextRules + 1 and has no grid condition.
example (w : World) : OnGrid w = ∀ start, w.start = some start →
    Start.onGrid start.height w.inbox.gridK w.inbox.checkpoint.height = true := rfl
example (env : Environment) (w : World) : LiveRules env w =
    ((OnGrid w ∧ RulesetLive env w.schedule.active ∧ RulesetLive env w.schedule.next ∧
        ∃ image, w.schedule.active ∈ env.imageRules image ∧ w.schedule.next ∈ env.imageRules image) ∨
      (RulesetLive env (w.schedule.next+1) ∧ ∃ image, w.schedule.next+1 ∈ env.imageRules image)) := rfl

-- Pin LiveAt's exact fields: types and order, then names. No field mentions the grid.
example (env : Environment) (w : World)
    (a : w.inbox.generation+2 < limit48) (b : w.inbox.recoveryNonce+1 < limit256)
    (c : w.schedule.next+1 < limit48) (d : w.inbox.checkpoint.height+w.inbox.gridK < limit48)
    (e : ∃ n keys, w.number < n ∧ n+4 < limit48 ∧ WindowBound env w ≤ env.time n ∧
      env.time n+8 < limit256 ∧ CommitteeLive env w n keys)
    (f : LiveRules env w) (g : UnzenLaneLive env w) :
    LiveAt env w := ⟨a,b,c,d,e,f,g⟩
example (env : Environment) (w : World)
    (a : w.inbox.generation+2 < limit48) (b : w.inbox.recoveryNonce+1 < limit256)
    (c : w.schedule.next+1 < limit48) (d : w.inbox.checkpoint.height+w.inbox.gridK < limit48)
    (e : ∃ n keys, w.number < n ∧ n+4 < limit48 ∧ WindowBound env w ≤ env.time n ∧
      env.time n+8 < limit256 ∧ CommitteeLive env w n keys)
    (f : LiveRules env w) (g : UnzenLaneLive env w) : LiveAt env w :=
  { generation := a, nonce := b, rules := c, height := d, window := e, ruleset := f, unzen := g }

-- Pin RecoveryPremises: it extends FundPremises with exactly these five fields.
example (env : Environment) (registry : RegistryMachine.State) (f : FundPremises env registry)
    (a : ∀ m n, m < n → env.time m < env.time n) (b : CatalogueHash env)
    (c : ProofComplete env) (d : PayloadLive env) (e : UnzenStartUsable env) :
    RecoveryPremises env registry := ⟨f,a,b,c,d,e⟩
example (env : Environment) (registry : RegistryMachine.State) (f : FundPremises env registry)
    (a : ∀ m n, m < n → env.time m < env.time n) (b : CatalogueHash env)
    (c : ProofComplete env) (d : PayloadLive env) (e : UnzenStartUsable env) :
    RecoveryPremises env registry :=
  { toFundPremises := f, recoveryClock := a, recoveryCatalogueHash := b, proofComplete := c,
    payloadLive := d, unzenStart := e }

end Etna.CurrentRecoveryRegression
