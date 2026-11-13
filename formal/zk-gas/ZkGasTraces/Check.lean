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
- (e) the step model agrees with every step's `spawn` and `gas_after` (for a spawn step, the gas
  left after the gas it forwards); and, unless the meter rejected the step's charge, the event
  after the step is one its outcome allows and starts from the gas the step hands it
  (`checkNext`): after `continue`, a step at the same depth whose `gas` is the step's
  `gas_after`; after an outcome that ends a child frame, a step one depth up, and after one that
  ends the top frame (depth 1), the tx's or frame's end, with the harness `frame_end` status of
  the outcome; after `newFrame`, the new frame's first step one deeper, whose `gas` is the gas
  the step forwards plus a value transfer's 2,300 stipend, the precompile run it opened, supplied
  that gas at the step's target address, or, when the new frame runs no step, a step at the same
  depth resuming with the `gas_after` plus that gas (or, where revm can also lose it, the
  `gas_after` alone: `noChildResume`).
- (f) the gas a frame gets back (`Walk.frameReturn`, revm-handler 43.0.2 `src/frame.rs`): when a
  child frame that ran steps ends, the frame that opened it resumes with the `gas_after` of its
  spawn step plus what the child returns (`returnedGas`): the child's gas left when its last
  step's outcome is `success` or `revert`, less a CREATE's code deposit, and 0 when it halts; and
  after a precompile run that a spawn step opened, the caller resumes with that step's
  `gas_after` plus the precompile's `left`.

So every step's `gas` is checked except the first step of a tx or harness frame.
-/
namespace TaikoSpec.ZkGas.Traces

/-- What a step model gives for one step: its `gas_after`, its outcome, the name of the branch
that decided it and, for a step that opens a frame, the gas it forwards to the new frame before a
value transfer's stipend (`StepResult.forwarded`; 0 for every other step). A step spawns exactly
when its outcome is `newFrame`. -/
structure Modeled where
  gasAfter : Nat
  outcome : Outcome
  branch : String
  forwarded : Nat := 0

/-- A step model. -/
abbrev Model := Pre → Except String Modeled

/-- The Unzen step model `stepOutcome` (`ZkGasModel.Step`). -/
def stepModel : Model := fun pre =>
  (stepOutcome .unzen pre).map fun r =>
    { gasAfter := r.gasAfter, outcome := r.outcome, branch := r.branch.name,
      forwarded := r.forwarded }

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
    if out.gasAfter > pre.gas then
      throw s!"gas_after {hexString out.gasAfter} exceeds gas {hexString pre.gas}"
    if out.spawn then
      match s.spawnEstimate pre.op with
      | none => throw s!"spawn step of opcode {opName pre.op}, which has no spawn estimate"
      | some estimate =>
        if out.charged && out.zk != estimate * mult then
          throw s!"zk {hexString out.zk}, but a spawn step charges its estimate {estimate} * multiplier {mult} = {hexString (estimate * mult)}"
    else
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

/-- (e): the model's result for one step: its `spawn` and `gas_after` must be the trace's.
Returns the model's result. -/
def checkModel (model : Model) (pre : Pre) (out : StepOut) : Except String Modeled := do
  let m ← model pre
  let spawn := m.outcome == .newFrame
  unless spawn == out.spawn do
    throw s!"model branch {m.branch}: spawn {spawn}, trace spawn {out.spawn}"
  unless m.gasAfter == out.gasAfter do
    throw s!"model branch {m.branch}: gas_after {hexString m.gasAfter}, trace gas_after {hexString out.gasAfter}"
  pure m

