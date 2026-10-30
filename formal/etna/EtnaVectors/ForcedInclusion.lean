import EtnaVectors.Machine

/-! Forced-inclusion queue vectors: `saveForcedInclusion` (fee formula and its doubling
threshold, size limit, refund, queue indices) and `sweepProtocolFees`. -/
namespace Etna.Vectors
open Etna.Design

def payName (kind : Nat) : String := if kind = 0 then "under" else if kind = 1 then "exact" else "over"

/-- Underpay by 1 wei, pay exactly, or overpay by 5 wei. -/
def payFor (kind fee : Nat) : Nat := if kind = 0 then fee-1 else if kind = 1 then fee else fee+5

/-- The fee formula over base fee, doubling threshold and pending count, and each payment. -/
def feeGrid : List Scenario :=
  [1, 3].flatMap fun fee => [1, 2, 3].flatMap fun thr => [0, 1, 2, 3].flatMap fun pending =>
    [0, 1, 2].map fun kind =>
      { label := "forced.enqueue.fee" ++ Nat.repr fee ++ ".threshold" ++ Nat.repr thr ++ ".pending" ++
          Nat.repr pending ++ ".paid-" ++ payName kind,
        deploy := { feeGwei := fee, threshold := thr },
        setup := fill pending,
        call := fun w => ⟨w.l1Block+1, .enqueue 2 32 (payFor kind (currentFee w.inbox)) true⟩ }

/-- The 8,192-byte limit, empty submissions and a refund the caller rejects. -/
def sizeGrid : List Scenario :=
  [0, 1, 8192, 8193].flatMap fun raw => [true, false].flatMap fun refundOK => [1, 2].map fun kind =>
    { label := "forced.enqueue.bytes" ++ Nat.repr raw ++ (if refundOK then ".refund-accepted" else ".refund-rejected") ++
        ".paid-" ++ payName kind,
      setup := fill 1,
      call := fun w => ⟨w.l1Block+1, .enqueue 2 raw (payFor kind (currentFee w.inbox)) refundOK⟩ }

/-- Pending is tail − head on L1: a landing that consumes entries lowers the next fee. -/
def consumedGrid : List Scenario :=
  [0, 1, 2, 3].flatMap fun k => [0, 1].map fun kind =>
    { label := "forced.enqueue.after-landing-consumes" ++ Nat.repr k ++ ".paid-" ++ payName kind,
      setup := fill 3 ++ [landTo 6 k],
      call := fun w => ⟨w.l1Block+1, .enqueue 2 32 (payFor kind (currentFee w.inbox)) true⟩ }

def sweepGrid : List Scenario :=
  [0, 2].flatMap fun n => [0, 5].flatMap fun extra => [true, false].map fun accepts =>
    { label := "forced.sweep.entries" ++ Nat.repr n ++ ".forced-eth" ++ Nat.repr extra ++
        (if accepts then ".recipient-accepts" else ".recipient-rejects"),
      deploy := { recipientAccepts := accepts },
      setup := fill n ++ (if extra = 0 then [] else [later 1 (.forceETH extra)]),
      call := later 1 (.sweep 3) }

def forcedHandwritten : List Scenario := [
  { label := "forced.hw.fee-stays-after-consumption", spec := some "spec L415",
    setup := fill 2 ++ [landTo 6 2],
    call := later 1 (.sweep 3) },
  { label := "forced.hw.sweep-leaves-queue-untouched", spec := some "spec L420",
    setup := fill 3,
    call := later 1 (.sweep 4) },
  { label := "forced.hw.second-sweep-sends-nothing", spec := some "spec L420",
    setup := fill 1 ++ [later 1 (.sweep 3)],
    call := later 1 (.sweep 3) },
  { label := "forced.hw.empty-submission-reads-as-blanked", spec := some "spec L461",
    call := fun w => ⟨w.l1Block+1, .enqueue 2 0 (currentFee w.inbox) true⟩ },
  { label := "forced.hw.failed-refund-charges-nothing", spec := some "spec L415",
    setup := fill 1,
    call := fun w => ⟨w.l1Block+1, .enqueue 2 32 (currentFee w.inbox + 1) false⟩ },
  { label := "forced.hw.entries-retained-after-consumption", spec := some "spec L426",
    setup := fill 3 ++ [landTo 6 2],
    call := fun w => ⟨w.l1Block+1, .enqueue 2 32 (currentFee w.inbox) true⟩ },
  { label := "forced.hw.timestamp-2pow48-minus1", spec := some "spec L791",
    call := fun w => ⟨w.l1Block+1, .enqueue 2 32 (currentFee w.inbox) true⟩, callTimestamp := some (limit48-1) },
  { label := "forced.hw.timestamp-2pow48", spec := some "spec L791",
    call := fun w => ⟨w.l1Block+1, .enqueue 2 32 (currentFee w.inbox) true⟩, callTimestamp := some limit48 },
  { label := "forced.hw.block-2pow48-minus1", spec := some "spec L791",
    call := fun w => ⟨limit48-1, .enqueue 2 32 (currentFee w.inbox) true⟩, callTimestamp := some (timestampOf 20) },
  { label := "forced.hw.block-2pow48", spec := some "spec L791",
    call := fun w => ⟨limit48, .enqueue 2 32 (currentFee w.inbox) true⟩, callTimestamp := some (timestampOf 20) }]

def forcedScenarios : List Scenario := feeGrid ++ sizeGrid ++ consumedGrid ++ sweepGrid ++ forcedHandwritten

end Etna.Vectors
