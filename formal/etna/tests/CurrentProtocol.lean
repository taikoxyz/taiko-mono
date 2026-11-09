import EtnaModel.CurrentProtocol

namespace Etna.CurrentProtocolRegression
open Etna.Design Etna.Design.Current

example (env : Protocol.Environment) (registry : RegistryMachine.State)
    (caller : Nat) (wrong : caller ≠ env.core.owner) :
    Protocol.initializeInbox env (Protocol.empty env registry) caller = none := by
  simp [Protocol.initializeInbox,wrong]

end Etna.CurrentProtocolRegression

namespace Etna.CurrentProtocolRegression
open Etna.Design Etna.Design.Current

-- The pre-initialization empty-chain counterexample must never authorize app trust.
example (env : Protocol.Environment) (w : Protocol.World) (archive : List Blocks.Header)
    (blocks : List Blocks.Block) (uninitialized : w.initialized = false) :
    ¬ Protocol.nodeTrust env w archive blocks := by
  simp [Protocol.nodeTrust,uninitialized]

-- Coherent target/cut fields cannot substitute for an authenticated full origin header.
example (env : Protocol.Environment) (w : Protocol.World) (archive : List Blocks.Header)
    (blocks : List Blocks.Block) :
    ¬ Protocol.nodeTrust {env with headerHash := fun h => h.elHash+1} w archive blocks := by
  simp [Protocol.nodeTrust]

end Etna.CurrentProtocolRegression

namespace Etna.CurrentProtocolRegression.NodeWitness
open Etna.Design Etna.Design.Current
set_option maxRecDepth 20000
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
def closed2 : Protocol.World := Protocol.transact env started (.advance 2)
def observed : Protocol.World := Protocol.transact env closed2 (.observe 1)

theorem authenticated_start_trust : Protocol.nodeTrust env observed [] [] := by
  refine ⟨rfl,⟨0,100,100⟩,rfl,0,⟨0,100,0,0,0,0,0⟩,?_,?_,?_,?_,?_,env.genesisHeader,
    ⟨0,100,0,0,0,0,0⟩,?_,?_,?_,?_,?_,?_,?_,?_,?_,?_⟩
  all_goals solve
    | exact True.intro
    | decide
    | simp [env]
    | (refine ⟨env.genesisHeader,[],rfl,rfl,rfl,rfl,rfl,True.intro,?_,?_,by decide,?_⟩ <;> simp)

-- Ordinary startup may trust the authenticated genesis after observing its completed block.
example : observed.initialized = true := by decide
example : observed.node.trusted = false := by decide
example : Protocol.NodeEvent env observed {observed.node with trusted := true} :=
  .trust [] [] authenticated_start_trust

-- A written switching origin with no authenticated Unzen root remains untrusted.
example : ¬ Protocol.nodeTrust {env with core := {env.core with unzenInbox := 5}}
    observed [] [] := by
  intro trust
  obtain ⟨_,start,hs,_,cp,_,_,hcp,_,_,p,_,_,_,_,_,_,switch,_⟩ := trust
  have actual : observed.start = some ⟨0,100,100⟩ := by decide
  have sh : start = ⟨0,100,100⟩ := Option.some.inj (hs.symm.trans actual)
  have atStart : cp.height = start.height := by rw [hcp,sh]; decide
  exact (switch (by decide) atStart).1

end Etna.CurrentProtocolRegression.NodeWitness

namespace Etna.CurrentProtocolRegression
open Etna.Design Etna.Design.Current

-- A replay cannot select historical committee anchors from an archive which omits
-- one of the actual replayed blocks, even when its final checkpoint fields match.
example (env : Protocol.Environment) (w : Protocol.World) (b : Blocks.Block) (bs : List Blocks.Block) :
    ¬ Protocol.nodeTrust env w [] (b :: bs) := by
  intro trusted
  obtain ⟨_,_,_,_,_,_,_,_,_,_,p,origin,_,_,_,_,_,_,_,_,_,auth⟩ := trusted
  obtain ⟨_,prior,_,_,_,shape,_⟩ := auth
  have lengths := congrArg List.length shape
  simp only [List.length_nil,List.length_append,List.length_map,List.length_cons] at lengths
  omega