/-- Outcome `o`'s constructor name, for messages. -/
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
  /-- The step's `gas_after`. -/
  gasAfter : Nat
  /-- The step is CREATE or CREATE2. -/
  create : Bool
  /-- For RETURN, the length of the data it returns (`stack[1]`); 0 otherwise. -/
  returnLen : Nat
  /-- For a step that opens a frame, the gas the new frame starts with: the gas the step forwards
  (`Modeled.forwarded`) plus the 2,300 stipend of a CALL or CALLCODE with a non-zero value
  (revm-interpreter 43.0.1 `call_helpers.rs:104-106`). 0 otherwise. -/
  frameGas : Nat
  /-- For a CALL-family step, its target `stack[1]` as an address (the low 160 bits), which is
  the code address revm runs a precompile by (revm-interpreter 43.0.1 `contract.rs:236`,
  `bytecode_address: to`; revm-handler 43.0.2 `precompile_provider.rs:146`), also for a target
  with an EIP-7702 delegation;
  `none` otherwise. -/
  target : Option Nat
  /-- For a step that opens a frame, the gas its frame may resume with when the new frame runs no
  step (`noChildResume`). -/
  resumeAlone : List Nat

/-- The gas a frame resumes with after a spawn step of opcode `op` (`transfer`: a CALL or CALLCODE
with a non-zero value) whose new frame runs no step, from the spawn step's `gasAfter` and the new
frame's gas `frameGas` (revm-handler 43.0.2 `src/frame.rs`). The handler ends such a frame at
once, and `handle_reservoir_remaining_gas` (`:595`) hands its gas back unless the result is a halt
(revm-interpreter 43.0.1 `instruction_result.rs:163-215`):

- CALL family (`make_call_frame`): the depth limit (`:176-178`, `CallTooDeep`) and a value the
  caller cannot pay (`:184-192`, `OutOfFunds`) are revert-class, and an account without code
  (`:232-235`, `Stop`) succeeds, so the whole frame gas comes back. A CALL with a non-zero value
  can also halt there, losing it: a transfer that overflows the target's balance
  (`OverflowPayment`, revm-context 43.0.2 `journal/inner.rs:492-495`). CALLCODE moves its value
  to its own account and cannot overflow (`:465-472`).
- CREATE family (`make_create_frame`): the depth limit (`:292-294`), the creator's balance
  (`:302-304`) and a nonce overflow (`:308-310`, `Return`) give the frame gas back; an address
  collision and a balance overflow of the new account (`:324-331`, `CreateCollision` and
  `OverflowPayment`) are halts and lose it.

The trace does not show which case ran, so where both are possible either amount passes. -/
def noChildResume (op : Nat) (transfer : Bool) (gasAfter frameGas : Nat) : List Nat :=
  if op = 0xf0 ∨ op = 0xf5 ∨ (op = 0xf1 ∧ transfer) then [gasAfter + frameGas, gasAfter]
  else [gasAfter + frameGas]

/-- A child frame that runs steps, opened by a spawn step. -/
structure Frame where
  /-- The spawn step's event index. -/
  event : Nat
  /-- The spawn step's depth; the child runs one deeper. -/
  depth : Nat
  /-- The spawn step's `gas_after`: the opening frame's gas while the child runs. -/
  gasAfter : Nat
  /-- The spawn step is CREATE or CREATE2. -/
  create : Bool

/-- Event `e`, for messages. -/
def describe : Event → String
  | .intrinsic .. => "intrinsic"
  | .step pre _ => s!"a step at depth {pre.depth}"
  | .precompile .. => "a precompile"
  | .txEnd .. => "tx_end"
  | .frameEnd .. => "frame_end"

/-- `xs` as a list of canonical 0x hex, for messages. -/
def showHexList (xs : List Nat) : String := toString (xs.map hexString)

