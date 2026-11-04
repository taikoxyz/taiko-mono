import EtnaProofs.CurrentCoherentCustody
import EtnaProofs.CurrentGovernance

namespace Etna.CurrentCustodyRegression
open Etna.Design Etna.Design.Current Protocol

example {env : Environment} {registry : RegistryMachine.State} {w : World}
    (genesis : RegistryMachine.Genesis registry)
    (primitive : Custody.Primitives env) (sound : VerifierSound env (empty env registry))
    (trace : Trace env (empty env registry) w) :
    ∀ s ∈ w.inbox.signals, Custody.SignalSafe env (empty env registry) s :=
  Custody.funds_authorized genesis primitive sound trace

-- A nonzero S requires only relative-grid divisibility, keeping absolute leaf heights.
example : (8-5)/3-1 < gridCount 3 5 11 ∧ 5+3*((8-5)/3-1+1) = 8 ∧
    3*((8-5)/3-1+1) = 8-5 :=
  offset_frontier_index (s := 5) (by decide) (by decide) (by decide) (by decide) (by decide)

def domain : Domain := ⟨1,2,3,4⟩
def genesis : Header := ⟨0,100,100,0,0,1,⟨1,1,1,0,100,0,0⟩⟩
def h1 : Header := ⟨1,101,101,201,0,2,⟨1,1,1,0,100,0,0⟩⟩
def h2 : Header := ⟨2,102,102,202,0,3,⟨1,1,1,0,100,0,0⟩⟩
def entry : Committee.Entry := ⟨7,Committee.minUnit,0,Staking.noExit⟩
def registry : RegistryMachine.State :=
  { ledger := ⟨1,fun id => if id = 0 then some ⟨⟨7,8,Committee.minUnit,0,Staking.noExit,false,none,0,0⟩,some 0⟩ else none,
      fun slot => if slot = 0 then some 0 else none,fun key => if key = 7 then some 0 else none,1,1⟩,
    config := { inbox := 3 },history := [⟨0,[entry]⟩] }
def adapters : ActualQueue.Primitives := ⟨fun _ => 0,fun _ => false,fun _ _ _ => .completedEmpty⟩
def definition : Blocks.Definition := ⟨fun _ _ => true,fun _ _ _ => true,adapters⟩
def signer : Signer.State := ⟨domain,0,1,[],false,[]⟩
/-- Finite executable regression adapters. Their accepted transitions and certificates
are proved below, but `verify := true` and `headerHash := elHash` intentionally do
not instantiate global `VerifierSound` or `Custody.Primitives.separation`. The
universal headline regression above retains those explicit trust assumptions. -/
def env : Environment where
  core := ⟨domain,7,8,0,2,9⟩
  parameters := ⟨1,10,0,⟨Committee.minUnit,Committee.minUnit,1,10⟩,1,1152,10,1,1,9⟩
  genesisHeader := genesis
  initialSigner := signer
  time := id
  stateRoot := Snapshot.number
  blockHash := fun _ n => 1000+n
  headerHash := BlockValidity.Header.elHash
  headerParent := fun hash => hash-1
  committeeHash := fun _ => 1
  configHash := fun _ => 0
  signature := fun _ => True
  txHash := fun _ => 0
  unzenNextProposal := 2
  timestampOf := fun _ => 1
  catalogue := fun id => if id = 0 then some definition else none
  payload := fun _ _ => true
  verify := fun _ _ _ _ _ => true
  imageRules := fun _ => [0]
  unzenValid := fun _ _ _ => true
  unzenRoot := fun _ => True
  startImplementation := fun _ => true
  importValid := fun _ _ _ => false
  signBytes := fun _ => 0
  token := ⟨4,9,RegistryPayments.standardTransfer 4⟩

def initial := empty env registry
def advanced := transact env initial (.advance 1)
def started := transact env advanced (.initializeInbox 7)
def imaged := transact env started (.image 7 11 true)
def source := transact env imaged (.advance 2)

theorem source_reachable : Trace env initial source :=
  .step (.step (.step (.step (.refl _) (.call _ (.advance 1))) (.call _ (.initializeInbox 7)))
    (.call _ (.image 7 11 true))) (.call _ (.advance 2))

