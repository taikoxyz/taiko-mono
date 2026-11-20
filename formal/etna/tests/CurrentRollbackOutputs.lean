import EtnaWitnesses.NonVacuity.Current
import EtnaProofs.CurrentGovernance

/-! A verifier failure may poison only a landing's saved snapshot or emitted root while
retaining a perfectly certifiable checkpoint. Rollback must judge the actual complete call. -/
namespace Etna.Design.Current.Protocol.RollbackOutputsReview
open Etna.Design Etna.Design.Current

set_option maxRecDepth 30000
set_option maxHeartbeats 1000000
set_option backward.isDefEq.respectTransparency false

abbrev N := NonVacuity.env

def broken : Environment := { N with verify := fun _ _ _ _ _ => true }
def initial : World := empty broken NonVacuity.registry
def before : World := NonVacuity.source broken

def firstLanding (snapshot root : Nat) : Landing :=
  { NonVacuity.landing with input := { NonVacuity.landing.input with
      activeCommitteeSnapshot := snapshot,lastStateRoot := root } }
def firstEvent (snapshot root : Nat) : LandingRecord :=
  ⟨before.inbox,before.history,firstLanding snapshot root⟩
def afterFirst (snapshot root : Nat) : World := landed before (firstLanding snapshot root)
def startRecord : Checkpoint := before.inbox.checkpoint
def firstRecord : Checkpoint := (afterFirst 1 100).inbox.checkpoint

private theorem before_records : before.activeRecords = [startRecord] := rfl
private theorem before_events : before.activeLandings = [] := rfl
private theorem first_events (snapshot root : Nat) :
    (afterFirst snapshot root).activeLandings = [firstEvent snapshot root] := rfl

private theorem seed_same (w : World) (call : Call) (notLanding : ∀ a, call ≠ .land a) :
    transact broken w call = transact NonVacuity.baseEnv w call := by
  cases call <;> first | rfl | exact (notLanding _ rfl).elim

private theorem source_same : before = NonVacuity.source N := by
  have emptySame : NonVacuity.deployed broken =
      NonVacuity.deployed NonVacuity.baseEnv := rfl
  have a (w : World) (n : Nat) :=
    seed_same w (.advance n) (by intro x impossible; cases impossible)
  have b (w : World) := seed_same w (.image 7 11 true) (by intro x impossible; cases impossible)
  have c (w : World) :=
    seed_same w (.enqueue [1] 1000000000 true) (by intro x impossible; cases impossible)
  have d (w : World) := seed_same w (.initializeInbox 7) (by intro x impossible; cases impossible)
  have e (w : World) := seed_same w (.registry 8 (.register 7 8 NonVacuity.unit 1))
    (by intro x impossible; cases impossible)
  have same : before = NonVacuity.source NonVacuity.baseEnv := by
    simp only [before,NonVacuity.source,NonVacuity.imaged,NonVacuity.enqueued,
      NonVacuity.initialized,NonVacuity.advanced,NonVacuity.registered,a,b,c,d,e,emptySame]
  exact same.trans NonVacuity.source_independent_of_verifier.symm

private theorem policy_same : policy broken before NonVacuity.archive 2 = NonVacuity.pol := by
  rw [source_same]
  rfl

private theorem before_reference_readable : referenceHash broken before 2 ≠ 0 := by
  simpa only [referenceHash, source_same, broken, NonVacuity.landing] using
    NonVacuity.source_landing_checks.referenceReadable

-- All three cases pass the physical guards; the broken verifier ignores the wrong output.
theorem first_accepted (snapshot root : Nat) (floor : before.inbox.snapshot ≤ snapshot) :
    land broken before (firstLanding snapshot root) = some (afterFirst snapshot root) := by
  have checks : LandingChecks broken before (firstLanding snapshot root) := by
    constructor
    case referenceReadable =>
      simpa only [firstLanding, NonVacuity.landing] using before_reference_readable
    case snapshotFloor => exact floor
    all_goals
      (try dsimp only [firstLanding,afterFirst,landed,proofsAccepted,broken,recordAt,writeRecord,
        firstFence,Start.firstLanding]) <;> first | rfl | decide +kernel
  simp only [land,checks,ite_true,afterFirst]

theorem first_reachable (snapshot root : Nat) (floor : before.inbox.snapshot ≤ snapshot) :
    Trace broken initial (afterFirst snapshot root) := by
  have next : transact broken before (.land (firstLanding snapshot root)) =
      afterFirst snapshot root := by
    change (land broken before (firstLanding snapshot root)).getD before = _
    rw [first_accepted snapshot root floor]
    rfl
  rw [← next]
  exact .step (NonVacuity.source_reachable broken) (.call _ (.land (firstLanding snapshot root)))

