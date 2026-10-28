import EtnaVectors.Machine

/-! `recover` vectors: the owner, the expected generation and checkpoint, the exclusion list
(sorted by bond id, matching entry keys, no released slot) and the FI indices to blank (strictly
increasing, inside [head, tail)). -/
namespace Etna.Vectors
open Etna.Design

/-- Four queued entries; bonds 1, 2, 3 (keys 2, 3, 4) registered; bond 3 released (its exit
covered by a landing to 6); a landing to 12 consuming one entry. Then c = 12, generation 0,
FI head 1, tail 4. -/
def recoverSetup : List CaseStep :=
  fill 4 ++ [later 1 (.register 2 2 10), later 1 (.register 3 3 10), later 1 (.register 4 4 10)] ++
    release 3 4 ++ [landTo 12 1]

/-- The owner recovers at block `b` with the current generation and checkpoint. -/
def recoverAt (b : Nat) (exclusions : List Recovery.Exclusion) : CaseStep := fun w =>
  ⟨b, .recover true ⟨w.inbox.generation, w.inbox.checkpoint.height, exclusions, []⟩⟩

def recoverCase (label : String) (call : CaseStep) (setup : List CaseStep := recoverSetup)
    (spec : Option String := none) : Scenario :=
  { label := label, spec := spec, setup := setup, call := call, registry := true }

def expectedGrid : List Scenario :=
  [0, 1].flatMap fun eg => [6, 12, 18].flatMap fun ec => [true, false].map fun owner =>
    recoverCase ("recover.expected.generation" ++ Nat.repr eg ++ ".c" ++ Nat.repr ec ++
      (if owner then ".owner" else ".stranger")) (later 1 (.recover owner ⟨eg, ec, [], []⟩))

def listName (xs : List Nat) : String := if xs.isEmpty then "none" else String.intercalate "-" (xs.map Nat.repr)

def fiGrid : List Scenario :=
  [[], [0], [1], [3], [4], [1, 2], [2, 1], [1, 1], [1, 3], [2, 3]].map fun fi =>
    recoverCase ("recover.fi-to-clear." ++ listName fi) (recoverNow [] fi)

def exclusionGrid : List Scenario :=
  [("none", []), ("bond1", [⟨1, 2⟩]), ("bond1-wrong-key", [⟨1, 3⟩]), ("unsorted", [⟨2, 3⟩, ⟨1, 2⟩]),
   ("duplicate", [⟨1, 2⟩, ⟨1, 2⟩]), ("bond1-bond2", [⟨1, 2⟩, ⟨2, 3⟩]), ("unknown-bond", [⟨9, 2⟩]),
   ("released-bond", [⟨3, 0⟩]), ("released-bond-old-key", [⟨3, 4⟩]), ("genesis-bond", [⟨0, 1⟩])].map
    fun (name, xs) => recoverCase ("recover.exclusions." ++ name) (recoverNow xs [])

def recoverHandwritten : List Scenario := [
  recoverCase "recover.lists.exclusion-and-blanking" (recoverNow [⟨1, 2⟩] [1, 3]),
  recoverCase "recover.hw.second-recovery" recoverNow (recoverSetup ++ [recoverNow]) (some "EN L483"),
  recoverCase "recover.hw.stale-checkpoint-after-landing" (later 1 (.recover true ⟨0, 12, [], []⟩))
    (recoverSetup ++ [landTo 18]) (some "EN L469"),
  recoverCase "recover.hw.stale-generation-after-recovery" (later 1 (.recover true ⟨0, 12, [], []⟩))
    (recoverSetup ++ [recoverNow]) (some "EN L483"),
  recoverCase "recover.hw.keeps-settled-state" (recoverNow [⟨1, 2⟩] [2]) (spec := some "EN L462"),
  recoverCase "recover.hw.exclusion-moves-exit-to-recovery-block" (recoverNow [⟨1, 2⟩] [])
    (recoverSetup ++ [later 1 (.requestExit 2 1)]) (some "EN L460"),
  recoverCase "recover.hw.exclusion-keeps-earlier-exit"
    (fun w => ⟨(w.registry.slots 1).exitAt+5, .recover true ⟨w.inbox.generation, w.inbox.checkpoint.height, [⟨1, 2⟩], []⟩⟩)
    (recoverSetup ++ [later 1 (.requestExit 2 1)]) (some "EN L460"),
  recoverCase "recover.hw.reused-slot-old-key" (recoverNow [⟨3, 4⟩] [])
    (recoverSetup ++ [later 1 (.register 5 5 10)]) (some "EN L460"),
  recoverCase "recover.hw.reused-slot-new-key" (recoverNow [⟨3, 5⟩] [])
    (recoverSetup ++ [later 1 (.register 5 5 10)]) (some "EN L460"),
  recoverCase "recover.hw.excluding-slashed-entry" (recoverNow [⟨1, 2⟩] [])
    (recoverSetup ++ [later 1 (.slash 5 1 { signer := 2 } { blockId := 12, signer := 2 })]) (some "EN L460"),
  recoverCase "recover.hw.blank-twice" (recoverNow [] [1]) (recoverSetup ++ [recoverNow [] [1]]) (some "EN L461"),
  { recoverCase "recover.hw.recovery-block-2pow48-minus1" (recoverAt (limit48-1) []) (spec := some "EN L747") with
    callTimestamp := some (timestampOf 200) },
  { recoverCase "recover.hw.recovery-block-2pow48" (recoverAt limit48 []) (spec := some "EN L747") with
    callTimestamp := some (timestampOf 200) },
  { recoverCase "recover.hw.exclusion-at-block-2pow48-minus1" (recoverAt (limit48-1) [⟨1, 2⟩]) (spec := some "EN L460") with
    callTimestamp := some (timestampOf 200) },
  { recoverCase "recover.hw.origin-timestamp-2pow48-minus1" (recoverNow) (spec := some "EN L747") with
    callTimestamp := some (limit48-1) },
  { recoverCase "recover.hw.origin-timestamp-2pow48" (recoverNow) (spec := some "EN L747") with
    callTimestamp := some limit48 }]

def recoverScenarios : List Scenario := expectedGrid ++ fiGrid ++ exclusionGrid ++ recoverHandwritten

end Etna.Vectors
