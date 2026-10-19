import Etna.Landing.Claim
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
private def hexBytes (bytes : List Byte) : String :=
  "0x" ++ String.join (bytes.map fun byte => (hexNat byte.val 2).drop 2 |>.toString)
private def errorName : ClaimError → String
  | .reentrant => "reentrant" | .invalidReceipt => "invalid-receipt"
  | .emptyAccountProof => "empty-account-proof" | .alreadyClaimed => "already-claimed"
  | .invalidAnchorRoot => "invalid-anchor-root" | .proof => "proof" | .transfer => "transfer"
/-- Outcomes decided before the EIP-4788 STATICCALL; every later outcome executes it. -/
private def beforeRoot : Except ClaimError Vault → Bool
  | .error .reentrant | .error .invalidReceipt | .error .emptyAccountProof | .error .alreadyClaimed => true
  | _ => false
/-- Outcomes that execute the value CALL when the amount is nonzero. -/
private def reachesTransfer : Except ClaimError Vault → Bool
  | .ok _ | .error .transfer => true
  | _ => false
private def jn (n : Nat) : Json := toJson n
private def js (s : String) : Json := toJson s
private def jb (b : Bool) : Json := toJson b
private def decimal (j : Json) (k : String) : Except String Nat := do
  match (← j.getObjValAs? String k).toNat? with | some x => pure x | none => throw "invalid decimal"
private def hexField (j : Json) (k : String) : Except String Nat := do parseHex (← j.getObjValAs? String k)
private def receiptOfJson (j : Json) : Except String Receipt := do
  let parentHeight ← j.getObjValAs? Nat "parentHeight"
  let lastHeight ← j.getObjValAs? Nat "lastHeight"
  -- Both heights are uint64 ABI words; the model's naturals must not exceed them.
  if parentHeight ≥ 2 ^ 64 || lastHeight ≥ 2 ^ 64 then throw "uint64 receipt height"
  return {
    l1ChainId := ← word 256 (← decimal j "l1ChainId")
    l2ChainId := ← word 64 (← j.getObjValAs? Nat "l2ChainId")
    inbox := ← word 160 (← hexField j "inbox")
    generation := ← word 64 (← j.getObjValAs? Nat "generation")
    parentHeight
    parentHash := ← word 256 (← hexField j "parentHash")
    lastHeight
    lastBlockHash := ← word 256 (← hexField j "lastBlockHash")
    recipient := ← word 160 (← hexField j "l2RewardRecipient")
    amount := ← word 256 (← decimal j "baseFeeAmount") }
