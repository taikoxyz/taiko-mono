import ZkGasStatements

/-!
# Step model proofs

Lemmas about each instruction body of `stepOutcome` (`ZkGasModel.Step`), and the three step
headline theorems, whose types are exactly the statements in `ZkGasStatements/Claims.lean`.

Each body lemma states, for every result the body returns with `gas` left to it, that the gas
after is at most `gas` and, for a body other than the CALL and CREATE families', that the step
opens no frame. The proofs unfold the body, split every `if` and `match`, and close each
result's case by arithmetic. The stage helpers that return `⊕` (`callRange`, `callRanges`,
`createInitcode`, `createBase`) have lemmas of their own for each side.
-/
namespace TaikoSpec.ZkGas.Proofs

open Statements

@[simp] theorem continueWith_gasAfter (g : Nat) (b : BranchId) : (continueWith g b).gasAfter = g :=
  rfl
@[simp] theorem succeedWith_gasAfter (g : Nat) (b : BranchId) : (succeedWith g b).gasAfter = g :=
  rfl
@[simp] theorem revertWith_gasAfter (g : Nat) (b : BranchId) : (revertWith g b).gasAfter = g :=
  rfl
@[simp] theorem haltKeeping_gasAfter (g : Nat) (b : BranchId) : (haltKeeping g b).gasAfter = g :=
  rfl
@[simp] theorem haltSpendingAll_gasAfter (b : BranchId) : (haltSpendingAll b).gasAfter = 0 := rfl
@[simp] theorem continueWith_outcome (g : Nat) (b : BranchId) :
    (continueWith g b).outcome = .continue := rfl
@[simp] theorem succeedWith_outcome (g : Nat) (b : BranchId) :
    (succeedWith g b).outcome = .success := rfl
@[simp] theorem revertWith_outcome (g : Nat) (b : BranchId) : (revertWith g b).outcome = .revert :=
  rfl
@[simp] theorem haltKeeping_outcome (g : Nat) (b : BranchId) :
    (haltKeeping g b).outcome = .haltKeep := rfl
@[simp] theorem haltSpendingAll_outcome (b : BranchId) :
    (haltSpendingAll b).outcome = .haltSpendAll := rfl

/-! ## Memory -/

