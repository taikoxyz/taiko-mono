import EtnaVectors.Machine

/-! Staking-registry vectors: `register` (minimum stake, lifetime keys, slot reuse),
`requestExit`, `confirmExit` (Inbox initialization and snapshot coverage), `withdraw`
(withdrawal delay, owner or anyone once slashed) and `slashDoubleSign` (the double-sign
conditions, Inbox initialization, signatures and the bounty). The genesis validator is bond 0
(key 1, owner 1, stake 10, active from block 20, no exit). -/
namespace Etna.Vectors
open Etna.Design

def registryOnly (label : String) (call : CaseStep) (setup : List CaseStep := []) (deploy : Deploy := {})
    (spec : Option String := none) : Scenario :=
  { label := label, spec := spec, deploy := deploy, setup := setup, call := call, inbox := false, registry := true }

/-- Two conflicting genesis-generation precommits signed by bond 0's key. -/
def conflictA : VoteIn := {}
def conflictB : VoteIn := { blockId := 12 }

def registerGrid : List Scenario :=
  [("below-min", 9), ("min", 10), ("above-min", 11)].flatMap fun (an, amount) =>
    [("fresh-key", 2), ("live-key", 1)].map fun (kn, key) =>
      registryOnly ("registry.register." ++ an ++ "." ++ kn) (later 1 (.register 2 key amount))

def registerCases : List Scenario := [
  registryOnly "registry.register.reuses-freed-slot" (later 1 (.register 3 3 10))
    ([later 1 (.register 2 2 10)] ++ release 1 2),
  registryOnly "registry.hw.key-registered-once-ever" (later 1 (.register 3 2 10))
    ([later 1 (.register 2 2 10)] ++ release 1 2) (spec := some "spec L135"),
  registryOnly "registry.hw.register-before-inbox-init" (later 1 (.register 2 2 10))
    (deploy := { initialized := false }) (spec := some "spec L167"),
  registryOnly "registry.hw.free-slot-reuse-order" (later 1 (.register 4 4 10))
    ([later 1 (.register 2 2 10), later 1 (.register 3 3 10)] ++ release 1 2 ++ release 2 3) (spec := some "spec L146"),
  registryOnly "registry.hw.one-checkpoint-per-block" (atBlock 12 (.register 3 3 10)) [atBlock 12 (.register 2 2 10)]
    (spec := some "spec L166")]

def requestExitGrid : List Scenario :=
  [("owner", 1), ("stranger", 2)].flatMap fun (cn, caller) =>
    [("before-activation", 12), ("after-activation", 25)].flatMap fun (tn, block) =>
      [false, true].map fun prior =>
        registryOnly ("registry.requestExit." ++ cn ++ "." ++ tn ++ (if prior then ".exit-already-set" else ""))
          (atBlock block (.requestExit caller 0)) (if prior then [atBlock 12 (.requestExit 1 0)] else [])

def requestExitCases : List Scenario := [
  registryOnly "registry.requestExit.unknown-bond" (later 1 (.requestExit 1 3)),
  registryOnly "registry.requestExit.released-bond" (later 1 (.requestExit 2 1))
    ([later 1 (.register 2 2 10)] ++ release 1 2),
  registryOnly "registry.hw.exit-request-after-slash" (later 1 (.requestExit 1 0))
    [later 1 (.slash 5 0 conflictA conflictB)] (spec := some "spec L150")]

/-- Bond 0's exit, requested at block 12, takes effect at max(12, 20) + 20 = 40. A landing at
block 42 proves a snapshot `off` below, at or above it. -/
def confirmGrid : List Scenario :=
  [("below", 0), ("at", 1), ("above", 2)].map fun (n, off) =>
    registryOnly ("registry.confirmExit.snapshot-" ++ n ++ "-exit") (later 1 (.confirmExit 9 0))
      [atBlock 12 (.requestExit 1 0), landTo 6 0 (some (40+off-1)) 42]

def confirmCases : List Scenario := [
  registryOnly "registry.confirmExit.inbox-uninitialized.exit-set" (atBlock 41 (.confirmExit 9 0))
    [atBlock 12 (.requestExit 1 0)] (deploy := { initialized := false }),
  registryOnly "registry.confirmExit.inbox-uninitialized.no-exit" (atBlock 41 (.confirmExit 9 0))
    (deploy := { initialized := false }),
  registryOnly "registry.confirmExit.no-exit" (later 1 (.confirmExit 9 0)) [landTo 6 0 (some 50) 52],
  registryOnly "registry.confirmExit.unknown-bond" (later 1 (.confirmExit 9 4)),
  registryOnly "registry.confirmExit.released-bond" (later 1 (.confirmExit 9 1))
    ([later 1 (.register 2 2 10)] ++ release 1 2),
  registryOnly "registry.hw.confirm-is-idempotent" (later 5 (.confirmExit 8 0))
    [atBlock 12 (.requestExit 1 0), coverExit 0, later 1 (.confirmExit 9 0)] (spec := some "spec L151")]

