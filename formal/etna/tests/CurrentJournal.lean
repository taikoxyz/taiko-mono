import EtnaProofs.CurrentJournal

namespace Etna.Design.Current.Journal.Tests
example (env : Protocol.Environment) (registry : RegistryMachine.State) (w : Protocol.World)
    (trace : Protocol.Trace env (Protocol.empty env registry) w) : Invariant env w := by
  exact trace_invariant trace
end Etna.Design.Current.Journal.Tests

namespace Etna.Design.Current.Journal.Tests
set_option maxRecDepth 20000
set_option maxHeartbeats 2000000

def domain : Domain := ⟨1,2,3,4⟩
def registry : RegistryMachine.State :=
  { ledger := {nextId := 0,bonds := fun _ => none,slots := fun _ => none,keyId := fun _ => none},
    config := {inbox := 3} }
def env : Protocol.Environment where
  core := ⟨domain,7,8,0,0,9⟩
  parameters := ⟨1,10,0,⟨Committee.minUnit,Committee.minUnit,1,10⟩,2,1152,10,1,1,9⟩
  genesisHeader := ⟨0,100,100,0,0,0,⟨0,0,0,0,0,0,0⟩,0⟩
  initialSigner := ⟨domain,0,0,[],false,[]⟩
  time := id
  stateRoot := fun s => s.number
  blockHash := fun _ n => n
  headerHash := fun h => h.elHash
  committeeHash := fun _ => 1
  configHash := fun _ => 0
  signature := fun _ => True
  txHash := fun raw => ((raw.head?).getD 0).toNat
  unzenNextProposal := 1
  timestampOf := fun _ => 0
  catalogue := fun _ => none
  payload := fun _ _ => true
  verify := fun _ _ _ _ _ => false
  imageRules := fun _ => [0]
  unzenValid := fun _ _ _ => false
  unzenRoot := fun _ => False
  startImplementation := fun _ => true
  importValid := fun _ _ _ => false
  signBytes := fun _ => 0
  token := RegistryPayments.standardEnvironment 4 9

def initial : Protocol.World := Protocol.empty env registry
def block1 : Protocol.World := Protocol.transact env initial (.advance 1)
def started : Protocol.World := Protocol.transact env block1 (.initializeInbox 7)
def one : Protocol.World := Protocol.transact env started (.enqueue [11] 1000000000 false)
def two : Protocol.World := Protocol.transact env one (.enqueue [12] 2000000000 false)
def closed : Protocol.World := Protocol.transact env two (.advance 3)
def third : Protocol.World := Protocol.transact env closed (.enqueue [13] 3000000000 false)

-- Both same-block admissions are present in the completed block, including empty block 2.
example : two.queue = [(0,⟨11,1,1⟩),(1,⟨12,1,1⟩)] := by decide
example : closed.history.map (fun s => (s.number,s.inbox.tail)) = [(0,0),(1,2),(2,2)] := by decide
example : closed.history.map (fun s => (s.number,s.timestamp)) = [(0,0),(1,1),(2,2)] := by decide
example : third.queue = [(0,⟨11,1,1⟩),(1,⟨12,1,1⟩),(2,⟨13,3,3⟩)] := by decide
example : third.history.map (fun s => s.queue) = [[],two.queue,two.queue] := by decide
example : (Protocol.transact env third (.advance 3)).history.map Protocol.Snapshot.number = [0,1,2] := by decide
example : (Protocol.transact env third (.sweep false)).queue = third.queue := by decide
example : (Protocol.transact env third (.sweep true)).queue = third.queue := by decide
example : (Protocol.transact env third .restart).queue = third.queue := by decide
example : (Protocol.transact env third (.scheduleRules 7 1 2000)).queue = third.queue := by decide

