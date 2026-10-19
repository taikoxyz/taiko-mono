module
public import Etna.Landing.Proofs
public section
set_option maxHeartbeats 2000000
namespace Etna.Landing

/-- `L2FeeVault` business state. `entered` is the reentrancy flag; a recipient callback that
re-enters `claim` reverts, which `ClaimCall.transferOk` already accounts for. -/
structure Vault where
  l1ChainId : Word256
  chainId : Word64
  inbox : Address
  entered : Bool := false
  claimed : Word256 → Bool := fun _ => false
  payouts : List Transfer := []

inductive ClaimError where
  | reentrant | invalidReceipt | emptyAccountProof | alreadyClaimed | invalidAnchorRoot | proof | transfer
  deriving DecidableEq, Repr

/-- One `claim` call. `rootAvailable` is the EIP-4788 staticcall returning a nonzero 32-byte
root; `proofAccepted` is `LibTrieProof.verifyMerkleProof` returning normally. -/
structure ClaimCall where
  receipt : Receipt
  accountProofNonempty : Bool
  rootAvailable : Bool
  proofAccepted : Bool
  transferOk : Bool
  deriving DecidableEq, Repr

@[expose] def receiptValid (v : Vault) (r : Receipt) : Bool :=
  r.l1ChainId == v.l1ChainId && r.l2ChainId == v.chainId && r.inbox == v.inbox &&
    decide (r.parentHeight < r.lastHeight) && r.recipient != 0

/-- `L2FeeVault.claim` in source order: guard, receipt identity, nonempty account proof,
claimed flag, anchored root, storage proof, then flag, transfer and event. -/
@[expose] def claim (keccak : List Byte → Word256) (v : Vault) (c : ClaimCall) : Except ClaimError Vault :=
  if v.entered then .error .reentrant
  else if !receiptValid v c.receipt then .error .invalidReceipt
  else if !c.accountProofNonempty then .error .emptyAccountProof
  else if v.claimed (batchId keccak c.receipt) then .error .alreadyClaimed
  else if !c.rootAvailable then .error .invalidAnchorRoot
  else if !c.proofAccepted then .error .proof
  else if c.receipt.amount.val ≠ 0 && !c.transferOk then .error .transfer
  else .ok { v with
    claimed := Function.update v.claimed (batchId keccak c.receipt) true,
    payouts := v.payouts ++ (if c.receipt.amount.val ≠ 0 then [⟨c.receipt.recipient, c.receipt.amount.val⟩] else []) }

/-- The storage-proof boundary: an accepted proof against the anchored root shows the fixed L1
Inbox holds the claimed receipt's commitment at `rewardCommitments[batchId]`. Account/storage
MPT verification and the mapping-slot hash are external; `storage` is that root's ledger. -/
@[expose] def ProofSound (keccak : List Byte → Word256) (storage : Word256 → Word256) (c : ClaimCall) : Prop :=
  c.proofAccepted = true → storage (batchId keccak c.receipt) = commitment keccak c.receipt