/-- Bond 0 exits (requested, or slashed at block 12), a landing covers the exit and the exit
is confirmed. -/
def withdrawSetup (slashed : Bool) : List CaseStep :=
  (if slashed then [atBlock 12 (.slash 5 0 conflictA conflictB)] else [atBlock 12 (.requestExit 1 0)]) ++
    [coverExit 0, later 1 (.confirmExit 9 0)]

def withdrawGrid : List Scenario :=
  [false, true].flatMap fun slashed => [("owner", 1), ("stranger", 2)].flatMap fun (cn, caller) =>
    [("early", 0), ("due", 1), ("late", 2)].map fun (tn, off) =>
      registryOnly ("registry.withdraw." ++ (if slashed then "slashed" else "staked") ++ "." ++ cn ++ "." ++ tn)
        (fun w => ⟨(w.registry.slots 0).confirmedAt.getD 0 + w.registry.withdrawalDelay + off - 1,
          .withdraw caller 0 caller⟩)
        (withdrawSetup slashed)

def withdrawCases : List Scenario := [
  registryOnly "registry.withdraw.unconfirmed" (atBlock 100 (.withdraw 1 0 1)) [atBlock 12 (.requestExit 1 0)],
  registryOnly "registry.withdraw.twice" (later 1 (.withdraw 1 0 1))
    (withdrawSetup false ++ [withdrawWhenDue 0 1 1]),
  registryOnly "registry.withdraw.unknown-bond" (later 1 (.withdraw 1 3 1)),
  registryOnly "registry.hw.withdraw-to-zero-address" (withdrawWhenDue 0 1 0) (withdrawSetup false)
    (spec := some "spec L152"),
  registryOnly "registry.hw.slashed-slot-released-by-anyone" (withdrawWhenDue 0 7 7) (withdrawSetup true)
    (spec := some "spec L152"),
  registryOnly "registry.withdraw.to-another-account" (withdrawWhenDue 0 1 6) (withdrawSetup false),
  registryOnly "registry.hw.withdraw-at-block-2pow48-minus1" (atBlock (limit48-1) (.withdraw 1 0 1)) (withdrawSetup false)
    (spec := some "spec L787"),
  registryOnly "registry.hw.confirm-at-block-2pow48-minus1" (atBlock (limit48-1) (.confirmExit 9 0))
    [atBlock 12 (.requestExit 1 0), coverExit 0] (spec := some "spec L791")]

def votePairs : List (String × VoteIn × VoteIn) := [
  ("precommit-conflict", {}, { blockId := 12 }),
  ("prevote-conflict", { kind := 1 }, { kind := 1, blockId := 12 }),
  ("nil-against-block", {}, { blockId := 0 }),
  ("same-block", {}, {}),
  ("type-mismatch", {}, { kind := 1, blockId := 12 }),
  ("height-mismatch", {}, { height := 1001, blockId := 12 }),
  ("round-mismatch", {}, { round := 4, blockId := 12 }),
  ("generation-mismatch", {}, { generation := 1, blockId := 12 }),
  ("vote-type-3", { kind := 3 }, { kind := 3, blockId := 12 }),
  ("future-generation", { generation := 1 }, { generation := 1, blockId := 12 }),
  ("other-deployment", { foreign := true }, { foreign := true, blockId := 12 }),
  ("vote-a-wrong-key", { signer := 2 }, { blockId := 12 }),
  ("vote-b-wrong-key", {}, { blockId := 12, signer := 2 })]

def slashGrid : List Scenario :=
  votePairs.map fun (name, a, b) => registryOnly ("registry.slash." ++ name) (later 1 (.slash 5 0 a b))