def b1 : Block := ⟨⟨h1,100,none,domain,0,2,100,100,true,none,1,1,1,0,
  [⟨domain,0,1,0,2,201,7⟩],none,.completedEmpty⟩,⟨0,0,0,0,0⟩,[],none,[]⟩
def b2 : Block := ⟨⟨h2,101,some 201,domain,0,3,100,100,false,none,1,1,1,0,
  [⟨domain,0,2,0,2,202,7⟩],none,.completedEmpty⟩,⟨0,0,0,0,0⟩,[],none,[]⟩
def archive : List Header := [h1,h2]
def pol := policy env source archive 1
instance : DecidablePred pol.signature := fun _ => inferInstanceAs (Decidable True)
instance (r : Blocks.Policy) (p : Header) (b : Block) : Decidable (Blocks.ParentAnchorValid r p b) := by
  unfold Blocks.ParentAnchorValid
  split <;> infer_instance
instance : Decidable (Blocks.HeaderValid pol genesis b1) := inferInstanceAs (Decidable (_ ∧ _))
instance : Decidable (Blocks.HeaderValid pol h1 b2) := inferInstanceAs (Decidable (_ ∧ _))

theorem b1_valid : Blocks.Valid pol genesis b1 := by
  constructor
  all_goals first
    | decide +kernel
    | rfl
    | (constructor <;> decide +kernel)
    | (intro wit carried; cases carried)

theorem b2_valid : Blocks.Valid pol h1 b2 := by
  constructor
  all_goals first
    | decide +kernel
    | rfl
    | (constructor <;> decide +kernel)
    | (intro wit carried; cases carried)

def landing : Landing := ⟨⟨0,2,102,202,102,1,0,0⟩,[cutLeaf 1 h1.cut],[1],[⟨.sgx,11,1⟩,⟨.sp1,11,2⟩]⟩

theorem landing_checks : LandingChecks env source landing := by decide +kernel
theorem landing_accepted : land env source landing = some (landed source landing) := by
  simp [Protocol.land,landing_checks]

theorem landing_certifies : LiveCertifies env source (statement env source landing) := by
  refine ⟨archive,genesis,[b1,b2],?_,⟨⟨b1_valid,b2_valid,True.intro⟩,rfl⟩,?_,rfl,?_,?_,?_⟩
  · decide +kernel
  · rfl
  · intro b member
    rcases List.mem_cons.mp member with rfl | later
    · rfl
    · have : b = b2 := by simpa using later
      subst b; rfl
  · intro impossible
    exact (impossible rfl).elim
  · refine ⟨genesis,[],rfl,rfl,rfl,rfl,rfl,?_,?_,?_,by decide,?_⟩
    · simp [Archive.Linked,env,archive,h1,h2,genesis]
    · intro h _; rfl
    · intro b member
      rcases List.mem_cons.mp member with rfl | later
      · rfl
      · have : b = b2 := by simpa using later
        subst b; rfl
    · intro h member
      rcases List.mem_cons.mp member with rfl | later
      · decide
      · have : h = h2 := by simpa [archive] using later
        subst h; decide

example : Nonempty (Suffix env source landing) :=
  accepted_suffix_from_certificate landing_accepted landing_certifies (by decide +kernel)

-- The first accepted edge settles only height 1; the next proof still starts at 0.
def firstLanding : Landing := { landing with input := ⟨0,1,101,201,101,1,0,0⟩,leaves := [] }
def afterFirst := landed source firstLanding

theorem first_checks : LandingChecks env source firstLanding := by decide +kernel
theorem first_accepted : Protocol.land env source firstLanding = some afterFirst := by
  simp [Protocol.land,first_checks,afterFirst]
theorem after_first_reachable : Trace env initial afterFirst := by
  have step := Protocol.Step.call (env := env) source (.land firstLanding)
  have actual : transact env source (.land firstLanding) = afterFirst := by
    simp [Protocol.transact,execute,first_accepted]
  exact .step source_reachable (actual ▸ step)

