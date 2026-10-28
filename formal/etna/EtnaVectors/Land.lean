import EtnaVectors.Machine

/-! `land` vectors with a verifier that accepts every proof: range and grid (K = 6),
maxBatchBlocks, the origin record and its generation, the FI head bounds, the leaf count and
the frontier leaf, the reference block and the blob count. Eight entries are queued first. -/
namespace Etna.Vectors
open Etna.Design

/-- c = 0, FI head 0, tail 8. -/
def landS0 : List CaseStep := fill 8
/-- c = 12 (records at 0, 6, 12), FI head 2. -/
def landS1 : List CaseStep := fill 8 ++ [landTo 6 1, landTo 12 1]
/-- Generation 1 starts at 12; c = 18 (a generation-1 record), FI head 3. -/
def landS2 : List CaseStep := landS1 ++ [recoverNow, landTo 18 1]
/-- Generation 2 starts at 18. -/
def landS3 : List CaseStep := landS2 ++ [recoverNow]
/-- Generations 1 and 2 both start at 12. -/
def landS4 : List CaseStep := landS1 ++ [recoverNow, recoverNow]

/-- Land (p, h] of the current generation's chain at the next block, keeping the FI head and
snapshot. -/
def landFrom (p h : Nat) : CaseStep := fun w =>
  let b := w.l1Block+1
  let s := w.inbox
  ⟨b, .land (chainInput s p h s.head s.snapshot b) (chainLeaves s p h) true 1 true⟩

def landCase (label : String) (setup : List CaseStep) (call : CaseStep) (deploy : Deploy := {})
    (spec : Option String := none) : Scenario :=
  { label := label, spec := spec, deploy := deploy, setup := setup, call := call }

def rangeGrid : List Scenario :=
  [("c0", landS0, 0), ("c12", landS1, 12), ("c18-generation1", landS2, 18)].flatMap fun (sn, setup, c) =>
    (([18, 12, 6, 3, 0].filter (· ≤ c)).map (c - ·)).flatMap fun p =>
      [0, 3, 6, 12, 18, 24].map fun dh =>
        landCase ("land.range." ++ sn ++ ".p" ++ Nat.repr p ++ ".h" ++ Nat.repr (c+dh)) setup (landFrom p (c+dh))

def headGrid : List Scenario :=
  [("c0", landS0, [0, 1, 6, 7]), ("c12", landS1, [1, 2, 8, 9])].flatMap fun (sn, setup, heads) =>
    heads.map fun hd =>
      landCase ("land.fi-head." ++ sn ++ ".head" ++ Nat.repr hd) setup fun w =>
        let b := w.l1Block+1
        let s := w.inbox
        let c := s.checkpoint.height
        ⟨b, .land (chainInput s c (c+6) hd s.snapshot b) (chainLeaves s c (c+6)) true 1 true⟩

/-- (0, 18] from c = 12: two leaves, at 6 and at the frontier 12. -/
def leafCase (name : String) (edit : State → List Leaf → List Leaf) : Scenario :=
  landCase ("land.leaves." ++ name) landS1 fun w =>
    let b := w.l1Block+1
    let s := w.inbox
    ⟨b, .land (chainInput s 0 18 s.head s.snapshot b) (edit s (chainLeaves s 0 18)) true 1 true⟩

def leafGrid : List Scenario := [
  leafCase "honest" fun _ ls => ls,
  leafCase "one-missing" fun _ ls => ls.take 1,
  leafCase "one-extra" fun s ls => ls ++ [.word (wordAtom s.generation 18)],
  leafCase "frontier-word" fun s ls => ls.set 1 (.word (wordAtom s.generation 12)),
  leafCase "frontier-wrong-head" fun s ls => ls.set 1 (cutLeaf 12 ⟨elAtom 0 12, cometAtom 0 12, s.head+1⟩),
  leafCase "frontier-wrong-el-hash" fun s ls => ls.set 1 (cutLeaf 12 ⟨elAtom 0 12+1, cometAtom 0 12, s.head⟩),
  leafCase "frontier-wrong-height" fun s ls => ls.set 1 (cutLeaf 6 ⟨elAtom 0 12, cometAtom 0 12, s.head⟩),
  leafCase "frontier-swapped" fun _ ls => ls.reverse,
  leafCase "interior-word" fun s ls => ls.set 0 (.word (wordAtom s.generation 6))]

/-- (0, 6] from c = 0 with reference block `block - age`, `blobs` blobs and the proofs. -/
def envCase (name : String) (age : Nat) (avail : Bool) (blobs : Nat) (ok : Bool) (wait : Nat := 1) : Scenario :=
  landCase ("land.env." ++ name) landS0 fun w =>
    let b := w.l1Block+wait
    let s := w.inbox
    ⟨b, .land { chainInput s 0 6 s.head s.snapshot b with l1ReferenceBlockNumber := b-age } (chainLeaves s 0 6)
      avail blobs ok⟩

def envGrid : List Scenario := [
  envCase "reference-is-current-block" 0 true 1 true,
  envCase "reference-age1" 1 true 1 true,
  envCase "reference-age1-hash-zero" 1 false 1 true,
  envCase "reference-age256" 256 true 1 true 300,
  envCase "reference-age257-no-history-contract" 257 false 1 true 300,
  envCase "reference-age8192" 8192 false 1 true 9000,
  envCase "blobs0" 1 true 0 true,
  envCase "blobs1" 1 true 1 true,
  envCase "blobs6" 1 true 6 true,
  envCase "blobs7" 1 true 7 true,
  envCase "proof-rejected" 1 true 1 false]

def landHandwritten : List Scenario := [
  landCase "land.hw.generation-start-reuses-older-record" landS2 (landFrom 12 24) (spec := some "EN L274"),
  landCase "land.hw.below-generation-start" landS2 (landFrom 6 24) (spec := some "EN L266"),
  landCase "land.hw.own-generation-record" landS2 (landFrom 18 24) (spec := some "EN L274"),
  landCase "land.hw.previous-generation-start" landS3 (landFrom 12 24) (spec := some "EN L266"),
  landCase "land.hw.second-recovery-start" landS3 (landFrom 18 24) (spec := some "EN L274"),
  landCase "land.hw.two-recoveries-at-one-checkpoint" landS4 (landFrom 12 18) (spec := some "EN L274"),
  landCase "land.hw.record-parent-is-actual-checkpoint" landS1 (landFrom 0 18) (spec := some "EN L315"),
  landCase "land.hw.max-batch-blocks-6.one-segment" landS0 (landFrom 0 6) { maxBatchBlocks := 6 } (some "EN L267"),
  landCase "land.hw.max-batch-blocks-6.two-segments" landS0 (landFrom 0 12) { maxBatchBlocks := 6 } (some "EN L267"),
  landCase "land.hw.inbox-does-not-enforce-unsettled-limit" [] (landFrom 0 18) { unsettled := 6 } (some "EN L372")]

def landScenarios : List Scenario := rangeGrid ++ headGrid ++ leafGrid ++ envGrid ++ landHandwritten

end Etna.Vectors