/-- A claim with an intact proof of its own receipt against a published root, as the driver builds
for prior and nested claims. Value transfer succeeds exactly when the vault holds the amount. -/
private def fundedCall (r : Receipt) (balance : Nat) : ClaimCall := ⟨r, true, true, true, decide (r.amount.val ≤ balance)⟩
private def runCase (j : Json) : Except String Json := do
  if (← j.getObjValAs? Nat "schemaVersion") != 1 then throw "schema"
  -- Keccak oracle: exact preimage bytes to the cast digests the driver derived from its own
  -- independent encodings. An encoding the driver did not anticipate is a hard failure.
  let mut table : List (String × Nat) := []
  for pair in (← j.getObjValAs? (Array (Array String)) "keccakOracle") do
    if pair.size != 2 then throw "oracle pair"
    table := table ++ [(pair[0]!.toLower, ← parseHex pair[1]!)]
  let lookup (bytes : List Byte) := table.lookup (hexBytes bytes)
  let keccak (bytes : List Byte) : Word256 := match checkedWord 256 ((lookup bytes).getD 0) with
    | some x => x | none => 0
  let known (r : Receipt) : Except String Unit := do
    if (lookup (batchIdWords r).flatten.toList).isNone ||
        (lookup (commitmentWords (batchId keccak r) r).flatten.toList).isNone then
      throw "missing Keccak oracle preimage"
  let vj ← j.getObjVal? "vault"
  let mut vault : Vault := {
    l1ChainId := ← word 256 (← decimal vj "l1ChainId")
    chainId := ← word 64 (← vj.getObjValAs? Nat "chainId")
    inbox := ← word 160 (← hexField vj "inbox") }
  let mut balance ← decimal vj "balanceWei"
  let r ← receiptOfJson (← j.getObjVal? "receipt")
  known r
  -- A prior successful claim runs first, from the unlocked vault, with its own intact proof.
  let mut priorClaimed := false
  if let .ok prior := j.getObjVal? "prior" then
    let pr ← receiptOfJson (← prior.getObjVal? "receipt")
    known pr
    match claim keccak vault (fundedCall pr balance) with
    | .ok after => vault := after; balance := balance - pr.amount.val; priorClaimed := true
    | .error _ => throw "prior claim must succeed"
  vault := { vault with entered := ← vj.getObjValAs? Bool "entered" }
  let ledger ← j.getObjVal? "ledger"
  let ledgerReceipt ← receiptOfJson (← ledger.getObjVal? "receipt")
  known ledgerReceipt
  let ledgerAccount ← word 160 (← hexField ledger "account")
  let accountProof ← j.getObjValAs? String "accountProof"
  let storageProof ← j.getObjValAs? String "storageProof"
  let root ← j.getObjValAs? String "root"
  let recipientMode ← j.getObjValAs? String "recipient"
  if !(["valid", "empty", "corrupt"].contains accountProof && ["valid", "empty", "corrupt"].contains storageProof &&
      ["published", "storage-root", "missing", "expired", "zero", "other"].contains root &&
      ["eoa", "rejecting", "reentrant"].contains recipientMode) then throw "invalid proof/root/recipient mode"
  -- The anchored root commits to `ledger`: `account`'s storage holds the ledger receipt's commitment
  -- at keccak(batchId, mappingSlot). An intact proof of that leaf verifies exactly when it is the
  -- claimed receipt's rewardCommitments entry. An empty account proof makes LibTrieProof treat the
  -- root as a storage root, dropping the account binding; the vault rejects that case first.
  let leafMatches := storageProof == "valid" && (← ledger.getObjValAs? Nat "mappingSlot") == 283 &&
    batchId keccak ledgerReceipt == batchId keccak r && commitment keccak ledgerReceipt == commitment keccak r
  let proofAccepted := leafMatches && (if accountProof == "empty" then root == "storage-root"
    else accountProof == "valid" && root == "published" && ledgerAccount == vault.inbox)
  -- EIP-4788 returns a stored root for an unexpired timestamp and reverts otherwise.
  let rootAvailable := ["published", "storage-root", "other"].contains root
  let call : ClaimCall := ⟨r, accountProof != "empty", rootAvailable, proofAccepted,
    recipientMode != "rejecting" && decide (r.amount.val ≤ balance)⟩
  let result := claim keccak vault call
  let attempted := reachesTransfer result && r.amount.val != 0
  -- The recipient's code runs only when the CALL can move the value. Its re-entry executes inside
  -- the outer call, whose guard is set; the guard check precedes every other field.
  let nested ← if recipientMode == "reentrant" && attempted && decide (r.amount.val ≤ balance) then do
      let nr ← receiptOfJson (← (← j.getObjVal? "reentry").getObjVal? "receipt")
      known nr
      pure (some (nr, claim keccak { vault with entered := true } (fundedCall nr (balance - r.amount.val))))
    else pure none
  let ok := match result with | .ok _ => true | .error _ => false
  let post := match result with | .ok v' => v' | .error _ => vault
  let nestedOk := match nested with | some (_, .ok _) => true | _ => false
  let nestedPayouts := match nested with
    | some (_, .ok nv) => if ok then nv.payouts.drop vault.payouts.length else []
    | _ => []
  let payouts := nestedPayouts ++ post.payouts.drop vault.payouts.length
  let paid := (payouts.map Transfer.wei).sum
  let id := batchId keccak r
  let nestedRoot := match nested with | some (_, n) => if beforeRoot n then 0 else 1 | none => 0
  let nestedTransfer := match nested with
    | some (nr, n) => if reachesTransfer n && nr.amount.val != 0 then 1 else 0
    | none => 0
  return Json.mkObj [("schemaVersion", jn 1), ("id", js (← j.getObjValAs? String "id")),
    ("status", js (if ok then "ok" else "revert")),
    ("error", js (match result with | .ok _ => "none" | .error e => errorName e)),
    ("batchId", js (hexNat id.val 64)), ("claimed", jb (post.claimed id)),
    ("paidTo", js (hexNat (payouts.getLast?.map (·.recipient.val) |>.getD 0) 40)),
    ("paidWei", js (toString paid)), ("vaultBalanceWei", js (toString (balance - paid))),
    ("rewardEvents", jn (if ok then 1 + (if nestedOk then 1 else 0) else 0)),
    ("eventBatchId", js (hexNat (if ok then id.val else 0) 64)),
    ("eventRecipient", js (hexNat (if ok then r.recipient.val else 0) 40)),
    ("eventAmount", js (toString (if ok then r.amount.val else 0))),
    ("rootQueries", jn ((if beforeRoot result then 0 else 1) + nestedRoot)),
    ("recipientCalls", jn ((if attempted then 1 else 0) + nestedTransfer)),
    ("nestedResult", js (match nested with | none => "none" | some (_, .ok _) => "ok" | some (_, .error e) => errorName e)),
    ("priorClaimed", jb priorClaimed),
    ("expectedBatchPreimage", js (hexBytes (batchIdWords r).flatten.toList)),
    ("expectedCommitmentPreimage", js (hexBytes (commitmentWords id r).flatten.toList))]

def main (args : List String) : IO UInt32 := do
  let stdout ← IO.getStdout
  for line in (← IO.FS.readFile (args.headD "corpus/claim.jsonl")).splitOn "\n" do
    if !line.isEmpty then
      let j ← IO.ofExcept (Json.parse line)
      let result ← IO.ofExcept (runCase j)
      stdout.putStrLn result.compress
  return 0
