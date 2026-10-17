import Etna.Landing.Model
import Etna.Landing.Statement
import Etna.Landing.Reward
import Lean
open Lean Etna Etna.Landing
private def parseHex (s : String) : Except String Nat := do
  let s := if s.startsWith "0x" then s.drop 2 |>.toString else s
  let mut n := 0
  for c in s.toList do
    let v := if c ≥ '0' && c ≤ '9' then c.toNat - '0'.toNat
      else if c ≥ 'a' && c ≤ 'f' then c.toNat - 'a'.toNat + 10
      else if c ≥ 'A' && c ≤ 'F' then c.toNat - 'A'.toNat + 10 else 256
    if v ≥ 16 then throw "bad hex"
    n := n * 16 + v
  return n
private def word (bits n : Nat) : Except String (Fin (2^bits)) :=
  match checkedWord bits n with | some x => .ok x | none => .error "word out of range"
private def hexNat (n width : Nat) : String := Id.run do
  let digits := "0123456789abcdef".toList.toArray
  let mut n := n
  let mut out := ""
  for _ in [:width] do
    out := String.singleton digits[n % 16]! ++ out
    n := n / 16
  return "0x" ++ out
private def errorName : Error → String
  | .reentrant => "reentrant" | .inactive => "inactive" | .noProgress => "no-progress"
  | .batchTooLarge => "batch-too-large" | .heightOverflow => "height-overflow"
  | .zeroRecipient => "zero-recipient" | .zeroRewardRecipient => "zero-reward-recipient"
  | .invalidHead => "invalid-head" | .rewardAlreadyRecorded => "reward-already-recorded"
  | .anchorUnavailable => "anchor-unavailable" | .blobsRequired => "blobs-required"
  | .environmentError => "environment-error" | .signalUnauthorized => "signal-unauthorized"
  | .signalInvalid => "signal-invalid" | .verifier => "verifier" | .payment => "payment"
private def mode : String → Except String ReentryMode
  | "none" => .ok .none | "land-caught" => .ok .landCaught | "save-caught" => .ok .saveCaught
  | "land-uncaught" => .ok .landUncaught | "save-uncaught" => .ok .saveUncaught
  | "verifier-land" => .ok .verifierLand | "verifier-save" => .ok .verifierSave
  | _ => .error "invalid reentry mode"
