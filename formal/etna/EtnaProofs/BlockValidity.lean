import EtnaModel.BlockValidity
import EtnaProofs.Consensus
import EtnaProofs.Landing
import EtnaProofs.Forced
import EtnaProofs.Encoding

/-! Proofs about `EtnaModel.BlockValidity`. -/
namespace Etna.Design.BlockValidity
open Consensus

theorem valid_parent_links {r : Rules} {p : Header} {b : Block} (ok : Valid r p b) :
    b.header.height = p.height+1 ∧ b.parentHash = p.elHash ∧
    b.lastBlockId = (if p.height = r.consensus.originHeight then none else some p.cometHash) :=
  ⟨ok.2.2.1.1,ok.2.2.1.2.1,ok.2.2.1.2.2.1⟩

theorem valid_header_rules {r : Rules} {p : Header} {b : Block} (ok : Valid r p b) :
    b.domain = r.consensus.domain ∧ b.generation = r.consensus.generation ∧
    b.feeShare = 100 ∧ b.blockBytes ≤ 124000 ∧
    b.parentBeaconRoot = b.header.anchor.stateRoot ∧
    b.validatorsHash = r.committeeHash (Consensus.activeAt r.consensus b.header.height) ∧
    b.nextValidatorsHash = r.committeeHash (Consensus.activeAt r.consensus (b.header.height+1)) ∧
    b.header.timestamp = max (max (p.timestamp+1) b.bftTime) b.header.anchor.timestamp := by
  rcases ok.2.2.1 with ⟨_,_,_,domain,generation,_,_,time,share,size,beacon,current,next⟩
  exact ⟨domain,generation,share,size,beacon,current,next,time⟩

theorem valid_anchor_rules {r : Rules} {p : Header} {b : Block} (ok : Valid r p b) :
    p.anchor.number ≤ b.header.anchor.number ∧ r.consensus.originBlock ≤ b.header.anchor.number ∧
    b.header.anchor.number ≤ r.referenceNumber ∧
    b.header.timestamp-b.header.anchor.timestamp ≤ r.maxAnchorAge ∧
    b.header.height-b.header.anchor.checkpointHeight ≤ r.unsettled ∧
    b.anchorWitness = decide (p.height = r.consensus.originHeight ∨ p.anchor.number ≠ b.header.anchor.number) := by
  rcases ok.2.2.2.1 with ⟨parent,origin,reference,_,_,_,age,pressure,_,_,witness,_,_⟩
  exact ⟨parent,origin,reference,age,pressure,witness⟩

theorem valid_switch_witness {r : Rules} {p : Header} {b : Block} (ok : Valid r p b)
    (switch : (b.header.height+1) % r.consensus.epochLen = 0) :
    ∃ w, b.committeeWitness = some w ∧
      w.record = Consensus.normal r.consensus ((b.header.height+1)/r.consensus.epochLen) ∧
      w.root = b.header.anchor.stateRoot ∧ w.record.cutoff ≤ b.header.anchor.number ∧
      Consensus.ElectionValid r.consensus w.record := by
  have witness := ok.2.2.2.2.1
  unfold WitnessValid at witness
  simp only [switch,ite_true] at witness
  cases hw : b.committeeWitness with
  | none => simp [hw] at witness
  | some w =>
    simp only [hw] at witness
    exact ⟨w,rfl,witness.1,witness.2.1,witness.2.2.1,witness.2.2.2.2⟩

theorem valid_commit {r : Rules} {p : Header} {b : Block} (ok : Valid r p b) :
    Consensus.CommitValid r.consensus r.signature b.header.height b.round b.header.cometHash b.votes := ok.2.2.2.2.2.1

theorem valid_cursor_step {r : Rules} {p : Header} {b : Block} (ok : Valid r p b) :
    p.cursor ≤ b.header.cursor ∧ b.header.cursor ≤ p.cursor+1 := by
  have step := Forced.step_one_or_zero ok.2.2.2.2.2.2.1
  rcases step with h | h <;> omega

/-- Two valid blocks over proof origins at the same height see the same origin anchor: the
origin anchor is fixed by authenticated history, not chosen by the prover. -/
theorem proof_origin_anchor_fixed {r : Rules} {p q : Header} {b c : Block}
    (okB : Valid r p b) (okC : Valid r q c) (same : p.height = q.height) : p.anchor.number = q.anchor.number := by
  have fromB := okB.2.2.2.1.2.2.2.2.2.2.2.2.2.1
  have fromC := okC.2.2.2.1.2.2.2.2.2.2.2.2.2.1
  rw [← fromB,← fromC,same]

