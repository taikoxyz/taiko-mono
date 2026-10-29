import EtnaVectors.Client

/-! `forced_step` vectors: one block's forced-inclusion decision, `Forced.step`. The input is the
parent cursor, the anchor's queue tail and timestamp, the delay, the block's forced witness (the
entry it proves and the raw bytes it carries), the block's first transaction and the result of
the singleton build `[tx]`. The model returns the next cursor, `waiting` (no build result yet) or
a rejection. -/
namespace Etna.Vectors
open Etna.Design

/-- The transaction bytes a vector names. The harness builds concrete bytes of each kind; the
model sees only their hash atom, their length (0, at most 8,192 or above it) and whether they are
one canonical EIP-2718 transaction. -/
inductive TxKind | empty | txA | txB | junk | junkMax | junkOver | txBig
  deriving DecidableEq, Repr

def TxKind.name : TxKind → String
  | .empty => "empty" | .txA => "txA" | .txB => "txB" | .junk => "junk" | .junkMax => "junkMax"
  | .junkOver => "junkOver" | .txBig => "txBig"

/-- Distinct kinds have distinct hashes; empty bytes hash to keccak256(""), the blank atom. -/
def TxKind.atom : TxKind → Hash
  | .empty => blankHash | .txA => 61 | .txB => 62 | .junk => 63 | .junkMax => 64 | .junkOver => 65
  | .txBig => 66

/-- The byte length the model sees. The harness's bytes have exactly this length for the
non-canonical kinds, and the same class (at most 8,192 or above) for the canonical ones. -/
def TxKind.bytes : TxKind → Nat
  | .empty => 0 | .txA => 100 | .txB => 100 | .junk => 32 | .junkMax => 8192 | .junkOver => 8193
  | .txBig => 8300

def TxKind.canonical : TxKind → Bool
  | .txA | .txB | .txBig => true
  | _ => false

def txKinds : List TxKind := [.empty, .txA, .txB, .junk, .junkMax, .junkOver, .txBig]

def txKindJ (k : TxKind) : JVal :=
  jLine [("name", jStr k.name), ("bytes", jNat k.bytes), ("canonical", jBool k.canonical)]

def singletonName : Forced.Singleton → String
  | .unavailable => "unavailable" | .completedRetained => "completedRetained"
  | .completedEmpty => "completedEmpty" | .inconsistent => "inconsistent"

/-- The witness a block carries: the index it names, whether its storage proof verifies under the
anchor, the entry it proves (transaction kind and L1 timestamp) and the raw bytes it carries. -/
structure StepWitness where
  index : Nat
  authenticated : Bool := true
  entry : TxKind
  entryTimestamp : Nat
  tx : TxKind

structure StepCase where
  label : String
  spec : Option String := none
  cursor : Nat := 2
  tail : Nat := 3
  anchorTimestamp : Nat
  delay : Nat := fiDelay
  witness : Option StepWitness
  first : Option TxKind := none
  /-- The result of the singleton build `[tx]`. -/
  build : Forced.Singleton := .completedEmpty

/-- The entry's L1 block; `Forced.step` does not read it. -/
def stepEntryBlock : Nat := 70

def StepCase.model (c : StepCase) : Option Forced.Witness :=
  c.witness.map fun w =>
    ⟨w.index, ⟨w.entry.atom, w.entryTimestamp, stepEntryBlock⟩, w.authenticated, w.tx.atom, w.tx.bytes,
      w.tx.canonical, c.first.map TxKind.atom, (c.first.map TxKind.canonical).getD false,
      (c.first.map TxKind.bytes).getD 0⟩

def stepResultJ : Forced.Result → List (String × JVal)
  | .accepted n => [("result", jStr "accepted"), ("cursor", jNat n)]
  | .waiting => [("result", jStr "waiting")]
  | .rejected => [("result", jStr "rejected")]

def StepCase.toClient (c : StepCase) : ClientCase :=
  { label := c.label, spec := c.spec,
    input := [("cursor", jNat c.cursor), ("tail", jNat c.tail), ("anchorTimestamp", jNat c.anchorTimestamp),
      ("delay", jNat c.delay),
      ("witness", match c.witness with
        | none => jNull
        | some w => jLine [("index", jNat w.index), ("authenticated", jBool w.authenticated),
            ("entry", jStr w.entry.name), ("entryTimestamp", jNat w.entryTimestamp), ("entryBlock", jNat stepEntryBlock),
            ("tx", jStr w.tx.name)]),
      ("firstTx", match c.first with | none => jNull | some k => jStr k.name),
      ("singleton", jStr (singletonName c.build))],
    expect := stepResultJ (Forced.step c.cursor c.tail c.anchorTimestamp c.delay c.model c.build) }

/-- The entry's submission time; due at `stepT0 + fiDelay`. -/
def stepT0 : Nat := 1700000000

