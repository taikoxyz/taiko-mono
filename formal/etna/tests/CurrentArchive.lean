import EtnaProofs.CurrentArchive

open Etna.Design Etna.Design.Current

namespace Etna.CurrentArchiveRegression

def domain : Domain := ⟨1,2,3,4⟩
def cfg : Finality.Config := ⟨domain,0,0,10,10,10,1,1,1⟩
def header (height anchor : Nat) : Blocks.Header :=
  ⟨height,100+height,200+height,300+height,0,10+height,⟨anchor,anchor,anchor,0,100,0,0⟩,0⟩
def block (h : Blocks.Header) (parent : Hash) : Blocks.Block :=
  ⟨⟨h,parent,none,domain,0,0,100,0,true,none,0,0,0,0,[],none,.unavailable⟩,
    ⟨1,1,0,0,0⟩,[],none,[]⟩
def root := header 0 0
def first := header 1 10
def second := block (header 2 11) first.elHash
def hash (h : Blocks.Header) := h.elHash
def parentOf (hash : Hash) := hash-1

-- A nonempty historical prefix reaches exactly p; the actual batch extends it.
theorem concrete_authenticated :
    Archive.Authenticated hash parentOf cfg root.cut 20 [first,second.header] first [second] := by
  refine ⟨root,[first],rfl,rfl,rfl,rfl,rfl,?_,?_,?_,by decide,?_⟩
  · simp [Archive.Linked,root,first,second,header,block,parentOf,Blocks.Block.header]
  · intro h _; rfl
  · intro b member
    simp only [List.mem_singleton] at member
    subst b; rfl
  · intro h member
    simp only [List.mem_cons,List.not_mem_nil,or_false] at member
    rcases member with rfl | rfl <;> decide

example : Archive.Linked parentOf first [second.header] := Archive.actual_linked concrete_authenticated

-- Historical material above the reference cannot be selected as a lookback.
example : ¬ Archive.Authenticated hash parentOf cfg root.cut 20
    [header 1 100,second.header] (header 1 100) [second] := by
  intro auth
  have future := Archive.archived_anchor_bounded auth (header 1 100) (by simp)
  change 100 ≤ 20 at future
  omega

-- The physical header parent must agree with the actual block body too.
example : ¬ Archive.Authenticated hash parentOf cfg root.cut 20
    [first,second.header] first [{second with body := {second.body with parentHash := 999}}] := by
  intro auth
  have parent := Archive.actual_body_parent auth
    {second with body := {second.body with parentHash := 999}} (by simp)
  change 101 = 999 at parent
  cases parent

-- This obligation failed against the old Ready-only archive: arbitrary future
-- historical anchors could make the actual governing cutoff exceed the reference.
example (hash : Blocks.Header → Hash) (parentOf : Hash → Hash)
    (cfg : Finality.Config) (origin : Cut) (reference : Nat)
    (archive : List Blocks.Header) (p : Blocks.Header) (bs : List Blocks.Block)
    (registry : RegistryMachine.State)
    (auth : Archive.Authenticated hash parentOf cfg origin reference archive p bs)
    (ready : Finality.Ready cfg registry archive (Blocks.terminal p bs).height) :
    (Consensus.activeAt (Finality.derive cfg registry archive) (Blocks.terminal p bs).height).cutoff ≤ reference :=
  Archive.active_cutoff_bounded auth ready

-- An archive cannot omit a real block while claiming to authenticate its batch.
example (hash : Blocks.Header → Hash) (parentOf : Hash → Hash)
    (cfg : Finality.Config) (origin : Cut) (reference : Nat)
    (archive : List Blocks.Header) (p : Blocks.Header) (b : Blocks.Block) (bs : List Blocks.Block)
    (missing : b.header ∉ archive) :
    ¬ Archive.Authenticated hash parentOf cfg origin reference archive p (b :: bs) := by
  intro auth
  exact missing (Archive.actual_member auth b (by simp))

-- A physical parent mismatch rejects the batch even if its body claims a link.
example (hash : Blocks.Header → Hash) (parentOf : Hash → Hash)
    (cfg : Finality.Config) (origin : Cut) (reference : Nat)
    (archive : List Blocks.Header) (p : Blocks.Header) (b : Blocks.Block) (bs : List Blocks.Block)
    (wrong : parentOf b.header.elHash ≠ p.elHash) :
    ¬ Archive.Authenticated hash parentOf cfg origin reference archive p (b :: bs) := by
  intro auth
  exact wrong (Archive.actual_linked auth).2.1

-- The actual first block is the next height after this exact parent.
example (hash : Blocks.Header → Hash) (parentOf : Hash → Hash)
    (cfg : Finality.Config) (origin : Cut) (reference : Nat)
    (archive : List Blocks.Header) (p : Blocks.Header) (b : Blocks.Block) (bs : List Blocks.Block)
    (auth : Archive.Authenticated hash parentOf cfg origin reference archive p (b :: bs)) :
    b.header.height = p.height+1 := (Archive.actual_linked auth).1

end Etna.CurrentArchiveRegression