/-- A memory expansion leaves at most the gas it had. -/
theorem resizeMemory_le {current gas offset len gas' words : Nat}
    (h : resizeMemory current gas offset len = some (gas', words)) : gas' ≤ gas := by
  unfold resizeMemory at h
  dsimp only at h
  split at h
  · simp only [Option.some.injEq, Prod.mk.injEq] at h
    omega
  · split at h
    · simp at h
    · simp only [Option.some.injEq, Prod.mk.injEq] at h
      omega

/-- An expansion of the step's memory leaves at most the gas it had. -/
theorem expandMemory_le {pre : Pre} {gas offset len gas' : Nat}
    (h : expandMemory pre gas offset len = .ok (some gas')) : gas' ≤ gas := by
  unfold expandMemory at h
  simp only [bind, Except.bind, pure, Except.pure] at h
  split at h
  · simp at h
  · rename_i words _
    simp only [Except.ok.injEq] at h
    cases hr : resizeMemory words gas offset len with
    | none => simp [hr] at h
    | some p =>
      obtain ⟨g, w⟩ := p
      simp only [hr, Option.map_some, Option.some.injEq] at h
      subst h
      exact resizeMemory_le hr

/-! ## Bodies that open no frame -/

theorem popStep_spec (pre : Pre) (gas n : Nat) (u s : BranchId) :
    (popStep pre gas n u s).gasAfter ≤ gas ∧ (popStep pre gas n u s).outcome ≠ .newFrame := by
  unfold popStep; split <;> simp

theorem pushStep_spec (pre : Pre) (gas : Nat) (o s : BranchId) :
    (pushStep pre gas o s).gasAfter ≤ gas ∧ (pushStep pre gas o s).outcome ≠ .newFrame := by
  unfold pushStep; split <;> simp

theorem dupStep_spec (pre : Pre) (gas n : Nat) :
    (dupStep pre gas n).gasAfter ≤ gas ∧ (dupStep pre gas n).outcome ≠ .newFrame := by
  unfold dupStep; repeat' split
  all_goals simp

theorem swapStep_spec (pre : Pre) (gas n : Nat) :
    (swapStep pre gas n).gasAfter ≤ gas ∧ (swapStep pre gas n).outcome ≠ .newFrame := by
  unfold swapStep; split <;> simp

theorem tstoreStep_spec (pre : Pre) (gas : Nat) :
    (tstoreStep pre gas).gasAfter ≤ gas ∧ (tstoreStep pre gas).outcome ≠ .newFrame := by
  unfold tstoreStep; split
  · simp
  · exact popStep_spec pre gas 2 _ _

theorem expStep_spec (pre : Pre) (gas : Nat) (r : StepResult) (h : expStep pre gas = .ok r) :
    r.gasAfter ≤ gas ∧ r.outcome ≠ .newFrame := by
  unfold expStep at h
  simp only [bind, Except.bind, pure, Except.pure] at h
  repeat' split at h
  all_goals first
    | (simp at h; done)
    | (injection h with h; subst h; (try simp) <;> omega)

theorem jumpStep_spec (pre : Pre) (gas : Nat) (r : StepResult) (h : jumpStep pre gas = .ok r) :
    r.gasAfter ≤ gas ∧ r.outcome ≠ .newFrame := by
  unfold jumpStep at h
  simp only [bind, Except.bind, pure, Except.pure] at h
  repeat' split at h
  all_goals first
    | (simp at h; done)
    | (injection h with h; subst h; simp)

theorem jumpiStep_spec (pre : Pre) (gas : Nat) (r : StepResult) (h : jumpiStep pre gas = .ok r) :
    r.gasAfter ≤ gas ∧ r.outcome ≠ .newFrame := by
  unfold jumpiStep at h
  simp only [bind, Except.bind, pure, Except.pure] at h
  repeat' split at h
  all_goals first
    | (simp at h; done)
    | (injection h with h; subst h; simp)

theorem memoryAccessStep_spec (pre : Pre) (gas len : Nat) (r : StepResult)
    (h : memoryAccessStep pre gas len = .ok r) :
    r.gasAfter ≤ gas ∧ r.outcome ≠ .newFrame := by
  unfold memoryAccessStep at h
  simp only [bind, Except.bind, pure, Except.pure] at h
  repeat' split at h
  all_goals first
    | (simp at h; done)
    | (injection h with h; subst h; simp; done)
    | (injection h with h; subst h; have := expandMemory_le ‹_›; simp; omega)

theorem mcopyStep_spec (pre : Pre) (gas : Nat) (r : StepResult) (h : mcopyStep pre gas = .ok r) :
    r.gasAfter ≤ gas ∧ r.outcome ≠ .newFrame := by
  unfold mcopyStep at h
  simp only [bind, Except.bind, pure, Except.pure] at h
  repeat' split at h
  all_goals first
    | (simp at h; done)
    | (injection h with h; subst h; (try simp) <;> omega)
    | (injection h with h; subst h; have := expandMemory_le ‹_›; simp; omega)

theorem keccakStep_spec (pre : Pre) (gas : Nat) (r : StepResult) (h : keccakStep pre gas = .ok r) :
    r.gasAfter ≤ gas ∧ r.outcome ≠ .newFrame := by
  unfold keccakStep at h
  simp only [bind, Except.bind, pure, Except.pure] at h
  repeat' split at h
  all_goals first
    | (simp at h; done)
    | (injection h with h; subst h; (try simp) <;> omega)
    | (injection h with h; subst h; have := expandMemory_le ‹_›; simp; omega)

theorem copyCostAndResize_spec (pre : Pre) (gas memOffset len : Nat) (b : CopyBranches)
    (r : StepResult) (h : copyCostAndResize pre gas memOffset len b = .ok r) :
    r.gasAfter ≤ gas ∧ r.outcome ≠ .newFrame := by
  unfold copyCostAndResize at h
  simp only [bind, Except.bind, pure, Except.pure] at h
  repeat' split at h
  all_goals first
    | (simp at h; done)
    | (injection h with h; subst h; (try simp) <;> omega)
    | (injection h with h; subst h; have := expandMemory_le ‹_›; simp; omega)

theorem dataCopyStep_spec (pre : Pre) (gas : Nat) (r : StepResult)
    (h : dataCopyStep pre gas = .ok r) : r.gasAfter ≤ gas ∧ r.outcome ≠ .newFrame := by
  unfold dataCopyStep at h
  simp only [bind, Except.bind, pure, Except.pure] at h
  repeat' split at h
  all_goals first
    | (simp at h; done)
    | (injection h with h; subst h; simp)
    | exact copyCostAndResize_spec _ _ _ _ _ _ h

theorem returndatacopyStep_spec (pre : Pre) (gas : Nat) (r : StepResult)
    (h : returndatacopyStep pre gas = .ok r) : r.gasAfter ≤ gas ∧ r.outcome ≠ .newFrame := by
  unfold returndatacopyStep at h
  simp only [bind, Except.bind, pure, Except.pure] at h
  repeat' split at h
  all_goals first
    | (simp at h; done)
    | (injection h with h; subst h; simp)
    | exact copyCostAndResize_spec _ _ _ _ _ _ h

theorem loadAccount_spec (pre : Pre) (gas : Nat) (b : LoadBranches) (r : StepResult)
    (h : loadAccount pre gas b = .ok r) : r.gasAfter ≤ gas ∧ r.outcome ≠ .newFrame := by
  unfold loadAccount at h
  simp only [bind, Except.bind, pure, Except.pure] at h
  repeat' split at h
  all_goals first
    | (simp at h; done)
    | (injection h with h; subst h; (try simp) <;> omega)

theorem extcodecopyStep_spec (pre : Pre) (gas : Nat) (r : StepResult)
    (h : extcodecopyStep pre gas = .ok r) : r.gasAfter ≤ gas ∧ r.outcome ≠ .newFrame := by
  unfold extcodecopyStep at h
  dsimp only at h
  simp only [bind, Except.bind, pure, Except.pure] at h
  repeat' split at h
  all_goals first
    | (simp at h; done)
    | (injection h with h; subst h; (try simp) <;> omega)
    | (injection h with h; subst h; have := expandMemory_le ‹_›; simp; omega)
    | (obtain ⟨h1, h2⟩ := loadAccount_spec _ _ _ _ h
       exact ⟨by have := expandMemory_le ‹_›; omega, h2⟩)
    | (obtain ⟨h1, h2⟩ := loadAccount_spec _ _ _ _ h; exact ⟨by omega, h2⟩)

theorem returnStep_spec (pre : Pre) (gas : Nat) (revert : Bool) (r : StepResult)
    (h : returnStep pre gas revert = .ok r) : r.gasAfter ≤ gas ∧ r.outcome ≠ .newFrame := by
  unfold returnStep at h
  simp only [bind, Except.bind, pure, Except.pure] at h
  repeat' split at h
  all_goals first
    | (simp at h; done)
    | (injection h with h; subst h; simp; done)
    | (injection h with h; subst h; have := expandMemory_le ‹_›; simp; omega)

theorem logStep_spec (pre : Pre) (gas n : Nat) (r : StepResult) (h : logStep pre gas n = .ok r) :
    r.gasAfter ≤ gas ∧ r.outcome ≠ .newFrame := by
  unfold logStep at h
  simp only [bind, Except.bind, pure, Except.pure] at h
  repeat' split at h
  all_goals first
    | (simp at h; done)
    | (injection h with h; subst h; (try simp) <;> omega)
    | (injection h with h; subst h; have := expandMemory_le ‹_›; simp; omega)

theorem accountAccessStep_spec (pre : Pre) (gas : Nat) (r : StepResult)
    (h : accountAccessStep pre gas = .ok r) : r.gasAfter ≤ gas ∧ r.outcome ≠ .newFrame := by
  unfold accountAccessStep at h
  split at h
  · simp only [pure, Except.pure, Except.ok.injEq] at h
    subst h
    simp
  · exact loadAccount_spec _ _ _ _ h

theorem selfdestructStep_spec (pre : Pre) (gas : Nat) (r : StepResult)
    (h : selfdestructStep pre gas = .ok r) : r.gasAfter ≤ gas ∧ r.outcome ≠ .newFrame := by
  unfold selfdestructStep at h
  simp only [bind, Except.bind, pure, Except.pure] at h
  repeat' split at h
  all_goals first
    | (simp at h; done)
    | (injection h with h; subst h; (try simp) <;> omega)

theorem sloadStep_spec (pre : Pre) (gas : Nat) (r : StepResult) (h : sloadStep pre gas = .ok r) :
    r.gasAfter ≤ gas ∧ r.outcome ≠ .newFrame := by
  unfold sloadStep at h
  simp only [bind, Except.bind, pure, Except.pure] at h
  repeat' split at h
  all_goals first
    | (simp at h; done)
    | (injection h with h; subst h; (try simp) <;> omega)

theorem sstoreStep_spec (pre : Pre) (gas : Nat) (r : StepResult) (h : sstoreStep pre gas = .ok r) :
    r.gasAfter ≤ gas ∧ r.outcome ≠ .newFrame := by
  unfold sstoreStep at h
  simp only [bind, Except.bind, pure, Except.pure] at h
  repeat' split at h
  all_goals first
    | (simp at h; done)
    | (injection h with h; subst h; (try simp) <;> omega)

/-! ## The CALL family -/

theorem callSpawn_spec (pre : Pre) (gas : Nat) (b : BranchId) (r : StepResult)
    (h : callSpawn pre gas b = .ok r) : r.gasAfter ≤ gas ∧ r.outcome = .newFrame := by
  unfold callSpawn at h
  simp only [bind, Except.bind, pure, Except.pure] at h
  split at h
  · simp at h
  · injection h with h
    subst h
    exact ⟨Nat.sub_le _ _, rfl⟩

theorem callRange_inl {gas words offset len : Nat} {a b c : BranchId} {r : StepResult}
    (h : callRange gas words offset len a b c = .inl r) :
    r.gasAfter ≤ gas ∧ r.outcome ≠ .newFrame := by
  unfold callRange at h
  repeat' split at h
  all_goals first
    | (simp at h; done)
    | (injection h with h; subst h; simp)

theorem callRange_inr {gas words offset len gas' words' : Nat} {a b c : BranchId}
    (h : callRange gas words offset len a b c = .inr (gas', words')) : gas' ≤ gas := by
  unfold callRange at h
  repeat' split at h
  all_goals first
    | (simp at h; done)
    | (simp only [Sum.inr.injEq, Prod.mk.injEq] at h; omega)
    | (simp only [Sum.inr.injEq] at h; subst h; exact resizeMemory_le ‹_›)

theorem callRanges_inl {gas words inOffset inLen outOffset outLen : Nat} {r : StepResult}
    (h : callRanges gas words inOffset inLen outOffset outLen = .inl r) :
    r.gasAfter ≤ gas ∧ r.outcome ≠ .newFrame := by
  unfold callRanges at h
  split at h
  · rename_i r' h1
    simp only [Sum.inl.injEq] at h
    subst h
    exact callRange_inl h1
  · rename_i g w h1
    split at h
    · rename_i r' h2
      simp only [Sum.inl.injEq] at h
      subst h
      have := callRange_inr h1
      obtain ⟨h3, h4⟩ := callRange_inl h2
      exact ⟨by omega, h4⟩
    · simp at h

theorem callRanges_inr {gas words inOffset inLen outOffset outLen gas' : Nat}
    (h : callRanges gas words inOffset inLen outOffset outLen = .inr gas') : gas' ≤ gas := by
  unfold callRanges at h
  split at h
  · simp at h
  · rename_i g w h1
    split at h
    · simp at h
    · rename_i g' w' h2
      simp only [Sum.inr.injEq] at h
      subst h
      have := callRange_inr h1
      have := callRange_inr h2
      omega

theorem callTarget_le (pre : Pre) (gas : Nat) (transfer : Bool) (r : StepResult)
    (h : callTarget pre gas transfer = .ok r) : r.gasAfter ≤ gas := by
  unfold callTarget at h
  simp only [bind, Except.bind, pure, Except.pure] at h
  repeat' split at h
  all_goals first
    | (simp at h; done)
    | (injection h with h; subst h; simp)
    | (have := (callSpawn_spec _ _ _ _ h).1; omega)

theorem callStep_le (pre : Pre) (gas : Nat) (r : StepResult) (h : callStep pre gas = .ok r) :
    r.gasAfter ≤ gas := by
  unfold callStep at h
  simp only [bind, Except.bind, pure, Except.pure] at h
  repeat' split at h
  all_goals first
    | (simp at h; done)
    | (injection h with h; subst h; simp; done)
    | (injection h with h; subst h; exact (callRanges_inl ‹_›).1)
    | (have := callTarget_le _ _ _ _ h; have := callRanges_inr ‹_›; omega)

/-! ## CREATE and CREATE2 -/

theorem createInitcode_inl {pre : Pre} {gas offset len : Nat} {r : StepResult}
    (h : createInitcode pre gas offset len = .ok (.inl r)) :
    r.gasAfter ≤ gas ∧ r.outcome ≠ .newFrame := by
  unfold createInitcode at h
  simp only [bind, Except.bind, pure, Except.pure] at h
  repeat' split at h
  all_goals first
    | (simp at h; done)
    | (simp only [Except.ok.injEq, Sum.inl.injEq] at h; subst h; (try simp) <;> omega)

theorem createInitcode_inr {pre : Pre} {gas offset len gas' : Nat}
    (h : createInitcode pre gas offset len = .ok (.inr gas')) : gas' ≤ gas := by
  unfold createInitcode at h
  simp only [bind, Except.bind, pure, Except.pure] at h
  repeat' split at h
  all_goals first
    | (simp at h; done)
    | (simp only [Except.ok.injEq, Sum.inr.injEq] at h; omega)
    | (simp only [Except.ok.injEq, Sum.inr.injEq] at h; subst h; have := expandMemory_le ‹_›;
       omega)

theorem createBase_inl {pre : Pre} {gas len : Nat} {create2 : Bool} {r : StepResult}
    (h : createBase pre gas len create2 = .inl r) :
    r.gasAfter ≤ gas ∧ r.outcome ≠ .newFrame := by
  unfold createBase at h
  dsimp only at h
  repeat' split at h
  all_goals first
    | (simp at h; done)
    | (simp only [Sum.inl.injEq] at h; subst h; simp)

theorem createBase_inr {pre : Pre} {gas len gas' : Nat} {create2 : Bool}
    (h : createBase pre gas len create2 = .inr gas') : gas' ≤ gas := by
  unfold createBase at h
  dsimp only at h
  repeat' split at h
  all_goals first
    | (simp at h; done)
    | (simp only [Sum.inr.injEq] at h; omega)

theorem createStep_le (pre : Pre) (gas : Nat) (create2 : Bool) (r : StepResult)
    (h : createStep pre gas create2 = .ok r) : r.gasAfter ≤ gas := by
  unfold createStep at h
  simp only [bind, Except.bind, pure, Except.pure] at h
  repeat' split at h
  all_goals first
    | (simp at h; done)
    | (injection h with h; subst h; simp; done)
    | (injection h with h; subst h; exact (createInitcode_inl ‹_›).1)
    | (injection h with h; subst h; have := createInitcode_inr ‹_›;
       have := (createBase_inl ‹_›).1; omega)
    | (injection h with h; subst h; have := createInitcode_inr ‹_›;
       have := createBase_inr ‹_›; simp only; omega)

/-! ## Every body -/

/-- The categories whose body opens a frame: the CALL and CREATE families. -/
def SpawnCategory (c : Category) : Prop := c = .call ∨ c = .create true ∨ c = .create false

/-- Every body leaves at most the gas it gets, and only the CALL and CREATE families' open a
frame. -/
theorem body_spec (pre : Pre) (gas : Nat) (c : Category) (r : StepResult)
    (h : body pre gas c = .ok r) :
    r.gasAfter ≤ gas ∧ (r.outcome = .newFrame → SpawnCategory c) := by
  have noSpawn : r.gasAfter ≤ gas ∧ r.outcome ≠ .newFrame →
      r.gasAfter ≤ gas ∧ (r.outcome = .newFrame → SpawnCategory c) :=
    fun ⟨hg, hn⟩ => ⟨hg, fun e => absurd e hn⟩
  cases c with
  | call => exact ⟨callStep_le _ _ _ h, fun _ => Or.inl rfl⟩
  | create create2 =>
    refine ⟨createStep_le _ _ _ _ h, fun _ => ?_⟩
    cases create2
    · exact Or.inr (Or.inr rfl)
    · exact Or.inr (Or.inl rfl)
  | exp => exact noSpawn (expStep_spec _ _ _ h)
  | jump => exact noSpawn (jumpStep_spec _ _ _ h)
  | jumpi => exact noSpawn (jumpiStep_spec _ _ _ h)
  | memoryAccess len => exact noSpawn (memoryAccessStep_spec _ _ _ _ h)
  | mcopy => exact noSpawn (mcopyStep_spec _ _ _ h)
  | keccak => exact noSpawn (keccakStep_spec _ _ _ h)
  | dataCopy => exact noSpawn (dataCopyStep_spec _ _ _ h)
  | returndatacopy => exact noSpawn (returndatacopyStep_spec _ _ _ h)
  | extcodecopy => exact noSpawn (extcodecopyStep_spec _ _ _ h)
  | ret revert => exact noSpawn (returnStep_spec _ _ _ _ h)
  | log n => exact noSpawn (logStep_spec _ _ _ _ h)
  | accountAccess => exact noSpawn (accountAccessStep_spec _ _ _ h)
  | selfdestruct => exact noSpawn (selfdestructStep_spec _ _ _ h)
  | sload => exact noSpawn (sloadStep_spec _ _ _ h)
  | sstore => exact noSpawn (sstoreStep_spec _ _ _ h)
  | arith | bitwise | pop | calldataload | blobhash | blockhash | tload =>
    simp only [body, tloadStep, pure, Except.pure, Except.ok.injEq] at h
    subst h
    exact noSpawn (popStep_spec _ _ _ _ _)
  | push | env | selfbalance =>
    simp only [body, pure, Except.pure, Except.ok.injEq] at h
    subst h
    exact noSpawn (pushStep_spec _ _ _ _)
  | dup n =>
    simp only [body, pure, Except.pure, Except.ok.injEq] at h
    subst h
    exact noSpawn (dupStep_spec _ _ _)
  | swap n =>
    simp only [body, pure, Except.pure, Except.ok.injEq] at h
    subst h
    exact noSpawn (swapStep_spec _ _ _)
  | tstore =>
    simp only [body, pure, Except.pure, Except.ok.injEq] at h
    subst h
    exact noSpawn (tstoreStep_spec _ _)
  | stop =>
    simp only [body, stopStep, pure, Except.pure, Except.ok.injEq] at h
    subst h
    exact noSpawn (by simp)
  | jumpdest =>
    simp only [body, jumpdestStep, pure, Except.pure, Except.ok.injEq] at h
    subst h
    exact noSpawn (by simp)
  | halt b =>
    simp only [body, haltStep, pure, Except.pure, Except.ok.injEq] at h
    subst h
    exact noSpawn (by simp)

/-! ## Headlines -/

/-- `allBranches` lists every branch. -/
theorem branches_complete : BranchesComplete := by
  intro b
  cases b <;> decide

/-- No step on Unzen leaves its frame more gas than it had. -/
theorem step_gas_monotone : StepGasMonotone := by
  intro pre r h
  simp only [stepOutcome] at h
  split at h
  · simp only [pure, Except.pure, Except.ok.injEq] at h
    subst h
    simp
  · have := (body_spec _ _ _ _ h).1
    omega

/-- An `if` equals `x` exactly when its taken branch does. -/
theorem ite_eq_iff' {c : Prop} [Decidable c] {α : Sort _} {a b x : α} :
    (if c then a else b) = x ↔ (c ∧ a = x) ∨ (¬c ∧ b = x) := by
  by_cases hc : c <;> simp [hc]

/-- The opcodes `classify` puts in the CALL family. -/
theorem classify_call {op : Nat} (h : classify op = .call) :
    op = 0xf1 ∨ op = 0xf2 ∨ op = 0xf4 ∨ op = 0xfa := by
  simp only [classify, ite_eq_iff', reduceCtorEq, and_false, false_or, or_false] at h
  omega

/-- The opcodes `classify` puts in the CREATE family. -/
theorem classify_create {op : Nat} {create2 : Bool} (h : classify op = .create create2) :
    op = 0xf0 ∨ op = 0xf5 := by
  simp only [classify, ite_eq_iff', reduceCtorEq, and_false, false_or, or_false] at h
  omega

/-- On Unzen, only an opcode with a spawn estimate opens a frame. -/
theorem spawn_only_for_spawn_ops : SpawnOnlyForSpawnOps := by
  intro pre r h hnew
  simp only [stepOutcome] at h
  split at h
  · simp only [pure, Except.pure, Except.ok.injEq] at h
    subst h
    simp at hnew
  · rcases (body_spec _ _ _ _ h).2 hnew with hc | hc | hc
    · rcases classify_call hc with h1 | h1 | h1 | h1 <;> rw [h1] <;> decide
    · rcases classify_create hc with h1 | h1 <;> rw [h1] <;> decide
    · rcases classify_create hc with h1 | h1 <;> rw [h1] <;> decide

end TaikoSpec.ZkGas.Proofs
