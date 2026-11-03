import EtnaProofs.CurrentProtocolFinality

open Etna.Design.Current
open Etna.Design.Current.ProtocolFinality

example (env : Protocol.Environment) (first later : Protocol.World)
    (run : Protocol.Trace env first later) :
    RegistryMachine.Trace (Protocol.registryWorld env first) (Protocol.registryWorld env later) :=
  registry_trace run

namespace Etna.CurrentProtocolFinalityRegression
open Etna.Design Etna.Design.Current Protocol ProtocolFinality
set_option maxRecDepth 30000
set_option maxHeartbeats 12000000

def domain : Domain := ⟨1,2,30,40⟩
def oldBond : Registry.Bond := ⟨⟨7,70,100,0,1000,false,none,0,0⟩,none⟩
def replacement : Registry.Bond := ⟨⟨8,80,101,0,1000,false,none,0,0⟩,some 0⟩
def registry : RegistryMachine.State where
  ledger := {
    nextId := 2
    bonds := fun id => if id = 0 then some oldBond else if id = 1 then some replacement else none
    slots := fun slot => if slot = 0 then some 1 else none
    keyId := fun key => if key = 7 then some 0 else if key = 8 then some 1 else none }
  config := {inbox := 30,owner := 1}
  verify := fun key _ signature => key == signature
  registerAuth := fun _ _ _ _ => true

def env : Environment where
  core := ⟨domain,1,2,0,0,90⟩
  parameters := ⟨1,10,0,⟨Committee.minUnit,Committee.minUnit,1,10⟩,1,1152,10,1,1,99⟩
  genesisHeader := ⟨0,100,200,0,0,0,⟨0,0,0,0,0,0,0⟩⟩
  initialSigner := ⟨domain,0,1,[],false,[]⟩
  time := id
  stateRoot := fun s => s.number+100
  blockHash := fun _ n => n
  headerHash := fun h => h.elHash
  committeeHash := fun _ => 1
  configHash := fun _ => 0
  signature := fun v => v.key = 7
  txHash := fun raw => raw.length
  unzenNextProposal := 0
  archiveAuthenticated := fun _ _ _ => true
  timestampOf := fun _ => 0
  catalogue := fun _ => none
  payload := fun _ _ => true
  verify := fun _ _ _ _ _ => true
  imageRules := fun _ => [1]
  unzenValid := fun _ _ _ => false
  unzenRoot := fun _ => False
  startImplementation := fun _ => true
  importValid := fun _ _ _ => false
  signBytes := fun _ => 0
  token := RegistryPayments.standardEnvironment 40 90
  initialToken := ⟨fun account => if account = 40 then 1000 else if account = 71 then 500 else 0,
    fun owner spender => if owner = 71 ∧ spender = 40 then 500 else 0⟩

def initial : World := Protocol.empty env registry
def advanced := Protocol.transact env initial (.advance 1)
def started := Protocol.transact env advanced (.initializeInbox 1)
def forfeited := Protocol.transact env started (.registry 1 (.forfeit 0 1 7 123 100))
def recovery : RecoveryRequest := ⟨1,0,0,0,100,[(0,7)],[],0,none⟩
def recovered := Protocol.transact env forfeited (.recover recovery)
def later := Protocol.transact env recovered (.advance 2)
def rolled := Protocol.transact env later (.rollback 1 later.inbox.checkpoint 0)
def signMessage : SigningBridge.SignMessage := ⟨domain,1,1,0,.precommitMsg,111⟩
def attempted := Protocol.transact env rolled (.sign signMessage 7 true)
def restarted := Protocol.transact env attempted .restart

theorem actual_run : Protocol.Trace env started restarted :=
  .step (.step (.step (.step (.step (.step (.refl started)
    (.call started (.registry 1 (.forfeit 0 1 7 123 100))))
    (.call forfeited (.recover recovery))) (.call recovered (.advance 2)))
    (.call later (.rollback 1 later.inbox.checkpoint 0))) (.call rolled (.sign signMessage 7 true)))
    (.call attempted .restart)

theorem started_reachable : Protocol.Trace env (Protocol.empty env registry) started :=
  .step (.step (.refl initial) (.call initial (.advance 1)))
    (.call advanced (.initializeInbox 1))

theorem full_run : Protocol.Trace env (Protocol.empty env registry) restarted :=
  .step (.step (.step (.step (.step (.step started_reachable
    (.call started (.registry 1 (.forfeit 0 1 7 123 100))))
    (.call forfeited (.recover recovery))) (.call recovered (.advance 2)))
    (.call later (.rollback 1 later.inbox.checkpoint 0))) (.call rolled (.sign signMessage 7 true)))
    (.call attempted .restart)

