import EtnaProofs.ActualQueue
import EtnaWitnesses.Counterexamples.ForcedPoisonResubmit

namespace Etna.Design.ActualQueueRegression
open ActualQueue ProtocolState NonVacuity

inductive Mode | included | empty | invalid
  deriving DecidableEq

def twiceInbox : State := (Forced.enqueue worldQ.inbox 1 1000000000 true).getD worldQ.inbox
def twice : World := enqueued worldQ twiceInbox 50 15 15

def journal : List World := [worldQ,twice]

theorem actual_history : Transactions id world0 journal twice := by
  have first : Transactions id world0 [worldQ] worldQ :=
    .step (.nil _) (.enqueue (raw := 10) (paid := 1000000000) (refund := true)
      (by decide) (by decide) (by decide) rfl)
      (.enqueue (raw := 10) (paid := 1000000000) (refund := true) (by decide) (by decide) (by decide) rfl rfl)
  exact .step first (.enqueue (raw := 1) (paid := 1000000000) (refund := true)
    (by decide) (by decide) (by decide) rfl)
    (.enqueue (raw := 1) (paid := 1000000000) (refund := true) (by decide) (by decide) (by decide) rfl rfl)

def anchor : BlockValidity.Anchor := ⟨75,75,85,0,genesisHeader.elHash,0,2⟩

def cut : EndBlock id world0 twice journal anchor where
  snapshot := twice
  priorStates := journal
  laterStates := []
  order := List.append_nil _
  before := actual_history
  later := .nil _
  closed := by decide
  after := by simp
  timestamp := rfl
  tail := rfl

def primitive (mode : Mode) : Primitives where
  hashBytes := fun raw => if raw.isEmpty then 99 else 50
  canonical := fun raw => !raw.isEmpty && decide (mode ≠ .invalid)
  buildSingleton := fun _ _ _ => if mode = .included then .completedRetained else .completedEmpty

def witness (mode : Mode) (index : Nat) : Forced.Witness :=
  ⟨index,entry0,true,50,1,decide (mode ≠ .invalid),
    if mode = .included then some 50 else none,decide (mode = .included),
    if mode = .included then 1 else 0⟩

def firstBlock (mode : Mode) : BlockValidity.Block :=
  { block1 with
    header := ⟨1,501,51,101,1,1274,anchor⟩,bftTime := 1274,parentBeaconRoot := 85,
    forced := some (witness mode 0),singleton := (primitive mode).buildSingleton genesisHeader block1.header [50] }

def secondBlock (mode : Mode) : BlockValidity.Block :=
  { block2 with
    header := ⟨2,502,52,102,2,1275,anchor⟩,parentHash := 501,bftTime := 1275,
    anchorWitness := false,parentBeaconRoot := 85,
    forced := some (witness mode 1),singleton := (primitive mode).buildSingleton (firstBlock mode).header block2.header [50] }

def localRules (mode : Mode) : BlockValidity.Rules :=
  { rules0 with
    consensus := { rules0.consensus with anchorAt := fun h => if h = 0 then 14 else 75 },
    referenceNumber := 76,
    anchorAuthenticated := fun a => decide (a = anchor),
    executionValid := fun p b => decide ((p = genesisHeader ∧ b = firstBlock mode) ∨
      (p = (firstBlock mode).header ∧ b = secondBlock mode)),
    payloadValid := fun b => decide (b = firstBlock mode ∨ b = secondBlock mode),
    forcedAuthenticated := fun _ wit => decide ((wit.index,wit.stored) ∈ twice.queue) }

instance (mode : Mode) : DecidablePred (localRules mode).signature :=
  fun v => inferInstanceAs (Decidable (signed v))

theorem actual_chain (mode : Mode) :
    BlockValidity.Chain (localRules mode) genesisHeader [firstBlock mode,secondBlock mode] := by
  cases mode <;> decide +kernel

