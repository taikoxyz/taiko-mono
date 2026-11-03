import EtnaProofs.CurrentSettlement

namespace Etna.Design.Current.Protocol

/-- The ordinary L1 frontier cut identifies a physical header in the actual full
hash-bound archive. No candidate cutoff or snapshot-order conclusion is a premise. -/
theorem accepted_certificate_checkpoint_split {env : Environment} {w t : World} {a : Landing}
    {archive : List Header} {p : Header} {bs : List Block}
    (ok : land env w a = some t)
    (cert : LiveBatchCertificate env w (statement env w a) archive p bs)
    (record : recordAt w.inbox w.inbox.checkpoint.height = some w.inbox.checkpoint) :
    ∃ root before after, root.height = (config w).originHeight ∧ archive = before ++ after ∧
      Archive.Linked env.headerParent root archive ∧
      (∀ h ∈ root :: archive, HashBound env h) ∧
      (Archive.terminal root before).height = w.inbox.checkpoint.height ∧
      (Archive.terminal root before).elHash = w.inbox.checkpoint.elHash := by
  have check := (land_success ok).1
  obtain ⟨ready,valid,binding,hashp,hashes,first,auth⟩ := cert
  have inputs := congrArg StatementData.input binding
  have parent : a.input.parentHeight = p.height := congrArg LandInput.parentHeight inputs
  have last : a.input.lastHeight = (Blocks.terminal p bs).height := congrArg LandInput.lastHeight inputs
  have lastHash : a.input.lastBlockHash = (Blocks.terminal p bs).elHash := congrArg LandInput.lastBlockHash inputs
  have lastComet : a.input.lastCometHash = (Blocks.terminal p bs).cometHash := congrArg LandInput.lastCometHash inputs
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
  have qcut : q.cut = ⟨w.inbox.checkpoint.elHash,w.inbox.checkpoint.cometHash,w.inbox.head⟩ := by
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
      have originCursor := congrArg StatementData.headBefore binding
      have originRecord : recordAt w.inbox a.input.parentHeight = some w.inbox.checkpoint := by
        rw [parent,eq]; exact record
      simp only [statement,originRecord,Option.getD_some,Blocks.statement] at originEl originComet originCursor
      have nz : n = 0 := by dsimp [n]; omega
      simp only [nz,Blocks.cuts,List.getD_cons_zero,BlockValidity.Header.cut]
      rw [← originEl,← originComet,← originCursor,cursor]
  obtain ⟨root,prior,rootHeight,_,rootBound,shape,priorTerminal,linked,archiveBound,_⟩ := auth
  let before := prior ++ (bs.take n).map Blocks.Block.header
  let after := (bs.drop n).map Blocks.Block.header
  have split : archive = before ++ after := by
    rw [shape]
    simp only [before,after,List.append_assoc,← List.map_append,List.take_append_drop]
  have frontier : Archive.terminal root before = q := by
    rw [Archive.terminal_append,priorTerminal,Archive.terminal_block_headers]
    rfl
  refine ⟨root,before,after,rootHeight,split,linked,?_,?_,?_⟩
  · intro h member
    rcases List.mem_cons.mp member with rfl | later
    · exact rootBound
    · exact archiveBound h later
  · rw [frontier]
    exact qheight
  · rw [frontier]
    exact congrArg Cut.elHash qcut

end Etna.Design.Current.Protocol