def firstSuffix : Suffix env source firstLanding where
  archive := archive
  parent := genesis
  blocks := [b1]
  ready := by decide +kernel
  valid := ⟨b1_valid,True.intro⟩
  parentHeight := rfl
  parentCut := rfl
  terminalHeight := rfl
  terminalCut := rfl
  terminalRoot := rfl
  parentHashBound := rfl
  headerHashes := by
    intro b mem
    have same : b = b1 := by simpa using mem
    subst b
    rfl

theorem genesis_path : Custody.Path env initial genesis := by
  have reach : Trace env initial advanced := .step (.refl _) (.call _ (.advance 1))
  exact .genesis 7 reach (show initializeInbox env advanced 7 = some started from rfl) rfl

theorem first_path : Custody.Path env initial h1 :=
  .landing source_reachable first_accepted firstSuffix genesis_path

theorem overlap_checks : LandingChecks env afterFirst landing := by decide +kernel
theorem overlap_accepted : Protocol.land env afterFirst landing = some (landed afterFirst landing) := by
  simp [Protocol.land,overlap_checks]
theorem overlap_certifies : LiveCertifies env afterFirst (statement env afterFirst landing) :=
  landing_certifies

example : Nonempty (Suffix env afterFirst landing) :=
  accepted_suffix_from_certificate overlap_accepted overlap_certifies (by decide +kernel)

def overlapSuffix : Suffix env afterFirst landing where
  archive := archive
  parent := h1
  blocks := [b2]
  ready := by decide +kernel
  valid := ⟨b2_valid,True.intro⟩
  parentHeight := rfl
  parentCut := rfl
  terminalHeight := rfl
  terminalCut := rfl
  terminalRoot := rfl
  parentHashBound := rfl
  headerHashes := by
    intro b mem
    have same : b = b2 := by simpa using mem
    subst b
    rfl

theorem overlap_path : Custody.Path env initial h2 :=
  .landing after_first_reachable overlap_accepted overlapSuffix first_path

example : Custody.SignalSafe env initial ⟨2,102,102⟩ := ⟨h2,overlap_path,rfl,rfl,rfl,rfl⟩
example : ∃ root, Custody.AuthenticRoot env initial root ∧ Custody.Descends env initial root h2 :=
  Custody.path_rooted overlap_path

-- A forged overlap frontier changes no accepted output state.
example : (Protocol.land env afterFirst { landing with leaves := [cutLeaf 1 ⟨999,201,0⟩] }).isNone = true := by
  decide +kernel

-- A refused start is corrected before any landing, preserving the old archival record.
def switchEnv : Environment := { env with core := { env.core with unzenInbox := 99 } }
def switchInitial := empty switchEnv registry
def switchAdvanced := Protocol.transact switchEnv switchInitial (.advance 2)
def switchInitialized := Protocol.transact switchEnv switchAdvanced (.initializeInbox 7)
def wrongStart := Protocol.transact switchEnv switchInitialized (.setOrigin 8 5 505 505)
def correctedStart := Protocol.transact switchEnv wrongStart (.correctStart 7 1 501 501)
def legacyHeader : Header := ⟨1,501,501,0,0,1,⟨500,1,500,0,0,0,0⟩⟩
def provenStart := Protocol.transact switchEnv correctedStart (.unzenProve 1 legacyHeader 77)
def switchImaged := Protocol.transact switchEnv provenStart (.image 7 11 true)
def switchSource := Protocol.transact switchEnv switchImaged (.advance 3)

theorem switch_reachable : Trace switchEnv switchInitial switchSource :=
  .step (.step (.step (.step (.step (.step (.step (.refl _) (.call _ (.advance 2)))
    (.call _ (.initializeInbox 7))) (.call _ (.setOrigin 8 5 505 505)))
    (.call _ (.correctStart 7 1 501 501))) (.call _ (.unzenProve 1 legacyHeader 77)))
    (.call _ (.image 7 11 true))) (.call _ (.advance 3))

example : correctedStart.inbox.generation = 1 ∧ correctedStart.inbox.signals = [] ∧
    (recordAt correctedStart.inbox 5).isSome = true ∧ correctedStart.inbox.checkpoint.height = 1 := by
  decide +kernel

