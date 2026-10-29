import EtnaProofs.Accounting

namespace Etna.Design.Accounting.Regression

def genesis : Checkpoint := ⟨0,100,200,0,0,0⟩
def inbox : State :=
  { domain := ⟨1,2,3,4⟩,committeeConfig := 7,gridK := 1,generation := 0,
    origin := ⟨0,0,0⟩,origins := [(0,⟨0,0,0⟩)],checkpoint := genesis,records := [genesis],
    head := 0,tail := 0,snapshot := 0,ethBalance := 0,feeAdmissions := 0,
    forcedETH := 0,swept := 0,signals := [],epochLen := 3,configuration := ⟨1,1,3,3600⟩,
    maxBatchBlocks := 100,forcedFee := 1,forcedThreshold := 100,protocolFeeRecipient := 9 }
def registry : RegistryHistory.State :=
  { RegistryHistory.empty with withdrawalDelay := 2,verify := fun _ _ _ => true }
def first : ProtocolState.World :=
  ⟨inbox,registry,[],Committee.recoverySchedule ⟨0,0,[]⟩,0,⟨fun _ => 7,fun _ => 8,⟨99,0⟩⟩⟩

def registerWorld (w : ProtocolState.World) (key amount now : Nat) : ProtocolState.World :=
  ProtocolState.registered w ((RegistryHistory.register w.registry key 9 amount now).getD w.registry) now
def editWorld (w : ProtocolState.World) (id now : Nat) (action : RegistryHistory.Edit) : ProtocolState.World :=
  ProtocolState.registered w (attempt w.registry (editEffect w.registry w.inbox id now action)).1 now

def input (w : ProtocolState.World) (snapshot : Nat) : LandInput :=
  ⟨w.inbox.checkpoint.height,w.inbox.checkpoint.height+1,101,201,301,snapshot,w.inbox.head,snapshot⟩
def environment (w : ProtocolState.World) (snapshot now : Nat) : LandingEnv :=
  let i := input w snapshot
  let certificate : StatementData :=
    ⟨w.inbox.domain,w.inbox.generation,w.inbox.committeeConfig,w.inbox.checkpoint.elHash,
      w.inbox.checkpoint.cometHash,w.inbox.head,i,400,[500],⟨w.inbox.generation,i.parentHeight,i.lastHeight,[]⟩⟩
  ⟨now,400,true,[500],[(.risc0,true),(.sp1,true)],certificate⟩
def landWorld (w : ProtocolState.World) (snapshot now : Nat) : ProtocolState.World :=
  ProtocolState.landed w (applyLanding w.inbox (input w snapshot)) now

def w1 := registerWorld first 7 100 1
def w2 := editWorld w1 0 2 (.topUp 9 21)
def w3 := editWorld w2 0 3 .activateTopUp
def w4 := editWorld w3 0 4 (.forfeit 7 50 100 4 true true)
def w5 := landWorld w4 4 5
def w6 := editWorld w5 0 5 .confirm
def w7 := editWorld w6 0 7 (.withdraw 9)
def w8 := registerWorld w7 8 200 8
def w9 := editWorld w8 0 9 (.topUp 9 50)
def w10 := editWorld w9 0 10 (.forfeit 8 50 100 10 true true)
def vote (blockId : Nat) : Staking.Vote := ⟨inbox.domain,0,1,0,2,blockId⟩
def w11 := editWorld w10 0 11 (.slash (vote 600) (vote 601) 0 0)
def w12 := registerWorld w11 9 40 12
def w13 := registerWorld w12 10 1 13
def request : Recovery.Request := ⟨0,1,[⟨1,9⟩],[],0,100⟩
def origin : Origin := ⟨1,14,14⟩
def recovered : Recovery.World :=
  Recovery.applyRecovery (ProtocolState.recoveryView w13) request first.adapters.recovery origin
def w14 := ProtocolState.recovered w13 request origin recovered
def w15 := editWorld w14 2 15 (.forfeit 10 51 100 15 true true)
def w16 := landWorld w15 15 16
def w17 := editWorld w16 1 16 .confirm
def trusted := w5.inbox.checkpoint
def w18 := ProtocolState.applyRollback w17 trusted 4 17
def w19 := landWorld w18 17 18
def w20 := editWorld w19 1 18 .confirm
def w21 := editWorld w20 1 20 (.withdraw 9)
def w22 := ProtocolState.enqueued w21 ((Forced.enqueue w21.inbox 0 1000000000 true).getD w21.inbox) 800 21 21
def w23 := ProtocolState.landed w22 ((Forced.sweep w22.inbox true).getD w22.inbox) 22
def last := ProtocolState.landed w23 (Recovery.applyInvalidation w23.inbox) 23

