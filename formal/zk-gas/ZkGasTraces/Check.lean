import ZkGasTraces.Json

/-!
# Trace checker

`checkTrace` re-checks one vector's trace against the metering model and the vector's expected
values:

- (a) the events follow the schema's scope and order rules: every block tx runs from
  `intrinsic` to its `tx_end`, in block order, except that a tx rejected before its intrinsic
  charge is a lone skipped `tx_end`, and the block ends at an aborted tx; a harness trace ends
  with `frame_end`; depth starts at 1 and rises by one only after a spawn step; a precompile
  event follows a CALL-family spawn step, or is a tx's or frame's only event; nothing follows a
  rejected charge but the end event.
- (b) each step's `zk` is `spawnEstimate(op) * mult(op)` for a spawn step and
  `(gas - gas_after) * mult(op)` otherwise; only spawn opcodes spawn.
- (c) each precompile's `zk` is `(supplied - left) * precompileMult(addr)`, and a failed
  precompile has `left = 0`. The intrinsic charge is the schedule's.
- (d) each charge's `ok` is the meter's verdict; `meterBlock` over the committed and aborted txs'
  charges (a skipped tx's are discarded) reproduces each tx's status and total and the vector's
  `included`, `truncated_at`, `cumulative_zk_gas` and `block_zk_gas`; a harness frame's
  `meterTx` total and status match `frame_zk_gas` and `status`.
- (e) a step model, where it returns an outcome, agrees with the trace's `spawn` and, for a step
  that does not spawn, `gas_after`; and, unless the meter rejected the step's charge, the event
  after the step is one its outcome allows (`checkNext`): a step at the same depth after
  `continue`; a step at a smaller depth or the tx's or frame's end after an outcome that ends the
  frame, with the harness `frame_end` status of the outcome when the top frame (depth 1) ends;
  and a step one deeper, a precompile, a step at the same depth (the new frame ran no step) or the
  end after `newFrame`.
-/
namespace TaikoSpec.ZkGas.Traces

/-- A step model: the step's `gas_after`, its outcome, and the name of the branch that decided
it; `none` for a step it does not model yet. A step spawns exactly when its outcome is
`newFrame`. -/
abbrev Model := Pre → Except String (Option (Nat × Outcome × String))

/-- The model that models no step. -/
def unmodeled : Model := fun _ => .ok none

/-- The Unzen step model `stepOutcome` (`ZkGasModel.Step`). -/
def stepModel : Model := fun pre =>
  (stepOutcome .unzen pre).map (·.map fun r => (r.gasAfter, r.outcome, r.branch.name))

/-- `model`, with every step it does not model an error. -/
def requireModeled (model : Model) : Model := fun p => do
  match ← model p with
  | none => throw s!"opcode {opName p.op} is not modeled"
  | some r => pure (some r)

/-- The multiplier of opcode `op` (the fail-safe outside the table). -/
def opcodeMult (s : Schedule) (op : Nat) : Nat := s.opcodeMult.getD op failsafeMultiplier

def callFamily (op : Nat) : Bool := op == 0xf1 || op == 0xf2 || op == 0xf4 || op == 0xfa

def statusName : TxStatus → String
  | .committed => "committed"
  | .aborted => "aborted"
  | .skipped => "skipped"

/-- (b), (c): the amount a step, precompile or intrinsic event charges. -/
def checkAmount (s : Schedule) : Event → Except String Unit
  | .intrinsic zk _ =>
    unless zk = s.txIntrinsic do
      throw s!"intrinsic zk {hexString zk}, but the schedule charges {hexString s.txIntrinsic}"
  | .step pre out => do
    let mult := opcodeMult s pre.op
    if out.spawn then
      match s.spawnEstimate pre.op with
      | none => throw s!"spawn step of opcode {opName pre.op}, which has no spawn estimate"
      | some estimate =>
        if out.charged && out.zk != estimate * mult then
          throw s!"zk {hexString out.zk}, but a spawn step charges its estimate {estimate} * multiplier {mult} = {hexString (estimate * mult)}"
    else
      if out.gasAfter > pre.gas then
        throw s!"gas_after {hexString out.gasAfter} exceeds gas {hexString pre.gas}"
      if out.charged && out.zk != (pre.gas - out.gasAfter) * mult then
        throw s!"zk {hexString out.zk}, want (gas - gas_after) * multiplier {mult} = {hexString ((pre.gas - out.gasAfter) * mult)}"
    unless out.charged || (out.zk == 0 && out.ok) do
      throw "a step the client did not meter (charged false) has zk 0x0 and ok true"
  | .precompile addr supplied left success zk _ => do
    if left > supplied then
      throw s!"left {hexString left} exceeds supplied {hexString supplied}"
    if !success && left != 0 then
      throw s!"a failed precompile leaves no gas, but left is {hexString left}"
    let mult := precompileMult s addr
    unless zk = (supplied - left) * mult do
      throw s!"zk {hexString zk}, want (supplied - left) * multiplier {mult} = {hexString ((supplied - left) * mult)}"
  | _ => pure ()

/-- (e): the model's result for one step, if it models the step; returns its outcome and
branch. -/
def checkModel (model : Model) (pre : Pre) (out : StepOut) :
    Except String (Option (Outcome × String)) := do
  match ← model pre with
  | none => pure none
  | some (gasAfter, outcome, branch) =>
    let spawn := outcome == .newFrame
    unless spawn == out.spawn do
      throw s!"model branch {branch}: spawn {spawn}, trace spawn {out.spawn}"
    unless spawn || gasAfter == out.gasAfter do
      throw s!"model branch {branch}: gas_after {hexString gasAfter}, trace gas_after {hexString out.gasAfter}"
    pure (some (outcome, branch))

def outcomeName : Outcome → String
  | .continue => "continue"
  | .success => "success"
  | .revert => "revert"
  | .haltKeep => "haltKeep"
  | .haltSpendAll => "haltSpendAll"
  | .newFrame => "newFrame"

/-- The harness `frame_end` status of a frame that ends with outcome `o`, or `none` when `o`
does not end the frame. -/
def frameStatus : Outcome → Option String
  | .success => some "success"
  | .revert => some "revert"
  | .haltKeep | .haltSpendAll => some "halt"
  | .continue | .newFrame => none

/-- A modeled step whose charge the meter accepted, waiting for the event after it. -/
structure Pending where
  /-- The step's event index. -/
  event : Nat
  depth : Nat
  outcome : Outcome
  branch : String

/-- Event `e`, for messages. -/
def describe : Event → String
  | .intrinsic .. => "intrinsic"
  | .step pre _ => s!"a step at depth {pre.depth}"
  | .precompile .. => "a precompile"
  | .txEnd .. => "tx_end"
  | .frameEnd .. => "frame_end"

/-- (e): event `e`, which follows the modeled step `p`, is one `p`'s outcome allows. -/
def checkNext (p : Pending) (e : Event) : Except String Unit := do
  let at_ := s!"event {p.event}: model branch {p.branch}: outcome {outcomeName p.outcome}"
  let fail (what : String) : Except String Unit :=
    throw s!"{at_}{what}, but the next event is {describe e}"
  match p.outcome, e with
  | .continue, .step pre _ => unless pre.depth = p.depth do fail ""
  | .continue, _ => fail ""
  | .newFrame, .step pre _ => unless pre.depth = p.depth + 1 ∨ pre.depth = p.depth do fail ""
  | .newFrame, .intrinsic .. => fail ""
  | .newFrame, _ => pure ()
  | _, .step pre _ => unless pre.depth < p.depth do fail " ends the frame"
  | o, .frameEnd status _ =>
    if let some want := frameStatus o then
      if p.depth = 1 ∧ want ≠ status then
        throw s!"{at_} ends the top frame with status {want}, but frame_end has status {status}"
  | _, .txEnd .. => pure ()
  | _, _ => fail " ends the frame"

inductive Layer
  | block
  | harness
  deriving DecidableEq

/-- The layer of a vector, from the shape of its expected values. -/
def layerOf (expected : Lean.Json) : Except String Layer :=
  match expected.getObjVal? "included", expected.getObjVal? "status" with
  | .ok _, _ => .ok .block
  | _, .ok _ => .ok .harness
  | _, _ => .error "expected: neither block (included) nor harness (status) expected values"

/-- One block tx of a trace. -/
structure TxTrace where
  index : Nat
  status : TxStatus
  /-- The trace's total; 0 unless committed. -/
  txZk : Nat
  /-- Its charges in metering order, intrinsic first. -/
  charges : List Nat
  /-- The event index of its `tx_end`. -/
  endEvent : Nat

/-- The checker's state after a prefix of the events. -/
structure Walk where
  /-- Inside a block tx, or a harness frame before `frame_end`. -/
  inTx : Bool
  /-- The depth of the current tx's or frame's last step. -/
  depth : Option Nat := none
  /-- The last event was a spawn step. -/
  spawned : Bool := false
  /-- The last event was a spawn step of the CALL family. -/
  callSpawned : Bool := false
  /-- The current tx or frame went straight to a precompile. -/
  direct : Bool := false
  /-- The meter rejected a charge of the current tx or frame. -/
  rejected : Bool := false
  /-- The accepted charges of the current tx or frame. -/
  total : Nat := 0
  /-- The current tx's or frame's charges, newest first. -/
  charges : List Nat := []
  /-- The block's committed zk gas. -/
  used : Nat := 0
  /-- The finished block txs, newest first. -/
  txs : List TxTrace := []
  /-- The harness frame's end: status and `frame_zk`. -/
  frame : Option (String × Nat) := none
  /-- The model branches of the modeled steps, newest first. -/
  branches : List String := []
  /-- The last event was a modeled step whose charge the meter accepted. -/
  pending : Option Pending := none

/-- Applies charge `amount` of event `i`; its `ok` must be the meter's verdict: the charge fits
when the tx's total stays within what the block has left. -/
def Walk.charge (s : Schedule) (w : Walk) (i amount : Nat) (ok : Bool) : Except String Walk := do
  let budget := s.blockLimit - w.used
  let fits := decide (w.total + amount ≤ budget)
  let verdict := if fits then "accepts" else "rejects"
  unless ok == fits do
    throw s!"event {i}: ok {ok}, but the meter {verdict} a charge of {hexString amount} after {hexString w.total} of the {hexString budget} left"
  return { w with
    total := if fits then w.total + amount else w.total
    charges := amount :: w.charges
    rejected := !fits }

/-- Rules every step and precompile event follows: it is inside a tx or frame, and no rejected
charge or direct precompile call precedes it there. -/
def Walk.inside (w : Walk) (layer : Layer) (i : Nat) (kind : String) : Except String Unit := do
  unless w.inTx do
    match layer with
    | .block => throw s!"event {i}: a block tx starts with intrinsic, got {kind}"
    | .harness => throw s!"event {i}: {kind} after frame_end"
  if w.rejected then
    throw s!"event {i}: {kind} after a rejected charge (only the end event may follow it)"
  if w.direct then
    throw s!"event {i}: {kind} after a direct precompile call (only the end event may follow it)"

/-- Checks event `i` and adds it to the walk. -/
def Walk.event (s : Schedule) (model : Model) (layer : Layer) (w : Walk) (i : Nat) :
    Event → Except String Walk
  | .intrinsic zk ok => do
    unless layer = .block do throw s!"event {i}: intrinsic in a harness trace"
    if w.inTx then throw s!"event {i}: intrinsic before the previous tx's tx_end"
    if let some tx := w.txs.head? then
      if tx.status = .aborted then
        throw s!"event {i}: a tx after aborted tx {tx.index} (the block ends at it)"
    (checkAmount s (.intrinsic zk ok)).mapError (s!"event {i}: " ++ ·)
    let w := { w with inTx := true, depth := none, spawned := false, callSpawned := false,
                      direct := false, rejected := false, total := 0, charges := [] }
    w.charge s i zk ok
  | .step pre out => do
    w.inside layer i "step"
    match w.depth with
    | none =>
      unless pre.depth = 1 do
        throw s!"event {i}: depth {pre.depth}, but a tx's or frame's first step runs at depth 1"
    | some d =>
      if pre.depth = 0 ∨ pre.depth > d + 1 ∨ (pre.depth = d + 1 ∧ !w.spawned) then
        throw s!"event {i}: depth {pre.depth} after depth {d} (depth rises by one, only after a spawn step)"
    (checkAmount s (.step pre out)).mapError (s!"event {i}: " ++ ·)
    let modeled ← (checkModel model pre out).mapError (s!"event {i}: " ++ ·)
    let branches := match modeled with
      | some (_, b) => b :: w.branches
      | none => w.branches
    let pending := match modeled with
      | some (outcome, branch) =>
        if out.ok then some { event := i, depth := pre.depth, outcome, branch } else none
      | none => none
    let w := { w with
      depth := some pre.depth
      spawned := out.spawn
      callSpawned := out.spawn && callFamily pre.op
      branches
      pending }
    if out.charged then w.charge s i out.zk out.ok else pure w
  | .precompile addr supplied left success zk ok => do
    w.inside layer i "precompile"
    let direct := w.depth.isNone
    unless w.callSpawned || direct do
      throw s!"event {i}: precompile event must follow a CALL-family spawn step, or be a tx's or frame's only event"
    (checkAmount s (.precompile addr supplied left success zk ok)).mapError (s!"event {i}: " ++ ·)
    let w := { w with spawned := false, callSpawned := false, direct }
    w.charge s i zk ok
  | .txEnd index status txZk => do
    unless layer = .block do throw s!"event {i}: tx_end in a harness trace"
    -- A tx the client rejects before charging its intrinsic zk gas (its gas limit exceeds the
    -- gas the block has left) has a lone skipped tx_end and no other event.
    let lone := !w.inTx
    if lone then
      unless status = .skipped do
        throw s!"event {i}: a block tx starts with intrinsic, got tx_end with status {statusName status} (only a skipped tx may have no intrinsic)"
      if let some tx := w.txs.head? then
        if tx.status = .aborted then
          throw s!"event {i}: a tx after aborted tx {tx.index} (the block ends at it)"
    let w := if lone then { w with rejected := false, total := 0, charges := [] } else w
    unless index = w.txs.length do
      throw s!"event {i}: index {index}, want {w.txs.length} (every tx in block order from the anchor)"
    match status with
    | .aborted =>
      unless w.rejected do
        throw s!"event {i}: status aborted, but the meter rejected none of the tx's charges"
    | _ =>
      if w.rejected then
        throw s!"event {i}: status {statusName status}, but the meter rejected a charge (the tx is aborted)"
    if status = .committed ∧ txZk ≠ w.total then
      throw s!"event {i}: tx_zk {hexString txZk}, but the tx's charges total {hexString w.total}"
    let tx : TxTrace := { index, status, txZk, charges := w.charges.reverse, endEvent := i }
    return { w with
      inTx := false
      used := if status = .committed then w.used + w.total else w.used
      txs := tx :: w.txs }
  | .frameEnd status frameZk => do
    unless layer = .harness do throw s!"event {i}: frame_end in a block trace"
    unless w.inTx do throw s!"event {i}: a second frame_end"
    let verdict := if w.rejected then "rejected a charge" else "accepted every charge"
    unless (status == "zk_limit") == w.rejected do
      throw s!"event {i}: status {status}, but the meter {verdict} (the status is zk_limit exactly when a charge is rejected)"
    if status ≠ "zk_limit" ∧ frameZk ≠ w.total then
      throw s!"event {i}: frame_zk {hexString frameZk}, but the frame's charges total {hexString w.total}"
    return { w with inTx := false, frame := some (status, frameZk) }

/-- Walks the events from index `i` on. Each event is checked on its own first, then against
the outcome of the modeled step before it. -/
def walkFrom (s : Schedule) (model : Model) (layer : Layer) : Nat → Walk → List Event →
    Except String Walk
  | _, w, [] => .ok w
  | i, w, e :: es =>
    match { w with pending := none }.event s model layer i e with
    | .error err => .error err
    | .ok w' =>
      match w.pending.map (checkNext · e) with
      | some (.error err) => .error err
      | _ => walkFrom s model layer (i + 1) w' es

def hexList (expected : Lean.Json) (k : String) : Except String (List Nat) := do
  match ← field expected k with
  | .arr items => items.toList.mapM (asHex k)
  | _ => throw s!"{k}: must be a list"

def indexList (expected : Lean.Json) (k : String) : Except String (List Nat) := do
  match ← field expected k with
  | .arr items => items.toList.mapM (asIndex k)
  | _ => throw s!"{k}: must be a list"

/-- Running totals of `xs`. -/
def prefixSums : Nat → List Nat → List Nat
  | _, [] => []
  | acc, x :: xs => (acc + x) :: prefixSums (acc + x) xs

def showHexList (xs : List Nat) : String := toString (xs.map hexString)

/-- A tx index, or `null` for none. -/
def showIndex : Option Nat → String
  | some i => toString i
  | none => "null"

/-- (d) for a block: `meterBlock` over the txs that are not skipped reproduces each tx's status
and total, and the vector's expected values. -/
def checkBlock (s : Schedule) (expected : Lean.Json) (txs : List TxTrace) : Except String Unit := do
  let metered := txs.filter (·.status != .skipped)
  let (results, total) := meterBlock s (metered.map (·.charges))
  unless results.length = metered.length do
    throw s!"meterBlock ends after {results.length} of the trace's {metered.length} metered txs"
  for (tx, result) in metered.zip results do
    match result, tx.status with
    | some n, .committed =>
      unless n = tx.txZk do
        throw s!"event {tx.endEvent}: meterBlock gives tx {tx.index} {hexString n}, trace tx_zk {hexString tx.txZk}"
    | none, .aborted => pure ()
    | some _, status =>
      throw s!"event {tx.endEvent}: tx {tx.index} is {statusName status}, but meterBlock commits it"
    | none, status =>
      throw s!"event {tx.endEvent}: tx {tx.index} is {statusName status}, but meterBlock aborts it"
  let committed := (txs.filter (·.status = .committed)).map (·.index)
  let included ← indexList expected "included"
  unless included = committed do
    throw s!"expected included {included}, but the trace commits {committed}"
  let truncatedAt ← match ← field expected "truncated_at" with
    | .null => pure none
    | v => some <$> asIndex "truncated_at" v
  let aborted := (txs.find? (·.status = .aborted)).map (·.index)
  unless truncatedAt = aborted do
    throw s!"expected truncated_at {showIndex truncatedAt}, but the trace aborts {showIndex aborted}"
  let rawTxs ← match ← field expected "raw_txs" with
    | .arr items => pure items.size
    | _ => throw "raw_txs: must be a list"
  let want := match aborted with
    | some k => k + 1
    | none => rawTxs
  unless txs.length = want do
    throw s!"the trace has {txs.length} txs, want {want} (every input tx up to the aborted or last one)"
  let cumulative ← hexList expected "cumulative_zk_gas"
  let sums := prefixSums 0 (results.filterMap id)
  unless cumulative = sums do
    throw s!"expected cumulative_zk_gas {showHexList cumulative}, but meterBlock gives {showHexList sums}"
  let blockZk ← hexField expected "block_zk_gas"
  unless blockZk = total do
    throw s!"expected block_zk_gas {hexString blockZk}, but meterBlock gives {hexString total}"

/-- (d) for a harness frame: `meterTx` over its charges reproduces the frame's status and total,
and the vector's expected values. Only the status is compared for `zk_limit`. -/
def checkHarness (s : Schedule) (expected : Lean.Json) (charges : List Nat) (status : String)
    (frameZk : Nat) : Except String Unit := do
  match meterTx s 0 charges with
  | some n =>
    if status = "zk_limit" then throw s!"frame status zk_limit, but meterTx accepts the frame"
    unless n = frameZk do
      throw s!"meterTx gives the frame {hexString n}, trace frame_zk {hexString frameZk}"
  | none =>
    unless status = "zk_limit" do
      throw s!"frame status {status}, but meterTx rejects the frame (zk_limit)"
  let wantStatus ← stringField expected "status"
  unless wantStatus = status do
    throw s!"expected status {wantStatus}, but the trace's frame_end status is {status}"
  match ← field expected "frame_zk_gas" with
  | .null =>
    unless status = "zk_limit" do throw "expected frame_zk_gas null, but status is not zk_limit"
  | v =>
    let n ← asHex "frame_zk_gas" v
    unless n = frameZk do
      throw s!"expected frame_zk_gas {hexString n}, but the trace's frame_zk is {hexString frameZk}"

/-- Checks a vector's trace `events` against schedule `s`, the vector's `expected` values and
`model`; returns the model branch of every step it modeled, in order. For a harness vector, `s`
carries the vector's `zk_block_limit`. -/
def checkTrace (s : Schedule) (expected : Lean.Json) (events : List Event) (model : Model) :
    Except String (List String) := do
  let layer ← layerOf expected
  let w ← walkFrom s model layer 0 { inTx := layer = .harness } events
  match layer with
  | .block =>
    if w.inTx then throw s!"the trace ends inside tx {w.txs.length} (no tx_end)"
    if w.txs.isEmpty then throw "the trace has no tx"
    checkBlock s expected w.txs.reverse
  | .harness =>
    let some (status, frameZk) := w.frame | throw "the trace ends without frame_end"
    checkHarness s expected w.charges.reverse status frameZk
  return w.branches.reverse

/-- What one vector's check covered. -/
structure Report where
  events : Nat
  steps : Nat
  /-- The model branch of every modeled step, in order. -/
  branches : List String
  deriving Repr, DecidableEq

/-- Checks the trace text `trace` of the vector whose case file text is `vector`. A block
vector runs the Unzen schedule; a harness vector runs it with the vector's `zk_block_limit`. -/
def checkVectorText (vector trace : String) (model : Model) : Except String Report := do
  let v ← (Lean.Json.parse vector).mapError ("vector: invalid JSON: " ++ ·)
  let expected ← (field v "expected").mapError fun _ => "the vector has no expected values"
  let s ← match ← stringField v "layer" with
    | "block" => pure unzen
    | "harness" => do
      let limit ← asHex "input.zk_block_limit" (← field (← field v "input") "zk_block_limit")
      pure { unzen with blockLimit := limit }
    | other => throw s!"layer: {other.quote} is not block or harness"
  let events ← parseTrace trace
  let branches ← checkTrace s expected events model
  let steps := events.countP fun | .step .. => true | _ => false
  return { events := events.length, steps, branches }

end TaikoSpec.ZkGas.Traces