def switchHeader : Header := ⟨2,502,502,602,0,3,⟨2,2,2,1,501,1,0⟩⟩
def switchBlock : Block := ⟨⟨switchHeader,501,none,domain,1,3,100,100,true,none,1,1,2,0,
  [⟨domain,1,2,0,2,602,7⟩],none,.completedEmpty⟩,⟨0,0,0,0,0⟩,[],none,[]⟩
def switchArchive : List Header := [switchHeader]
def switchPolicy := policy switchEnv switchSource switchArchive 2
instance : DecidablePred switchPolicy.signature := fun _ => inferInstanceAs (Decidable True)
instance : Decidable (Blocks.HeaderValid switchPolicy legacyHeader switchBlock) := inferInstanceAs (Decidable (_ ∧ _))

theorem switch_valid : Blocks.Valid switchPolicy legacyHeader switchBlock := by
  constructor
  all_goals first
    | decide +kernel
    | rfl
    | (constructor <;> decide +kernel)
    | (intro wit carried; cases carried)

def switchLanding : Landing := ⟨⟨1,2,502,602,502,2,0,2⟩,[],[1],[⟨.sgx,11,1⟩,⟨.sp1,11,2⟩]⟩
theorem switch_checks : LandingChecks switchEnv switchSource switchLanding := by decide +kernel
theorem switch_accepted : Protocol.land switchEnv switchSource switchLanding = some (landed switchSource switchLanding) := by
  simp [Protocol.land,switch_checks]

theorem switch_certifies : LiveCertifies switchEnv switchSource (statement switchEnv switchSource switchLanding) := by
  refine ⟨switchArchive,legacyHeader,[switchBlock],?_,⟨⟨switch_valid,True.intro⟩,rfl⟩,rfl,rfl,?_,?_,?_⟩
  · decide +kernel
  · intro b mem
    have same : b = switchBlock := by simpa using mem
    subst b
    rfl
  · intro _ _
    rfl
  · refine ⟨legacyHeader,[],rfl,rfl,rfl,rfl,rfl,?_,?_,?_,by decide,?_⟩
    · simp [Archive.Linked,switchEnv,env,switchArchive,switchHeader,legacyHeader]
    · intro h _; rfl
    · intro b member
      have : b = switchBlock := by simpa using member
      subst b; rfl
    · intro h member
      have : h = switchHeader := by simpa [switchArchive] using member
      subst h; decide

example : Nonempty (Suffix switchEnv switchSource switchLanding) :=
  accepted_suffix_from_certificate switch_accepted switch_certifies (by decide +kernel)

def switchSuffix : Suffix switchEnv switchSource switchLanding where
  archive := switchArchive
  parent := legacyHeader
  blocks := [switchBlock]
  ready := by decide +kernel
  valid := ⟨switch_valid,True.intro⟩
  parentHeight := rfl
  parentCut := rfl
  terminalHeight := rfl
  terminalCut := rfl
  terminalRoot := rfl
  parentHashBound := rfl
  headerHashes := by
    intro b mem
    have same : b = switchBlock := by simpa using mem
    subst b
    rfl

theorem corrected_root_path : Custody.Path switchEnv switchInitial legacyHeader :=
  .unzen switch_reachable switch_accepted rfl (by decide) rfl True.intro
    ⟨rfl,rfl,rfl,rfl,rfl,rfl,rfl⟩ rfl ⟨⟨1,501,501⟩,by decide +kernel⟩

theorem corrected_landing_path : Custody.Path switchEnv switchInitial switchHeader :=
  .landing switch_reachable switch_accepted switchSuffix corrected_root_path

example : Custody.SignalSafe switchEnv switchInitial ⟨2,502,502⟩ :=
  ⟨switchHeader,corrected_landing_path,rfl,rfl,rfl,rfl⟩

-- Neither the wrong archival start nor a start lacking the legacy proof can land.
example : (Protocol.land switchEnv wrongStart switchLanding).isNone = true := by decide +kernel
example : (Protocol.land switchEnv correctedStart switchLanding).isNone = true := by decide +kernel

