module
public import Etna.Landing.Statement
public section
set_option maxHeartbeats 2000000
namespace Etna.Landing
abbrev Address := Fin (2 ^ 160)

/-- `bytes32("ETNA_L2_REWARD_BATCH_V1")`, right padded. -/
@[expose] def rewardBatchDomain : AbiWord :=
  #v[69, 84, 78, 65, 95, 76, 50, 95, 82, 69, 87, 65, 82, 68, 95, 66, 65, 84, 67, 72, 95, 86, 49,
     0, 0, 0, 0, 0, 0, 0, 0, 0]
/-- `bytes32("ETNA_L2_REWARD_RECEIPT_V1")`, right padded. -/
@[expose] def rewardReceiptDomain : AbiWord :=
  #v[69, 84, 78, 65, 95, 76, 50, 95, 82, 69, 87, 65, 82, 68, 95, 82, 69, 67, 69, 73, 80, 84, 95,
     86, 49, 0, 0, 0, 0, 0, 0, 0]

/-- `LibEtnaRewards.Receipt` in field order. Heights are naturals here; the source types are
uint64 and every landed height is checked below `2^48` before a receipt is built. -/
structure Receipt where
  l1ChainId : Word256
  l2ChainId : Word64
  inbox : Address
  generation : Word64
  parentHeight : Nat
  parentHash : Word256
  lastHeight : Nat
  lastBlockHash : Word256
  recipient : Address
  amount : Word256
  deriving DecidableEq, Repr

/-- The eight identity words after the batch domain; recipient and amount are excluded. -/
@[expose] def batchIdWords (r : Receipt) : Vector AbiWord 9 :=
  #v[rewardBatchDomain, natWord r.l1ChainId.val, natWord r.l2ChainId.val, natWord r.inbox.val,
     natWord r.generation.val, natWord r.parentHeight, natWord r.parentHash.val,
     natWord r.lastHeight, natWord r.lastBlockHash.val]

@[expose] def commitmentWords (id : Word256) (r : Receipt) : Vector AbiWord 4 :=
  #v[rewardReceiptDomain, natWord id.val, natWord r.recipient.val, natWord r.amount.val]

/-- `LibEtnaRewards.batchId` over the given Keccak primitive. -/
@[expose] def batchId (keccak : List Byte → Word256) (r : Receipt) : Word256 :=
  keccak (batchIdWords r).flatten.toList

/-- `LibEtnaRewards.commitment`: domain, batch id, recipient and amount. -/
@[expose] def commitment (keccak : List Byte → Word256) (r : Receipt) : Word256 :=
  keccak (commitmentWords (batchId keccak r) r).flatten.toList

/-- The receipt's batch identity: everything `batchId` hashes. -/
@[expose] def Receipt.identity (r : Receipt) : Word256 × Word64 × Address × Word64 × Nat × Word256 × Nat × Word256 :=
  (r.l1ChainId, r.l2ChainId, r.inbox, r.generation, r.parentHeight, r.parentHash, r.lastHeight, r.lastBlockHash)

/-- Trace-local collision separation for the two compared batch preimages only. -/
@[expose] def LocalBatchSeparation (keccak : List Byte → Word256) (a b : Receipt) : Prop :=
  (batchIdWords a).flatten.toList ≠ (batchIdWords b).flatten.toList →
    keccak (batchIdWords a).flatten.toList ≠ keccak (batchIdWords b).flatten.toList

/-- Trace-local collision separation for the two compared commitment preimages only. -/
@[expose] def LocalCommitmentSeparation (keccak : List Byte → Word256) (a b : Receipt) : Prop :=
  (commitmentWords (batchId keccak a) a).flatten.toList ≠ (commitmentWords (batchId keccak b) b).flatten.toList →
    commitment keccak a ≠ commitment keccak b

private theorem flatten_list_inj {n : Nat} (a b : Vector AbiWord n)
    (same : a.flatten.toList = b.flatten.toList) : a = b :=
  (blob_encoding_injective a b).mp (Vector.toList_inj.mp same)