/-- Along a valid chain anchors never decrease, never drop below the generation's fixed
origin block or the proof origin's authenticated anchor, never pass the reference block,
and every anchor is the authenticated history value at its height. -/
theorem chain_anchor_window {r : Rules} {p : Header} {bs : List Block} (ok : Chain r p bs) :
    (∀ b ∈ bs, p.anchor.number ≤ b.header.anchor.number ∧ r.consensus.originBlock ≤ b.header.anchor.number ∧
      b.header.anchor.number ≤ r.referenceNumber ∧ r.consensus.anchorAt b.header.height = b.header.anchor.number) ∧
    (bs.map (fun b => b.header.anchor.number)).Pairwise (· ≤ ·) := by
  induction bs generalizing p with
  | nil => simp
  | cons b rest ih =>
    have anchor := ok.1.2.2.2.1
    have later := ih ok.2
    refine ⟨?_,List.pairwise_cons.mpr ⟨?_,later.2⟩⟩
    · intro x mem
      rcases List.mem_cons.mp mem with rfl | tail
      · exact ⟨anchor.1,anchor.2.1,anchor.2.2.1,anchor.2.2.2.2.2.2.2.2.1⟩
      · have bound := later.1 x tail
        exact ⟨Nat.le_trans anchor.1 bound.1,bound.2.1,bound.2.2.1,bound.2.2.2⟩
    · intro n mem
      obtain ⟨x,tail,rfl⟩ := List.mem_map.mp mem
      exact (later.1 x tail).1

/-- EL timestamps strictly increase from the proof origin along a valid chain and never
precede the block's anchor timestamp, whose age stays within maxAnchorAge. -/
theorem chain_timestamps_increase {r : Rules} {p : Header} {bs : List Block} (ok : Chain r p bs) :
    (∀ b ∈ bs, p.timestamp < b.header.timestamp ∧ b.header.anchor.timestamp ≤ b.header.timestamp ∧
      b.header.timestamp-b.header.anchor.timestamp ≤ r.maxAnchorAge) ∧
    (bs.map (fun b => b.header.timestamp)).Pairwise (· < ·) := by
  induction bs generalizing p with
  | nil => simp
  | cons b rest ih =>
    have time := ok.1.2.2.1.2.2.2.2.2.2.2.1
    have parent : p.timestamp < b.header.timestamp := by
      rw [time]
      exact Nat.lt_of_lt_of_le (Nat.lt_succ_self _)
        (Nat.le_trans (Nat.le_max_left _ _) (Nat.le_max_left _ _))
    have anchor := ok.1.2.2.2.1
    have later := ih ok.2
    refine ⟨?_,List.pairwise_cons.mpr ⟨?_,later.2⟩⟩
    · intro x mem
      rcases List.mem_cons.mp mem with rfl | tail
      · exact ⟨parent,anchor.2.2.2.2.2.1,anchor.2.2.2.2.2.2.1⟩
      · have bound := later.1 x tail
        exact ⟨Nat.lt_trans parent bound.1,bound.2.1,bound.2.2⟩
    · intro n mem
      obtain ⟨x,tail,rfl⟩ := List.mem_map.mp mem
      exact (later.1 x tail).1

/-- Every parent hash on a valid chain is the EL hash of the preceding header, starting at
the proof origin: the batch is one hash-linked EL chain. -/
theorem chain_parent_hashes {r : Rules} {p : Header} {bs : List Block} (ok : Chain r p bs) :
    bs.map Block.parentHash = ((p :: bs.map Block.header).dropLast).map Header.elHash := by
  induction bs generalizing p with
  | nil => rfl
  | cons b rest ih =>
    have link := ok.1.2.2.1.2.1
    have tail := ih ok.2
    cases rest with
    | nil => simp [link]
    | cons c more =>
      simp only [List.map_cons,List.dropLast_cons_cons] at tail ⊢
      rw [link,tail]