private def goodSegment : Suffix broken before (firstLanding 1 100) where
  archive := NonVacuity.archive
  parent := NonVacuity.genesis
  blocks := [NonVacuity.block]
  ready := by decide +kernel
  valid := by
    change Blocks.Chain (policy broken before NonVacuity.archive 2)
      NonVacuity.genesis [NonVacuity.block]
    rw [policy_same]
    exact ⟨NonVacuity.first_valid,True.intro⟩
  parentHeight := rfl
  parentCut := rfl
  terminalHeight := rfl
  terminalCut := rfl
  terminalRoot := rfl
  parentHashBound := NonVacuity.genesis_bound
  headerHashes := by
    intro b member
    have same : b = NonVacuity.block := by simpa using member
    subst b
    exact NonVacuity.first_bound

private theorem genesis_path : Custody.Path broken initial NonVacuity.genesis := by
  have reach : Trace broken initial (NonVacuity.advanced broken) :=
    .step (.step (.refl _) (.call _ (.registry 8 (.register 7 8 NonVacuity.unit 1))))
      (.call _ (.advance 2))
  exact .genesis 7 reach
    (show initializeInbox broken (NonVacuity.advanced broken) 7 =
      some (NonVacuity.initialized broken) from rfl) rfl

private theorem start_certified : Custody.Certified broken initial startRecord := by
  refine ⟨NonVacuity.genesis,?_,NonVacuity.genesis_bound,genesis_path⟩
  constructor <;> rfl

-- This alternate honest landing certifies the same checkpoint as either poisoned call.
theorem first_record_still_certified (snapshot root : Nat) :
    (afterFirst snapshot root).inbox.checkpoint = firstRecord ∧
      Custody.Certified broken initial firstRecord := by
  refine ⟨rfl,NonVacuity.first,?_,NonVacuity.first_bound,?_⟩
  · constructor <;> rfl
  · exact .landing (NonVacuity.source_reachable broken) (first_accepted 1 100 (by decide +kernel))
      goodSegment genesis_path

private theorem good_event_certified : (firstEvent 1 100).Certified broken initial := by
  have same : statement broken ((firstEvent 1 100).source initial) (firstLanding 1 100) =
      NonVacuity.template := by
    have sourceStatement : statement broken ((firstEvent 1 100).source initial)
        (firstLanding 1 100) = statement N (NonVacuity.source N) NonVacuity.landing := by
      change statement broken { initial with inbox := before.inbox,history := before.history }
        (firstLanding 1 100) = _
      rw [source_same]
      rfl
    exact sourceStatement.trans NonVacuity.source_statement
  change Certifies broken ((firstEvent 1 100).source initial)
    (statement broken ((firstEvent 1 100).source initial) (firstLanding 1 100))
  rw [same]
  refine ⟨NonVacuity.archive,NonVacuity.genesis,[NonVacuity.block],?_⟩
  have certificate := NonVacuity.source_pure_certificate
  change BatchCertificate broken { initial with inbox := before.inbox,history := before.history }
    NonVacuity.template NonVacuity.archive NonVacuity.genesis [NonVacuity.block]
  rw [source_same]
  change BatchCertificate N
    { initial with inbox := (NonVacuity.source N).inbox,history := (NonVacuity.source N).history }
    NonVacuity.template NonVacuity.archive NonVacuity.genesis [NonVacuity.block]
  exact certificate

private theorem bad_snapshot_uncertified (root : Nat) :
    ¬ (firstEvent 999 root).Certified broken initial := by
  intro certificate
  obtain ⟨archive,parent,blocks,live,_,_⟩ := certificate
  obtain ⟨ready,valid,binding,rest⟩ := live
  have snapshot := congrArg (fun d : StatementData => d.input.activeCommitteeSnapshot) binding
  have bounded := Archive.active_cutoff_bounded rest.2.2.2 ready
  change 999 = (Consensus.activeAt
    (policy broken (certificateWorld broken ((firstEvent 999 root).source initial) 2)
      archive 2).consensus (Blocks.terminal parent blocks).height).cutoff at snapshot
  change (Consensus.activeAt
    (policy broken (certificateWorld broken ((firstEvent 999 root).source initial) 2)
      archive 2).consensus (Blocks.terminal parent blocks).height).cutoff ≤ 2 at bounded
  rw [← snapshot] at bounded
  omega