private def jn (n : Nat) : Json := toJson n
private def js (s : String) : Json := toJson s
private def jb (b : Bool) : Json := toJson b
private def runCase (j : Json) : Except String Json := do
  let n (k : String) := j.getObjValAs? Nat k
  let b (k : String) := j.getObjValAs? Bool k
  let s (k : String) := j.getObjValAs? String k
  let h (k : String) := do parseHex (← s k)
  let dec (k : String) := do
    let str ← s k
    match str.toNat? with | some x => pure x | none => throw "invalid decimal"
  let parentHash ← match j.getObjValAs? String "parentHash" with
    | .ok v => parseHex v | .error _ => pure 0
  let feeJson ← j.getObjValAs? (Array String) "feesGwei"
  let mut fs : Array Word64 := #[]
  for v in feeJson do
    let val ← match v.toNat? with | some x => pure x | none => throw "invalid fee"
    fs := fs.push (← word 64 val)
  let before ← n "headBefore"
  -- Keccak oracle values: the driver derives them from its own receipt preimages.
  let oracle (k : String) : Except String Word256 := match j.getObjValAs? String k with
    | .ok value => do word 256 (← parseHex value)
    | .error _ => pure 0
  let rewardId ← oracle "rewardBatchId"
  let rewardValue ← oracle "rewardCommitmentValue"
  let rewardSeed ← word 256 (← h "rewardSeed")
  let w : World := {
    inbox := 1
    active := ← b "active"
    maxBatchBlocks := ← n "maxBatchBlocks"
    checkpoint := ⟨← n "parentHeight", ← word 256 parentHash⟩
    head := ← word 48 before
    tail := ← word 48 (← n "tail")
    fee := fun index => if index < before then 0 else fs[index-before]?.getD 0
    signal := []
    inboxBalance := ← dec "inboxBalanceWei"
    rewardCommitments := fun id => if id = rewardId then rewardSeed else 0
    transfers := []
    logs := []
    guard := ← b "guardLocked" }
  let w ← if let .ok context := j.getObjVal? "context" then do
    let ch (k : String) := do parseHex (← context.getObjValAs? String k)
    let cn (k : String) := context.getObjValAs? Nat k
    pure { w with
      inbox := ← word 160 (← ch "proxy")
      l1ChainId := ← word 256 (← cn "chainid")
      l2ChainId := ← word 64 (← cn "l2chainid")
      registry := ← word 160 (← ch "registry")
      generation := ← word 64 (← cn "generation")
      config := ← word 256 (← ch "config") }
    else pure w
  let i : LandInput := ⟨← word 64 (← n "lastHeight"), ← word 256 (← h "lastBlockHash"),
    ← word 256 (← h "lastStateRoot"), ← word 64 (← n "reference"), ← word 48 (← n "headAfter"),
    ← word 160 (← h "recipient"), ← word 160 (← h "l2RewardRecipient"), ← word 256 (← dec "baseFeeAmount"),
    ← word 160 (← h "caller")⟩
  let mut blobs := []
  for v in (← j.getObjValAs? (Array String) "blobs") do
    blobs := blobs ++ [← word 256 (← parseHex v)]
  let e : Etna.Landing.Environment := ⟨← n "currentBlock", ← word 256 (← h "referenceHash"),
    ← b "historySuccess", ← n "historyLength", ← word 256 (← h "referenceHash"), blobs⟩
  let blobCommitment ← match j.getObjValAs? String "blobCommitment" with
    | .ok value => word 256 (← parseHex value)
    | .error _ => pure (0 : Word256)
  let x : ExternalOutcomes := ⟨e, ← b "signalAuthorized", ← b "verifierAccepts",
    ← b "paymentAccepts", ← mode (← s "reentryMode"), fun _ => blobCommitment,
    -- A two-point oracle keyed by preimage length: 288-byte batch id, 128-byte commitment.
    fun bytes => if bytes.length = 288 then rewardId else rewardValue⟩
  let tentative := execLandSteps w i x
  let result := runTransaction w tentative
  let post := result.world
  let signal := post.signal.getLast?
  let transfer := post.transfers.getLast?
  let ok := result.error.isNone
  let mut fields := [("schemaVersion", jn 1), ("id", js (← s "id")),
    ("status", js (if ok then "ok" else "revert")),
    ("error", js (result.error.map errorName |>.getD "none")),
    ("head", jn post.head.val), ("tail", jn post.tail.val),
    ("checkpointHeight", jn post.checkpoint.height), ("checkpointHash", js (hexNat post.checkpoint.blockHash.val 64)),
    ("signalPresent", jb signal.isSome), ("signalHeight", jn (signal.map (·.height) |>.getD 0)),
    ("signalHash", js (hexNat (signal.map (·.blockHash.val) |>.getD 0) 64)),
    ("signalRoot", js (hexNat (signal.map (·.stateRoot.val) |>.getD 0) 64)),
    ("paidTo", js (hexNat (transfer.map (·.recipient.val) |>.getD 0) 40)),
    ("paidWei", js (toString (transfer.map (·.wei) |>.getD 0))),
    ("batchEvent", jb ok), ("consumedEvent", jb (ok && i.headAfter != w.head)),
    ("tentativeHead", jn tentative.journal.current.head.val),
    ("tentativeCheckpointHeight", jn tentative.journal.current.checkpoint.height),
    ("tentativeSignalPresent", jb (!tentative.journal.current.signal.isEmpty)),
    ("tentativeBatchEvent", jb (tentative.journal.current.logs.any fun e => match e with | .batchLanded .. => true | _ => false)),
    ("rewardEvent", jb (ok && post.logs.any fun e => match e with | .rewardRecorded .. => true | _ => false)),
    ("rewardCommitment", js (hexNat (post.rewardCommitments rewardId).val 64)),
    ("tentativeRewardCommitment", js (hexNat (if tentative.trace.contains .reward && tentative.stage != .reward
      then (tentative.journal.current.rewardCommitments rewardId).val else 0) 64))]
  if let some stmt := tentative.statement then
    let encoded := (encodeStatement stmt).toArray.toList.map fun byte => (hexNat byte.val 2).drop 2 |>.toString
    fields := fields ++ [("expectedPreimage", js ("0x" ++ String.join encoded))]
  if tentative.trace.contains .reward then
    let hexBytes (bytes : List Byte) := "0x" ++ String.join (bytes.map fun byte => (hexNat byte.val 2).drop 2 |>.toString)
    let receipt := receiptOf w i
    fields := fields ++ [
      ("expectedRewardBatchPreimage", js (hexBytes (batchIdWords receipt).flatten.toList)),
      ("expectedRewardCommitmentPreimage", js (hexBytes (commitmentWords rewardId receipt).flatten.toList))]
  return Json.mkObj fields

def main (args : List String) : IO UInt32 := do
  let stdout ← IO.getStdout
  for line in (← IO.FS.readFile (args.headD "corpus/landing.jsonl")).splitOn "\n" do
    if !line.isEmpty then
      let j ← IO.ofExcept (Json.parse line)
      let result ← IO.ofExcept (runCase j)
      stdout.putStrLn result.compress
  return 0