theorem deposit : Step first w1 ⟨100,0,0,0⟩ := .registration (key := 7) (owner := 9) (by decide) rfl
theorem topup : Step w1 w2 ⟨21,0,0,0⟩ := .modification (id := 0) (action := .topUp 9 21) (by decide) rfl rfl
theorem activation : Step w2 w3 Flow.zero := .modification (id := 0) (action := .activateTopUp) (by decide) rfl rfl
theorem partial_forfeit : Step w3 w4 ⟨0,0,0,13⟩ :=
  .modification (id := 0) (action := .forfeit 7 50 100 4 true true) (by decide) rfl rfl
theorem landing1 : Step w4 w5 Flow.zero := .landing (i := input w4 4) (leaves := [])
  (e := environment w4 4 5) (by decide) (by decide +kernel)
theorem confirmation1 : Step w5 w6 Flow.zero := .modification (id := 0) (action := .confirm) (by decide) rfl rfl
theorem withdrawal1 : Step w6 w7 ⟨0,108,0,0⟩ :=
  .modification (id := 0) (action := .withdraw 9) (by decide) rfl rfl
theorem reuse : Step w7 w8 ⟨200,0,0,0⟩ := .registration (key := 8) (owner := 9) (by decide) rfl
theorem topup2 : Step w8 w9 ⟨50,0,0,0⟩ := .modification (id := 0) (action := .topUp 9 50) (by decide) rfl rfl
theorem partial_forfeit2 : Step w9 w10 ⟨0,0,0,25⟩ :=
  .modification (id := 0) (action := .forfeit 8 50 100 10 true true) (by decide) rfl rfl
theorem double_slash : Step w10 w11 ⟨0,0,22,203⟩ :=
  .modification (id := 0) (action := .slash (vote 600) (vote 601) 0 0) (by decide) rfl rfl
theorem deposit2 : Step w11 w12 ⟨40,0,0,0⟩ := .registration (key := 9) (owner := 9) (by decide) rfl
theorem deposit3 : Step w12 w13 ⟨1,0,0,0⟩ := .registration (key := 10) (owner := 9) (by decide) rfl
theorem recovery : Step w13 w14 Flow.zero :=
  .recovery (a := request) (r := origin) (owner := true) (externalOK := true) (by decide) (by decide +kernel)
theorem full_forfeit : Step w14 w15 ⟨0,0,0,1⟩ :=
  .modification (id := 2) (action := .forfeit 10 51 100 15 true true) (by decide) rfl rfl
theorem landing2 : Step w15 w16 Flow.zero := .landing (i := input w15 15) (leaves := [])
  (e := environment w15 15 16) (by decide) (by decide +kernel)
theorem confirmation2 : Step w16 w17 Flow.zero := .modification (id := 1) (action := .confirm) (by decide) rfl rfl
theorem rollback : Step w17 w18 Flow.zero := .rollback trusted 4 17 (by decide) (by decide +kernel) (by decide +kernel)
theorem landing3 : Step w18 w19 Flow.zero := .landing (i := input w18 17) (leaves := [])
  (e := environment w18 17 18) (by decide) (by decide +kernel)
theorem confirmation3 : Step w19 w20 Flow.zero := .modification (id := 1) (action := .confirm) (by decide) rfl rfl
theorem withdrawal2 : Step w20 w21 ⟨0,40,0,0⟩ :=
  .modification (id := 1) (action := .withdraw 9) (by decide) rfl rfl
theorem enqueue : Step w21 w22 Flow.zero := .enqueue (raw := 0) (paid := 1000000000) (refund := true)
  (by decide) (by decide +kernel) (by decide +kernel) rfl
theorem sweep : Step w22 w23 Flow.zero := .sweep (transfer := true) (by decide) rfl
theorem invalidation : Step w23 last Flow.zero := .invalidation (expected := 2) (owner := true) (by decide) rfl

theorem failed_before_maturity : Step w2 w2 Flow.zero :=
  .rejectedCall (.modification (id := 0) (now := 2) (action := .activateTopUp) rfl)
theorem failed_before_withdrawal_delay : Step w6 w6 Flow.zero :=
  .rejectedCall (.modification (id := 0) (now := 6) (action := .withdraw 9) rfl)
theorem failed_after_slash : Step w11 w11 Flow.zero :=
  .rejectedCall (.modification (id := 0) (now := 11) (action := .slash (vote 600) (vote 601) 0 0) rfl)