/-- Distinct identity fields (heights below `2^256`) give distinct batch preimages. -/
theorem batch_words_injective (a b : Receipt) (ha : a.parentHeight < 2 ^ 256) (hb : b.parentHeight < 2 ^ 256)
    (la : a.lastHeight < 2 ^ 256) (lb : b.lastHeight < 2 ^ 256)
    (same : (batchIdWords a).flatten.toList = (batchIdWords b).flatten.toList) :
    a.identity = b.identity := by
  have words := flatten_list_inj _ _ same
  have w i (hi : i < 9) := congrArg (fun v : Vector AbiWord 9 => v[i]'hi) words
  have e1 := natWord_injective _ _ (by have := a.l1ChainId.isLt; omega) (by have := b.l1ChainId.isLt; omega) (w 1 (by omega))
  have e2 := natWord_injective _ _ (by have := a.l2ChainId.isLt; omega) (by have := b.l2ChainId.isLt; omega) (w 2 (by omega))
  have e3 := natWord_injective _ _ (by have := a.inbox.isLt; omega) (by have := b.inbox.isLt; omega) (w 3 (by omega))
  have e4 := natWord_injective _ _ (by have := a.generation.isLt; omega) (by have := b.generation.isLt; omega) (w 4 (by omega))
  have e5 := natWord_injective _ _ ha hb (w 5 (by omega))
  have e6 := natWord_injective _ _ (a.parentHash.isLt) (b.parentHash.isLt) (w 6 (by omega))
  have e7 := natWord_injective _ _ la lb (w 7 (by omega))
  have e8 := natWord_injective _ _ (a.lastBlockHash.isLt) (b.lastBlockHash.isLt) (w 8 (by omega))
  simp only [Receipt.identity, Prod.mk.injEq]
  exact ⟨Fin.ext e1, Fin.ext e2, Fin.ext e3, Fin.ext e4, e5, Fin.ext e6, e7, Fin.ext e8⟩

/-- Receipts whose parent heights differ have different ids under local separation. -/
theorem batch_id_distinct (keccak : List Byte → Word256) (a b : Receipt)
    (ha : a.parentHeight < 2 ^ 256) (hb : b.parentHeight < 2 ^ 256)
    (la : a.lastHeight < 2 ^ 256) (lb : b.lastHeight < 2 ^ 256)
    (separation : LocalBatchSeparation keccak a b) (different : a.parentHeight ≠ b.parentHeight) :
    batchId keccak a ≠ batchId keccak b := by
  apply separation
  intro same
  have identity := batch_words_injective a b ha hb la lb same
  simp only [Receipt.identity, Prod.mk.injEq] at identity
  exact different identity.2.2.2.2.1

/-- An equal commitment recovers the batch id, recipient and amount of the recorded receipt. -/
theorem commitment_binding (keccak : List Byte → Word256) (a b : Receipt)
    (separation : LocalCommitmentSeparation keccak a b)
    (matched : commitment keccak a = commitment keccak b) :
    batchId keccak a = batchId keccak b ∧ a.recipient = b.recipient ∧ a.amount = b.amount := by
  by_contra different
  apply separation _ matched
  intro same
  have words := flatten_list_inj _ _ same
  have w i (hi : i < 4) := congrArg (fun v : Vector AbiWord 4 => v[i]'hi) words
  have e1 := natWord_injective _ _ (Fin.isLt _) (Fin.isLt _) (w 1 (by omega))
  have e2 := natWord_injective _ _ (by have := a.recipient.isLt; omega) (by have := b.recipient.isLt; omega) (w 2 (by omega))
  have e3 := natWord_injective _ _ (a.amount.isLt) (b.amount.isLt) (w 3 (by omega))
  exact different ⟨Fin.ext e1, Fin.ext e2, Fin.ext e3⟩

/-- Local separation is satisfiable for any distinct preimages; this is not Keccak. -/
theorem batch_separation_nonvacuity (a b : Receipt) :
    ∃ keccak : List Byte → Word256, LocalBatchSeparation keccak a b := by
  refine ⟨fun bytes => if bytes = (batchIdWords a).flatten.toList then 0 else 1, ?_⟩
  intro different
  have reverse : (batchIdWords b).flatten.toList ≠ (batchIdWords a).flatten.toList := Ne.symm different
  simp [reverse]

end Etna.Landing