/-- (e): event `e`, which follows the modeled step `p`, is one `p`'s outcome allows, and starts
from the gas `p` hands it. A step that continues is followed by a step at its depth whose gas is
`p`'s `gas_after`. A step that opens a frame is followed by the new frame's first step, one deeper,
with the frame's gas; by the precompile run it opened, supplied that gas and at its target; or,
when the new frame ran no step, by a step at its depth that resumes with `noChildResume`. A step
that ends a child frame is followed by a step one depth up (its gas is checked by
`Walk.frameReturn`), and one that ends the top frame by the end of the tx or frame, where a
harness `frame_end` has the status of the outcome. -/
def checkNext (p : Pending) (e : Event) : Except String Unit := do
  let at_ := s!"event {p.event}: model branch {p.branch}: outcome {outcomeName p.outcome}"
  let fail (what : String) : Except String Unit :=
    throw s!"{at_}{what}, but the next event is {describe e}"
  match p.outcome, e with
  | .continue, .step pre _ =>
    unless pre.depth = p.depth do fail ""
    unless pre.gas = p.gasAfter do
      throw s!"{at_} with gas_after {hexString p.gasAfter}, but the next step at its depth has gas {hexString pre.gas}"
  | .continue, _ => fail ""
  | .newFrame, .step pre _ =>
    if pre.depth = p.depth + 1 then
      unless pre.gas = p.frameGas do
        throw s!"{at_} opens a frame with {hexString p.frameGas} gas (forwarded, plus a value transfer's stipend), but its first step has gas {hexString pre.gas}"
    else if pre.depth = p.depth then
      unless p.resumeAlone.contains pre.gas do
        throw s!"{at_} with gas_after {hexString p.gasAfter} opens a frame of {hexString p.frameGas} gas that runs no step, so its frame resumes with one of {showHexList p.resumeAlone}, but the next step at its depth has gas {hexString pre.gas}"
    else fail ""
  | .newFrame, .precompile addr supplied .. =>
    unless supplied = p.frameGas do
      throw s!"{at_} opens a frame with {hexString p.frameGas} gas (forwarded, plus a value transfer's stipend), but the precompile run is supplied {hexString supplied}"
    if let some target := p.target then
      unless addr = target do
        throw s!"{at_} calls {hexString target}, but the precompile run is at {hexString addr}"
  | .newFrame, _ => fail ""
  | _, .step pre _ => unless pre.depth + 1 = p.depth do fail s!" ends a frame at depth {p.depth}"
  | o, .frameEnd status _ =>
    unless p.depth = 1 do fail s!" ends a frame at depth {p.depth}"
    if let some want := frameStatus o then
      if want ≠ status then
        throw s!"{at_} ends the top frame with status {want}, but frame_end has status {status}"
  | _, .txEnd .. => unless p.depth = 1 do fail s!" ends a frame at depth {p.depth}"
  | _, _ => fail s!" ends a frame at depth {p.depth}"

/-- EIP-170's `MAX_CODE_SIZE` (revm-primitives 43.0.0 `eip170.rs`), the code size limit before
Amsterdam: alethia-reth sets no `limit_contract_code_size` (revm-context 43.0.2 `cfg.rs:462`). -/
def maxCodeSize : Nat := 24576

/-- `code_deposit_cost` per byte (revm-context-interface 43.0.1 `gas.rs`, `CODEDEPOSIT`). -/
def codeDepositGas : Nat := 200

