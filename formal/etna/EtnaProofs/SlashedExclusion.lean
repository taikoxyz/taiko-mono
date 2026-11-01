import EtnaProofs.SigningEscrow

/-! §12 item 19 (spec L626): "no selection snapshot at or after the slashing block includes the
entry". Double-sign slashing (4.1, spec L161) zeroes the entry's principal and sets
exitEffectiveL1 to at most the slashing block, and an entry is eligible only while the snapshot
is below exitEffectiveL1 (4.3, spec L179). So a slashed member keeps voting power only in
committees selected from snapshots before the slash: from the first committee whose cutoff is at
or after the slashing block, its key is absent, in every later World, also after its slot is
released and reused. -/
namespace Etna.Design.SigningEscrow
open ProtocolState

/-- A key that occurs once among the allocated entries is excluded at its own exit. -/
private theorem slashed_excluded_of_unique {r : RegistryHistory.State} {id : Nat}
    (keys : KeysWellFormed r) (range : id < r.nextId) (nonzero : (r.slots id).key ≠ 0) :
    Excluded (r.slots id).key (r.slots id).exitAt r := by
  intro other bound identity
  have same := keys.unique _ nonzero other bound id range identity rfl
  subst other
  exact Nat.le_refl _

/-- A successful double-sign slash at L1 block `now` leaves the entry no principal, and its key
is absent from every committee whose selection cutoff is at or after `now`, in every World
reached afterwards and in every context built there. The trace starts from a registry with
unique keys and visible exits, as in `confirmed_key_absent_above_checkpoint`; `now` fits the
48-bit exitEffectiveL1 field. Committees selected before the slash are not covered: they keep
the member's power (§12 item 19). -/
theorem slashed_key_absent_from_later_committees {initial w t : World} {id now : Nat}
    {a b : Staking.Vote} {sigA sigB : Hash} {s : RegistryHistory.State}
    {cfg : HistoricalContext.Parameters} {archive : List Nat} {ctx : Consensus.Context} {h : Nat}
    (prior : Trace initial w) (core : Core initial) (keys : KeysWellFormed initial.registry)
    (visible : ExitVisible initial.registry) (time : w.l1Block ≤ now) (bounded : now < Staking.noExit)
    (slashed : RegistryHistory.edit w.registry w.inbox id now (.slash a b sigA sigB) = some s)
    (nonzero : (w.registry.slots id).key ≠ 0) (suffix : Trace (registered w s now) t)
    (built : HistoricalContext.build t.inbox t.registry cfg archive = some ctx)
    (later : now ≤ (Consensus.activeAt ctx h).cutoff) :
    (s.slots id).balance = 0 ∧ ∀ m ∈ (Consensus.activeAt ctx h).members, m.key ≠ (w.registry.slots id).key := by
  obtain ⟨_,_,_,_,_,_,_,sameKey,exitBound⟩ := RegistryHistory.edit_slash_double_sign slashed
  have range : id < s.nextId := by
    obtain ⟨bound,_,_,_,rfl⟩ := RegistryHistory.edit_success slashed
    exact bound
  have reached : Trace initial (registered w s now) := .step prior (.modification time rfl slashed)
  have keyNonzero : (s.slots id).key ≠ 0 := by rw [sameKey]; exact nonzero
  have finite : (s.slots id).exitAt ≠ Staking.noExit := by omega
  have keysNow : KeysWellFormed s := trace_keys_well_formed reached keys
  have history : HistoryExcluded (s.slots id).key (s.slots id).exitAt s :=
    trace_exit_visible reached core keys visible id range keyNonzero finite
  have carried := trace_history_excluded suffix keyNonzero (keysNow.allocated id range keyNonzero)
    (slashed_excluded_of_unique keysNow range keyNonzero) history
  refine ⟨RegistryHistory.edit_slash_balance slashed,?_⟩
  rw [← sameKey]
  exact selected_excludes_confirmed_key built carried (Nat.le_trans exitBound later)

end Etna.Design.SigningEscrow