-- Rollback restores the snapshot saved with its checkpoint, never an arbitrary argument.
theorem arbitrary_rollback_snapshot_rejected :
    (rollback env afterFirst 7 source.inbox.checkpoint 999).isNone = true := by
  decide +kernel

def retainedHeader (cp : Checkpoint) : Header := if cp.height = 0 then genesis else h1

theorem first_shared_chain : Custody.Coherent env initial afterFirst := by
  refine Or.inr ⟨retainedHeader,rfl,?_,?_,?_⟩
  · intro cp member
    change cp ∈ [afterFirst.inbox.checkpoint,source.inbox.checkpoint] at member
    rcases List.mem_cons.mp member with rfl | older
    · exact ⟨⟨rfl,rfl⟩,rfl⟩
    · have same : cp = source.inbox.checkpoint := by simpa using older
      subst cp
      exact ⟨⟨rfl,rfl⟩,rfl⟩
  · refine .step afterFirst.inbox.checkpoint source.inbox.checkpoint [] rfl (by decide +kernel) ?_ ?_
    · exact ⟨source,afterFirst,firstLanding,firstSuffix,source_reachable,first_accepted,rfl,rfl⟩
    · exact .root _ ⟨⟨0,100,100⟩,rfl,rfl,rfl,rfl,Or.inl ⟨rfl,rfl⟩⟩
  · intro signal member
    change signal ∈ [⟨0,100,100⟩,⟨1,101,101⟩] at member
    rcases List.mem_cons.mp member with rfl | later
    · exact ⟨source.inbox.checkpoint,by decide +kernel,rfl,rfl,rfl⟩
    · have same : signal = ⟨1,101,101⟩ := by simpa using later
      subst signal
      exact ⟨afterFirst.inbox.checkpoint,by decide +kernel,rfl,rfl,rfl⟩

def restored : World := (rollback env afterFirst 7 source.inbox.checkpoint 0).getD afterFirst

theorem rollback_accepted : rollback env afterFirst 7 source.inbox.checkpoint 0 = some restored := by
  rfl

theorem rollback_retains_one_shared_chain : Custody.Coherent env initial restored :=
  Custody.rollback_coherent first_shared_chain rollback_accepted

def staleSignalMutant : World :=
  { restored with inbox := { restored.inbox with signals := afterFirst.inbox.signals } }

theorem missing_signal_filter_breaks_shared_chain : ¬ Custody.Coherent env initial staleSignalMutant := by
  intro held
  have impossible := Custody.coherent_signal_bounded held
    (show (⟨1,101,101⟩ : Signal) ∈ staleSignalMutant.inbox.signals from by decide +kernel)
  change 1 ≤ 0 at impossible
  omega

-- Start reuse and correction after any landing remain rejected after a rollback to S.
example : (setOrigin switchEnv correctedStart 8 2 502 502).isNone = true := by decide +kernel
example : (correctStart switchEnv (landed switchSource switchLanding) 7 1 501 501).isNone = true := by
  decide +kernel

example : (rollback env afterFirst 7 source.inbox.checkpoint 0).isSome = true ∧
    restored.inbox.snapshot = 0 ∧ restored.inbox.signals = [⟨0,100,100⟩] := by decide +kernel

def recovery : RecoveryRequest := ⟨7,0,1,0,100,[],[],0,none⟩
def recovered : World := (recover env afterFirst recovery).getD afterFirst

example : (recover env afterFirst recovery).isSome = true ∧ recovered.inbox.generation = 1 ∧
    recovered.inbox.checkpoint = afterFirst.inbox.checkpoint ∧
    recovered.inbox.signals = afterFirst.inbox.signals := by decide +kernel

-- Competing accepted batches share the same source. The later overlapping batch
-- writes only its suffix, and rollback retains the earlier signal and exact snapshot.
def afterOverlap := landed afterFirst landing
example : (land env source firstLanding).isSome = true ∧ (land env source landing).isSome = true ∧
    (land env afterFirst landing).isSome = true ∧
    ((rollback env afterOverlap 7 afterFirst.inbox.checkpoint 0).map (fun w => w.inbox.signals)) =
      some afterFirst.inbox.signals := by decide +kernel

