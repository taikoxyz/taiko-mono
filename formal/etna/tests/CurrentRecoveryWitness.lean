import EtnaWitnesses

/-! The premises of H1–H4 can hold of one deployment (reports/recoverability.md, Joint witness): a
single environment, registry and engine satisfy H1–H3's `Premises` and H4's `RecoveryPremises`
together, with a reachable initialized world that satisfies `LiveAt`, and H4's proof reaches an
accepted landing from that world (`live_recovers`). The same holds of a switching deployment
(`RecoverySwitchNonVacuity`), from a world where a start S > 0 is written and the Unzen lane is
not yet proven. -/
namespace Etna.CurrentRecoveryWitnessRegression
open Etna.Design Etna.Design.Current Etna.Design.Current.Protocol

example : ∃ e registry engine w, Etna.Statements.Current.Premises e registry engine ∧
    Etna.Statements.Current.RecoveryPremises e registry ∧
    Trace e (empty e registry) w ∧ w.initialized = true ∧ Etna.Statements.Current.LiveAt e w :=
  Etna.Design.Current.Protocol.RecoveryNonVacuity.all_premises_satisfiable

-- H4 at the joint witness: its premises and hypotheses hold of `env`, `registry` and `live`,
-- and so does its conclusion.
example : Etna.Statements.Current.RecoveryPremises RecoveryNonVacuity.env RecoveryNonVacuity.registry ∧
    Trace RecoveryNonVacuity.env (empty RecoveryNonVacuity.env RecoveryNonVacuity.registry) RecoveryNonVacuity.live ∧
    RecoveryNonVacuity.live.initialized = true ∧
    Etna.Statements.Current.LiveAt RecoveryNonVacuity.env RecoveryNonVacuity.live ∧
    Etna.Statements.Current.RecoverableAt RecoveryNonVacuity.env RecoveryNonVacuity.live :=
  Etna.Design.Current.Protocol.RecoveryNonVacuity.live_recovers

-- `LiveAt` holds there by `LiveRules`' first case: c = S = 0 is on the K = 1 grid, so the path
-- runs a plain recovery and the structural branch is not exercised.
example : Etna.Statements.Current.OnGrid RecoveryNonVacuity.live := by
  intro start started
  have written : RecoveryNonVacuity.live.start =
      some ⟨0,RecoveryNonVacuity.genesis.elHash,RecoveryNonVacuity.genesis.stateRoot⟩ := by
    decide +kernel
  rw [written] at started
  cases started
  decide +kernel

-- The world: one bond for the online key, initialized at S = 0 on K = 1 at L1 block 2, nothing
-- landed yet, on the initial rulesets 0/0.
example : RecoveryNonVacuity.live.registry.registry.ledger.nextId = 1 ∧ RecoveryNonVacuity.live.number = 2 ∧
    RecoveryNonVacuity.live.inbox.checkpoint.height = 0 ∧ RecoveryNonVacuity.live.inbox.gridK = 1 ∧
    RecoveryNonVacuity.live.everLanded = false ∧ RecoveryNonVacuity.live.schedule.active = 0 ∧
    RecoveryNonVacuity.live.schedule.next = 0 := by
  decide +kernel

/-! The switching joint witness. -/

example : ∃ e registry engine w, Etna.Statements.Current.Premises e registry engine ∧
    Etna.Statements.Current.RecoveryPremises e registry ∧
    Trace e (empty e registry) w ∧ w.initialized = true ∧ Etna.Statements.Current.LiveAt e w ∧
    e.core.unzenInbox ≠ 0 ∧ (∃ s, w.start = some s ∧ 0 < s.height) ∧ w.unzen.checkpointExists = false :=
  Etna.Design.Current.Protocol.RecoverySwitchNonVacuity.all_premises_satisfiable