-- The fixed EL catalogue allows only the two known headers. A one-block certificate must
-- bind one of their actual roots and hashes, even when the proof verifier accepts everything.
private theorem certified_outputs (event : LandingRecord)
    (consecutive : event.landing.input.lastHeight = event.landing.input.parentHeight+1)
    (certificate : event.Certified broken initial) :
    (event.landing.input.lastStateRoot = 100 ∨ event.landing.input.lastStateRoot = 101) ∧
      (event.landing.input.lastBlockHash = 101 ∨ event.landing.input.lastBlockHash = 102) := by
  obtain ⟨archive,parent,blocks,live,_,_⟩ := certificate
  obtain ⟨ready,valid,binding,rest⟩ := live
  have parentHeight := congrArg (fun d : StatementData => d.input.parentHeight) binding
  have lastHeight := congrArg (fun d : StatementData => d.input.lastHeight) binding
  change event.landing.input.parentHeight = parent.height at parentHeight
  change event.landing.input.lastHeight = (Blocks.terminal parent blocks).height at lastHeight
  have heights := Blocks.chain_height valid.1
  have length : blocks.length = 1 := by omega
  cases blocks with
  | nil => simp at length
  | cons block more =>
    have empty : more = [] := by
      have zero : more.length = 0 := by simpa using length
      exact List.eq_nil_of_length_eq_zero zero
    subst more
    have execution := valid.1.1.execution
    change decide ((parent = NonVacuity.genesis ∧ block.body.header = NonVacuity.first) ∨
      (parent = NonVacuity.first ∧ block.body.header = NonVacuity.second)) = true at execution
    have root := congrArg (fun d : StatementData => d.input.lastStateRoot) binding
    have hash := congrArg (fun d : StatementData => d.input.lastBlockHash) binding
    change event.landing.input.lastStateRoot = block.body.header.stateRoot at root
    change event.landing.input.lastBlockHash = block.body.header.elHash at hash
    rcases of_decide_eq_true execution with ⟨_,header⟩ | ⟨_,header⟩
    · rw [header] at root hash
      exact ⟨Or.inl root,Or.inl hash⟩
    · rw [header] at root hash
      exact ⟨Or.inr root,Or.inr hash⟩

private theorem bad_root_uncertified (snapshot : Nat) :
    ¬ (firstEvent snapshot 999).Certified broken initial := by
  intro certificate
  have outputs := certified_outputs (firstEvent snapshot 999) rfl certificate
  rcases outputs.1 with root | root <;> simp only [firstEvent,firstLanding] at root <;>
    contradiction

private theorem start_trusted (snapshot root : Nat) :
    Governance.TrustedRecord broken initial (afterFirst snapshot root) startRecord := by
  refine ⟨Or.inl start_certified,Or.inl ?_,?_⟩
  · exact ⟨⟨0,100,10⟩,rfl,rfl,rfl,rfl,rfl⟩
  · intro event member matching
    have same : event = firstEvent snapshot root := by
      simpa only [first_events,List.mem_singleton] using member
    subst event
    have height := congrArg Checkpoint.height matching
    change 1 = 0 at height
    contradiction

private theorem first_untrusted (snapshot root : Nat)
    (bad : ¬ (firstEvent snapshot root).Certified broken initial) :
    ¬ Governance.TrustedRecord broken initial (afterFirst snapshot root) firstRecord := by
  intro trusted
  exact bad (trusted.2.2 (firstEvent snapshot root) List.mem_cons_self rfl)

private theorem rollback_start (snapshot root : Nat)
    (bad : ¬ (firstEvent snapshot root).Certified broken initial) :
    Governance.RollbackAuthorized broken initial (afterFirst snapshot root) startRecord 1 := by
  refine ⟨List.mem_cons_of_mem _ List.mem_cons_self,
    List.mem_cons_of_mem _ List.mem_cons_self,?_,firstRecord,
    List.mem_cons_self,by decide,first_untrusted snapshot root bad,?_⟩
  · intro cp member low
    rcases List.mem_cons.mp member with fresh | old
    · have height : cp.height = 1 := congrArg Checkpoint.height fresh
      change cp.height ≤ 0 at low
      omega
    · have same : cp = startRecord := by simpa only [before_records,List.mem_singleton] using old
      subst cp
      exact start_trusted snapshot root
  · intro cp _ lower
    change cp.height < 1 at lower
    change cp.height ≤ 0
    omega

