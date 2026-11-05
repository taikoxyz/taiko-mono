import EtnaModel.CurrentProtocol
import EtnaProofs.CurrentBlocks
import EtnaProofs.Landing
import EtnaProofs.CurrentCertificate

namespace Etna.Design.Current.Protocol

/-- Grid differences are divisible even when S is not an absolute multiple of K. -/
theorem offset_grid_difference {s k p h : Nat}
    (pg : Start.onGrid s k p = true) (hg : Start.onGrid s k h = true) : k ∣ h-p := by
  simp only [Start.onGrid,decide_eq_true_eq] at pg hg
  have d := Nat.dvd_sub (Nat.dvd_of_mod_eq_zero hg.2.2) (Nat.dvd_of_mod_eq_zero pg.2.2)
  have eq : (h-s)-(p-s) = h-p := by omega
  simpa only [eq] using d

/-- The raw cut leaf keeps the absolute height; only grid arithmetic uses offsets. -/
theorem offset_frontier_index {s k p c h : Nat}
    (pg : Start.onGrid s k p = true) (cg : Start.onGrid s k c = true)
    (hg : Start.onGrid s k h = true) (pc : p < c) (ch : c < h) :
    (c-p)/k-1 < gridCount k p h ∧ p+k*((c-p)/k-1+1) = c ∧ k*((c-p)/k-1+1) = c-p := by
  have dc := offset_grid_difference pg cg
  have dh := offset_grid_difference pg hg
  have positive : 0 < k := (of_decide_eq_true pg).1
  have ec : k*((c-p)/k) = c-p := Nat.mul_div_cancel' dc
  have eh : k*((h-p)/k) = h-p := Nat.mul_div_cancel' dh
  have apos : 0 < (c-p)/k := Nat.div_pos (Nat.le_of_dvd (by omega) dc) positive
  have altb : (c-p)/k < (h-p)/k := Nat.lt_of_mul_lt_mul_left (by rw [ec,eh]; omega)
  have succ : (c-p)/k-1+1 = (c-p)/k := by omega
  unfold gridCount
  refine ⟨by omega,?_,?_⟩
  · rw [succ,ec]; omega
  · rw [succ,ec]

theorem headerAt_hash_bound {env : Environment} {p : Header} {bs : List Block}
    (initial : HashBound env p) (hashes : ∀ b ∈ bs, HashBound env b.header) (n : Nat) :
    HashBound env (Blocks.headerAt p bs n) := by
  induction bs generalizing p n with
  | nil => simpa [Blocks.headerAt,Blocks.terminal] using initial
  | cons b rest ih =>
    cases n with
    | zero => exact initial
    | succ n =>
      exact ih (hashes b List.mem_cons_self) (fun c mem => hashes c (List.mem_cons_of_mem _ mem)) n

