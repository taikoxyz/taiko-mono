import EtnaModel.CurrentJournal

/-! Current FI service, admission and importer contracts. Complete decoded payloads and
their selected parser/EL interpreter remain explicit implementation boundaries. -/
namespace Etna.Design.Current.QueueIntegrity
open Protocol

/-- Exact successful admission accounting. `paid-fee` is the same-call refund, so the
collected fee, never the overpayment, is recorded as Inbox revenue and balance. -/
structure AdmissionAccounting (before after : Etna.Design.State) (raw paid : Nat) (refund : Bool) : Prop where
  bytes : raw ≤ 8192
  queue : before.head ≤ before.tail
  tailRange : before.tail+1 < limit48
  payment : Forced.admissionFee before.forcedFee before.forcedThreshold (before.tail-before.head) ≤ paid
  refund : paid = Forced.admissionFee before.forcedFee before.forcedThreshold (before.tail-before.head) ∨ refund = true
  splitPayment : paid = Forced.admissionFee before.forcedFee before.forcedThreshold
    (before.tail-before.head) + (paid-Forced.admissionFee before.forcedFee before.forcedThreshold (before.tail-before.head))
  balanceRange : before.ethBalance + Forced.admissionFee before.forcedFee before.forcedThreshold
    (before.tail-before.head) < limit256
  head : after.head = before.head
  tail : after.tail = before.tail+1
  balance : after.ethBalance = before.ethBalance +
    Forced.admissionFee before.forcedFee before.forcedThreshold (before.tail-before.head)
  revenue : after.feeAdmissions = before.feeAdmissions +
    Forced.admissionFee before.forcedFee before.forcedThreshold (before.tail-before.head)

/-- Every consumed edge carries its real queue entry, complete position-zero binding,
and either inclusion or a due-qualified skip under the selected interpreter. -/
def LandingService (env : Environment) (w t : World) (a : Landing) : Prop :=
  ∃ segment : Suffix env w a,
    (Blocks.consumingPairs segment.parent segment.blocks).map (fun x => x.1.cursor) =
      List.range' w.inbox.head (t.inbox.head-w.inbox.head) ∧
    (∀ x ∈ Blocks.consumingPairs segment.parent segment.blocks,
      ∃ entry, (x.1.cursor,entry) ∈ w.queue ∧ x.2.first = x.2.transactions.head? ∧
        Blocks.TimelyByteAction (Blocks.definition
          (policy env w segment.archive a.input.l1ReferenceBlockNumber) x.2).bytes
          w.inbox.forcedDelay x.1 x.2.body entry x.2.raw x.2.first) ∧ t.queue = w.queue

/-- A nondue consuming edge authenticates the entry at position zero of the complete
decoded payload; a later occurrence is insufficient. -/
def NoEarlySkip (env : Environment) (w : World) : Prop :=
  ∀ archive reference parent block entry,
    Blocks.Valid (policy env w archive reference) parent block →
    block.header.cursor = parent.cursor+1 → (parent.cursor,entry) ∈ w.queue →
    block.header.anchor.timestamp < entry.timestamp+w.inbox.forcedDelay →
    Blocks.Included (Blocks.definition (policy env w archive reference) block).bytes
      entry block.transactions.head?

/-- Publication installs every original generation header, including both endpoints,
with no duplicate or missing index. -/
structure ImportRange (candidate : Import.Candidate) (installed : Import.Installed) : Prop where
  ordered : installed.headerNumbers = List.range' candidate.origin (candidate.height-candidate.origin+1)
  origin : candidate.origin ≤ candidate.height
  length : installed.headerNumbers.length = candidate.height-candidate.origin+1
  complete : ∀ n, n ∈ installed.headerNumbers ↔ candidate.origin ≤ n ∧ n ≤ candidate.height
  distinct : installed.headerNumbers.Nodup

end Etna.Design.Current.QueueIntegrity
