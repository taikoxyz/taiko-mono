module
public import Etna.Integration.Composition
public import Etna.Landing.Claim
@[expose] public section
namespace Etna.Integration

/-- Claims with pairwise-distinct keys, each matched by a recorded receipt with the same key
and amount, pay at most the recorded total. The recorded list need not be distinct. -/
theorem matched_sum_le (key : Landing.Receipt → Word256) (amount : Landing.Receipt → Nat) :
    ∀ (cs rs : List Landing.Receipt), cs.Pairwise (fun a b => key a ≠ key b) →
      (∀ c ∈ cs, ∃ r ∈ rs, key r = key c ∧ amount r = amount c) →
      (cs.map amount).sum ≤ (rs.map amount).sum := by
  intro cs
  induction cs with
  | nil => simp
  | cons c cs ih =>
    intro rs distinct matched
    obtain ⟨r, member, sameKey, sameAmount⟩ := matched c List.mem_cons_self
    have perm := List.perm_cons_erase member
    have split : (rs.map amount).sum = amount r + ((rs.erase r).map amount).sum := by
      rw [(perm.map amount).sum_eq]; simp
    have rest : (cs.map amount).sum ≤ ((rs.erase r).map amount).sum := by
      apply ih _ (List.pairwise_cons.mp distinct).2
      intro c' member'
      obtain ⟨r', member'', key', amount'⟩ := matched c' (List.mem_cons_of_mem _ member')
      have different : r' ≠ r := by
        intro same
        apply (List.pairwise_cons.mp distinct).1 c' member'
        rw [← sameKey, ← same, key']
      exact ⟨r', (List.mem_erase_of_ne different).mpr member'', key', amount'⟩
    simp only [List.map_cons, List.sum_cons]
    omega

/-- CLAIM-04: across any landed cuts and any sequence of successful L2 claims whose receipts
are recorded ones (CLAIM-03 supplies this per claim), the vault pays out at most the treasury
credits of the landed blocks: reward claims never exceed credited base fees. -/
theorem claims_bounded_by_credits {ctx : Committee.Context} {a : Authentication ctx}
    {keccak : List Landing.Byte → Word256}
    {w before parts consumed updates final after paid receipts}
    (cuts : LandedCuts a keccak w before parts consumed updates final after paid receipts)
    {v v' : Landing.Vault} {cs : List Landing.Receipt} (claims : Landing.ClaimTrace keccak v cs v')
    (recorded : ∀ c ∈ cs, ∃ r ∈ receipts,
      Landing.batchId keccak r = Landing.batchId keccak c ∧ r.amount = c.amount) :
    (v'.payouts.map Landing.Transfer.wei).sum ≤ (v.payouts.map Landing.Transfer.wei).sum + credits a parts.flatten := by
  rw [Landing.claim_trace_payouts claims, ← (landed_cuts_rewards cuts).2]
  have bound := matched_sum_le (Landing.batchId keccak) (fun r => r.amount.val) cs receipts
    (Landing.claim_trace_ids_distinct claims).1
    (fun c member => by
      obtain ⟨r, m, k, am⟩ := recorded c member
      exact ⟨r, m, k, by rw [am]⟩)
  omega

end Etna.Integration