-- H4 at the switching witness: its premises and hypotheses hold of `env`, `registry` and `live`,
-- and so does its conclusion.
example : Etna.Statements.Current.RecoveryPremises RecoverySwitchNonVacuity.env RecoveryNonVacuity.registry ∧
    Trace RecoverySwitchNonVacuity.env (empty RecoverySwitchNonVacuity.env RecoveryNonVacuity.registry)
      RecoverySwitchNonVacuity.live ∧
    RecoverySwitchNonVacuity.live.initialized = true ∧
    Etna.Statements.Current.LiveAt RecoverySwitchNonVacuity.env RecoverySwitchNonVacuity.live ∧
    Etna.Statements.Current.RecoverableAt RecoverySwitchNonVacuity.env RecoverySwitchNonVacuity.live :=
  Etna.Design.Current.Protocol.RecoverySwitchNonVacuity.live_recovers

open RecoverySwitchNonVacuity in
-- The legacy header: height S = 5, a timestamp before the fork time, hash-bound under
-- `Encoding.headerHash`, nonzero hash and state root.
example : legacy.height = 5 ∧ legacy.timestamp < env.core.forkTime ∧ HashBound env legacy ∧
    legacy.elHash ≠ 0 ∧ legacy.stateRoot ≠ 0 :=
  ⟨rfl,by decide +kernel,rfl,by decide +kernel,by decide⟩

open RecoverySwitchNonVacuity in
-- The Unzen guest accepts exactly one proof, of the final proposal 1, for `legacy`, the only
-- authenticated root; the parent decoder returns the empty lane's finalized hash 0.
example (proposal : Nat) (h : Header) (proof : Hash) :
    (env.unzenValid proposal h proof = true ↔ proposal = 1 ∧ h = legacy ∧ proof = 77) ∧
    (env.unzenRoot h ↔ h = legacy) ∧ env.unzenNextProposal = 2 ∧ env.unzenParent 0 1 legacy 77 = 0 :=
  ⟨decide_eq_true_iff,Iff.rfl,rfl,rfl⟩

open RecoverySwitchNonVacuity in
-- The world: Unzen Inbox 99, L1 block 3 at the fork time, S = 5 written from `legacy` by the
-- origin writer with c = S on K = 1, nothing landed, and the Unzen lane unproven (proposal 1
-- open, no checkpoint, no legacy signal) on the initial rulesets 0/0.
example : env.core.unzenInbox = 99 ∧ live.number = 3 ∧ env.core.forkTime = env.time live.number ∧
    live.start = some ⟨5,legacy.elHash,legacy.stateRoot⟩ ∧ live.inbox.checkpoint.height = 5 ∧
    live.inbox.gridK = 1 ∧ live.everLanded = false ∧ live.unzen.nextProposal = 2 ∧
    live.unzen.finalizedProposal = 0 ∧ live.unzen.checkpointExists = false ∧ live.legacySignals = [] ∧
    live.schedule.active = 0 ∧ live.schedule.next = 0 := by
  decide +kernel

open RecoverySwitchNonVacuity in
-- The first-landing fence refuses at `live`, and passes once `unzenProve` of the final proposal
-- has saved the Unzen checkpoint at S = 5: H4's path must run that proof before it lands.
example : firstFence env live = false ∧
    (transact env live (.unzenProve 1 legacy 77)).unzen.checkpointHeight = 5 ∧
    firstFence env (transact env live (.unzenProve 1 legacy 77)) = true := by
  decide +kernel

open RecoverySwitchNonVacuity in
-- The fence's height check matters here: a start at S = 6 with `legacy`'s hash and state root
-- admits the same Unzen proof (5 ≤ 6), but the fence refuses, as the Unzen checkpoint is at 5.
example : (transact env (transact env forked (.setOrigin 8 6 legacy.elHash legacy.stateRoot))
      (.unzenProve 1 legacy 77)).unzen.checkpointExists = true ∧
    firstFence env (transact env (transact env forked (.setOrigin 8 6 legacy.elHash legacy.stateRoot))
      (.unzenProve 1 legacy 77)) = false := by
  decide +kernel

end Etna.CurrentRecoveryWitnessRegression