theorem actual_anchors (mode : Mode) : Anchors id world0 twice journal (localRules mode) := by
  intro a accepted
  have same : a = anchor := of_decide_eq_true accepted
  subst a
  exact ⟨cut⟩

private theorem opening (mode : Mode) (index : Nat) (parent : BlockValidity.Header)
    (b : BlockValidity.Block) (stored : (index,entry0) ∈ twice.queue)
    (result : b.singleton = (primitive mode).buildSingleton parent b.header [50]) :
    WitnessOpening (primitive mode) twice parent b (witness mode index) := by
  refine ⟨[50],if mode = .included then some [50] else none,stored,?_,?_,?_,?_,?_,?_,?_,result⟩
  all_goals cases mode <;> rfl

theorem actual_openings (mode : Mode) : Openings (primitive mode) id world0 twice journal (localRules mode) := by
  intro p b wit _ executed _ _ carried
  have decoded : (p = genesisHeader ∧ b = firstBlock mode) ∨
      (p = (firstBlock mode).header ∧ b = secondBlock mode) := of_decide_eq_true executed
  rcases decoded with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  · have same : witness mode 0 = wit := Option.some.inj carried
    subst wit
    exact ⟨cut,opening mode 0 _ _ (by decide +kernel) rfl⟩
  · have same : witness mode 1 = wit := Option.some.inj carried
    subst wit
    exact ⟨cut,opening mode 1 _ _ (by decide +kernel) rfl⟩

/-- Two entries really enqueued in one L1 block are served by two unlanded local blocks.
The second inherits the same anchor and consumes local cursor 1 at exact deadline equality,
although the L1 head remains 0. Each parser/singleton branch has explicit raw-byte semantics. -/
theorem local_exact_service (mode : Mode) :
    twice.inbox.head = 0 ∧ (1,entry0) ∈ twice.queue ∧
    (secondBlock mode).header.timestamp = entry0.timestamp+(localRules mode).forcedDelay+(localRules mode).maxAnchorAge ∧
    (secondBlock mode).anchorWitness = false ∧
    (secondBlock mode).header.cursor = (firstBlock mode).header.cursor+1 ∧
    Etna.Statements.ServesQueue twice (localRules mode) (firstBlock mode).header (secondBlock mode) := by
  have service := local_chain_service (r := localRules mode) premises.genesis.1 actual_history (fun _ _ h => h)
    (show 0 < (localRules mode).forcedDelay by change 0 < 60; decide) rfl (actual_anchors mode) (actual_openings mode) (actual_chain mode)
    ((firstBlock mode).header,secondBlock mode) (by simp [Etna.Statements.pairs])
  exact ⟨rfl,by decide +kernel,rfl,rfl,service.2 entry0 (by change (1,entry0) ∈ twice.queue; decide +kernel) (by change 1275 ≤ 1275; decide),service.1⟩

theorem exact_deadline_nonvacuous : ∃ (w : World) (entry : Forced.Entry)
    (p : BlockValidity.Header) (b : BlockValidity.Block) (r : BlockValidity.Rules),
    (p.cursor,entry) ∈ w.queue ∧ BlockValidity.Valid r p b ∧
    b.header.timestamp = entry.timestamp+r.forcedDelay+r.maxAnchorAge ∧ b.header.cursor = p.cursor+1 := by
  exact ⟨twice,entry0,(firstBlock .empty).header,secondBlock .empty,localRules .empty,
    by decide +kernel,(actual_chain .empty).2.1,rfl,(local_exact_service .empty).2.2.2.2.1⟩