def stakeAt (w : World) (id : Nat) : Option Nat := (w.registry.registry.ledger.bonds id).map (fun b => b.value.stake)
def slotAt (w : World) (id : Nat) : Option (Option Nat) := (w.registry.registry.ledger.bonds id).map (fun b => b.slot)

example : started.initialized = true := by decide +kernel
example : stakeAt forfeited 0 = some 90 := by decide +kernel
example : restarted.inbox.generation = 1 := by decide +kernel
example : restarted.number = 2 := by decide +kernel
example : slotAt restarted 0 = some none := by decide +kernel
example : stakeAt restarted 0 = some 90 := by decide +kernel
example : restarted.node.signer.log = [] := by decide +kernel
example : RegistryMachine.Trace (registryWorld env started) (registryWorld env restarted) := registry_trace actual_run
example : restarted.registry.registry.verify = started.registry.registry.verify := (trace_fields actual_run).2.2.2.2.2.2

def voteA : Staking.Vote := ⟨domain,0,1,0,2,111⟩
def voteB : Staking.Vote := ⟨domain,0,1,0,2,222⟩
def slash : RegistryMachine.Action := .slash 0 voteA voteB 7 7
def paid := registryCall env restarted 77 slash

theorem authentic : RegistryMachine.Evidence started.registry.registry (registryView env started) 7 voteA voteB 7 7 := by
  decide +kernel
example : PaidFutureLiability env started 7 voteA voteB 7 7 :=
  paid_evidence_future_liability rfl (by decide +kernel) (by decide +kernel) authentic

-- The successful public transaction writes both principal and the precise atomic payouts.
example : paid.isSome = true := by decide +kernel
example : paid.bind (fun w => stakeAt w 0) = some 0 := by decide +kernel
example : paid.map (fun w => w.registry.token.balances 40) = some 900 := by decide +kernel
example : paid.map (fun w => w.registry.token.balances 77) = some 9 := by decide +kernel
example : paid.map (fun w => w.registry.token.balances 90) = some 91 := by decide +kernel
example : paid.map World.receipts = some [⟨40,90,10,false⟩,⟨40,77,9,false⟩,⟨40,90,81,false⟩] := by decide +kernel

-- The successful paid slash is reachable from the headline's exact initial constructor.
example : Protocol.Trace env (Protocol.empty env registry)
    (Protocol.transact env restarted (.registry 77 slash)) :=
  .step full_run (.call restarted (.registry 77 slash))

-- External TAIKO balances and prior approval are deployment inputs, not manual World edits.
def deposited := Protocol.transact env started (.registry 71 (.register 9 71 102 9))
example : (Protocol.execute env started (.registry 71 (.register 9 71 102 9))).isSome = true := by decide +kernel
example : stakeAt deposited 2 = some 102 := by decide +kernel
example : deposited.registry.token.balances 71 = 398 := by decide +kernel
example : deposited.registry.token.balances 40 = 1102 := by decide +kernel
example : deposited.registry.token.allowances 71 40 = 398 := by decide +kernel
example : deposited.receipts = [⟨71,40,102,true⟩] := by decide +kernel
example : Protocol.Trace env (Protocol.empty env registry) deposited :=
  .step started_reachable (.call started (.registry 71 (.register 9 71 102 9)))

-- Evidence alone cannot commit the transaction when its token balance is unavailable.
def unfunded : World := { restarted with registry := { restarted.registry with token := ⟨fun _ => 0,fun _ _ => 0⟩ } }
example : (registryCall env unfunded 77 slash).isNone = true := by decide +kernel
example : stakeAt (Protocol.transact env unfunded (.registry 77 slash)) 0 = some 90 := by decide +kernel

-- A clock which decreases at the requested height cannot create a hidden backwards frame.
def badClock : Environment := {env with time := fun n => 100-n}
example : (Protocol.advance badClock initial 1).isNone = true := by decide +kernel
example (before after : World) (run : Protocol.Trace badClock before after) :
    badClock.time before.number ≤ badClock.time after.number := (trace_fields run).2.2.2.2.1

end Etna.CurrentProtocolFinalityRegression

-- The root headline consumes actual reachable state and explicit low-level primitives.
example (env : Protocol.Environment) (initial w : Protocol.World) (engine : Finality.Engine)
    (run : Protocol.Trace env initial w) (standard : StandardToken env)
    (refinement : Finality.SignatureRefinement initial.registry.registry env.signature)
    (initialized : w.initialized = true) (rate : initial.registry.registry.config.slashBountyBps ≤ 10000)
    (codec : CodecSound env w) (honesty : HonestExecutions engine env w)
    (attribution : VoteAttribution engine env w) : H2 env w :=
  current_h2 run standard refinement initialized rate codec honesty attribution