/-- CLAIM-01: a successful claim pays exactly the receipt's recipient and amount once, marks
its batch id, and (under the proof boundary) the anchored ledger holds its commitment. -/
theorem claim_success (keccak : List Byte → Word256) (storage : Word256 → Word256) (v v' : Vault) (c : ClaimCall)
    (sound : ProofSound keccak storage c) (ok : claim keccak v c = .ok v') :
    v.claimed (batchId keccak c.receipt) = false ∧ receiptValid v c.receipt = true ∧
    storage (batchId keccak c.receipt) = commitment keccak c.receipt ∧
    v'.claimed = Function.update v.claimed (batchId keccak c.receipt) true ∧
    v'.payouts = v.payouts ++
      (if c.receipt.amount.val ≠ 0 then [⟨c.receipt.recipient, c.receipt.amount.val⟩] else []) ∧
    v'.entered = v.entered ∧ v'.inbox = v.inbox ∧ v'.chainId = v.chainId ∧ v'.l1ChainId = v.l1ChainId := by
  unfold claim at ok
  split_ifs at ok with h1 h2 h3 h4 h5 h6 h7
  all_goals first | (simp at ok; done) | skip
  all_goals
    cases ok
    refine ⟨?_, ?_, sound ?_, rfl, ?_, rfl, rfl, rfl, rfl⟩ <;> simp_all

/-- CLAIM-02: once a batch id is claimed, every later claim for that id reverts. -/
theorem claim_once (keccak : List Byte → Word256) (v : Vault) (c : ClaimCall)
    (paid : v.claimed (batchId keccak c.receipt) = true) : ∃ e, claim keccak v c = .error e := by
  unfold claim
  split_ifs <;> simp_all

theorem claim_frame (keccak : List Byte → Word256) (v v' : Vault) (c : ClaimCall)
    (ok : claim keccak v c = .ok v') :
    v'.entered = v.entered ∧ v'.inbox = v.inbox ∧ v'.chainId = v.chainId ∧ v'.l1ChainId = v.l1ChainId ∧
    ∀ id, v.claimed id = true → v'.claimed id = true := by
  have s := claim_success keccak (fun id => if id = batchId keccak c.receipt then commitment keccak c.receipt else 0)
    v v' c (by intro _; simp) ok
  refine ⟨s.2.2.2.2.2.1, s.2.2.2.2.2.2.1, s.2.2.2.2.2.2.2.1, s.2.2.2.2.2.2.2.2, ?_⟩
  intro id before
  rw [s.2.2.2.1]
  by_cases same : id = batchId keccak c.receipt
  · subst same; simp
  · simp [Function.update_of_ne same, before]

/-- In a landing trace with pairwise-separated batch preimages, the final ledger still holds
each recorded receipt's commitment: later landings never overwrite an earlier slot. -/
theorem reward_trace_storage {keccak : List Byte → Word256} {w : World} {rs : List Receipt} {final : World}
    (trace : RewardTrace keccak w rs final) (start : w.checkpoint.height < 2 ^ 64)
    (separation : rs.Pairwise (LocalBatchSeparation keccak)) :
    ∀ r ∈ rs, final.rewardCommitments (batchId keccak r) = commitment keccak r := by
  have distinct := reward_ids_distinct trace start separation
  induction trace with
  | nil => simp
  | @cons w rest final i x primitive accepted tail ih =>
    have cp := committed_checkpoint w i x accepted
    have record := (reward_recorded_exact w i x accepted).2.1
    have restFacts := reward_trace_facts tail (by rw [cp]; exact i.lastHeight.isLt)
    have restDistinct := (List.pairwise_cons.mp distinct).2
    have headDistinct := (List.pairwise_cons.mp distinct).1
    intro r member
    rcases List.mem_cons.mp member with rfl | member
    · by_contra changed
      have idEq : rewardId w i x = batchId keccak (receiptOf w i) := by rw [rewardId, primitive]
      have cEq : rewardCommitment w i x = commitment keccak (receiptOf w i) := by rw [rewardCommitment, primitive]
      have mid : (runTransaction w (execLandSteps w i x)).world.rewardCommitments (batchId keccak (receiptOf w i)) =
          commitment keccak (receiptOf w i) := by
        rw [record, ← idEq, Function.update_self, cEq]
      have newer : final.rewardCommitments (batchId keccak (receiptOf w i)) ≠
          (runTransaction w (execLandSteps w i x)).world.rewardCommitments (batchId keccak (receiptOf w i)) := by
        rw [mid]; exact changed
      obtain ⟨later, laterMember, laterId⟩ := restFacts.2.2.2.1 _ newer
      exact headDistinct later laterMember laterId.symm
    · exact ih (by rw [cp]; exact i.lastHeight.isLt) (List.pairwise_cons.mp separation).2 restDistinct r member

/-- CLAIM-03: a claim proven against any ledger reached by successful landings from an empty
one pays a recorded receipt: same batch id, recipient and amount. A zero commitment would
need no landing, so its nonzero value is an explicit Keccak premise. -/
theorem claim_pays_recorded {keccak : List Byte → Word256} {w : World} {rs : List Receipt} {final : World}
    (trace : RewardTrace keccak w rs final) (empty : ∀ id, w.rewardCommitments id = 0)
    (start : w.checkpoint.height < 2 ^ 64)
    (separation : rs.Pairwise (LocalBatchSeparation keccak))
    (v v' : Vault) (c : ClaimCall) (sound : ProofSound keccak final.rewardCommitments c)
    (nonzero : commitment keccak c.receipt ≠ 0)
    (commitmentSeparation : ∀ r ∈ rs, LocalCommitmentSeparation keccak c.receipt r)
    (ok : claim keccak v c = .ok v') :
    ∃ r ∈ rs, batchId keccak r = batchId keccak c.receipt ∧ r.recipient = c.receipt.recipient ∧
      r.amount = c.receipt.amount := by
  have stored := (claim_success keccak _ v v' c sound ok).2.2.1
  obtain ⟨_, _, _, changed, _⟩ := reward_trace_facts trace start
  obtain ⟨r, member, id⟩ := changed _ (by rw [empty, stored]; exact nonzero)
  have recorded := reward_trace_storage trace start separation r member
  rw [id, stored] at recorded
  obtain ⟨sameId, sameRecipient, sameAmount⟩ :=
    commitment_binding keccak c.receipt r (commitmentSeparation r member) recorded
  exact ⟨r, member, sameId.symm, sameRecipient.symm, sameAmount.symm⟩

/-- Successful claims from one vault in order, with their receipts. -/
inductive ClaimTrace (keccak : List Byte → Word256) : Vault → List Receipt → Vault → Prop where
  | nil (v : Vault) : ClaimTrace keccak v [] v
  | cons {v v' final : Vault} {rest : List Receipt} (c : ClaimCall) (ok : claim keccak v c = .ok v')
      (tail : ClaimTrace keccak v' rest final) : ClaimTrace keccak v (c.receipt :: rest) final

/-- Claimed batch ids are pairwise distinct along any successful claim sequence. -/
theorem claim_trace_ids_distinct {keccak : List Byte → Word256} {v : Vault} {cs : List Receipt} {final : Vault}
    (trace : ClaimTrace keccak v cs final) :
    cs.Pairwise (fun a b => batchId keccak a ≠ batchId keccak b) ∧
    ∀ r ∈ cs, final.claimed (batchId keccak r) = true := by
  induction trace with
  | nil => simp
  | @cons v v' final rest c ok tail ih =>
    have s := claim_success keccak (fun id => if id = batchId keccak c.receipt then commitment keccak c.receipt else 0)
      v v' c (by intro _; simp) ok
    have marked : v'.claimed (batchId keccak c.receipt) = true := by rw [s.2.2.2.1]; simp
    have preserved : ∀ {u u' : Vault} {xs : List Receipt}, ClaimTrace keccak u xs u' →
        ∀ id, u.claimed id = true → u'.claimed id = true := by
      intro u u' xs t
      induction t with
      | nil => intro id h; exact h
      | cons c' ok' _ ih' => intro id h; exact ih' id ((claim_frame keccak _ _ c' ok').2.2.2.2 id h)
    refine ⟨List.Pairwise.cons ?_ ih.1, ?_⟩
    · intro later member same
      have laterPaid := ih.2 later member
      -- `later` was claimed after `v'` already marked this id, so its claim must have failed.
      have first : ∀ {u u' : Vault} {xs : List Receipt}, ClaimTrace keccak u xs u' →
          u.claimed (batchId keccak c.receipt) = true → ∀ y ∈ xs, batchId keccak y ≠ batchId keccak c.receipt := by
        intro u u' xs t
        induction t with
        | nil => simp
        | @cons u u₁ u₂ ys c' ok' t' ih' =>
          intro marked' y hy
          rcases List.mem_cons.mp hy with rfl | hy
          · intro eq
            obtain ⟨e, err⟩ := claim_once keccak u c' (by rw [eq]; exact marked')
            rw [ok'] at err; cases err
          · exact ih' ((claim_frame keccak _ _ c' ok').2.2.2.2 _ marked') y hy
      exact first tail marked later member same.symm
    · intro r member
      rcases List.mem_cons.mp member with rfl | member
      · exact preserved tail _ marked
      · exact ih.2 r member

/-- Total payouts of a claim sequence: the amounts of its receipts. -/
theorem claim_trace_payouts {keccak : List Byte → Word256} {v : Vault} {cs : List Receipt} {final : Vault}
    (trace : ClaimTrace keccak v cs final) :
    (final.payouts.map Transfer.wei).sum = (v.payouts.map Transfer.wei).sum + (cs.map fun r => r.amount.val).sum := by
  induction trace with
  | nil => simp
  | @cons v v' final rest c ok tail ih =>
    have s := claim_success keccak (fun id => if id = batchId keccak c.receipt then commitment keccak c.receipt else 0)
      v v' c (by intro _; simp) ok
    rw [ih, s.2.2.2.2.1]
    by_cases zero : c.receipt.amount.val = 0 <;> simp [zero]; omega

end Etna.Landing