/-- The byte-level theorem is exercised on each include/empty/invalid branch at a real
deadline, so none of the primitive contracts is hidden behind vacuous overdue premises. -/
theorem local_byte_actions (mode : Mode) :
    ∃ wit raw first, (secondBlock mode).forced = some wit ∧ wit.stored = entry0 ∧
      PayloadFields (primitive mode) (firstBlock mode).header (secondBlock mode) wit raw first ∧
      ByteAction (primitive mode) (firstBlock mode).header (secondBlock mode) entry0 raw first := by
  obtain ⟨_,wit,raw,first,carried,_,stored,fields,action⟩ := local_chain_byte_service (r := localRules mode) premises.genesis.1
    actual_history (fun _ _ h => h) (by change 0 < 60; decide) rfl (actual_anchors mode) (actual_openings mode)
    (actual_chain mode) ((firstBlock mode).header,secondBlock mode) (by simp [Etna.Statements.pairs])
    entry0 (by change (1,entry0) ∈ twice.queue; decide +kernel) (by change 1275 ≤ 1275; decide)
  exact ⟨wit,raw,first,carried,stored,fields,action⟩

/-- The same two original admission calls also inhabit the unchanged canonical API.
The compatible time annotation then supplies the semantic journal used above. -/
theorem canonical_admissions : CanonicalHistory.Run world0 twice [] ∧
    ∃ states, Transactions id world0 states twice := by
  have first : CanonicalHistory.Run world0 worldQ [] := .edit (.genesis premises.genesis.1)
    (.enqueue (raw := 10) (paid := 1000000000) (refund := true) (by decide) (by decide) (by decide) rfl)
  have run : CanonicalHistory.Run world0 twice [] := .edit first
    (.enqueue (raw := 1) (paid := 1000000000) (refund := true) (by decide) (by decide) (by decide) rfl)
  have timedFirst : TraceTime id (CanonicalHistory.run_trace first) :=
    .step (.refl _) (.enqueue (raw := 10) (paid := 1000000000) (refund := true)
      (by decide) (by decide) (by decide) rfl)
      (.enqueue (raw := 10) (paid := 1000000000) (refund := true) (by decide) (by decide) (by decide) rfl rfl)
  have timed : TraceTime id (CanonicalHistory.run_trace run) :=
    .step timedFirst (.enqueue (raw := 1) (paid := 1000000000) (refund := true)
      (by decide) (by decide) (by decide) rfl)
      (.enqueue (raw := 1) (paid := 1000000000) (refund := true) (by decide) (by decide) (by decide) rfl rfl)
  exact ⟨run,canonical_journal run timed⟩

/-- Omitting an eligible retained singleton is rejected; including it was valid above. -/
theorem nonempty_skip_rejected :
    Forced.step 0 2 75 60 (some ⟨0,entry0,true,50,1,true,none,false,0⟩) .completedRetained = .rejected := by decide +kernel

/-- An end-block cut at 15 cannot omit the second enqueue merely because the first
transaction has already completed: the purported suffix is still in that same block. -/
theorem incomplete_same_block_cut_rejected :
    ¬ (∀ state ∈ [twice], 15 < state.l1Block) := by
  intro after
  exact Nat.lt_irrefl 15 (after twice (by simp))

open ForcedPoisonResubmit

def recoveredJournal : List World := [worldP,worldR,worldAgain]

private theorem recovery_ok : Recovery.recover (recoveryView worldP) request worldP.adapters.recovery
    ForcedPoisonResubmit.origin true true = some (Recovery.applyRecovery (recoveryView worldP) request
      SecondBatch.recoveryConfig ForcedPoisonResubmit.origin) := by decide +kernel

private theorem before_resubmission : Transactions id world0 [worldP,worldR] worldR := by
  have admitted : Transactions id world0 [worldP] worldP :=
    .step (.nil _) (.enqueue (raw := 100) (paid := 1000000000) (refund := true)
      (by decide) (by decide) (by decide) rfl)
      (.enqueue (raw := 100) (paid := 1000000000) (refund := true) (by decide) (by decide) (by decide) rfl rfl)
  exact .step admitted (.recovery (by decide) recovery_ok) (.recovery (by decide) recovery_ok)

