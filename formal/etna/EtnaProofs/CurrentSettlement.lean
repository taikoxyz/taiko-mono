import EtnaModel.CurrentProtocol
import EtnaProofs.CurrentBlocks
import EtnaProofs.Landing
import EtnaProofs.CurrentCertificate

namespace Etna.Design.Current.Protocol

/-- The leaf at the frontier keeps the absolute height; its index is c-p-1. -/
theorem frontier_index {p c h : Nat} (pc : p < c) (ch : c < h) :
    c-p-1 < h-p-1 ∧ p+(c-p-1+1) = c ∧ c-p-1+1 = c-p := by
  omega

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
  have lastRoot : a.input.lastStateRoot = (Blocks.terminal p bs).stateRoot := congrArg LandInput.lastStateRoot inputs
  have lastCursor : a.input.forcedInclusionHead = (Blocks.terminal p bs).cursor := congrArg LandInput.forcedInclusionHead inputs
  have leaves : a.leaves = innerLeaves p.height (Blocks.terminal p bs).height (Blocks.cuts p bs) := by
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
      ⟨w.inbox.checkpoint.elHash,w.inbox.checkpoint.cometHash,w.inbox.head⟩ := by
    rw [Blocks.headerAt_cut p bs n bound]
    rcases Nat.lt_or_eq_of_le low with lt | eq
    · have frontier := check.frontier (by omega)
      rw [leaves,parent] at frontier
      obtain ⟨index,pos,off⟩ := frontier_index lt high
      rw [innerLeaves_getD _ _ _ _ index,pos,off] at frontier
      exact (Leaf.cut.inj frontier).2
    · have originEl := congrArg StatementData.parentHash binding
      have originComet := congrArg StatementData.parentCometHash binding
      have originCursor := congrArg StatementData.headBefore binding
      have originRecord : recordAt w.inbox a.input.parentHeight = some w.inbox.checkpoint := by
        rw [parent,eq]; exact record
      simp only [statement,originRecord,Option.getD_some,Blocks.statement]
        at originEl originComet originCursor
      have nz : n = 0 := by dsimp [n]; omega
      simp only [nz,Blocks.cuts,List.getD_cons_zero,BlockValidity.Header.cut]
      rw [← originEl,← originComet,← originCursor,cursor]
  have qbound : HashBound env q := headerAt_hash_bound hashp hashes n
  have terminal := Blocks.suffix_terminal p bs n
  refine ⟨⟨archive,q,bs.drop n,?_,(Blocks.chain_suffix valid.1 n).2,qheight,qcut,?_,?_,?_,qbound,?_⟩⟩
  · simpa only [q,terminal] using ready
  · exact terminal ▸ last.symm
  · rw [terminal]
    exact congrArg (fun (x : Nat × Nat × Nat) => (⟨x.1,x.2.1,x.2.2⟩ : Cut))
      (show ((Blocks.terminal p bs).elHash,(Blocks.terminal p bs).cometHash,(Blocks.terminal p bs).cursor) =
        (a.input.lastBlockHash,a.input.lastCometHash,a.input.forcedInclusionHead) from
        by rw [lastHash,lastComet,lastCursor])
  · rw [terminal]; exact lastRoot.symm
  · intro b member
    exact hashes b (List.mem_of_mem_drop member)

