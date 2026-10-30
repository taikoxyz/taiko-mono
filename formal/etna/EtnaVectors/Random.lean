import EtnaVectors.Machine

/-! Opt-in random vectors: `lake exe etna-vectors --random <seed> --count <n> --write <dir>`
writes `random-land.json` and `random-forced.json`. Each vector is a random call sequence whose
expectations come from the same model transitions as the committed families. Setup steps are
always accepted (exact fees, honest landings of one to three grid segments, a recovery only
after a landing; `tests/test_random_vectors.py` checks seeds 0 to 9); only the final call is
unconstrained. Each file's `generator` header names the seed and count. Nothing here is committed
or checked by CI; the files are input for differential testing. -/
namespace Etna.Vectors
open Etna.Design

/-- A 64-bit linear congruential generator with Knuth's MMIX constants. -/
structure Lcg where
  state : Nat

/-- The next state and its high 31 bits. -/
def Lcg.next (g : Lcg) : Nat × Lcg :=
  let s := (6364136223846793005*g.state + 1442695040888963407) % 2^64
  (s / 2^33, ⟨s⟩)

/-- A draw below `n`; `n = 0` draws 0. -/
def Lcg.below (g : Lcg) (n : Nat) : Nat × Lcg :=
  let (x, g') := g.next
  (if n = 0 then 0 else x % n, g')

/-- `count` draws below `n`. -/
def Lcg.draws (g : Lcg) (count n : Nat) : List Nat × Lcg :=
  (List.range count).foldl (fun (acc, g) _ => let (x, g) := g.below n; (acc ++ [x], g)) ([], g)

/-- An honest landing of `segments` grid segments from the checkpoint, consuming at most `want`
pending entries. -/
def landSegments (segments want : Nat) : CaseStep := fun w =>
  landTo (w.inbox.checkpoint.height + landGrid*segments) (min want (w.inbox.tail - w.inbox.head)) none 0 w

/-- Up to 8 queued entries, up to 4 landings of 1 to 3 segments (so records can skip grid
points), an optional recovery after a landing, then either (half the time) an honest landing of
up to 4 segments, or `land` from a random parent (on or off the grid, up to 4 segments below the
checkpoint) to a random height (up to 4 segments above it, on or off the grid) with a random FI
head, which mostly reverts. -/
def randomLand (seed i : Nat) (g : Lcg) : Scenario × Lcg :=
  let (queued, g) := g.below 9
  let (landings, g) := g.below 5
  let (segments, g) := g.draws landings 3
  let (consumes, g) := g.draws landings 2
  let (recover, g) := g.below 3
  let (back, g) := g.below 5
  let (offParent, g) := g.below 4
  let (up, g) := g.below 5
  let (offHeight, g) := g.below 4
  let (headDelta, g) := g.below 4
  let (honest, g) := g.below 2
  let (consume, g) := g.below 3
  let lands := (segments.zip consumes).map fun (s, k) => landSegments (s+1) k
  let setup := fill queued ++ lands ++ (if 0 < landings ∧ recover = 0 then [recoverNow] else [])
  let call : CaseStep := if honest = 0 then landSegments (up+1) consume else fun w =>
    let s := w.inbox
    let c := s.checkpoint.height
    let p := c - min c (landGrid*back) + (if offParent = 0 then 1 else 0)
    let h := c + landGrid*up + (if offHeight = 0 then 1 else 0)
    let b := w.l1Block+1
    ⟨b, .land (chainInput s p h (s.head+headDelta) s.snapshot b) (chainLeaves s p h) true 1 true⟩
  ({ label := "land.random." ++ Nat.repr seed ++ "." ++ Nat.repr i, setup := setup, call := call }, g)

/-- Up to 8 queued entries, an optional sweep, an optional one-segment landing that consumes
entries, then a sweep or an enqueue of 0, 1, 32, 8192, 8193 or a random number of bytes below
9000, paying one gwei unit less than, exactly, or five more than the current fee. -/
def randomForced (seed i : Nat) (g : Lcg) : Scenario × Lcg :=
  let (queued, g) := g.below 9
  let (sweep, g) := g.below 3
  let (consume, g) := g.below 3
  let (kind, g) := g.below 6
  let (rawPick, g) := g.below 6
  let (rawFree, g) := g.below 9000
  let (payPick, g) := g.below 3
  let (refund, g) := g.below 2
  let setup := fill queued ++ (if sweep = 0 then [later 1 (.sweep 3)] else [])
    ++ (if 0 < consume then [landSegments 1 consume] else [])
  let raw := match rawPick with
    | 0 => 0 | 1 => 1 | 2 => 32 | 3 => 8192 | 4 => 8193 | _ => rawFree
  let call : CaseStep := fun w =>
    if kind = 5 then ⟨w.l1Block+1, .sweep 3⟩ else
    let fee := currentFee w.inbox
    let paid := match payPick with
      | 0 => fee - 1 | 1 => fee | _ => fee + 5
    ⟨w.l1Block+1, .enqueue 2 raw paid (refund = 0)⟩
  ({ label := "forced.random." ++ Nat.repr seed ++ "." ++ Nat.repr i, setup := setup, call := call }, g)

/-- `count` scenarios from one generator stream seeded with `seed`. -/
def randomScenarios (step : Nat → Nat → Lcg → Scenario × Lcg) (seed count : Nat) : List Scenario :=
  ((List.range count).foldl (fun (acc, g) i => let (sc, g) := step seed i g; (acc ++ [sc], g)) ([], ⟨seed⟩)).1

/-- The command that writes the random files for `seed` and `count`. -/
def randomGenerator (seed count : Nat) : String :=
  "formal/etna: lake exe etna-vectors --write <dir> --random " ++ Nat.repr seed ++ " --count " ++ Nat.repr count

/-- The two random family files. -/
def randomFiles (seed count : Nat) : List (String × Except String String) := [
  ("random-land.json", familyFileWith (randomGenerator seed count) "land" none (randomScenarios randomLand seed count)),
  ("random-forced.json",
    familyFileWith (randomGenerator seed count) "forced" none (randomScenarios randomForced seed count))]

end Etna.Vectors
