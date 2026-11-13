import Lean.Data.Json
import ZkGasModel

/-!
# Trace schema v1: events and their parser

A trace is a JSON Lines file, one event per line, written by alethia-reth for one vector of
`testdata/zk_gas_vectors` (the schema is in that directory's README). `parseTrace` turns it into
`Event`s and rejects any line that does not follow the schema: unknown events, missing or
unknown fields, numbers in the wrong encoding, a `stack` of the wrong length, and `facts` keys
the opcode does not record. Whether the events are in a valid order and add up is checked by
`ZkGasTraces.Check`.

Event indices in error messages count lines from 0.
-/
namespace TaikoSpec.ZkGas.Traces

/-- What one step did, as the client recorded it. -/
structure StepOut where
  /-- The frame's gas after the step, as fed to the meter. Only for reference when `spawn`. -/
  gasAfter : Nat
  /-- Whether the step opened a new frame (CALL or CREATE family). -/
  spawn : Bool
  /-- The zk gas the step charged, or tried to charge when `ok` is false. -/
  zk : Nat
  /-- Whether the meter accepted the charge; false when it exceeded the limit. -/
  ok : Bool
  /-- Whether the client called the meter for this step at all. -/
  charged : Bool
  deriving Repr, DecidableEq

/-- One trace event. -/
inductive Event
  /-- A block transaction starts with its intrinsic charge. -/
  | intrinsic (zk : Nat) (ok : Bool)
  /-- One interpreter step: the state it ran from and what it did. -/
  | step (pre : Pre) (out : StepOut)
  /-- A precompile run: its address, the gas it was given and had left, whether it succeeded,
  and the zk gas it charged. -/
  | precompile (addr supplied left : Nat) (success : Bool) (zk : Nat) (ok : Bool)
  /-- A block transaction ends. `txZk` is its total when committed; the parser maps the `null`
  of an aborted or skipped tx to 0. -/
  | txEnd (index : Nat) (status : TxStatus) (txZk : Nat)
  /-- A harness frame ends. `frameZk` is its total; the parser maps the `null` of `zk_limit` to
  0. -/
  | frameEnd (status : String) (frameZk : Nat)
  deriving Repr, DecidableEq

/-! ## Scalars -/

/-- `n` as canonical 0x hex, for messages. -/
def hexString (n : Nat) : String := "0x" ++ String.ofList (Nat.toDigits 16 n)

/-- Opcode `op` as two-digit 0x hex, for messages. -/
def opName (op : Nat) : String :=
  let digits := String.ofList (Nat.toDigits 16 op)
  "0x" ++ (if digits.length < 2 then "0" ++ digits else digits)

def hexDigit? (c : Char) : Option Nat :=
  if '0' ≤ c ∧ c ≤ '9' then some (c.toNat - '0'.toNat)
  else if 'a' ≤ c ∧ c ≤ 'f' then some (c.toNat - 'a'.toNat + 10)
  else none

/-- The value of the lowercase hex digits `cs` after `acc`, most significant first. -/
def hexDigits? : List Char → Nat → Option Nat
  | [], acc => some acc
  | c :: cs, acc => (hexDigit? c).bind fun d => hexDigits? cs (acc * 16 + d)

/-- Parses canonical 0x hex, the encoding of every integer in the corpus: lowercase, no leading
zeros, and zero is `0x0`. -/
def parseHex (s : String) : Except String Nat :=
  let err : Except String Nat :=
    .error s!"{s.quote} is not canonical 0x hex (lowercase, no leading zeros, zero is 0x0)"
  match s.toList with
  | ['0', 'x', '0'] => .ok 0
  | '0' :: 'x' :: '0' :: _ => err
  | '0' :: 'x' :: c :: cs => match hexDigits? (c :: cs) 0 with
    | some n => .ok n
    | none => err
  | _ => err

/-- Parses a 20-byte address: `0x` and 40 lowercase hex digits. -/
def parseAddress (s : String) : Except String Nat :=
  let err : Except String Nat := .error s!"{s.quote} is not a 20-byte lowercase 0x address"
  match s.toList with
  | '0' :: 'x' :: cs =>
    if cs.length = 40 then
      match hexDigits? cs 0 with
      | some n => .ok n
      | none => err
    else err
  | _ => err

/-! ## JSON fields -/

/-- The keys of a JSON object. -/
def objectKeys (j : Lean.Json) : Except String (List String) :=
  match j with
  | .obj kvs => .ok kvs.keys
  | _ => .error "not a JSON object"

/-- Checks that the object `j` has exactly the fields `keys`. -/
def exactFields (j : Lean.Json) (keys : List String) : Except String Unit := do
  let present ← objectKeys j
  for k in keys do
    unless present.contains k do throw s!"missing field {k}"
  for k in present do
    unless keys.contains k do throw s!"unknown field {k}"

def field (j : Lean.Json) (k : String) : Except String Lean.Json :=
  match j.getObjVal? k with
  | .ok v => .ok v
  | .error _ => .error s!"missing field {k}"

def asHex (k : String) (v : Lean.Json) : Except String Nat :=
  match v with
  | .str s => (parseHex s).mapError (s!"{k}: " ++ ·)
  | _ => .error s!"{k}: must be a canonical 0x hex string"

/-- A 256-bit word: a stack item, a storage value or a balance. -/
def asWord (k : String) (v : Lean.Json) : Except String Nat := do
  let n ← asHex k v
  if n < 2 ^ 256 then pure n else throw s!"{k}: {hexString n} exceeds 2^256 - 1"

/-- A JSON integer (`pc`, `d`, `op`, `sl`, `index`). Lean's reader also turns `1e2` into 100;
the corpus `check.py` rejects every spelling but a plain integer. -/
def asIndex (k : String) (v : Lean.Json) : Except String Nat :=
  match v with
  | .num n =>
    if n.exponent = 0 ∧ n.mantissa ≥ 0 then .ok n.mantissa.toNat
    else .error s!"{k}: must be a non-negative JSON integer"
  | _ => .error s!"{k}: must be a non-negative JSON integer"

def asBool (k : String) (v : Lean.Json) : Except String Bool :=
  match v with
  | .bool b => .ok b
  | _ => .error s!"{k}: must be true or false"

def asString (k : String) (v : Lean.Json) : Except String String :=
  match v with
  | .str s => .ok s
  | _ => .error s!"{k}: must be a string"

def hexField (j : Lean.Json) (k : String) : Except String Nat := do asHex k (← field j k)

def boolField (j : Lean.Json) (k : String) : Except String Bool := do asBool k (← field j k)

def indexField (j : Lean.Json) (k : String) : Except String Nat := do asIndex k (← field j k)

def stringField (j : Lean.Json) (k : String) : Except String String := do asString k (← field j k)

/-! ## Facts -/

/-- The `facts` keys a step of opcode `op` records when the stack holds all `inputs op` of its
inputs. With fewer, the step halts on stack underflow and records no facts. -/
def factKeys (op : Nat) : List String :=
  if op = 0x56 ∨ op = 0x57 then ["jumpdest_valid"]
  else if op = 0x3e then ["returndata_size"]
  else if op = 0x54 then ["slot_warm"]
  else if op = 0x55 then ["slot_warm", "original", "current"]
  else if op = 0x31 ∨ op = 0x3b ∨ op = 0x3c ∨ op = 0x3f then ["account_warm"]
  else if op = 0xf1 ∨ op = 0xf2 ∨ op = 0xf4 ∨ op = 0xfa then
    ["account_warm", "account_empty", "delegate_warm"]
  else if op = 0xff then ["account_warm", "account_empty", "self_balance"]
  else []

/-- The fact `k` of `j` read with `f` when `want` lists it, else `none`. -/
def optFact (want : List String) (j : Lean.Json) (k : String) (f : String → Lean.Json → Except String α) :
    Except String (Option α) :=
  if want.contains k then do some <$> f s!"facts.{k}" (← field j k) else pure none

def asDelegateWarm (k : String) (v : Lean.Json) : Except String (Option Bool) :=
  match v with
  | .null => .ok none
  | .bool b => .ok (some b)
  | _ => .error s!"{k}: must be true, false or null (no EIP-7702 delegation)"

def parseFacts (op stackLen : Nat) (j : Lean.Json) : Except String Facts := do
  let want := if stackLen < inputs op then [] else factKeys op
  let present ← (objectKeys j).mapError ("facts: " ++ ·)
  for k in want do
    unless present.contains k do throw s!"facts: missing fact {k} for opcode {opName op}"
  for k in present do
    unless want.contains k do
      throw s!"facts: fact {k} not allowed for opcode {opName op} with {stackLen} of its {inputs op} stack inputs"
  return {
    jumpdestValid := ← optFact want j "jumpdest_valid" asBool
    returndataSize := ← optFact want j "returndata_size" asHex
    slotWarm := ← optFact want j "slot_warm" asBool
    original := ← optFact want j "original" asWord
    current := ← optFact want j "current" asWord
    accountWarm := ← optFact want j "account_warm" asBool
    accountEmpty := ← optFact want j "account_empty" asBool
    delegateWarm := ← optFact want j "delegate_warm" asDelegateWarm
    selfBalance := ← optFact want j "self_balance" asWord }

/-! ## Events -/

/-- The fields of each event, in the order the schema writes them. -/
def stepFields : List String :=
  ["e", "d", "pc", "op", "gas", "static", "sl", "stack", "mem", "facts", "gas_after", "spawn",
   "zk", "ok", "charged"]

def parseStep (j : Lean.Json) : Except String Event := do
  exactFields j stepFields
  let op ← indexField j "op"
  if op > 255 then throw s!"op: {op} is not an opcode byte"
  let sl ← indexField j "sl"
  if sl > 1024 then throw s!"sl: {sl} exceeds the stack limit 1024"
  let stack ← match ← field j "stack" with
    | .arr items => items.toList.mapM (asWord "stack")
    | _ => throw "stack: must be an array"
  unless stack.length = min sl (inputs op) do
    throw s!"stack: {stack.length} entries, want min(sl, inputs(op)) = {min sl (inputs op)}"
  let pre : Pre := {
    op, stack, stackLen := sl
    depth := ← indexField j "d"
    pc := ← indexField j "pc"
    gas := ← hexField j "gas"
    static := ← boolField j "static"
    mem := ← hexField j "mem"
    facts := ← parseFacts op sl (← field j "facts") }
  let out : StepOut := {
    gasAfter := ← hexField j "gas_after"
    spawn := ← boolField j "spawn"
    zk := ← hexField j "zk"
    ok := ← boolField j "ok"
    charged := ← boolField j "charged" }
  return .step pre out

def parseEvent (j : Lean.Json) : Except String Event := do
  let kind ← match j with
    | .obj _ => stringField j "e"
    | _ => throw "not a JSON object"
  match kind with
  | "intrinsic" =>
    exactFields j ["e", "zk", "ok"]
    return .intrinsic (← hexField j "zk") (← boolField j "ok")
  | "step" => parseStep j
  | "precompile" =>
    exactFields j ["e", "addr", "supplied", "left", "success", "zk", "ok"]
    let addr ← (parseAddress (← stringField j "addr")).mapError ("addr: " ++ ·)
    return .precompile addr (← hexField j "supplied") (← hexField j "left")
      (← boolField j "success") (← hexField j "zk") (← boolField j "ok")
  | "tx_end" =>
    exactFields j ["e", "index", "status", "tx_zk"]
    let index ← indexField j "index"
    let status ← match ← stringField j "status" with
      | "committed" => pure TxStatus.committed
      | "aborted" => pure .aborted
      | "skipped" => pure .skipped
      | other => throw s!"status: {other.quote} must be committed, aborted or skipped"
    let txZk ← match status, ← field j "tx_zk" with
      | .committed, v => asHex "tx_zk" v
      | _, .null => pure 0
      | _, _ => throw "tx_zk: must be null unless the tx is committed"
    return .txEnd index status txZk
  | "frame_end" =>
    exactFields j ["e", "status", "frame_zk"]
    let status ← stringField j "status"
    unless ["success", "revert", "halt", "zk_limit"].contains status do
      throw s!"status: {status.quote} must be success, revert, halt or zk_limit"
    let frameZk ← match status == "zk_limit", ← field j "frame_zk" with
      | true, .null => pure 0
      | true, _ => throw "frame_zk: must be null when status is zk_limit"
      | false, v => asHex "frame_zk" v
    return .frameEnd status frameZk
  | other => throw s!"unknown event {other}"

/-- Parses the lines from event index `i` on, after the events `acc` (newest first). A single
empty last line is the file's final newline. -/
def parseLines : Nat → List String → List Event → Except String (List Event)
  | _, [], acc => .ok acc.reverse
  | i, line :: rest, acc =>
    if line.isEmpty then
      if rest.isEmpty then .ok acc.reverse else .error s!"event {i}: empty line"
    else
      match Lean.Json.parse line with
      | .error e => .error s!"event {i}: invalid JSON: {e}"
      | .ok j =>
        match parseEvent j with
        | .error e => .error s!"event {i}: {e}"
        | .ok event => parseLines (i + 1) rest (event :: acc)

/-- Parses a trace file: JSON Lines, one event per line. -/
def parseTrace (text : String) : Except String (List Event) := do
  let events ← parseLines 0 (text.splitOn "\n") []
  if events.isEmpty then throw "trace has no events"
  return events

end TaikoSpec.ZkGas.Traces