theorem recovered_history : Transactions id world0 recoveredJournal worldAgain :=
  .step before_resubmission (.enqueue (raw := 100) (paid := 1000000000) (refund := true)
    (by decide) (by decide) (by decide) rfl)
    (.enqueue (raw := 100) (paid := 1000000000) (refund := true) (by decide) (by decide) (by decide) rfl rfl)

def recoveryAnchor : BlockValidity.Anchor := ⟨16,16,26,0,genesisHeader.elHash,1,1⟩

def recoveryCut : EndBlock id world0 worldAgain recoveredJournal recoveryAnchor where
  snapshot := worldR
  priorStates := [worldP,worldR]
  laterStates := [worldAgain]
  order := rfl
  before := before_resubmission
  later := .step (.nil _) (.enqueue (raw := 100) (paid := 1000000000) (refund := true)
    (by decide) (by decide) (by decide) rfl)
    (.enqueue (raw := 100) (paid := 1000000000) (refund := true) (by decide) (by decide) (by decide) rfl rfl)
  closed := by decide
  after := by intro state member; simp only [List.mem_singleton] at member; subst state; decide
  timestamp := rfl
  tail := rfl

def cleared : Forced.Entry := Forced.clear 99 poison

/-- Recovery keeps original admission time/block; a later resubmission has a fresh index
and timestamp. An opening after recovery transports across the later enqueue exactly. -/
theorem recovery_and_resubmission :
    AnchorHonesty.QueueTimed id worldAgain ∧ (0,cleared) ∈ worldAgain.queue ∧
    (1,again) ∈ worldAgain.queue ∧ cleared.timestamp = poison.timestamp ∧
    cleared.l1Block = poison.l1Block ∧ again.txHash = poison.txHash ∧
    ¬ worldAgain.inbox.origin.l1Block ≤ 15 := by
  exact ⟨history_queue_timed premises.genesis.1 recovered_history,
    end_block_entry_current recoveryCut (by decide) (by decide +kernel),
    by decide +kernel,rfl,rfl,rfl,by decide +kernel⟩

def recoveredAnchor : BlockValidity.Anchor := ⟨77,77,87,0,genesisHeader.elHash,1,2⟩

def recoveredCut : EndBlock id world0 worldAgain recoveredJournal recoveredAnchor where
  snapshot := worldAgain
  priorStates := recoveredJournal
  laterStates := []
  order := List.append_nil _
  before := recovered_history
  later := .nil _
  closed := by decide
  after := by simp
  timestamp := rfl
  tail := rfl

def recoveredPrimitive : Primitives where
  hashBytes := fun raw => if raw.isEmpty then 99 else 666
  canonical := fun raw => !raw.isEmpty
  buildSingleton := fun _ _ _ => .completedRetained

def blankWitness : Forced.Witness := ⟨0,cleared,true,99,0,false,none,false,0⟩
def againWitness : Forced.Witness := ⟨1,again,true,666,1,true,some 666,true,1⟩

def blankBlock : BlockValidity.Block :=
  { (firstBlock .empty) with
    header := ⟨1,601,51,101,1,1276,recoveredAnchor⟩,generation := 1,bftTime := 1276,
    parentBeaconRoot := 87,votes := [vote 1 1 101],forced := some blankWitness,singleton := .completedRetained }

def againBlock : BlockValidity.Block :=
  { (secondBlock .included) with
    header := ⟨2,602,52,102,2,1277,recoveredAnchor⟩,generation := 1,bftTime := 1277,
    parentHash := 601,parentBeaconRoot := 87,votes := [vote 1 2 102],forced := some againWitness }

def recoveredRules : BlockValidity.Rules :=
  { localRules .included with
    consensus := HistoricalContext.derive worldAgain.inbox worldAgain.registry
      (Deployment.parameters worldAgain.inbox worldAgain.inbox.configuration) [14,77,77],
    referenceNumber := 78,signature := fun v => v ∈ [vote 1 1 101,vote 1 2 102],
    anchorAuthenticated := fun a => decide (a = recoveredAnchor),
    executionValid := fun p b => decide ((p = genesisHeader ∧ b = blankBlock) ∨
      (p = blankBlock.header ∧ b = againBlock)),
    payloadValid := fun b => decide (b = blankBlock ∨ b = againBlock),
    forcedAuthenticated := fun _ wit => decide ((wit.index,wit.stored) ∈ worldAgain.queue) }

