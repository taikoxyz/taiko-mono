import EtnaProofs.PerBlockCommittee

namespace Etna.PerBlockCommitteeRegression
open Etna.Design Etna.Design.PerBlockCommittee

set_option maxRecDepth 20000

private def keyA : Hash := compressedKey 2 17
private def keyB : Hash := compressedKey 2 19
private def keyC : Hash := compressedKey 3 23

/-- The point and commitment adapters use fixture values in these decoded regressions. -/
private def rules : Rules :=
  ⟨fun key ↦ key != compressedKey 2 101, fun keys ↦ if keys = [keyA] then 10 else 11⟩

private def padded (records : List SnapshotSeat) : List SnapshotSeat :=
  records ++ List.replicate (seatCount - records.length) default

private def snapshot : Snapshot := ⟨41, 120, padded [packSnapshotSeat 2 19 5]⟩
private def anchor : Anchor := ⟨120, 11⟩
private def candidate : List Member := [⟨keyB, 5⟩]
private def anchoredFallback : List Member := [⟨keyC, 1⟩]

example : decision rules 41 snapshot anchor [keyC] = some candidate := by decide +kernel

-- Snapshot height is compared as a full word. Equality with the threshold is sufficient.
example : decision rules 41 { snapshot with heightWord := 40 } anchor [keyC] =
      some anchoredFallback ∧
    decision rules 41 { snapshot with heightWord := 41 + 2^48 } anchor [keyC] =
      some anchoredFallback ∧
    decision rules 41 snapshot { anchor with minTotalStake := 121 } [keyC] =
      some anchoredFallback := by decide +kernel

example : decision rules 41 { snapshot with totalStake := forceFallback }
      { anchor with minTotalStake := forceFallback } [keyC] = some anchoredFallback ∧
    decision rules 41 snapshot { anchor with minTotalStake := limit256 } [keyC] = none := by
  decide +kernel

-- Every stored record is read, including seat 127. Only both-zero records are skipped.
example : candidateMembers rules (List.replicate 127 default ++ [packSnapshotSeat 2 19 5]) =
      some candidate ∧
    candidateMembers rules (padded [packSnapshotSeat 2 19 5, packSnapshotSeat 3 23 0]) = none ∧
    candidateMembers rules (padded []) = none ∧
    candidateMembers rules [packSnapshotSeat 2 19 5] = none := by decide +kernel

example : candidateMembers rules (padded [packSnapshotSeat 2 19 5, packSnapshotSeat 2 19 5]) =
      none ∧
    candidateMembers rules (padded [packSnapshotSeat 2 101 5]) = none ∧
    candidateMembers rules (padded [packSnapshotSeat 4 19 5]) = none ∧
    candidateMembers rules (padded [packSnapshotSeat 2 fieldPrime 5]) = none ∧
    candidateMembers rules (padded [⟨19, 2^72 + 2 + 2^8 * 5⟩]) = none := by decide +kernel

example : candidateMembers rules (padded [packSnapshotSeat 2 19 maxPower]) =
      some [⟨keyB, maxPower⟩] ∧
    candidateMembers rules (padded [packSnapshotSeat 2 19 maxPower, packSnapshotSeat 3 23 1]) =
      none ∧
    candidateMembers rules
      (padded [packSnapshotSeat 2 19 (2^64 - 1), packSnapshotSeat 3 23 2]) = none := by
  decide +kernel

example : fallback rules 11 [keyA, keyC] = some [⟨keyA, 1⟩, ⟨keyC, 1⟩] ∧
    fallback rules 11 [] = none ∧ fallback rules 11 [keyA, keyA] = none ∧
    fallback rules 11 [keyC, keyA] = none ∧ fallback rules 10 [keyC] = none := by decide +kernel

private def origin : GenerationOrigin := ⟨40, 100, 200, 10⟩

private def inputAt (height : Nat) : Option DecisionInput :=
  match height with
  | 41 => some ⟨snapshot, anchor, [keyC]⟩
  | 42 => some ⟨{ snapshot with heightWord := 42 },
      { anchor with minTotalStake := 121 }, [keyC]⟩
  | _ => none

example : signingSet rules origin [keyA] inputAt 41 = some [⟨keyA, 1⟩] ∧
    signingSet rules origin [keyA] inputAt 42 = some [⟨keyA, 1⟩] ∧
    signingSet rules origin [keyA] inputAt 43 = some candidate ∧
    signingSet rules origin [keyA] inputAt 44 = some anchoredFallback ∧
    signingSet rules origin [keyA] inputAt 45 = none ∧
    signingSet rules origin [keyC] inputAt 41 = none := by decide +kernel

example :
    validatorUpdates [⟨keyA, 1⟩, ⟨keyB, 2⟩, ⟨keyC, 3⟩] [⟨keyB, 4⟩, ⟨keyA, 1⟩] =
    [⟨keyB, 4⟩, ⟨keyC, 0⟩] ∧
    validatorUpdates [⟨keyA, 1⟩, ⟨keyB, 2⟩] [⟨keyB, 2⟩, ⟨keyA, 1⟩] = [] := by decide

private def liveWord : Nat → Nat
  | 7 => 1
  | 8 => 1
  | 9 => 1 + 256 * 127
  | 10 => 1 + 256 * 128
  | 11 => 2 + 256 * 1
  | 12 => 2^16 + 1 + 256 * 1
  | _ => 0

-- Missing nil and absent entries are looked up in the current parent storage map.
example : missBitmap false [7, 8, 9, 10, 11, 12, 13] [3, 2, 1, 1, 3, 3, 1] liveWord =
      some (2^127 + 1) ∧
    missBitmap false [7, 8] [1, 3] liveWord = some 1 ∧
    missBitmap false [7, 8] [1] liveWord = none := by decide +kernel

example : missBitmap true [] [] liveWord = some 0 ∧
    missBitmap true [7] [1] liveWord = none := by decide +kernel

private def extraDataBytes : List UInt8 :=
  [100, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 128] ++ List.replicate 14 0 ++ [1]

example : decodeExtraData extraDataBytes = some ⟨0x010203040506, 0x0708090a0b0c, 2^127 + 1⟩ ∧
    decodeExtraData (extraDataBytes ++ [0]) = none ∧
    decodeExtraData (extraDataBytes.take 28) = none ∧
    decodeExtraData (99 :: extraDataBytes.drop 1) = none := by decide +kernel

end Etna.PerBlockCommitteeRegression