end Etna.CurrentProtocolRegression

/-! `recover`'s only grid check is RECOV-8.3-3a, with the K it installs; SPEC 8.3 has no
planned-stop check, and vector 14e.k of START-10.1-14e recovers from a settled c below a stop
point that cannot settle. A new network (S = 0, K = 2, a verifier that accepts every proof)
lands 0 → 2. A structural recovery at c = 2 that installs K = 1 with `rules` = nextRules + 1 is
then accepted with no stop scheduled, and also once a stop on grid 4 is scheduled whose time
c's block has not reached: c = 2 is below the stop point 4. -/
namespace Etna.CurrentProtocolRegression.StructuralRecovery
open Etna.Design Etna.Design.Current

def domain : Domain := ⟨1,2,3,4⟩
def unit : Nat := Committee.minUnit
def registry : RegistryMachine.State where
  ledger := ⟨0,fun _ => none,fun _ => none,fun _ => none,unit,1⟩
  config := { inbox := 3 }
  registerAuth := fun key owner amount pop => decide (key = 7 ∧ owner = 8 ∧ amount = unit ∧ pop = 1)
def env : Protocol.Environment where
  core := ⟨domain,7,8,0,2,9⟩
  parameters := ⟨2,10,1,⟨unit,unit,1,6⟩,1,1152,10,1,1,9⟩
  genesisHeader := ⟨0,100,10,0,0,1,⟨0,0,0,0,0,0,0⟩,0⟩
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
  timestampOf := fun _ => 0
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

/-- Register a bond, initialize at S = 0, register image 11 and land 0 → 2 on K = 2. -/
def landed : Protocol.World :=
  [.registry 8 (.register 7 8 unit 1),.advance 2,.initializeInbox 7,.image 7 11 true,.advance 3,
    .land ⟨⟨0,2,102,202,302,402,2,0,1⟩,[],[1],[⟨.sgx,11,1⟩,⟨.sp1,11,2⟩]⟩].foldl
    (Protocol.transact env) (Protocol.empty env registry)

/-- A stop on grid 4 at L1 time 7296, the earliest `scheduleStop` accepts; c's block is at
time 0 (`timestampOf`), so the stop is not in effect at c, and c = 2 is not on the stop grid. -/
def stopping : Protocol.World := Protocol.transact env landed (.scheduleStop 7 7296 4)

/-- Install K = 1, keeping every other parameter, with `rules` = nextRules + 1 = 1. -/
def structural (w : Protocol.World) : Protocol.RecoveryRequest :=
  { caller := 7, expectedGeneration := 0, expectedCheckpoint := 2, expectedNonce := 0,
    validUntil := 10000, exclusions := [], clear := [], rules := 1,
    upgrade := some { Protocol.parametersOf w.inbox with gridK := 1 } }

-- c = 2 after the landing, with K = 2 and no stop scheduled.
example : landed.everLanded = true ∧ landed.inbox.checkpoint.height = 2 ∧ landed.inbox.gridK = 2 ∧
    landed.schedule.stopTime = 0 ∧ landed.schedule.next = 0 := by decide +kernel
-- Accepted with no stop scheduled.
example : (Protocol.recover env landed (structural landed)).isSome = true := by decide +kernel
-- 14e.k: accepted from c = 2 below the scheduled stop point.
example : stopping.schedule.stopTime = 7296 ∧ stopping.schedule.stopGrid = 4 ∧
    (Protocol.recover env stopping (structural stopping)).isSome = true := by decide +kernel

end Etna.CurrentProtocolRegression.StructuralRecovery
