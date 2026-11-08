import EtnaStatements

/-! H4 statement surface: which calls a recovery trace may use, and the exact shape of
`LiveAt`, `RecoveryPremises` and `Recoverability`. -/
namespace Etna.CurrentRecoveryRegression
open Etna.Design Etna.Design.Current Etna.Design.Current.Protocol Etna.Statements.Current

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
example (n : Nat) : NoRollback (.advance n) := trivial
-- Pin LiveAt's exact fields and order.
example (env : Environment) (w : World)
    (a : ∀ start, w.start = some start →
      Start.onGrid start.height w.inbox.gridK w.inbox.checkpoint.height = true)
    (b : w.inbox.generation+2 < limit48) (c : w.inbox.recoveryNonce+1 < limit256)
    (d : w.schedule.next+1 < limit48) (e : w.inbox.checkpoint.height+w.inbox.gridK < limit48)
    (f : ∃ n keys, w.number < n ∧ n+4 < limit48 ∧ WindowBound env w ≤ env.time n ∧
      env.time n+8 < limit256 ∧ CommitteeLive env w n keys)
    (g : LiveRules env w) (h : UnzenLaneLive env w) :
    LiveAt env w := ⟨a,b,c,d,e,f,g,h⟩
example : Recoverability = ∀ env registry, RecoveryPremises env registry → ∀ w,
    Trace env (empty env registry) w → w.initialized = true → LiveAt env w →
    RecoverableAt env w := rfl
-- Pin RecoveryPremises: it extends FundPremises with exactly five fields.
example (env : Environment) (registry : RegistryMachine.State) (f : FundPremises env registry)
    (a : ∀ m n, m < n → env.time m < env.time n) (b : CatalogueHash env)
    (c : ProofComplete env) (d : PayloadLive env) (e : UnzenStartUsable env) :
    RecoveryPremises env registry := ⟨f,a,b,c,d,e⟩

end Etna.CurrentRecoveryRegression
