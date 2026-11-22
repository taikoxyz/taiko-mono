import EtnaModel.Common

/-! Per-block validator selection and header miss accounting. The inputs are openings of
authenticated L1 and L2 state and of CometBFT's LastCommit. SEC1 point validation and the
ABI/Keccak fallback commitment are explicit adapters. -/
namespace Etna.Design.PerBlockCommittee

def seatCount : Nat := 128
def maxPower : Nat := (2^63 - 1) / 8
def forceFallback : Nat := limit256 - 1
def fieldPrime : Nat := 2^256 - 2^32 - 977

/-- A canonical compressed key's 33-byte big-endian value, including its prefix. -/
def compressedKey (ckPrefix x : Nat) : Hash := ckPrefix * limit256 + x

structure Rules where
  validPoint : Hash → Bool
  hashFallbackKeys : List Hash → Hash

def validKey (rules : Rules) (key : Hash) : Bool :=
  let ckPrefix := key / limit256
  (ckPrefix == 2 || ckPrefix == 3) && key % limit256 < fieldPrime && rules.validPoint key

structure Member where
  key : Hash
  power : Nat
  deriving DecidableEq, Repr

/-- The two words read at T + 3 + 2s and T + 4 + 2s. -/
structure SnapshotSeat where
  ckX : Nat := 0
  packed : Nat := 0
  deriving DecidableEq, Repr, Inhabited

/-- Pack fields that already fit the storage widths in STOR-B-21. -/
def packSnapshotSeat (ckPrefix x power : Nat) : SnapshotSeat := ⟨x, ckPrefix + 2^8 * power⟩

structure Snapshot where
  heightWord : Nat
  totalStake : Nat
  seats : List SnapshotSeat
  deriving DecidableEq, Repr

def decodeSeat (seat : SnapshotSeat) : Option Member :=
  if seat.ckX < limit256 ∧ seat.packed < 2^72 then
    some ⟨compressedKey (seat.packed % 2^8) seat.ckX, seat.packed / 2^8⟩
  else none

def validMembers (rules : Rules) (members : List Member) : Bool :=
  decide (members ≠ [] ∧ members.length ≤ seatCount ∧
    (members.map Member.key).Nodup ∧ (members.map Member.power).sum ≤ maxPower) &&
    members.all (fun m ↦ m.power != 0 && validKey rules m.key)

def candidateMembers (rules : Rules) (seats : List SnapshotSeat) : Option (List Member) := do
  if seats.length ≠ seatCount then none else do
    let members ← (seats.filter (· != default)).mapM decodeSeat
    if validMembers rules members then some members else none

def usableCandidate (rules : Rules) (height threshold : Nat) (snapshot : Snapshot) :
    Option (List Member) :=
  if threshold ≠ forceFallback ∧ snapshot.heightWord = height ∧
      threshold ≤ snapshot.totalStake ∧ snapshot.totalStake < limit256 then
    candidateMembers rules snapshot.seats
  else none

def validFallbackKeys (rules : Rules) (keys : List Hash) : Bool :=
  decide (keys ≠ [] ∧ keys.length ≤ seatCount ∧ keys.Pairwise (· < ·)) &&
    keys.all (validKey rules)

def fallback (rules : Rules) (expectedHash : Hash) (keys : List Hash) : Option (List Member) :=
  if expectedHash < limit256 ∧ rules.hashFallbackKeys keys = expectedHash ∧
      validFallbackKeys rules keys then
    some (keys.map (fun key ↦ ⟨key, 1⟩))
  else none

/-- The only two words of the authenticated anchor used in validator derivation. -/
structure Anchor where
  minTotalStake : Nat
  fallbackKeysHash : Hash
  deriving DecidableEq, Repr

/-- The decision in block H for the set signing H+2. It opens the fallback commitment when used. -/
def decision (rules : Rules) (height : Nat) (snapshot : Snapshot) (anchor : Anchor)
    (fallbackKeys : List Hash) : Option (List Member) :=
  if height < limit48 ∧ anchor.minTotalStake < limit256 ∧
      anchor.fallbackKeysHash < limit256 then
    match usableCandidate rules height anchor.minTotalStake snapshot with
    | some members => some members
    | none => fallback rules anchor.fallbackKeysHash fallbackKeys
  else none

structure GenerationOrigin where
  height : Nat
  l1Block : Nat
  timestamp : Nat
  fallbackKeysHash : Hash
  deriving DecidableEq, Repr

structure DecisionInput where
  snapshot : Snapshot
  anchor : Anchor
  fallbackKeys : List Hash
  deriving DecidableEq, Repr

/-- At a non-origin height, the lookup supplies the authenticated state and anchor of H-2. -/
def signingSet (rules : Rules) (origin : GenerationOrigin) (originKeys : List Hash)
    (inputAt : Nat → Option DecisionInput) (height : Nat) : Option (List Member) :=
  if height ≤ origin.height then none
  else if height ≤ origin.height + 2 then fallback rules origin.fallbackKeysHash originKeys
  else do
    let input ← inputAt (height - 2)
    decision rules (height - 2) input.snapshot input.anchor input.fallbackKeys

/-- FinalizeBlock emits this delta against the set signing H+1, as required by stock ABCI. -/
def validatorUpdates (next target : List Member) : List Member :=
  target.filter (fun m ↦ !next.contains m) ++
    (next.filter (fun m ↦ !target.any (·.key == m.key))).map (fun m ↦ { m with power := 0 })

/-- The parent post-state word packs holdsSeat in its first byte and seat in its second. -/
def liveSeat (word : Nat) : Option Nat :=
  let seat := word / 2^8
  if word % 2^8 = 1 ∧ seat < seatCount then some seat else none

/-- Stock CometBFT `BLOCK_ID_FLAG_COMMIT` has numeric value 2. -/
def commitFlag : Nat := 2

def missingSeats (parentAddresses flags : List Nat) (liveWord : Nat → Nat) : List Nat :=
  (parentAddresses.zip flags).filterMap (fun (address, flag) ↦
    if flag = commitFlag then none else liveSeat (liveWord address))

def seatBitmap : List Nat → Nat
  | [] => 0
  | s :: seats => (2^s) ||| seatBitmap seats

/-- Addresses come from the parent's validators in stock set order. Flags come from an
authenticated LastCommit and are used in that same order. -/
def missBitmap (first : Bool) (parentAddresses flags : List Nat) (liveWord : Nat → Nat) :
    Option Nat :=
  if first then
    if flags.isEmpty then some 0 else none
  else if parentAddresses.length = flags.length then
    some (seatBitmap (missingSeats parentAddresses flags liveWord))
  else none

structure ExtraData where
  generation : Nat
  anchorNumber : Nat
  missBitmap : Nat
  deriving DecidableEq, Repr

private def readBE (bytes : List UInt8) : Nat :=
  bytes.foldl (fun n byte ↦ n * 256 + byte.toNat) 0

/-- The 29-byte execution header field in ENC-A-10, with the base-fee share fixed at 100. -/
def decodeExtraData : List UInt8 → Option ExtraData
  | 100 :: fields =>
    if fields.length = 28 then
      some ⟨readBE (fields.take 6), readBE ((fields.drop 6).take 6), readBE (fields.drop 12)⟩
    else none
  | _ => none

end Etna.Design.PerBlockCommittee