theorem snapshot_only_failure :
    (afterFirst 999 100).inbox.snapshot = 999 ∧
    Custody.Certified broken initial (afterFirst 999 100).inbox.checkpoint ∧
    Governance.RollbackAuthorized broken initial (afterFirst 999 100) startRecord 1 ∧
    (Governance.rawRollback broken (afterFirst 999 100) 7 startRecord 1).isSome = true := by
  exact ⟨rfl,(first_record_still_certified 999 100).2,
    rollback_start 999 100 (bad_snapshot_uncertified 100),by decide +kernel⟩

theorem root_only_failure :
    (afterFirst 1 999).inbox.signals.getLast? = some ⟨1,101,999⟩ ∧
    Custody.Certified broken initial (afterFirst 1 999).inbox.checkpoint ∧
    Governance.RollbackAuthorized broken initial (afterFirst 1 999) startRecord 1 ∧
    (Governance.rawRollback broken (afterFirst 1 999) 7 startRecord 1).isSome = true := by
  exact ⟨rfl,(first_record_still_certified 1 999).2,
    rollback_start 1 999 (bad_root_uncertified 1),by decide +kernel⟩

-- A subsequent visibly wrong hash must not make the preceding poisoned landing trusted.
def nextLanding : Landing :=
  ⟨⟨1,2,999,999,999,2,1,999⟩,[],[1],NonVacuity.landing.proofs⟩
def nextEvent (snapshot root : Nat) : LandingRecord :=
  ⟨(afterFirst snapshot root).inbox,(afterFirst snapshot root).history,nextLanding⟩
def afterNext (snapshot root : Nat) : World := landed (afterFirst snapshot root) nextLanding

theorem next_accepted (snapshot root : Nat) (floor : snapshot ≤ 999) :
    land broken (afterFirst snapshot root) nextLanding = some (afterNext snapshot root) := by
  have checks : LandingChecks broken (afterFirst snapshot root) nextLanding := by
    constructor
    case referenceReadable =>
      simpa only [referenceHash, referencePrefix, afterFirst, landed, nextLanding] using
        before_reference_readable
    case snapshotFloor => exact floor
    all_goals
      (try dsimp only [firstLanding,afterFirst,landed,proofsAccepted,broken,recordAt,writeRecord,
        firstFence,Start.firstLanding]) <;> first | rfl | decide +kernel
  simp only [land,checks,ite_true,afterNext]

private theorem next_uncertified (snapshot root : Nat) :
    ¬ (nextEvent snapshot root).Certified broken initial := by
  intro certificate
  have outputs := certified_outputs (nextEvent snapshot root) rfl certificate
  rcases outputs.2 with hash | hash <;> simp only [nextEvent,nextLanding] at hash <;>
    contradiction

private theorem next_start_trusted (snapshot root : Nat) :
    Governance.TrustedRecord broken initial (afterNext snapshot root) startRecord := by
  refine ⟨Or.inl start_certified,Or.inl ?_,?_⟩
  · exact ⟨⟨0,100,10⟩,rfl,rfl,rfl,rfl,rfl⟩
  · intro event member matching
    rcases List.mem_cons.mp member with fresh | old
    · subst event
      have height := congrArg Checkpoint.height matching
      change 2 = 0 at height
      contradiction
    · have same : event = firstEvent snapshot root := by
        simpa only [first_events,List.mem_singleton] using old
      subst event
      have height := congrArg Checkpoint.height matching
      change 1 = 0 at height
      contradiction

private theorem next_first_untrusted (snapshot root : Nat)
    (bad : ¬ (firstEvent snapshot root).Certified broken initial) :
    ¬ Governance.TrustedRecord broken initial (afterNext snapshot root) firstRecord := by
  intro trusted
  exact bad (trusted.2.2 (firstEvent snapshot root)
    (List.mem_cons_of_mem _ List.mem_cons_self) rfl)

private theorem next_rollback_start (snapshot root : Nat)
    (bad : ¬ (firstEvent snapshot root).Certified broken initial) :
    Governance.RollbackAuthorized broken initial (afterNext snapshot root) startRecord 1 := by
  refine ⟨List.mem_cons_of_mem _ (List.mem_cons_of_mem _ List.mem_cons_self),
    List.mem_cons_of_mem _ (List.mem_cons_of_mem _ List.mem_cons_self),?_,firstRecord,
    List.mem_cons_of_mem _ List.mem_cons_self,
    by decide,next_first_untrusted snapshot root bad,?_⟩
  · intro cp member low
    rcases List.mem_cons.mp member with newest | old
    · have height : cp.height = 2 := congrArg Checkpoint.height newest
      change cp.height ≤ 0 at low
      omega
    · rcases List.mem_cons.mp old with first | start
      · have height : cp.height = 1 := congrArg Checkpoint.height first
        change cp.height ≤ 0 at low
        omega
      · have same : cp = startRecord := by
          simpa only [before_records,List.mem_singleton] using start
        subst cp
        exact next_start_trusted snapshot root
  · intro cp _ lower
    change cp.height < 1 at lower
    change cp.height ≤ 0
    omega

