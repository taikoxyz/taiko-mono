import EtnaModel.Budget
import EtnaProofs.Landing

/-! Proofs about `EtnaModel.Budget`. -/
namespace Etna.Design.Budget

theorem cap_derivation :
    blobUsable = 125948 ∧ blobUsable-headerFrame-16 = 124908 ∧ blockCap ≤ blobUsable-headerFrame-16 := by
  decide

theorem stored_monotone {a b : Nat} (le : a ≤ b) : storedSize a ≤ storedSize b := by
  have : (a+storedBlock-1)/storedBlock ≤ (b+storedBlock-1)/storedBlock :=
    Nat.div_le_div_right (by omega)
  simp only [storedSize]
  omega

/-- Any valid block, with at most 1,024 bytes of framing, fits one blob as stored
zlib: every decided block can be landed alone. -/
theorem single_block_one_blob {b f : Nat} (block : b ≤ blockCap) (frame : f ≤ headerFrame) :
    storedSize (f+b) ≤ blobUsable := by
  have := stored_monotone (show f+b ≤ headerFrame+blockCap by omega)
  have bound : storedSize (headerFrame+blockCap) = 125040 := by decide
  have usable : blobUsable = 125948 := by decide
  omega

/-- m maximal blocks (1 ≤ m ≤ 6) fit an m-blob landing even if every blob loses 4 KiB;
in particular one six-blob landing holds six maximal blocks. -/
theorem blocks_fit_blobs {m len : Nat} (pos : 1 ≤ m) (cap : m ≤ 6)
    (size : len ≤ m*(blockCap+headerFrame)) : storedSize len ≤ m*blobUsable := by
  have mono := stored_monotone size
  have table : ∀ k, 1 ≤ k → k ≤ 6 → storedSize (k*(blockCap+headerFrame)) ≤ k*blobUsable := by
    intro k lo hi
    have : k = 1 ∨ k = 2 ∨ k = 3 ∨ k = 4 ∨ k = 5 ∨ k = 6 := by omega
    rcases this with rfl | rfl | rfl | rfl | rfl | rfl <;> decide
  exact Nat.le_trans mono (table m pos cap)

/-- The single-block payload `0x06 ‖ stored zlib` stays within one blob's usable bytes,
so the lander's stored fallback threshold (125,948 bytes) is always met. -/
theorem stored_fallback_fits {b f : Nat} (block : b ≤ blockCap) (frame : f ≤ headerFrame) :
    1+storedSize (f+b) ≤ blobUsable := by
  have := stored_monotone (show f+b ≤ headerFrame+blockCap by omega)
  have bound : storedSize (headerFrame+blockCap) = 125040 := by decide
  have usable : blobUsable = 125948 := by decide
  omega

/-- 6.3 grid costs: B/K − 1 leaves of 32 bytes. For 300 blocks, 99 leaves (3,168 bytes) at
K = 3 and 49 (1,568 bytes) at K = 6; a 3,600-block catch-up at K = 6 is 599 leaves (19,168
bytes); the shortest landing (h = p+K) carries none. -/
theorem grid_calldata_examples :
    gridCount 3 0 300 = 99 ∧ 32*gridCount 3 0 300 = 3168 ∧
    gridCount 6 0 300 = 49 ∧ 32*gridCount 6 0 300 = 1568 ∧
    gridCount 6 0 3600 = 599 ∧ 32*gridCount 6 0 3600 = 19168 ∧
    gridCount 3 0 3 = 0 ∧ gridCount 6 0 6 = 0 := by
  decide

/-- For every allowed K ≤ 6, a grid segment of K maximal blocks, as `0x06 ‖ stored zlib`, fits
the K ≤ 6 blobs of one landing (at K = 6: 750,211 ≤ 755,688 bytes). -/
theorem grid_segment_fits_one_landing {k len : Nat} (range : GridRange k)
    (size : len ≤ k*(blockCap+headerFrame)) : 1+storedSize len ≤ k*blobUsable := by
  have mono := stored_monotone size
  have bound : 1+storedSize (k*(blockCap+headerFrame)) ≤ k*blobUsable := by
    have : k = 1 ∨ k = 2 ∨ k = 3 ∨ k = 4 ∨ k = 5 ∨ k = 6 := by unfold GridRange at range; omega
    rcases this with rfl | rfl | rfl | rfl | rfl | rfl <;> decide
  omega

/-- A lander waits at most K − 1 blocks for the next grid point. -/
theorem next_grid_point_within (k x : Nat) (kpos : 0 < k) :
    (x+(k-x%k)%k) % k = 0 ∧ (k-x%k)%k ≤ k-1 := by
  have r := Nat.mod_lt x kpos
  have dm := Nat.div_add_mod x k
  refine ⟨?_, by have := Nat.mod_lt (k-x%k) kpos; omega⟩
  by_cases h0 : x % k = 0
  · rw [h0, Nat.sub_zero, Nat.mod_self, Nat.add_zero, h0]
  · rw [Nat.mod_eq_of_lt (by omega : k-x%k < k)]
    have e : x+(k-x%k) = k*(x/k+1) := by rw [Nat.mul_add, Nat.mul_one]; omega
    rw [e, Nat.mul_mod_right]

/-- Settling to the last provable grid point leaves at most K − 1 provable blocks behind (8.1). -/
theorem last_grid_point_within (k x : Nat) (kpos : 0 < k) : (x-x%k) % k = 0 ∧ x-(x-x%k) ≤ k-1 := by
  have r := Nat.mod_lt x kpos
  have dm := Nat.div_add_mod x k
  have e : x-x%k = k*(x/k) := by omega
  rw [e, Nat.mul_mod_right]
  omega

/-- §6.4 / appendix C arithmetic at 4 s blocks and 12 s slots: U = 3,600 is 4 h; the
20+20+20 min operating budget is 900 blocks, leaving 2,700 blocks (3 h) of margin;
15 blocks/min, 300 per 20 min batch; for K dividing 6, six-block six-blob landings are 150
per hour, i.e. 3 blobs per L1 slot (`data_worst_case_landing_rate` covers other K). -/
theorem schedule_arithmetic :
    3600*4 = 4*3600 ∧ (20+20+20)*60/4 = 900 ∧ (3600-900)*4 = 3*3600 ∧ 60/4 = 15 ∧
    20*60/4 = 300 ∧ 3600/4/6 = 150 ∧ 6*150*12/3600 = 3 := by decide

/-- Appendix C data worst case for every allowed K: a landing of data-full blocks holds the
largest multiple of K that fits six blobs, 6 − 6 % K blocks, so at 900 blocks per hour there
are 150 landings at K ∈ {1, 2, 3, 6}, 225 at K = 4 and 180 at K = 5. -/
theorem data_worst_case_landing_rate :
    ((List.range 6).map fun j => 900/(6-6%(j+1))) = [150,150,150,225,180,150] := by decide

end Etna.Design.Budget
