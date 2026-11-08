import EtnaProofs.CurrentRecoveryTrap

/-! A reachable rollback-across-K-change trap (design section 5). A new network with K = 2
lands 0→2, 2→4 and 4→6, schedules a stop on grid 2, passes the stop time and upgrades to
K = 3 at c = 6. A verifier-failure rollback then restores the height-2 landing: c = 2 is on
the old grid but not on the new one, so no rollback-free continuation lands again
(`Recovery.offgrid_no_landing`). A second rollback, to the start record, escapes. The
environment's verifier accepts every proof, which is the failure the rollback exists for, so
the environment satisfies no premise record. -/
namespace Etna.Design.Current.Protocol.RollbackGridTrap
open Etna.Design Etna.Design.Current Protocol

def domain : Domain := ⟨1,2,3,4⟩
def unit : Nat := Committee.minUnit

def registry : RegistryMachine.State where
  ledger := ⟨0,fun _ => none,fun _ => none,fun _ => none,unit,1⟩
  config := { inbox := 3 }
  registerAuth := fun key owner amount pop => decide (key = 7 ∧ owner = 8 ∧ amount = unit ∧ pop = 1)

def genesis : Header := ⟨0,100,10,0,0,1,⟨0,0,0,0,0,0,0⟩,0⟩

/-- K = 2. The unsettled bound 6 is a multiple of both 2 and 3, so the K = 3 upgrade is valid. -/
def parameters : Parameters := ⟨2,10,1,⟨unit,unit,1,6⟩,1,1152,10,1,1,9⟩
def upgraded : Parameters := { parameters with gridK := 3 }

/-- A new network (no Unzen inbox) whose verifier accepts every proof. Every checkpoint's
timestamp is the largest 48-bit value, so a scheduled stop is always in effect at it. -/
def env : Environment where
  core := ⟨domain,7,8,0,2,9⟩
  parameters := parameters
  genesisHeader := genesis
  initialSigner := ⟨domain,0,1,[],false,[]⟩
  time := fun n => 2048*n
  stateRoot := fun _ => 0
  blockHash := fun _ _ => 0
  headerHash := fun _ => 0
  committeeHash := fun _ => 0
  configHash := fun _ => 0
  signature := fun _ => False
  txHash := fun _ => 0
  unzenNextProposal := 1
  timestampOf := fun _ => limit48-1
  catalogue := fun _ => none
  payload := fun _ _ => true
  verify := fun _ _ _ _ _ => true
  imageRules := fun _ => []
  unzenValid := fun _ _ _ => false
  unzenRoot := fun _ => False
  startImplementation := fun _ => true
  importValid := fun _ _ _ => false
  signBytes := fun _ => 0
  token := RegistryPayments.standardEnvironment 4 9
  initialToken := ⟨fun account => if account = 8 then unit else 0,
    fun owner spender => if owner = 8 ∧ spender = 4 then unit else 0⟩

/-- The calls in order, each through `transact`. -/
def run (w : World) (calls : List Call) : World := calls.foldl (transact env) w

/-- Batch `parent → last` at L1 reference block 2 with no forced inclusions; a one-interval
batch has no interior grid leaves. Its record carries the active committee snapshot 1. -/
def batch (parent last : Nat) : Landing :=
  ⟨⟨parent,last,100+last,200+last,300+last,400+last,2,0,1⟩,[],[1],[⟨.sgx,11,1⟩,⟨.sp1,11,2⟩]⟩

/-- The start record and the record the 0→2 landing writes (generation 0). -/
def recordZero : Checkpoint :=
  { height := 0, elHash := 100, cometHash := 0, cursor := 0, generation := 0, parent := 0, valStateHash := 0 }
def recordTwo : Checkpoint :=
  { height := 2, elHash := 102, cometHash := 202, cursor := 0, generation := 0, parent := 0, valStateHash := 302 }

/-- Register a bond, initialize at S = 0, register image 11, land to 6 on K = 2, stop on
grid 2 at L1 time 7296 and pass it, recover at c = 6 with the K = 3 upgrade (6 is on both
grids), then roll back to the height-2 landing. -/
def setup : List Call :=
  [.registry 8 (.register 7 8 unit 1),.advance 2,.initializeInbox 7,.image 7 11 true,.advance 3,
    .land (batch 0 2),.land (batch 2 4),.land (batch 4 6),.scheduleStop 7 7296 2,.advance 4,
    .recover
      { caller := 7, expectedGeneration := 0, expectedCheckpoint := 6, expectedNonce := 0,
        validUntil := 10000, exclusions := [], clear := [], rules := 1, upgrade := some upgraded },
    .rollback 7 recordTwo 1]

/-- The trapped state: c = 2, K = 3, generation 1 with origin 6, landed. -/
def trapped : World := run (empty env registry) setup

/-- The escape a second rollback gives: back to the start record, then a plain recovery at
c = 0, which is on the K = 3 grid. -/
def escaped : World := run trapped [.rollback 7 recordZero 1,
  .recover
    { caller := 7, expectedGeneration := 1, expectedCheckpoint := 0, expectedNonce := 3,
      validUntil := 10000, exclusions := [], clear := [], rules := 0, upgrade := none }]

private theorem run_trace (w : World) (calls : List Call) : Trace env w (run w calls) := by
  induction calls generalizing w with
  | nil => exact .refl w
  | cons call rest ih => exact Custody.trace_append (.step (.refl w) (.call w call)) (ih _)

private theorem trapped_state : trapped.start = some ⟨0,100,10⟩ ∧ trapped.everLanded = true ∧
    Start.onGrid 0 trapped.inbox.gridK trapped.inbox.checkpoint.height = false := by
  decide +kernel

private theorem escape_checks : LandingChecks env escaped (batch 0 3) := by
  decide +kernel

/-- The verifier-failure scenario (RECOV-8-24..34): an off-grid frontier after a rollback
across a K change is reachable and never lands again along a rollback-free path. RECOV-8-34
requires a recovery after the rollback, and RECOV-8.3-3a's grid condition blocks it. A second
rollback, which RECOV-8-28 and RECOV-8-58 forbid, escapes. -/
theorem rollback_grid_trap :
    ∃ env registry w, Trace env (empty env registry) w ∧
      (∀ u, CallTrace env NoRollback w u → ∀ a, land env u a = none) ∧
      ∃ u a t, Trace env w u ∧ land env u a = some t := by
  have reach : Trace env (empty env registry) trapped := run_trace _ _
  refine ⟨env,registry,trapped,reach,
    Recovery.offgrid_no_landing reach trapped_state.1 trapped_state.2.1 trapped_state.2.2,
    escaped,batch 0 3,landed escaped (batch 0 3),run_trace _ _,?_⟩
  simp only [Protocol.land,escape_checks,ite_true]

end Etna.Design.Current.Protocol.RollbackGridTrap