private theorem next_wrong_target (snapshot root : Nat)
    (bad : ¬ (firstEvent snapshot root).Certified broken initial) (saved : Nat) :
    ¬ Governance.RollbackAuthorized broken initial (afterNext snapshot root) firstRecord saved := by
  intro authorized
  exact next_first_untrusted snapshot root bad
    (authorized.2.2.1 firstRecord (List.mem_cons_of_mem _ List.mem_cons_self) (Nat.le_refl _))

theorem first_bad_snapshot_still_selects_start :
    Governance.RollbackAuthorized broken initial (afterNext 999 100) startRecord 1 ∧
    ¬ Governance.RollbackAuthorized broken initial (afterNext 999 100) firstRecord 999 ∧
    ¬ (nextEvent 999 100).Certified broken initial ∧
    (Governance.rawRollback broken (afterNext 999 100) 7 firstRecord 999).isSome = true :=
  ⟨next_rollback_start 999 100 (bad_snapshot_uncertified 100),
    next_wrong_target 999 100 (bad_snapshot_uncertified 100) 999,
    next_uncertified 999 100,by decide +kernel⟩

theorem first_bad_root_still_selects_start :
    Governance.RollbackAuthorized broken initial (afterNext 1 999) startRecord 1 ∧
    ¬ Governance.RollbackAuthorized broken initial (afterNext 1 999) firstRecord 1 ∧
    ¬ (nextEvent 1 999).Certified broken initial ∧
    (Governance.rawRollback broken (afterNext 1 999) 7 firstRecord 1).isSome = true :=
  ⟨next_rollback_start 1 999 (bad_root_uncertified 1),
    next_wrong_target 1 999 (bad_root_uncertified 1) 1,
    next_uncertified 1 999,by decide +kernel⟩

-- Honest output remains distinguishable: its actual event certifies, and no rollback exists.
theorem honest_landing_control :
    (firstEvent 1 100).Certified broken initial ∧
    ¬ Governance.RollbackAuthorized broken initial (afterFirst 1 100) startRecord 1 := by
  refine ⟨good_event_certified,?_⟩
  intro authorized
  obtain ⟨bad,member,_,untrusted,_⟩ := authorized.2.2.2
  rcases List.mem_cons.mp member with first | start
  · subst bad
    apply untrusted
    refine ⟨Or.inl (first_record_still_certified 1 100).2,
      Or.inr ⟨firstEvent 1 100,List.mem_cons_self,rfl,good_event_certified⟩,?_⟩
    intro event retained _
    have same : event = firstEvent 1 100 := by
      simpa only [first_events,List.mem_singleton] using retained
    subst event
    exact good_event_certified
  · have same : bad = startRecord := by simpa only [before_records,List.mem_singleton] using start
    subst bad
    exact untrusted (start_trusted 1 100)

-- Voiding the poisoned event permits a clean landing at that same height.
def restored (snapshot root : Nat) : World :=
  (Governance.rawRollback broken (afterFirst snapshot root) 7 startRecord 1).getD
    (afterFirst snapshot root)

theorem rollback_voids_poisoned_events :
    (restored 999 100).activeLandings = [] ∧
    (restored 1 999).activeLandings = [] ∧
    (restored 999 100).inbox.signals = [⟨0,100,10⟩] ∧
    (restored 1 999).inbox.signals = [⟨0,100,10⟩] := by
  exact ⟨rfl,rfl,rfl,rfl⟩

theorem correct_landing_reuses_voided_height :
    land broken (restored 999 100) (firstLanding 1 100) =
      some (landed (restored 999 100) (firstLanding 1 100)) ∧
    (landed (restored 999 100) (firstLanding 1 100)).activeLandings.length = 1 ∧
    (landed (restored 999 100) (firstLanding 1 100)).inbox.signals.getLast? =
      some ⟨1,101,100⟩ := by
  have checks : LandingChecks broken (restored 999 100) (firstLanding 1 100) := by
    constructor <;> first | rfl | decide +kernel
  exact ⟨by simp only [land,checks,ite_true],rfl,rfl⟩

end Etna.Design.Current.Protocol.RollbackOutputsReview