/-- The gas a child frame whose last step's outcome is `o`, with `left` gas after it, gives back
to the frame that opened it (revm-handler 43.0.2 `src/frame.rs`): `handle_reservoir_remaining_gas`
(`:595`) returns the child's remaining gas for a successful or reverted result (`:613-614`) and
nothing for a halt, which spends it (`:604-611`). A CREATE child that returns code goes through
`return_create` (`:640`) first: code above `maxCodeSize` bytes (`:664`), code starting with 0xEF
(`:674`, EIP-3541) and a code deposit of 200 gas per byte the child cannot pay (`:684-693`) make
the result a halt, and otherwise the deposit is spent. A trace does not record the code's first
byte, so a CREATE child that can pay its deposit may give back either the rest or nothing. A CALL
child's gas includes the 2,300 stipend of a value transfer, which it gives back like the rest. -/
def returnedGas (create : Bool) (o : Outcome) (left len : Nat) : List Nat :=
  match o with
  | .success =>
    if !create || len = 0 then [left]
    else if len > maxCodeSize ∨ left < codeDepositGas * len then [0]
    else [left - codeDepositGas * len, 0]
  | .revert => [left]
  | _ => [0]

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
  /-- The depth and `gas_after` of the current tx's or frame's last step. -/
  lastStep : Option (Nat × Nat) := none
  /-- The child frames that are running, innermost first. -/
  frames : List Frame := []
  /-- After a precompile run a spawn step opened: the depth and gas its caller resumes with, and
  where they come from. -/
  resume : Option (Nat × Nat × String) := none
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
                      lastStep := none, frames := [], direct := false, rejected := false,
                      total := 0, charges := [] }
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
    let m ← (checkModel model pre out).mapError (s!"event {i}: " ++ ·)
    let transfer := (pre.op == 0xf1 || pre.op == 0xf2) && pre.stack.getD 2 0 != 0
    let frameGas := m.forwarded + if transfer then callStipend else 0
    let pending : Option Pending :=
      if out.ok then
        some { event := i, depth := pre.depth, outcome := m.outcome, branch := m.branch
               gasAfter := out.gasAfter
               create := pre.op = 0xf0 ∨ pre.op = 0xf5
               returnLen := if pre.op = 0xf3 then pre.stack.getD 1 0 else 0
               frameGas
               target := if callFamily pre.op then some (pre.stack.getD 1 0 % 2 ^ 160) else none
               resumeAlone := noChildResume pre.op transfer out.gasAfter frameGas }
      else none
    let w := { w with
      depth := some pre.depth
      spawned := out.spawn
      callSpawned := out.spawn && callFamily pre.op
      lastStep := some (pre.depth, out.gasAfter)
      branches := m.branch :: w.branches
      pending }
    if out.charged then w.charge s i out.zk out.ok else pure w
  | .precompile addr supplied left success zk ok => do
    w.inside layer i "precompile"
    let direct := w.depth.isNone
    unless w.callSpawned || direct do
      throw s!"event {i}: precompile event must follow a CALL-family spawn step, or be a tx's or frame's only event"
    (checkAmount s (.precompile addr supplied left success zk ok)).mapError (s!"event {i}: " ++ ·)
    let resume := match w.lastStep with
      | some (d, gasAfter) =>
        if !direct && ok then
          some (d, gasAfter + left,
            s!"the precompile run of event {i} leaves {hexString left} to the spawn step of gas_after {hexString gasAfter}")
        else none
      | none => none
    let w := { w with spawned := false, callSpawned := false, direct, resume }
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

/-- (f): event `e`, number `i`, after the walk `prev`, with `w` the walk after `e`'s own
checks. A step one deeper than the modeled spawn step before it enters that step's child frame.
A step after a modeled step that ends a child frame resumes the frame that opened it, whose gas
must be the spawn step's `gas_after` plus what the child gives back (`returnedGas`). The event
after a precompile run that a spawn step opened is its caller's step, with the spawn step's
`gas_after` plus the gas the precompile left. -/
def Walk.frameReturn (w prev : Walk) (i : Nat) : Event → Except String Walk
  | .step pre _ => do
    if let some (d, want, what) := prev.resume then
      unless pre.depth = d ∧ pre.gas = want do
        throw s!"event {i}: a step at depth {pre.depth} with gas {hexString pre.gas}, but {what}, so its caller resumes at depth {d} with {hexString want}"
    let some p := prev.pending | return w
    if p.outcome = .newFrame ∧ pre.depth = p.depth + 1 then
      let f : Frame := { event := p.event, depth := p.depth, gasAfter := p.gasAfter, create := p.create }
      return { w with frames := f :: w.frames }
    if (frameStatus p.outcome).isNone ∨ p.depth ≤ 1 then return w
    match w.frames with
    | f :: rest =>
      unless f.depth + 1 = p.depth do
        throw s!"event {i}: the child frame that ends at event {p.event} runs at depth {p.depth}, but the innermost open frame was opened at depth {f.depth}"
      let returned := returnedGas f.create p.outcome p.gasAfter p.returnLen
      unless returned.any (pre.gas = f.gasAfter + ·) do
        throw s!"event {i}: gas {hexString pre.gas}, but the frame resumes with gas_after {hexString f.gasAfter} of its spawn step (event {f.event}) plus {showHexList returned}, what its child gives back after outcome {outcomeName p.outcome} with {hexString p.gasAfter} left (event {p.event}, model branch {p.branch})"
      return { w with frames := rest }
    | [] => throw s!"event {i}: the child frame that ends at event {p.event} has no open frame"
  | e => do
    if let some (_, _, what) := prev.resume then
      throw s!"event {i}: {describe e}, but {what}, so its caller resumes with a step"
    return w

