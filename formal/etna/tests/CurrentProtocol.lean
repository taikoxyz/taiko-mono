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
  parameters := ⟨1,10,0,⟨Committee.minUnit,Committee.minUnit,1,10⟩,2,1152,10,0,1,9⟩
  genesisHeader := ⟨0,100,100,0,0,0,⟨0,0,0,0,0,0,0⟩⟩
  initialSigner := ⟨domain,0,0,[],false,[]⟩
  time := id
  stateRoot := fun s => s.number
  blockHash := id
  headerHash := fun h => h.elHash
  committeeHash := fun _ => 1
  configHash := fun _ => 0
  signature := fun _ => True
  txHash := fun raw => ((raw.head?).getD 0).toNat
  unzenNextProposal := 1
  archiveAuthenticated := fun _ _ _ => true
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
  refine ⟨rfl,⟨0,100,100⟩,rfl,0,⟨0,100,0,0,0,0⟩,?_,?_,?_,?_,?_,env.genesisHeader,
    ⟨0,100,0,0,0,0⟩,?_,?_,?_,?_,?_,?_,?_,?_,?_⟩
  all_goals first | exact True.intro | decide | simp [env]

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