instance : DecidablePred recoveredRules.signature :=
  fun v => inferInstanceAs (Decidable (v ∈ [vote 1 1 101,vote 1 2 102]))

theorem recovered_chain : BlockValidity.Chain recoveredRules genesisHeader [blankBlock,againBlock] := by
  decide +kernel

theorem recovered_anchors : Anchors id world0 worldAgain recoveredJournal recoveredRules := by
  intro a accepted
  have same : a = recoveredAnchor := of_decide_eq_true accepted
  subst a
  exact ⟨recoveredCut⟩

theorem recovered_openings : Openings recoveredPrimitive id world0 worldAgain recoveredJournal recoveredRules := by
  intro p b wit _ executed _ _ carried
  have decoded : (p = genesisHeader ∧ b = blankBlock) ∨
      (p = blankBlock.header ∧ b = againBlock) := of_decide_eq_true executed
  rcases decoded with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  · have same : blankWitness = wit := Option.some.inj carried
    subst wit
    exact ⟨recoveredCut,[],none,by decide +kernel,rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl⟩
  · have same : againWitness = wit := Option.some.inj carried
    subst wit
    exact ⟨recoveredCut,[66],some [66],by decide +kernel,rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl⟩

/-- A blanked entry is legally skipped, then the resubmitted transaction at local cursor
1 is included at its fresh exact deadline. L1 head is still zero; neither block landed. -/
theorem recovered_exact_service :
    worldAgain.inbox.head = 0 ∧ blankBlock.header.cursor = 1 ∧
    againBlock.header.timestamp = again.timestamp+recoveredRules.forcedDelay+recoveredRules.maxAnchorAge ∧
    againBlock.header.cursor = blankBlock.header.cursor+1 ∧
    Etna.Statements.ServesQueue worldAgain recoveredRules blankBlock.header againBlock := by
  have service := local_chain_service (r := recoveredRules) premises.genesis.1 recovered_history (fun _ _ h => h)
    (by decide) rfl recovered_anchors recovered_openings recovered_chain
    (blankBlock.header,againBlock) (by simp [Etna.Statements.pairs])
  exact ⟨rfl,rfl,rfl,service.2 again (by decide +kernel) (by decide),service.1⟩

/-- Actual byte-level service also covers recovery blanking and the fresh resubmission;
the blank parses invalid even with a retained singleton, while the copy is tx0. -/
theorem recovered_byte_actions :
    (∃ wit raw first, PayloadFields recoveredPrimitive genesisHeader blankBlock wit raw first ∧
      ByteAction recoveredPrimitive genesisHeader blankBlock cleared raw first) ∧
    (∃ wit raw first, PayloadFields recoveredPrimitive blankBlock.header againBlock wit raw first ∧
      ByteAction recoveredPrimitive blankBlock.header againBlock again raw first) := by
  have service := local_chain_byte_service (r := recoveredRules) premises.genesis.1 recovered_history (fun _ _ h => h)
    (by decide) rfl recovered_anchors recovered_openings recovered_chain
  constructor
  · obtain ⟨_,wit,raw,first,_,_,_,fields,action⟩ := service (genesisHeader,blankBlock)
      (by simp [Etna.Statements.pairs]) cleared (by decide +kernel) (by decide)
    exact ⟨wit,raw,first,fields,action⟩
  · obtain ⟨_,wit,raw,first,_,_,_,fields,action⟩ := service (blankBlock.header,againBlock)
      (by simp [Etna.Statements.pairs]) again (by decide +kernel) (by decide)
    exact ⟨wit,raw,first,fields,action⟩

end Etna.Design.ActualQueueRegression