/-- On a valid chain, a block has an empty Comet LastBlockID exactly when it is the first
block of its generation; every other block names its parent's Comet hash. -/
theorem chain_last_block_ids {r : Rules} {p : Header} {bs : List Block} (ok : Chain r p bs) :
    ∀ b ∈ bs, (b.lastBlockId = none ↔ b.header.height = r.consensus.originHeight+1) ∧
      (b.header.height ≠ r.consensus.originHeight+1 → ∃ comet, b.lastBlockId = some comet) := by
  induction bs generalizing p with
  | nil => simp
  | cons b rest ih =>
    intro x mem
    rcases List.mem_cons.mp mem with rfl | tail
    · have height := ok.1.2.2.1.1
      have lastId := ok.1.2.2.1.2.2.1
      have floor := ok.1.2.1
      by_cases first : p.height = r.consensus.originHeight
      · rw [lastId,ite_eq_left first]
        exact ⟨⟨fun _ => by omega,fun _ => rfl⟩,fun other => absurd (by omega) other⟩
      · rw [lastId,ite_eq_right first]
        exact ⟨⟨fun h => by simp at h,fun _ => absurd (by omega) first⟩,fun _ => ⟨_,rfl⟩⟩
    · exact ih ok.2 x tail

/-- The switch block's witnessed committee is exactly the authority two heights later
(H+2): the witness record, its anchor root and its election become the next epoch's
active committee, because a valid block always lies above the generation origin. -/
theorem valid_switch_witness_activates {r : Rules} {p : Header} {b : Block} (ok : Valid r p b)
    (switch : (b.header.height+1) % r.consensus.epochLen = 0) :
    ∃ w, b.committeeWitness = some w ∧ w.record = Consensus.activeAt r.consensus (b.header.height+2) ∧
      w.root = b.header.anchor.stateRoot ∧ w.record.cutoff ≤ b.header.anchor.number ∧
      Consensus.ElectionValid r.consensus (Consensus.activeAt r.consensus (b.header.height+2)) := by
  obtain ⟨w,some,record,root,cutoff,elected⟩ := valid_switch_witness ok switch
  have config := of_decide_eq_true ok.1
  have positive : 0 < r.consensus.epochLen := by omega
  have height := ok.2.2.1.1
  have floor := ok.2.1
  have exact : (b.header.height+1)/r.consensus.epochLen*r.consensus.epochLen = b.header.height+1 :=
    Nat.div_mul_cancel (Nat.dvd_of_mod_eq_zero switch)
  have occurred : r.consensus.originHeight <
      Consensus.switchHeight r.consensus ((b.header.height+1)/r.consensus.epochLen) := by
    unfold Consensus.switchHeight
    omega
  have active := Consensus.active_at_handover r.consensus ((b.header.height+1)/r.consensus.epochLen) positive occurred
  rw [exact] at active
  rw [show b.header.height+2 = b.header.height+1+1 by omega,active]
  exact ⟨w,some,record,root,cutoff,record ▸ elected⟩

theorem chain_height {r : Rules} {p : Header} {bs : List Block} (ok : Chain r p bs) :
    (terminal p bs).height = p.height+bs.length := by
  induction bs generalizing p with
  | nil => simp [terminal]
  | cons b rest ih =>
    have height := (valid_parent_links ok.1).1
    have tail := ih ok.2
    simp only [terminal,List.length_cons]
    omega

theorem cuts_length (p : Header) (bs : List Block) : (cuts p bs).length = bs.length+1 := by
  simp [cuts]

theorem cuts_origin (p : Header) (bs : List Block) : (cuts p bs).head? = some p.cut := rfl

theorem cuts_terminal (p : Header) (bs : List Block) : (cuts p bs).getLast? = some (terminal p bs).cut := by
  induction bs generalizing p with
  | nil => rfl
  | cons b rest ih =>
    simpa only [cuts,List.map_cons,List.getLast?_cons_cons,terminal] using ih b.header

theorem chain_cursor_steps {r : Rules} {p : Header} {bs : List Block} (ok : Chain r p bs) :
    cursorSteps (cuts p bs) = true := by
  induction bs generalizing p with
  | nil => rfl
  | cons b rest ih =>
    have step := valid_cursor_step ok.1
    change decide (p.cursor ≤ b.header.cursor ∧ b.header.cursor ≤ p.cursor+1) &&
      cursorSteps (cuts b.header rest) = true
    simp only [Bool.and_eq_true,decide_eq_true_eq]
    exact ⟨step,ih ok.2⟩

theorem chain_commits {r : Rules} {p : Header} {bs : List Block} (ok : Chain r p bs) :
    ∀ b ∈ bs, Consensus.CommitValid r.consensus r.signature b.header.height b.round b.header.cometHash b.votes := by
  induction bs generalizing p with
  | nil => simp
  | cons b rest ih =>
    intro x mem
    rcases List.mem_cons.mp mem with rfl | later
    · exact valid_commit ok.1
    · exact ih ok.2 x later

end Etna.Design.BlockValidity
