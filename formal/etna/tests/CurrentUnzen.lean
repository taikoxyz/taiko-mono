import EtnaProofs.CurrentEncoding
import EtnaProofs.CurrentUnzen
namespace Etna.Design.Current.Protocol.UnzenReview
open Etna.Design Etna.Design.Current

def domain : Domain := ⟨1,2,3,4⟩
def genesis : Header := ⟨0,100,10,0,0,1,⟨0,0,0,0,0,0,0⟩,0⟩
def registry : RegistryMachine.State where
  ledger := ⟨0,fun _ => none,fun _ => none,fun _ => none,Committee.minUnit,1⟩
  config := { inbox := 3 }

def h5 : Header := ⟨5,101,15,0,0,1,⟨0,0,0,0,0,0,0⟩,0⟩
def h10 : Header := ⟨10,102,20,0,0,1,⟨0,0,0,0,0,0,0⟩,0⟩
def headerCommitment (h : Header) : Hash :=
  Encoding.relabel [Encoding.header genesis,Encoding.header h5,Encoding.header h10]
    Encoding.Tree.code (Encoding.header h)+100

def env : Environment where
  core := ⟨domain,7,8,99,2,9⟩
  parameters := ⟨1,10,1,⟨Committee.minUnit,Committee.minUnit,1,10⟩,1,1152,10,1,1,9⟩
  genesisHeader := genesis
  initialSigner := ⟨domain,0,1,[],false,[]⟩
  time := id
  stateRoot := fun _ => 0
  blockHash := fun _ _ => 0
  headerHash := headerCommitment
  committeeHash := fun _ => 0
  configHash := fun _ => 0
  signature := fun _ => False
  txHash := fun _ => 0
  unzenNextProposal := 3
  timestampOf := fun _ => 0
  catalogue := fun _ => none
  payload := fun _ _ => false
  verify := fun _ _ _ _ _ => false
  imageRules := fun _ => []
  unzenValid := fun p h _ => decide ((p = 2 ∨ p = 3) ∧ (h = h5 ∨ h = h10))
  unzenParent := fun boundary proposal h _ => if boundary < proposal then
    (if boundary = 2 ∧ proposal = 3 ∧ h = h10 then 101 else 0) else 102
  unzenRoot := fun h => h = h5 ∨ h = h10
  startImplementation := fun _ => false
  importValid := fun _ _ _ => false
  signBytes := fun _ => 0
  token := ⟨4,9,RegistryPayments.standardTransfer 4⟩

theorem primitives : Custody.Primitives env := by
  refine ⟨?_,?_,?_⟩
  · change headerCommitment genesis = 100
    decide +kernel
  · intro x y hx hy same
    have codes : headerCommitment x = headerCommitment y := hx.trans (same.trans hy.symm)
    have relabelled := Nat.add_right_cancel codes
    have trees := Encoding.relabel_injective _ _ (fun eq => Encoding.tree_code_injective eq) relabelled
    exact Encoding.header_hash_separation (congrArg Encoding.Tree.code trees)
  · intro p h proof valid
    change decide ((p = 2 ∨ p = 3) ∧ (h = h5 ∨ h = h10)) = true at valid
    obtain ⟨_,rfl | rfl⟩ := of_decide_eq_true valid
    · exact ⟨Or.inl rfl,by change headerCommitment h5 = 101; decide +kernel,by decide⟩
    · exact ⟨Or.inr rfl,by change headerCommitment h10 = 102; decide +kernel,by decide⟩

def initial := empty env registry
def advanced := transact env initial (.advance 2)
def initialized := transact env advanced (.initializeInbox 7)
def proven10 := transact env initialized (.unzenProve 2 h10 77)
def wrongStart := transact env proven10 (.setOrigin 8 5 101 15)
def replayed5 := transact env wrongStart (.unzenProve 2 h5 77)

theorem wrong_start_reachable : Trace env initial wrongStart :=
  .step (.step (.step (.step (.refl _) (.call _ (.advance 2))) (.call _ (.initializeInbox 7)))
    (.call _ (.unzenProve 2 h10 77))) (.call _ (.setOrigin 8 5 101 15))

/-- The new per-proof progress boundary is simultaneously consistent with global
header separation. Disconnected proofs decode parent hash 0. The legitimate second proof links
to the already authenticated height-5 header. -/
theorem extension : Custody.UnzenExtension env env.unzenParent := by
  intro boundary proposal h proof parent proper _ bound same
  change headerCommitment parent = parent.elHash at bound
  by_cases linked : boundary = 2 ∧ proposal = 3 ∧ h = h10
  · simp only [env,linked] at same
    have endHeader : h = h10 := linked.2.2
    subst h
    have startBound : HashBound env h5 := by change headerCommitment h5 = 101; decide +kernel
    have fields := primitives.separation parent h5 bound startBound same.symm
    change parent.height < 10
    have height : parent.height = 5 := fields.1
    omega
  · simp only [env,proper,linked,↓reduceIte] at same
    have zero : parent.elHash = 0 := same.symm
    have impossible : headerCommitment parent = 0 := bound.trans zero
    have positive : 0 < headerCommitment parent := by
      exact Nat.lt_of_lt_of_le (by decide : 0 < 100) (Nat.le_add_left _ _)
    exact (Nat.ne_of_gt positive impossible).elim

example : Custody.LegacyPrefix env wrongStart :=
  Custody.trace_legacy_prefix primitives extension wrong_start_reachable

-- This exact replay opened the first fence before strict proposal progress was modeled.
example : proven10.legacySignals = [⟨10,102,20⟩] ∧ firstFence env wrongStart = false := by
  decide +kernel
example : (unzenProve env wrongStart 2 h5 77).isNone = true := by decide +kernel

def longerEnv : Environment := { env with unzenNextProposal := 4 }
def longerInitial := empty longerEnv registry
def longerAdvanced := transact longerEnv longerInitial (.advance 2)
def longerInitialized := transact longerEnv longerAdvanced (.initializeInbox 7)
def longerProven10 := transact longerEnv longerInitialized (.unzenProve 2 h10 77)

-- Advancing the proposal number cannot bypass the stored-parent hash check.
example : longerProven10.legacySignals = [⟨10,102,20⟩] := by decide +kernel
example : (unzenProve longerEnv longerProven10 3 h5 77).isNone = true := by decide +kernel
-- A genuine higher-proposal proof can extend an already authenticated endpoint.
-- This exercises the new progress premise with a nonzero, hash-bound parent.
def longerProven5 := transact longerEnv longerInitialized (.unzenProve 2 h5 77)
def longerExtended10 := transact longerEnv longerProven5 (.unzenProve 3 h10 77)

theorem longer_extension_reachable : Trace longerEnv longerInitial longerExtended10 :=
  .step (.step (.step (.step (.refl _) (.call _ (.advance 2))) (.call _ (.initializeInbox 7)))
    (.call _ (.unzenProve 2 h5 77))) (.call _ (.unzenProve 3 h10 77))

example : longerExtended10.legacySignals = [⟨5,101,15⟩,⟨10,102,20⟩] ∧
    longerExtended10.unzen.finalizedProposal = 3 := by decide +kernel

example : Custody.LegacyPrefix longerEnv longerExtended10 :=
  Custody.trace_legacy_prefix (env := longerEnv)
    ⟨primitives.genesis,primitives.separation,primitives.unzen⟩ extension longer_extension_reachable

end Etna.Design.Current.Protocol.UnzenReview