example : ((rollback env recovered 7 source.inbox.checkpoint 0).map
    (fun w => (w.inbox.generation,w.inbox.checkpoint.height,w.inbox.snapshot))) = some (1,0,0) := by
  decide +kernel

def switchAfterLanding := landed switchSource switchLanding
def switchRestored : World :=
  (rollback switchEnv switchAfterLanding 7 switchSource.inbox.checkpoint 0).getD switchAfterLanding

example : (rollback switchEnv switchAfterLanding 7 switchSource.inbox.checkpoint 0).isSome = true ∧
    switchRestored.everLanded = true ∧ switchRestored.inbox.checkpoint.height = 1 ∧
    switchRestored.legacySignals = switchAfterLanding.legacySignals ∧
    (correctStart switchEnv switchRestored 7 2 502 502).isNone = true := by decide +kernel

-- An earlier Unzen checkpoint alone is insufficient: every accepted proposal must
-- have finalized, and rollback to S reopens this same fence.
example : (land switchEnv { switchSource with unzen := { switchSource.unzen with nextProposal := 3 } }
    switchLanding).isNone = true ∧
    (land switchEnv { switchRestored with unzen := { switchRestored.unzen with nextProposal := 3 } }
      switchLanding).isNone = true := by decide +kernel

-- Executable semantic mutants demonstrate which lifecycle boundary each rejection
-- protects. The signal guard is deliberately retained in the correction mutant.
def setOriginWithoutOnce (w : World) (caller height hash root : Nat) : Option World :=
  if w.initialized = true ∧ w.inbox.generation = 0 ∧ caller = switchEnv.core.originWriter ∧
      switchEnv.core.unzenInbox ≠ 0 ∧ switchEnv.core.forkTime ≤ switchEnv.time w.number ∧
      0 < height ∧ height < limit48 ∧ hash ≠ 0 ∧ root ≠ 0 then
    some (writeStart w height hash root w.number (switchEnv.time w.number) 0)
  else none

def correctWithoutEverLanded (w : World) (caller height hash root : Nat) : Option World :=
  w.start.bind fun old =>
    if caller = switchEnv.core.owner ∧ switchEnv.core.unzenInbox ≠ 0 ∧ w.inbox.checkpoint.height = old.height ∧ w.inbox.signals = [] ∧
        0 < height ∧ height < limit48 ∧ hash ≠ 0 ∧ root ≠ 0 ∧ w.inbox.generation+1 < limit48 then
      some (writeStart w height hash root w.number (switchEnv.time w.number) (w.inbox.generation+1))
    else none

example : (setOrigin switchEnv wrongStart 8 2 502 502).isNone = true ∧
    (setOriginWithoutOnce wrongStart 8 2 502 502).isSome = true := by decide +kernel

example : (correctStart switchEnv switchRestored 7 2 502 502).isNone = true ∧
    (correctWithoutEverLanded switchRestored 7 2 502 502).isSome = true := by decide +kernel

-- Ghost guards describe DAO upgrade admissibility, not storage checks. Erasing them
-- accepts these raw owner actions, and external historical authorization rejects them.
example : (Governance.rawCorrectStart switchEnv switchRestored 7 2 502 502).isSome = true ∧
    ¬ Governance.UpgradeAuthorized switchRestored (.correctStart 7 2 502 502) := by
  constructor
  · decide +kernel
  · change ¬ switchRestored.everLanded = false
    decide +kernel

example : (Governance.rawRollback env afterFirst 7 source.inbox.checkpoint 999).isSome = true ∧
    ¬ Governance.UpgradeAuthorized afterFirst (.rollback 7 source.inbox.checkpoint 999) := by
  constructor
  · decide +kernel
  · change ¬ (source.inbox.checkpoint ∈ afterFirst.activeRecords ∧
      (source.inbox.checkpoint,999) ∈ afterFirst.activeSnapshots)
    decide +kernel

end Etna.CurrentCustodyRegression
