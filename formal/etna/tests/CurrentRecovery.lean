import EtnaStatements

/-! H4 statement surface: which calls `RecoveryCall` admits (no rollback, only plain
recoveries, every other call), the trace class `RecoveryTrace`, the conclusion `RecoverableAt`,
the claim `Recoverability`, and the field names, types and order of `LiveAt` and
`RecoveryPremises`. -/
namespace Etna.CurrentRecoveryRegression
open Etna.Design Etna.Design.Current Etna.Design.Current.Protocol Etna.Statements.Current

-- RecoveryCall: rollback and recoveries with exclusions, clears or an upgrade are out;
-- a plain recovery and the catch-all arm are in.
example (caller : Nat) (trusted : Checkpoint) (snapshot : Nat) :
    ¬ RecoveryCall (.rollback caller trusted snapshot) := id
example (r : RecoveryRequest) (x : Nat × Hash) :
    ¬ RecoveryCall (.recover { r with exclusions := [x] }) := fun h => nomatch h.1
example (r : RecoveryRequest) (i : Nat) :
    ¬ RecoveryCall (.recover { r with clear := [i] }) := fun h => nomatch h.2.1
example (r : RecoveryRequest) (p : Current.Protocol.Parameters) :
    ¬ RecoveryCall (.recover { r with upgrade := some p }) := fun h => nomatch h.2.2
example (r : RecoveryRequest) (h1 : r.exclusions = []) (h2 : r.clear = []) (h3 : r.upgrade = none) :
    RecoveryCall (.recover r) := ⟨h1,h2,h3⟩
example (a : Landing) : RecoveryCall (.land a) := trivial

-- Pin the trace class and the conclusion.
example (env : Environment) : RecoveryTrace env = CallTrace env RecoveryCall := rfl
example (env : Environment) (w : World) :
    RecoverableAt env w = ∃ u a t, RecoveryTrace env w u ∧ land env u a = some t ∧
      (w.everLanded = true → w.inbox.checkpoint.height < t.inbox.checkpoint.height) := rfl
example : Recoverability = ∀ env registry, RecoveryPremises env registry → ∀ w,
    Trace env (empty env registry) w → w.initialized = true → LiveAt env w →
    RecoverableAt env w := rfl

-- Pin LiveAt's exact fields: types and order, then names.
example (env : Environment) (w : World)
    (a : ∀ start, w.start = some start →
      Start.onGrid start.height w.inbox.gridK w.inbox.checkpoint.height = true)
    (b : w.inbox.generation+2 < limit48) (c : w.inbox.recoveryNonce+1 < limit256)
    (d : w.schedule.next+1 < limit48) (e : w.inbox.checkpoint.height+w.inbox.gridK < limit48)
    (f : ∃ n keys, w.number < n ∧ n+4 < limit48 ∧ WindowBound env w ≤ env.time n ∧
      env.time n+8 < limit256 ∧ CommitteeLive env w n keys)
    (g : LiveRules env w) (h : UnzenLaneLive env w) :
    LiveAt env w := ⟨a,b,c,d,e,f,g,h⟩
example (env : Environment) (w : World)
    (a : ∀ start, w.start = some start →
      Start.onGrid start.height w.inbox.gridK w.inbox.checkpoint.height = true)
    (b : w.inbox.generation+2 < limit48) (c : w.inbox.recoveryNonce+1 < limit256)
    (d : w.schedule.next+1 < limit48) (e : w.inbox.checkpoint.height+w.inbox.gridK < limit48)
    (f : ∃ n keys, w.number < n ∧ n+4 < limit48 ∧ WindowBound env w ≤ env.time n ∧
      env.time n+8 < limit256 ∧ CommitteeLive env w n keys)
    (g : LiveRules env w) (h : UnzenLaneLive env w) : LiveAt env w :=
  { grid := a, generation := b, nonce := c, rules := d, height := e, window := f,
    ruleset := g, unzen := h }

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