/-- Current checks and an independently certified complete batch determine the actual
execution-time suffix. No accepted transition takes a suffix as an input. -/
theorem accepted_suffix_from_certificate {env : Environment} {w t : World} {a : Landing}
    (ok : land env w a = some t) (cert : LiveCertifies env w (statement env w a))
    (record : recordAt w.inbox w.inbox.checkpoint.height = some w.inbox.checkpoint) :
    Nonempty (Suffix env w a) := by
  have check := (land_success ok).1
  obtain ⟨archive,p,bs,ready,valid,binding,hashp,hashes,_⟩ := cert
  have inputs := congrArg StatementData.input binding
  have parent : a.input.parentHeight = p.height := congrArg LandInput.parentHeight inputs
  have last : a.input.lastHeight = (Blocks.terminal p bs).height := congrArg LandInput.lastHeight inputs
  have lastHash : a.input.lastBlockHash = (Blocks.terminal p bs).elHash := congrArg LandInput.lastBlockHash inputs
  have lastComet : a.input.lastCometHash = (Blocks.terminal p bs).cometHash := congrArg LandInput.lastCometHash inputs
  have lastVal : a.input.lastValStateHash = (Blocks.terminal p bs).valStateHash :=
    congrArg LandInput.lastValStateHash inputs
  have lastRoot : a.input.lastStateRoot = (Blocks.terminal p bs).stateRoot := congrArg LandInput.lastStateRoot inputs
  have lastCursor : a.input.forcedInclusionHead = (Blocks.terminal p bs).cursor := congrArg LandInput.forcedInclusionHead inputs
  have leaves : a.leaves = gridLeaves w.inbox.gridK p.height (Blocks.terminal p bs).height (Blocks.cuts p bs) := by
    have h := congrArg (fun d : StatementData => d.cutHash.leaves) binding
    exact h
  have size := Blocks.chain_height valid.1
  have low : p.height ≤ w.inbox.checkpoint.height := parent ▸ check.parentBeforeFrontier
  have high : w.inbox.checkpoint.height < (Blocks.terminal p bs).height := last ▸ check.progress
  have bound : w.inbox.checkpoint.height-p.height ≤ bs.length := by omega
  let n := w.inbox.checkpoint.height-p.height
  let q := Blocks.headerAt p bs n
  have qheight : q.height = w.inbox.checkpoint.height := by
    have h := Blocks.headerAt_height valid.1 bound
    dsimp [q,n]
    rw [h]
    omega
  have cursor : w.inbox.checkpoint.cursor = w.inbox.head := by
    simpa [record] using check.cursor
  have qcut : q.cut =
      ⟨w.inbox.checkpoint.elHash,w.inbox.checkpoint.cometHash,w.inbox.head,w.inbox.checkpoint.valStateHash⟩ := by
    rw [Blocks.headerAt_cut p bs n bound]
    rcases Nat.lt_or_eq_of_le low with lt | eq
    · have frontier := check.frontier (by omega)
      rw [leaves,parent] at frontier
      obtain ⟨index,pos,off⟩ := offset_frontier_index
        (parent ▸ check.parentGrid) check.frontierGrid (last ▸ check.lastGrid) lt high
      rw [gridLeaves_getD _ _ _ _ _ index,pos,off] at frontier
      exact (Leaf.cut.inj frontier).2
    · have originEl := congrArg StatementData.parentHash binding
      have originComet := congrArg StatementData.parentCometHash binding
      have originVal := congrArg StatementData.parentValStateHash binding
      have originCursor := congrArg StatementData.headBefore binding
      have originRecord : recordAt w.inbox a.input.parentHeight = some w.inbox.checkpoint := by
        rw [parent,eq]; exact record
      simp only [statement,originRecord,Option.getD_some,Blocks.statement]
        at originEl originComet originVal originCursor
      have nz : n = 0 := by dsimp [n]; omega
      simp only [nz,Blocks.cuts,List.getD_cons_zero,BlockValidity.Header.cut]
      rw [← originEl,← originComet,← originVal,← originCursor,cursor]
  have qbound : HashBound env q := headerAt_hash_bound hashp hashes n
  have terminal := Blocks.suffix_terminal p bs n
  refine ⟨⟨archive,q,bs.drop n,?_,(Blocks.chain_suffix valid.1 n).2,qheight,qcut,?_,?_,?_,qbound,?_⟩⟩
  · simpa only [q,terminal] using ready
  · exact terminal ▸ last.symm
  · rw [terminal]
    exact congrArg (fun (x : Nat × Nat × Nat × Nat) => (⟨x.1,x.2.1,x.2.2.1,x.2.2.2⟩ : Cut))
      (show ((Blocks.terminal p bs).elHash,(Blocks.terminal p bs).cometHash,(Blocks.terminal p bs).cursor,
          (Blocks.terminal p bs).valStateHash) =
        (a.input.lastBlockHash,a.input.lastCometHash,a.input.forcedInclusionHead,a.input.lastValStateHash) from
        by rw [lastHash,lastComet,lastCursor,lastVal])
  · rw [terminal]; exact lastRoot.symm
  · intro b member
    exact hashes b (List.mem_of_mem_drop member)

end Etna.Design.Current.Protocol
