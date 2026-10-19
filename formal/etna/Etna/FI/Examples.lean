module
public import Etna.FI.Proofs
@[expose] public section
namespace Etna.FI

/-- Finite satisfiability instance, not an implementation of Keccak or MPT. -/
def exampleCodec : Codec := ⟨fun _ => none, List.length, List.isEmpty⟩

def exampleContext : Context := ⟨1, 2, 3, 7, 8, 0, 1, 20, 10⟩

def exampleStorage (entry : Entry) (root inbox : Nat) (slots : List Nat) : Option Entry :=
  if root = 7 ∧ inbox = 8 ∧ slots = [0, 1] then some entry else none

def exampleAuthentication (entry : Entry) (time tail : Nat) : Authentication where
  committedParent := 1
  expectedAttributes := fun _ _ => 2
  committedRoot := fun _ => 7
  anchorTime := fun _ => time
  queueTail := fun _ _ => tail
  storageEntry := exampleStorage entry
  verify := fun root inbox slots got _ => decide (exampleStorage entry root inbox slots = some got)
  slot := fun index => index * 2
  sound := by intros; simpa using ‹decide _ = true›

def exampleExecution : Execution where
  run := fun request => .completed request []
  validExecution := fun _ retained => retained = []
  sound := by intro request returned retained h; cases h; rfl

theorem authenticated_ordinary_example :
    ContextEvidence (exampleAuthentication ⟨10, 0⟩ 20 0) { exampleContext with tail := 0 } ∧
    evaluate (exampleAuthentication ⟨10, 0⟩ 20 0) exampleCodec
      { exampleContext with tail := 0 } none [] = .ok .ordinary := by
  constructor
  · constructor <;> rfl
  · rfl

theorem authenticated_predue_include_example :
    ContextEvidence (exampleAuthentication ⟨10, 0⟩ 11 1)
      { exampleContext with anchorTimestamp := 11 } ∧
    evaluate (exampleAuthentication ⟨10, 0⟩ 11 1) exampleCodec
      { exampleContext with anchorTimestamp := 11 }
      (some ⟨0, ⟨10, 0⟩, [], []⟩) [[]] = .ok (.included 0) := by
  constructor
  · constructor <;> rfl
  · rfl

theorem authenticated_due_invalid_example :
    ContextEvidence (exampleAuthentication ⟨10, 1⟩ 20 1) exampleContext ∧
    evaluate (exampleAuthentication ⟨10, 1⟩ 20 1) exampleCodec exampleContext
      (some ⟨0, ⟨10, 1⟩, [0], []⟩) [] = .ok (.skippedInvalid 0) := by
  constructor
  · constructor <;> rfl
  · rfl

theorem authenticated_due_empty_example :
    ContextEvidence (exampleAuthentication ⟨10, 0⟩ 20 1) exampleContext ∧
    execute (exampleAuthentication ⟨10, 0⟩ 20 1) exampleCodec exampleExecution exampleContext
      (some ⟨0, ⟨10, 0⟩, [], []⟩) [] = .ok 1 := by
  constructor
  · constructor <;> rfl
  · rfl

def exampleCache : CacheEntry := ⟨exampleContext, [], .needsSkip 0, .completedEmpty⟩

def exampleCachedCodec : Codec :=
  { exampleCodec with decodeEnvelope := fun _ => some (some ⟨0, ⟨10, 0⟩, [], []⟩, []) }

/-- Cache assumptions are simultaneously satisfiable with concrete decoded input and execution. -/
theorem authenticated_cache_example :
    CacheEvidence (exampleAuthentication ⟨10, 0⟩ 20 1) exampleCachedCodec exampleExecution
      exampleContext (some ⟨0, ⟨10, 0⟩, [], []⟩) [] exampleCache ∧
    finalizeCached exampleCache exampleContext [] = .ok 1 := by
  constructor
  · constructor
    · constructor <;> rfl
    · rfl
    · rfl
    · rfl
  · rfl

theorem local_separation_example (bytes : Bytes) : LocallySeparated exampleCodec.hash bytes bytes := by
  intro impossible
  exact False.elim (impossible rfl)
end Etna.FI