def slashCases : List Scenario := [
  registryOnly "registry.slash.inbox-uninitialized" (later 1 (.slash 5 0 conflictA conflictB))
    (deploy := { initialized := false }),
  registryOnly "registry.slash.unknown-bond" (later 1 (.slash 5 4 conflictA conflictB)),
  registryOnly "registry.slash.released-bond" (later 1 (.slash 5 1 { signer := 2 } { blockId := 12, signer := 2 }))
    ([later 1 (.register 2 2 10)] ++ release 1 2),
  registryOnly "registry.slash.already-slashed" (later 1 (.slash 6 0 conflictA conflictB))
    [later 1 (.slash 5 0 conflictA conflictB)],
  registryOnly "registry.hw.slash-moves-exit-earlier" (atBlock 30 (.slash 5 0 conflictA conflictB))
    [atBlock 12 (.requestExit 1 0)] (spec := some "spec L161"),
  registryOnly "registry.hw.slash-keeps-earlier-exit" (atBlock 50 (.slash 5 0 conflictA conflictB))
    [atBlock 12 (.requestExit 1 0)] (spec := some "spec L161"),
  registryOnly "registry.hw.slash-historical-generation" (later 1 (.slash 5 0 conflictA conflictB))
    [recoverNow] (spec := some "spec L159"),
  registryOnly "registry.slash.after-recovery.generation1"
    (later 1 (.slash 5 0 { generation := 1 } { generation := 1, blockId := 12 })) [recoverNow],
  registryOnly "registry.slash.after-recovery.generation2"
    (later 1 (.slash 5 0 { generation := 2 } { generation := 2, blockId := 12 })) [recoverNow],
  registryOnly "registry.hw.slash-at-block-2pow48-minus1" (atBlock (limit48-1) (.slash 5 0 conflictA conflictB))
    (spec := some "spec L161")]

/-- Deposit becomes ready at block 30; neither deposit nor maturity changes the checkpoint. -/
def topUpSetup : List CaseStep := [atBlock 20 (.topUp 1 0 7 true)]

/-- Execution-time forfeiture authority is the registry owner, independent of recovery nonce. -/
def forfeitNow (id key : Nat) (incident : Nat := 7) (validUntil : Nat := limit256-1)
    (owner : Bool := true) (externalOK : Bool := true) : CaseStep :=
  later 1 (.forfeit owner id key incident validUntil externalOK)

def topUpCases : List Scenario := [
  registryOnly "registry.hw.top-up-owner" (atBlock 20 (.topUp 1 0 7 true)) (spec := some "spec L147"),
  registryOnly "registry.hw.top-up-nonowner" (atBlock 20 (.topUp 2 0 7 true)) (spec := some "spec L147"),
  registryOnly "registry.hw.top-up-before-active" (atBlock 19 (.topUp 1 0 7 true)) (spec := some "spec L147"),
  registryOnly "registry.hw.top-up-zero" (atBlock 20 (.topUp 1 0 0 true)) (spec := some "spec L147"),
  registryOnly "registry.hw.top-up-transfer-failure-atomic" (atBlock 20 (.topUp 1 0 7 false))
    (spec := some "spec L147"),
  registryOnly "registry.hw.top-up-single-pending" (later 1 (.topUp 1 0 8 true)) topUpSetup
    (spec := some "spec L147"),
  registryOnly "registry.hw.top-up-exit-set" (later 1 (.topUp 1 0 7 true))
    [atBlock 20 (.requestExit 1 0)] (spec := some "spec L149"),
  registryOnly "registry.hw.top-up-unknown-entry" (atBlock 20 (.topUp 1 9 7 true)) (spec := some "spec L147"),
  registryOnly "registry.hw.top-up-released-entry" (later 1 (.topUp 1 0 7 true)) (release 0 1)
    (spec := some "spec L147"),
  registryOnly "registry.hw.top-up-before-inbox-initialization" (atBlock 20 (.topUp 1 0 7 true))
    (deploy := { initialized := false }) (spec := some "spec L149"),
  registryOnly "registry.hw.top-up-maturity-does-not-activate" (atBlock 30 (.topUp 1 0 8 true)) topUpSetup
    (spec := some "spec L148"),
  registryOnly "registry.hw.top-up-activate-before-ready" (atBlock 29 (.activateTopUp 9 0)) topUpSetup
    (spec := some "spec L148"),
  registryOnly "registry.hw.top-up-activate-at-ready" (atBlock 30 (.activateTopUp 9 0)) topUpSetup
    (spec := some "spec L148"),
  registryOnly "registry.hw.top-up-activate-after-ready" (atBlock 31 (.activateTopUp 9 0)) topUpSetup
    (spec := some "spec L148"),
  registryOnly "registry.hw.top-up-activation-before-inbox-initialization" (atBlock 30 (.activateTopUp 9 0))
    topUpSetup (deploy := { initialized := false }) (spec := some "spec L149"),
  registryOnly "registry.hw.top-up-activate-no-pending" (atBlock 30 (.activateTopUp 9 0))
    (spec := some "spec L148"),
  registryOnly "registry.hw.top-up-activate-exit-before-ready" (atBlock 30 (.activateTopUp 9 0))
    (topUpSetup ++ [later 1 (.requestExit 1 0)]) (spec := some "spec L149"),
  registryOnly "registry.hw.top-up-activate-twice" (later 1 (.activateTopUp 9 0))
    (topUpSetup ++ [atBlock 30 (.activateTopUp 9 0)]) (spec := some "spec L148"),
  registryOnly "registry.hw.top-up-again-after-activation" (later 1 (.topUp 1 0 8 true))
    (topUpSetup ++ [atBlock 30 (.activateTopUp 9 0)]) (spec := some "spec L147"),
  registryOnly "registry.hw.top-up-total-balance-last-valid" (atBlock 20 (.topUp 1 0 1 true))
    (deploy := { minStake := limit256-2 }) (spec := some "spec L147"),
  registryOnly "registry.hw.top-up-total-balance-overflow" (atBlock 20 (.topUp 1 0 2 true))
    (deploy := { minStake := limit256-2 }) (spec := some "spec L147"),
  registryOnly "registry.hw.top-up-ready-block-last-valid" (atBlock (limit48-11) (.topUp 1 0 7 true))
    (spec := some "spec L147"),
  registryOnly "registry.hw.top-up-ready-block-overflow" (atBlock (limit48-10) (.topUp 1 0 7 true))
    (spec := some "spec L147"),
  registryOnly "registry.hw.top-up-full-registry" (atBlock 20 (.topUp 1 0 7 true))
    (deploy := { registrySize := 4096 }) (spec := some "spec L147"),
  registryOnly "registry.hw.withdraw-pays-pending-principal" (withdrawWhenDue 0 1 6)
    (topUpSetup ++ [later 1 (.requestExit 1 0), coverExit 0, later 1 (.confirmExit 9 0)])
    (spec := some "spec L152"),
  registryOnly "registry.hw.slash-pending-principal" (later 1 (.slash 5 0 conflictA conflictB)) topUpSetup
    (spec := some "spec L161")]