theorem failed_after_rollback : Step w18 w18 Flow.zero :=
  .rejectedCall (.modification (id := 1) (now := 18) (action := .withdraw 9) rfl)

/-- All expected totals are hand-computed: 100+21+200+50+40+1 deposited;
108+40 withdrawn; 22 bounty; 13+25+203+1 sent to the sink. -/
theorem mixed_trace : Trace first last ⟨412,148,22,242⟩ := by
  exact .step (.step (.step (.step (.step (.step (.step (.step (.step (.step
    (.step (.step (.step (.step (.step (.step (.step (.step (.step (.step
    (.step (.step (.step (.step (.step (.step (.step (.step (.refl first) deposit)
    topup) failed_before_maturity) activation) partial_forfeit) landing1) confirmation1)
    failed_before_withdrawal_delay) withdrawal1) reuse) topup2) partial_forfeit2) double_slash)
    failed_after_slash) deposit2) deposit3) recovery) full_forfeit) landing2) confirmation2)
    rollback) failed_after_rollback) landing3) confirmation3) withdrawal2) enqueue) sweep) invalidation

theorem initial_slot_good : SlotGood first.registry := empty_slot_good

theorem mixed_run_conserves :
    held first.registry = 0 ∧ held last.registry = 0 ∧
    412 = held last.registry+148+22+242 ∧ SlotGood last.registry := by
  refine ⟨rfl,rfl,?_,trace_preserves_slot_good initial_slot_good mixed_trace⟩
  exact trajectory_conservation initial_slot_good.1 mixed_trace

theorem failed_calls_have_zero_flow :
    (attempt w2.registry (editEffect w2.registry w2.inbox 0 2 .activateTopUp)).2 = Flow.zero ∧
    (attempt w6.registry (editEffect w6.registry w6.inbox 0 6 (.withdraw 9))).2 = Flow.zero ∧
    (attempt w18.registry (editEffect w18.registry w18.inbox 1 18 (.withdraw 9))).2 = Flow.zero ∧
    (attempt w1.registry (registerEffect w1.registry 7 9 100 2)).2 = Flow.zero ∧
    (attempt w3.registry (editEffect w3.registry w3.inbox 0 4 (.forfeit 7 50 100 4 true false))).2 = Flow.zero := by
  decide +kernel

theorem reuse_does_not_resurrect_principal :
    held w7.registry = 0 ∧ held w8.registry = 200 ∧ w8.registry.nextId = 1 ∧
    (w8.registry.slots 0).pendingTopUp = 0 ∧ (w8.registry.slots 0).confirmedAt = none := by decide +kernel

theorem rollback_and_recovery_keep_economic_effects :
    held w13.registry = 41 ∧ held w14.registry = 41 ∧
    (w14.registry.slots 1).exitAt = 14 ∧
    held w17.registry = 40 ∧ held w18.registry = 40 ∧
    (w17.registry.slots 1).confirmedAt = some 16 ∧
    (w18.registry.slots 1).confirmedAt = none ∧
    w18.registry.forfeited = [10,8,7] ∧ w18.inbox.ethBalance = 0 ∧
    last.inbox.swept = 1000000000 := by decide +kernel

theorem mixed_protocol_trace : ProtocolState.Trace first last := trace_project mixed_trace

/-- Deliberately malformed raw input: a released allocated slot still carries 13 units.
This cannot arise from the empty registry lifecycle. It illustrates why raw structure
construction needs an initialization invariant, rather than a protocol design flaw. -/
def malformed : RegistryHistory.State :=
  { registry with
    nextId := 1,free := [0],usedKeys := [7],
    slots := fun id => if id = 0 then { RegistryHistory.vacant with stake := 13 } else RegistryHistory.vacant }
def overwritten : RegistryHistory.State :=
  (RegistryHistory.register malformed 8 9 5 1).getD malformed

theorem raw_released_principal_is_an_initialization_boundary :
    ¬ ReleasedZero malformed ∧
    (RegistryHistory.register malformed 8 9 5 1).isSome = true ∧
    held malformed = 13 ∧ held overwritten = 5 ∧
    held overwritten ≠ held malformed+5 := by
  refine ⟨?_,by decide +kernel,by decide +kernel,by decide +kernel,by decide +kernel⟩
  intro zero
  have lost := zero 0 rfl
  change 13 = 0 at lost
  contradiction

theorem malformed_unreachable_from_empty : ¬ RegistryHistory.Trace RegistryHistory.empty malformed := by
  intro run
  exact raw_released_principal_is_an_initialization_boundary.1 (released_zero_from_empty run)

end Etna.Design.Accounting.Regression