/-- LAND-6.1-5, ENC-A-31/32: a landing of the single block p+1 carries no leaves, every honest
cut table gives the same empty inner list (keccak256("") on L1), and `land` accepts it whenever
the checks that do not read the leaves pass. -/
theorem land_single_block {env : Environment} {w : World} {a : Landing}
    (single : a.input.lastHeight = a.input.parentHeight+1) (empty : a.leaves = [])
    (initialized : w.initialized = true) (started : w.start.isSome = true)
    (entered : w.inbox.entered = false) (origin : w.inbox.origin.height ≤ a.input.parentHeight)
    (parentBeforeFrontier : a.input.parentHeight ≤ w.inbox.checkpoint.height)
    (progress : w.inbox.checkpoint.height < a.input.lastHeight) (height : a.input.lastHeight < limit48)
    (batchSize : a.input.lastHeight-a.input.parentHeight ≤ w.inbox.maxBatchBlocks)
    (record : (recordAt w.inbox a.input.parentHeight).isSome = true)
    (generation : ((recordAt w.inbox a.input.parentHeight).getD default).generation = w.inbox.generation ∨
      a.input.parentHeight = w.inbox.origin.height)
    (cursor : ((recordAt w.inbox w.inbox.checkpoint.height).getD default).cursor = w.inbox.head)
    (head : w.inbox.head ≤ a.input.forcedInclusionHead) (tail : a.input.forcedInclusionHead ≤ w.inbox.tail)
    (service : a.input.forcedInclusionHead-w.inbox.head ≤ a.input.lastHeight-w.inbox.checkpoint.height)
    (reference : a.input.l1ReferenceBlockNumber < w.number)
    (referenceAge : w.number-a.input.l1ReferenceBlockNumber ≤ 8191)
    (referenceReadable : referenceHash env w a.input.l1ReferenceBlockNumber ≠ 0)
    (blobs : 1 ≤ a.blobs.length ∧ a.blobs.length ≤ 6) (unzen : firstFence env w = true)
    (proofs : proofsAccepted env w a = true) :
    (∀ table, innerLeaves a.input.parentHeight a.input.lastHeight table = a.leaves) ∧
      land env w a = some (landed w a) := by
  refine ⟨fun table => by simp [innerLeaves,single,empty],?_⟩
  have checks : LandingChecks env w a :=
    { initialized,started,entered,origin,parentBeforeFrontier,progress,height,batchSize,record,generation,
      leafCount := by rw [empty,single]; simp,
      frontier := fun lt => absurd lt (by omega),
      cursor,head,tail,service,reference,referenceAge,referenceReadable,blobs,unzen,proofs }
  simp only [land,checks,↓reduceIte]

/-- LAND-6.1-4/7/8, BATCH-6.3-10: after a competing landing moves c to p+1, the original
transaction's leaf checks still pass. Its leaf count h-p-1 does not depend on c, and the check at
c reads leaf index c-p-1 = 0, which the honest list fills with cutLeaf(p+1); it passes whenever
c's slot 285 record and the FI head match the batch's cut at p+1. -/
theorem land_overlap_at_p_succ {w : World} {a : Landing} {table : List Cut}
    (honest : a.leaves = innerLeaves a.input.parentHeight a.input.lastHeight table)
    (moved : w.inbox.checkpoint.height = a.input.parentHeight+1)
    (below : w.inbox.checkpoint.height < a.input.lastHeight)
    (recorded : table.getD 1 default = ⟨w.inbox.checkpoint.elHash,w.inbox.checkpoint.cometHash,w.inbox.head⟩) :
    w.inbox.checkpoint.height-a.input.parentHeight-1 = 0 ∧
      a.leaves.length = a.input.lastHeight-a.input.parentHeight-1 ∧
      (a.input.parentHeight < w.inbox.checkpoint.height →
        a.leaves.getD (w.inbox.checkpoint.height-a.input.parentHeight-1) default =
          cutLeaf w.inbox.checkpoint.height
            ⟨w.inbox.checkpoint.elHash,w.inbox.checkpoint.cometHash,w.inbox.head⟩) := by
  have index : w.inbox.checkpoint.height-a.input.parentHeight-1 = 0 := by omega
  refine ⟨index,by simp [honest,innerLeaves],fun _ => ?_⟩
  have room : 0 < a.input.lastHeight-a.input.parentHeight-1 := by omega
  rw [index,honest,innerLeaves_getD _ _ _ _ room,recorded,moved]

end Etna.Design.Current.Protocol