/-- Walks the events from index `i` on. Each event is checked on its own first, then against
the outcome of the modeled step before it, then for the gas a frame gets back. -/
def walkFrom (s : Schedule) (model : Model) (layer : Layer) : Nat → Walk → List Event →
    Except String Walk
  | _, w, [] => .ok w
  | i, w, e :: es =>
    match { w with pending := none, resume := none }.event s model layer i e with
    | .error err => .error err
    | .ok w' =>
      match w.pending.map (checkNext · e) with
      | some (.error err) => .error err
      | _ =>
        match w'.frameReturn w i e with
        | .error err => .error err
        | .ok w'' => walkFrom s model layer (i + 1) w'' es

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

/-- The coverage gate over `hits`, the number of steps of each branch name: every branch of
`allBranches` that `unreachableBranches` does not list has a step, no listed one has, and no step
reports a branch outside `allBranches`. One message per failure. -/
def coverageErrors (hits : List (String × Nat)) : List String :=
  let count (name : String) : Nat := (hits.lookup name).getD 0
  let unreachable (b : BranchId) : Bool := unreachableBranches.any (·.1 == b)
  let missing := allBranches.filter fun b => !unreachable b && count b.name = 0
  let reached := unreachableBranches.filter fun (b, _) => count b.name > 0
  let unknown := hits.filter fun (name, n) => n > 0 && !allBranches.any (·.name == name)
  let noStep := if missing.length = 1 then "branch has no step" else "branches have no step"
  (if missing.isEmpty then [] else
    [s!"{missing.length} {noStep}: {", ".intercalate (missing.map (·.name))}"]) ++
  reached.map (fun (b, why) => s!"branch {b.name} is listed as unreachable ({why}), but {count b.name} steps reach it") ++
  unknown.map fun (name, n) => s!"{n} steps report branch {name}, which allBranches does not list"

/-- What one vector's check covered. -/
structure Report where
  events : Nat
  steps : Nat
  /-- The model branch of every modeled step, in order. -/
  branches : List String
  deriving Repr, DecidableEq

/-- Checks the trace `events` of the vector whose case file text is `vector`. A block vector
runs the Unzen schedule; a harness vector runs it with the vector's `zk_block_limit`. -/
def checkVectorEvents (vector : String) (events : List Event) (model : Model) :
    Except String Report := do
  let v ← (Lean.Json.parse vector).mapError ("vector: invalid JSON: " ++ ·)
  let expected ← (field v "expected").mapError fun _ => "the vector has no expected values"
  let s ← match ← stringField v "layer" with
    | "block" => pure unzen
    | "harness" => do
      let limit ← asHex "input.zk_block_limit" (← field (← field v "input") "zk_block_limit")
      pure { unzen with blockLimit := limit }
    | other => throw s!"layer: {other.quote} is not block or harness"
  let branches ← checkTrace s expected events model
  let steps := events.countP fun | .step .. => true | _ => false
  return { events := events.length, steps, branches }

/-- Checks the trace text `trace` of the vector whose case file text is `vector`
(`checkVectorEvents` on the parsed events). -/
def checkVectorText (vector trace : String) (model : Model) : Except String Report := do
  checkVectorEvents vector (← parseTrace trace) model

end TaikoSpec.ZkGas.Traces