def dueName (k : Nat) : String := if k = 0 then "early" else if k = 1 then "exact" else "late"

/-- One second before due, exactly due, or an hour after. -/
def dueAnchor (k : Nat) : Nat := if k = 0 then stepT0 + fiDelay - 1 else if k = 1 then stepT0 + fiDelay else stepT0 + 2*fiDelay

/-- Another transaction than `k`, of a different hash. -/
def otherTx : TxKind → TxKind
  | .txA => .txB
  | _ => .txA

/-- The raw bytes a witness carries: none (empty bytes), the entry's own bytes, or other bytes. -/
def rawName (k : Nat) : String := if k = 0 then "omitted" else if k = 1 then "same" else "other"
def rawFor (entry : TxKind) (k : Nat) : TxKind := if k = 0 then .empty else if k = 1 then entry else otherTx entry
def firstName (k : Nat) : String := if k = 0 then "none" else if k = 1 then "entry" else "other"
def firstFor (entry : TxKind) (k : Nat) : Option TxKind :=
  if k = 0 then none else if k = 1 then some entry else some (otherTx entry)

def pending (entry tx : TxKind) : StepWitness := { index := 2, entry := entry, entryTimestamp := stepT0, tx := tx }

/-- c ≥ tail: no witness is allowed. -/
def exhaustedGrid : List StepCase :=
  [(0, 0), (5, 5), (5, 2)].flatMap fun (c, t) => [false, true].map fun w =>
    { label := "forced_step.exhausted.cursor" ++ Nat.repr c ++ ".tail" ++ Nat.repr t ++
        (if w then ".witness" else ".no-witness"),
      cursor := c, tail := t, anchorTimestamp := dueAnchor 2,
      witness := if w then some { index := c, entry := .txA, entryTimestamp := stepT0, tx := .empty } else none }

/-- c < tail: the witness must name entry c and its proof must verify. -/
def structuralGrid : List StepCase := [
  { label := "forced_step.pending.no-witness", anchorTimestamp := dueAnchor 2, witness := none },
  { label := "forced_step.pending.index-above-cursor", anchorTimestamp := dueAnchor 2,
    witness := some { pending .txA .empty with index := 3 } },
  { label := "forced_step.pending.index-below-cursor", anchorTimestamp := dueAnchor 2,
    witness := some { pending .txA .empty with index := 1 } },
  { label := "forced_step.pending.unauthenticated", anchorTimestamp := dueAnchor 2,
    witness := some { pending .txA .empty with authenticated := false } },
  { label := "forced_step.pending.unauthenticated-included", anchorTimestamp := dueAnchor 0,
    witness := some { pending .txA .empty with authenticated := false }, first := some .txA }]

/-- Entry kind × raw bytes carried × first transaction × due status, with an empty singleton
build. For a blanked entry the omitted and the same raw bytes coincide, so only one is kept. -/
def decisionGrid : List StepCase :=
  [TxKind.txA, .junk, .empty, .junkMax].flatMap fun entry =>
    ([0, 1, 2].filter fun r => !(entry = .empty ∧ r = 1)).flatMap fun raw =>
      [0, 1, 2].flatMap fun f => [0, 1, 2].map fun due =>
        { label := "forced_step.decide." ++ entry.name ++ ".raw-" ++ rawName raw ++ ".first-" ++ firstName f ++
            "." ++ dueName due,
          anchorTimestamp := dueAnchor due, witness := some (pending entry (rawFor entry raw)),
          first := firstFor entry f }

/-- Every singleton result on a due canonical entry that is not included. -/
def singletonGrid : List StepCase :=
  [Forced.Singleton.unavailable, .completedRetained, .completedEmpty, .inconsistent].flatMap fun s =>
    [0, 2].flatMap fun f => [1, 2].map fun due =>
      { label := "forced_step.singleton." ++ singletonName s ++ ".first-" ++ firstName f ++ "." ++ dueName due,
        anchorTimestamp := dueAnchor due, witness := some (pending .txA .txA), first := firstFor .txA f,
        build := s }

/-- The 8,192-byte limit on raw bytes and on the first transaction. -/
def stepSizeGrid : List StepCase := [
  { label := "forced_step.size.raw-over-limit.early", anchorTimestamp := dueAnchor 0,
    witness := some (pending .junkOver .junkOver) },
  { label := "forced_step.size.raw-over-limit.late", anchorTimestamp := dueAnchor 2,
    witness := some (pending .junkOver .junkOver) },
  { label := "forced_step.size.raw-omitted-over-limit-entry.late", anchorTimestamp := dueAnchor 2,
    witness := some (pending .junkOver .empty) },
  { label := "forced_step.size.raw-at-limit.late", anchorTimestamp := dueAnchor 2,
    witness := some (pending .junkMax .junkMax), build := .unavailable },
  { label := "forced_step.size.big-first-tx.early", anchorTimestamp := dueAnchor 0,
    witness := some (pending .txBig .empty), first := some .txBig },
  { label := "forced_step.size.big-first-tx.late", anchorTimestamp := dueAnchor 2,
    witness := some (pending .txBig .empty), first := some .txBig },
  { label := "forced_step.size.big-raw-tx.late", anchorTimestamp := dueAnchor 2,
    witness := some (pending .txBig .txBig) }]