def request : Protocol.RecoveryRequest := ⟨7,0,0,0,1000,[],[0],0,none⟩
def recovered : Protocol.World := Protocol.transact env third (.recover request)
example : recovered.inbox.generation = 1 := by decide
example : recovered.queue = [(0,⟨0,1,1⟩),(1,⟨12,1,1⟩),(2,⟨13,3,3⟩)] := by decide
example : recovered.history.map (fun s => s.queue) = [[],two.queue,two.queue] := by decide
-- Clearing preserves actual admission time even though historical bytes belong to generation 0.
example : (recovered.queue.map (fun pair => (pair.1,pair.2.timestamp,pair.2.l1Block))) =
    [(0,1,1),(1,1,1),(2,3,3)] := by decide
example : (Protocol.transact env recovered (.recover request)).queue = recovered.queue := by decide

theorem third_trace : Protocol.Trace env initial third :=
  .step (.step (.step (.step (.step (.step (.refl initial)
    (.call initial (.advance 1))) (.call block1 (.initializeInbox 7)))
    (.call started (.enqueue [11] 1000000000 false))) (.call one (.enqueue [12] 2000000000 false)))
    (.call two (.advance 3))) (.call closed (.enqueue [13] 3000000000 false))
example : Invariant env third := trace_invariant third_trace
example : Invariant env recovered := trace_invariant (.step third_trace (.call third (.recover request)))
example : RecordShape third := trace_record_shape third_trace
example : (Protocol.transact env third (.rollback 7 third.inbox.checkpoint 0)).inbox.head ≤ third.inbox.head :=
  nonlanding_never_advances third_trace _ (by intro a h; cases h)

end Etna.Design.Current.Journal.Tests

namespace Etna.Design.Current.Journal.Tests
set_option maxRecDepth 20000
set_option maxHeartbeats 2000000

example : third.inbox.checkpoint ∈ third.activeRecords ∧
    recordAt third.inbox third.inbox.checkpoint.height = some third.inbox.checkpoint ∧
    third.inbox.checkpoint.cursor = third.inbox.head :=
  trace_frontier_record third_trace (by decide)

def rolled : Protocol.World := Protocol.transact env third (.rollback 7 third.inbox.checkpoint 0)
example : recordAt rolled.inbox rolled.inbox.checkpoint.height = some rolled.inbox.checkpoint :=
  (trace_frontier_record (.step third_trace (.call third (.rollback 7 third.inbox.checkpoint 0))) (by decide)).2.1

-- A genuine switching start correction keeps old records archival and installs a new frontier.
def switchEnv : Protocol.Environment := {env with core := {env.core with unzenInbox := 5}}
def switchInitial : Protocol.World := Protocol.empty switchEnv registry
def switchBlock : Protocol.World := Protocol.transact switchEnv switchInitial (.advance 1)
def switchReady : Protocol.World := Protocol.transact switchEnv switchBlock (.initializeInbox 7)
def switchWritten : Protocol.World := Protocol.transact switchEnv switchReady (.setOrigin 8 8 108 208)
def switchCorrected : Protocol.World := Protocol.transact switchEnv switchWritten (.correctStart 7 9 109 209)
theorem switch_trace : Protocol.Trace switchEnv switchInitial switchCorrected :=
  .step (.step (.step (.step (.refl switchInitial) (.call switchInitial (.advance 1)))
    (.call switchBlock (.initializeInbox 7))) (.call switchReady (.setOrigin 8 8 108 208)))
    (.call switchWritten (.correctStart 7 9 109 209))
example : switchCorrected.inbox.generation = 1 := by decide
example : switchCorrected.activeRecords.map Checkpoint.height = [9] := by decide
example : (recordAt switchCorrected.inbox 8).map Checkpoint.elHash = some 108 := by decide
example : (recordAt switchCorrected.inbox 9).map Checkpoint.elHash = some 109 := by decide
example : switchCorrected.inbox.checkpoint ∈ switchCorrected.activeRecords ∧
    recordAt switchCorrected.inbox switchCorrected.inbox.checkpoint.height = some switchCorrected.inbox.checkpoint ∧
    switchCorrected.inbox.checkpoint.cursor = switchCorrected.inbox.head :=
  trace_frontier_record switch_trace (by decide)

end Etna.Design.Current.Journal.Tests