/-- A ten-unit penalty consumes effective stake first and leaves ninety pending units. -/
def pendingOnlySetup : List CaseStep :=
  [atBlock 20 (.topUp 1 0 90 true), forfeitNow 0 1]

def forfeitCases : List Scenario := [
  registryOnly "registry.hw.forfeit-exact-penalty" (forfeitNow 0 1) (spec := some "spec L206"),
  registryOnly "registry.hw.forfeit-ceiling-penalty" (forfeitNow 0 1)
    [atBlock 20 (.topUp 1 0 1 true)] (spec := some "spec L206"),
  registryOnly "registry.hw.forfeit-consumes-pending-after-effective" (forfeitNow 0 1)
    [atBlock 20 (.topUp 1 0 91 true)] (spec := some "spec L206"),
  registryOnly "registry.hw.forfeit-full-rate-clears-ready-block" (forfeitNow 0 1) topUpSetup
    (deploy := { forfeitBps := 10000 }) (spec := some "spec L206"),
  registryOnly "registry.hw.forfeit-nonowner" (forfeitNow 0 1 (owner := false)) (spec := some "spec L204"),
  registryOnly "registry.hw.forfeit-wrong-key" (forfeitNow 0 2) (spec := some "spec L205"),
  registryOnly "registry.hw.forfeit-unknown-entry" (forfeitNow 9 1) (spec := some "spec L205"),
  registryOnly "registry.hw.forfeit-uninitialized" (forfeitNow 0 1)
    (deploy := { initialized := false }) (spec := some "spec L204"),
  registryOnly "registry.hw.forfeit-expired" (forfeitNow 0 1 (validUntil := timestampOf 12-1))
    (spec := some "spec L205"),
  registryOnly "registry.hw.forfeit-expiry-equality" (forfeitNow 0 1 (validUntil := timestampOf 12))
    (spec := some "spec L205"),
  registryOnly "registry.hw.forfeit-transfer-failure-atomic" (forfeitNow 0 1 (externalOK := false))
    topUpSetup (spec := some "spec L209"),
  registryOnly "registry.hw.forfeit-repeat-same-entry" (forfeitNow 0 1) [forfeitNow 0 1]
    (spec := some "spec L207"),
  registryOnly "registry.hw.forfeit-same-incident-different-entry" (forfeitNow 1 2)
    [later 1 (.register 2 2 10), forfeitNow 0 1] (spec := some "spec L204"),
  registryOnly "registry.hw.forfeit-after-slash" (forfeitNow 0 1)
    [later 1 (.slash 5 0 conflictA conflictB)] (spec := some "spec L207"),
  registryOnly "registry.hw.slash-after-forfeit" (later 1 (.slash 5 0 conflictA conflictB)) [forfeitNow 0 1]
    (spec := some "spec L207"),
  registryOnly "registry.hw.forfeit-after-withdrawal" (forfeitNow 0 1) (release 0 1)
    (spec := some "spec L209"),
  registryOnly "registry.hw.withdraw-after-forfeit" (withdrawWhenDue 0 1 1)
    [forfeitNow 0 1, coverExit 0, later 1 (.confirmExit 9 0)] (spec := some "spec L209"),
  registryOnly "registry.hw.forfeit-preserves-confirmed-clock" (forfeitNow 0 1)
    [atBlock 12 (.requestExit 1 0), coverExit 0, later 1 (.confirmExit 9 0)] (spec := some "spec L207"),
  registryOnly "registry.hw.forfeit-before-recovery" (recoverNow [⟨0, 1⟩]) [forfeitNow 0 1]
    (spec := some "spec L209"),
  registryOnly "registry.hw.forfeit-after-recovery" (forfeitNow 0 1) [recoverNow [⟨0, 1⟩]]
    (spec := some "spec L208"),
  registryOnly "registry.hw.forfeit-after-landing" (forfeitNow 0 1) [landTo 6] (spec := some "spec L208"),
  registryOnly "registry.hw.forfeit-after-nonce-invalidation" (forfeitNow 0 1)
    [later 1 (.invalidateRecoveryNonce true 0)] (spec := some "spec L208"),
  registryOnly "registry.hw.forfeit-deposit-after-authorization" (forfeitNow 0 1) topUpSetup
    (spec := some "spec L206"),
  registryOnly "registry.hw.top-up-rejected-after-forfeit" (later 1 (.topUp 1 0 7 true)) [forfeitNow 0 1]
    (spec := some "spec L149"),
  registryOnly "registry.hw.activation-rejected-after-forfeit" (atBlock 30 (.activateTopUp 9 0))
    (topUpSetup ++ [forfeitNow 0 1]) (spec := some "spec L149"),
  registryOnly "registry.hw.pending-only-withdraw-owner" (withdrawWhenDue 0 1 1)
    (pendingOnlySetup ++ [coverExit 0, later 1 (.confirmExit 9 0)]) (spec := some "spec L152"),
  registryOnly "registry.hw.pending-only-withdraw-stranger" (withdrawWhenDue 0 2 2)
    (pendingOnlySetup ++ [coverExit 0, later 1 (.confirmExit 9 0)]) (spec := some "spec L152"),
  registryOnly "registry.hw.pending-only-slash" (later 1 (.slash 5 0 conflictA conflictB)) pendingOnlySetup
    (spec := some "spec L161"),
  registryOnly "registry.hw.forfeit-flag-survives-release-and-reuse" (later 1 (.register 2 2 10))
    [forfeitNow 0 1, coverExit 0, later 1 (.confirmExit 9 0), withdrawWhenDue 0 1 1]
    (spec := some "spec L207"),
  registryOnly "registry.hw.new-entry-can-forfeit-after-reuse" (forfeitNow 0 2)
    [forfeitNow 0 1, coverExit 0, later 1 (.confirmExit 9 0), withdrawWhenDue 0 1 1,
      later 1 (.register 2 2 10)] (spec := some "spec L207"),
  registryOnly "registry.hw.forfeit-flag-survives-rollback" (later 1 .rollbackGenesis) [forfeitNow 0 1]
    (spec := some "spec L207"),
  registryOnly "registry.hw.forfeit-repeat-rejected-after-rollback" (forfeitNow 0 1)
    [forfeitNow 0 1, later 1 .rollbackGenesis] (spec := some "spec L207")]

def registryScenarios : List Scenario :=
  registerGrid ++ registerCases ++ requestExitGrid ++ requestExitCases ++ confirmGrid ++ confirmCases ++
    withdrawGrid ++ withdrawCases ++ slashGrid ++ slashCases ++ topUpCases ++ forfeitCases

end Etna.Vectors