def stepHandwritten : List StepCase := [
  { label := "forced_step.hw.exhausted-queue-forbids-witness", spec := some "spec L427", cursor := 3, tail := 3,
    anchorTimestamp := dueAnchor 2, witness := some { pending .txA .empty with index := 3 } },
  { label := "forced_step.hw.pending-entry-needs-witness", spec := some "spec L427",
    anchorTimestamp := dueAnchor 0, witness := none },
  { label := "forced_step.hw.only-entry-c", spec := some "spec L426", anchorTimestamp := dueAnchor 2,
    witness := some { pending .txA .txA with index := 3 }, tail := 4, first := some .txA },
  { label := "forced_step.hw.due-at-48-bit-entry-timestamp.before", spec := some "spec L428",
    anchorTimestamp := 2*limit48 - 2, delay := limit48,
    witness := some { pending .txA .empty with entryTimestamp := limit48 - 1 } },
  { label := "forced_step.hw.due-at-48-bit-entry-timestamp.at", spec := some "spec L428",
    anchorTimestamp := 2*limit48 - 1, delay := limit48,
    witness := some { pending .junk .junk with entryTimestamp := limit48 - 1 } },
  { label := "forced_step.hw.included-before-due", spec := some "spec L439", anchorTimestamp := dueAnchor 0,
    witness := some (pending .txA .empty), first := some .txA },
  { label := "forced_step.hw.not-included-not-due-keeps-cursor", spec := some "spec L440",
    anchorTimestamp := dueAnchor 0, witness := some (pending .txA .empty), first := some .txB },
  { label := "forced_step.hw.due-ineligible-skips-without-el", spec := some "spec L441",
    anchorTimestamp := dueAnchor 1, witness := some (pending .junk .junk), build := .unavailable },
  { label := "forced_step.hw.due-eligible-empty-build-skips", spec := some "spec L442",
    anchorTimestamp := dueAnchor 1, witness := some (pending .txA .txA), build := .completedEmpty },
  { label := "forced_step.hw.due-eligible-retained-build-rejects", spec := some "spec L442",
    anchorTimestamp := dueAnchor 1, witness := some (pending .txA .txA), build := .completedRetained },
  { label := "forced_step.hw.transient-build-failure-waits", spec := some "spec L447",
    anchorTimestamp := dueAnchor 1, witness := some (pending .txA .txA), build := .unavailable },
  { label := "forced_step.hw.build-for-another-context-rejects", spec := some "spec L447",
    anchorTimestamp := dueAnchor 1, witness := some (pending .txA .txA), build := .inconsistent },
  { label := "forced_step.hw.only-position-zero-counts", spec := some "spec L451",
    anchorTimestamp := dueAnchor 1, witness := some (pending .txA .txA), first := some .txB,
    build := .completedRetained },
  { label := "forced_step.hw.due-skip-needs-raw-bytes", spec := some "spec L456",
    anchorTimestamp := dueAnchor 1, witness := some (pending .txA .empty) },
  { label := "forced_step.hw.nonempty-raw-bytes-must-match", spec := some "spec L456",
    anchorTimestamp := dueAnchor 0, witness := some (pending .txA .junk) },
  { label := "forced_step.hw.inclusion-omits-raw-bytes", spec := some "spec L456",
    anchorTimestamp := dueAnchor 2, witness := some (pending .txA .empty), first := some .txA },
  { label := "forced_step.hw.blanked-entry-due-skips-without-el", spec := some "spec L461",
    anchorTimestamp := dueAnchor 1, witness := some (pending .empty .empty), build := .unavailable },
  { label := "forced_step.hw.blanked-entry-not-due", spec := some "spec L461",
    anchorTimestamp := dueAnchor 0, witness := some (pending .empty .empty) }]

def stepCases : List StepCase :=
  exhaustedGrid ++ structuralGrid ++ decisionGrid ++ singletonGrid ++ stepSizeGrid ++ stepHandwritten

def forcedStepHeader : List (String × JVal) :=
  [("constants", jObj [("maxForcedTxBytes", jNat 8192), ("entryTimestamp", jNat stepT0),
      ("forcedInclusionDelay", jNat fiDelay)]),
   ("txKinds", jArr (txKinds.map txKindJ))]

def forcedStepFile (provenance : Option String) : Except String String :=
  clientFile "forced_step" provenance forcedStepHeader (stepCases.map StepCase.toClient)

end Etna.Vectors
