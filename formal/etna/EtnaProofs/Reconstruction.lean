import EtnaModel.Reconstruction
import EtnaProofs.Recovery
import EtnaProofs.Settlement
import EtnaProofs.SigningBridge

namespace Etna.Design.Reconstruction

/-- A fixed public input stream has at most one result. -/
theorem trace_unique {el : Primitives} {start : Rebuilt} {records : List Record} {a b : Rebuilt}
    (left : reconstruct el start records = some a) (right : reconstruct el start records = some b) :
    a = b := Option.some.inj (left.symm.trans right)

/-- Lower-level full-block semantics construct success; success is not a premise. -/
theorem execution_succeeds {el : Primitives} {p : Point} {state : Bytes}
    {blocks : List PublicBlock} {out : Executed} (run : Execution el p state blocks out) :
    executeSuffix el p state blocks = some out := by
  induction run with
  | nil => rfl
  | @cons p state b bs q h next out header height parent hash execution root rest ih =>
    subst hash
    have point : nextPoint el p b = some ⟨h.height,el.headerHash b.header⟩ := by
      simp [nextPoint,header,height,parent]
    simp [executeSuffix,point,header,execution,root,ih]

private theorem stored_tip {el : Primitives} {base : Nat} {p : Point} {state : Bytes}
    {archive : List (Nat × Bytes)} (stored : Stored el base p state archive) :
    ∃ raw h, archive.lookup p.height = some raw ∧ el.readHeader raw = some h ∧
      h.height = p.height ∧ el.headerHash raw = p.elHash ∧ el.stateRoot state = h.stateRoot := by
  cases stored with
  | start header height root => exact ⟨_,_,by simp,header,rfl,rfl,root⟩
  | next prior header height parent execution root => exact ⟨_,_,by simp,header,rfl,rfl,root⟩

private theorem lookup_ne {archive : List (Nat × Bytes)} {n key : Nat} {raw : Bytes}
    (different : n ≠ key) : ((key,raw) :: archive).lookup n = archive.lookup n := by
  simp only [List.lookup_cons,beq_eq_false_iff_ne.mpr different]

private theorem lookup_member {archive : List (Nat × Bytes)} {n : Nat} {raw : Bytes}
    (found : archive.lookup n = some raw) : raw ∈ archive.map Prod.snd := by
  induction archive with
  | nil => simp at found
  | cons a rest ih =>
    rcases a with ⟨key,value⟩
    by_cases eq : n = key
    · subst key
      simp only [List.lookup_cons_self] at found
      cases found
      simp
    · rw [lookup_ne eq] at found
      exact List.mem_cons_of_mem _ (ih found)

/-- Every stored non-starting header exposes its actual preceding public hash. -/
private theorem stored_parent {el : Primitives} {base : Nat} {p : Point} {state : Bytes}
    {archive : List (Nat × Bytes)} (stored : Stored el base p state archive)
    {n : Nat} (above : base < n) (below : n ≤ p.height) :
    ∃ raw h, archive.lookup n = some raw ∧ el.readHeader raw = some h ∧ h.height = n ∧
      (archive.lookup (n-1)).map el.headerHash = some h.parentHash := by
  induction stored with
  | start header height root => simp only at below; omega
  | @next p state archive b h next prior header height parent execution root ih =>
    by_cases atTip : n = h.height
    · subst n
      obtain ⟨raw,old,found,_,_,hash,_⟩ := stored_tip prior
      refine ⟨b.header,h,by simp,header,rfl,?_⟩
      have previous : h.height-1 = p.height := by omega
      have different : h.height ≠ p.height := by omega
      rw [previous,lookup_ne (Ne.symm different),found]
      simp [hash,parent]
    · have lower : n ≤ p.height := by dsimp only at below; omega
      obtain ⟨raw,old,found,decoded,number,linked⟩ := ih lower
      refine ⟨raw,old,?_,decoded,number,?_⟩
      · rw [lookup_ne atTip,found]
      · have different : h.height ≠ n-1 := by omega
        simpa only [lookup_ne (Ne.symm different)] using linked

/-- State application extends the saved header chain by the newly executed suffix. -/
theorem execution_stored {el : Primitives} {base : Nat} {p : Point} {state : Bytes}
    {archive : List (Nat × Bytes)} {blocks : List PublicBlock} {out : Executed}
    (stored : Stored el base p state archive) (run : Execution el p state blocks out) :
    Stored el base out.point out.state (out.headers.reverse ++ archive) := by
  induction run generalizing archive with
  | nil => simpa using stored
  | cons header height parent hash execution root rest ih =>
    subst hash
    have extended := Stored.next stored header height parent execution root
    simpa [List.reverse_cons,List.append_assoc] using ih extended

private theorem terminal_encoding {el : Primitives} (laws : ProjectionLaws el)
    {r : BlockValidity.Rules} {p : BlockValidity.Header} {bs : List BlockValidity.Block}
    (valid : BlockValidity.Chain r p bs) (soundRules : laws.guestRules r) (parent : HeaderEncoding el p) :
    HeaderEncoding el (BlockValidity.terminal p bs) := by
  induction bs generalizing p with
  | nil => exact parent
  | cons b rest ih =>
    apply ih valid.2
    exact ⟨(laws.project b).header,_,laws.fields r p b valid.1 soundRules,laws.headerBound r p b valid.1 soundRules,rfl,rfl⟩

/-- The deterministic EL contract supplies an actual successful state for every suffix
of a valid private chain projected to public executionBlocks. Private fields are used
only to discharge the projection laws; execution receives public bytes alone. -/
theorem projected_execution {el : Primitives} (laws : ProjectionLaws el)
    {r : BlockValidity.Rules} {p : BlockValidity.Header} {bs : List BlockValidity.Block}
    {state : Bytes} (valid : BlockValidity.Chain r p bs) (soundRules : laws.guestRules r) (root : el.stateRoot state = p.stateRoot) :
    ∃ out, Execution el ⟨p.height,p.elHash⟩ state (bs.map laws.project) out ∧
      out.point = ⟨(BlockValidity.terminal p bs).height,(BlockValidity.terminal p bs).elHash⟩ ∧
      el.stateRoot out.state = (BlockValidity.terminal p bs).stateRoot ∧
      out.applied = bs.map (fun b => b.header.height) := by
  induction bs generalizing p state with
  | nil => exact ⟨_,.nil _ _,rfl,root,rfl⟩
  | cons b rest ih =>
    obtain ⟨next,execution,root'⟩ := laws.fullEL r p b state valid.1 soundRules root
    obtain ⟨out,run,last,root'',applied⟩ := ih valid.2 root'
    obtain ⟨height,parent,_⟩ := BlockValidity.valid_parent_links valid.1
    refine ⟨{ out with
      headers := (b.header.height,(laws.project b).header) :: out.headers
      applied := b.header.height :: out.applied },?_,last,root'',?_⟩
    · exact .cons (laws.fields r p b valid.1 soundRules) height parent
        (by simp [laws.headerBound r p b valid.1 soundRules]) execution root' run
    · simp [applied]

/-- Backward induction derives every overlapping hash from the accepted terminal cut
and the saved chain. Only per-header collision exclusion is assumed. -/
theorem overlap_backwards {el : Primitives} (laws : ProjectionLaws el)
    {r : BlockValidity.Rules} {p : BlockValidity.Header} {bs : List BlockValidity.Block}
    {base : Nat} {tip : Point} {state : Bytes} {archive : List (Nat × Bytes)} {incoming : List Bytes}
    (stored : Stored el base tip state archive) (valid : BlockValidity.Chain r p bs)
    (soundRules : laws.guestRules r)
    (separation : HeaderSeparation el (archive.map Prod.snd) incoming)
    (members : ∀ b ∈ bs, (laws.project b).header ∈ incoming)
    (lower : base ≤ p.height) (upper : (BlockValidity.terminal p bs).height ≤ tip.height)
    (cut : (archive.lookup (BlockValidity.terminal p bs).height).map el.headerHash =
      some (BlockValidity.terminal p bs).elHash) :
    (archive.lookup p.height).map el.headerHash = some p.elHash ∧
      ∀ b ∈ bs, (archive.lookup b.header.height).map el.headerHash = some b.header.elHash := by
  induction bs generalizing p with
  | nil => exact ⟨cut,by simp⟩
  | cons b rest ih =>
    obtain ⟨height,parent,_⟩ := BlockValidity.valid_parent_links valid.1
    have lower' : base ≤ b.header.height := by omega
    obtain ⟨atBlock,tail⟩ := ih valid.2 (fun x hx => members x (List.mem_cons_of_mem b hx)) lower' upper cut
    have bound := BlockValidity.chain_height valid.2
    change (BlockValidity.terminal b.header rest).height ≤ tip.height at upper
    obtain ⟨raw,h,found,decoded,number,linked⟩ := stored_parent stored (n := b.header.height) (by omega) (by omega)
    have hash : el.headerHash raw = b.header.elHash := by
      rw [found] at atBlock
      exact Option.some.inj atBlock
    have same := separation raw (lookup_member found) (laws.project b).header (members b (by simp))
      (by rw [decoded]; simp) (by rw [laws.fields r p b valid.1 soundRules]; simp)
      (hash.trans (laws.headerBound r p b valid.1 soundRules).symm)
    have fields := laws.fields r p b valid.1 soundRules
    rw [← same,decoded] at fields
    cases Option.some.inj fields
    have prev : b.header.height-1 = p.height := by omega
    refine ⟨?_,?_⟩
    · simpa only [prev,parent] using linked
    · intro x member
      rcases List.mem_cons.mp member with same | member
      · subst x; exact atBlock
      · exact tail x member

/-- Once backward agreement has been derived, forward verification reads every prefix
header/link and never calls full-block execution. -/
theorem overlap_verified {el : Primitives} (laws : ProjectionLaws el)
    {r : BlockValidity.Rules} {p : BlockValidity.Header} {bs : List BlockValidity.Block}
    {archive : List (Nat × Bytes)} (valid : BlockValidity.Chain r p bs)
    (soundRules : laws.guestRules r)
    (known : ∀ b ∈ bs, (archive.lookup b.header.height).map el.headerHash = some b.header.elHash) :
    verifyOverlap el archive ⟨p.height,p.elHash⟩ (bs.map laws.project) =
      some ⟨(BlockValidity.terminal p bs).height,(BlockValidity.terminal p bs).elHash⟩ := by
  induction bs generalizing p with
  | nil => rfl
  | cons b rest ih =>
    obtain ⟨height,parent,_⟩ := BlockValidity.valid_parent_links valid.1
    have point : nextPoint el ⟨p.height,p.elHash⟩ (laws.project b) =
        some ⟨b.header.height,b.header.elHash⟩ := by
      simp [nextPoint,laws.fields r p b valid.1 soundRules,height,parent,laws.headerBound r p b valid.1 soundRules]
    have rest' := ih valid.2 (fun x hx => known x (List.mem_cons_of_mem b hx))
    simp only [List.map_cons,verifyOverlap,point]
    change (if (archive.lookup b.header.height).map el.headerHash = some b.header.elHash then
      verifyOverlap el archive ⟨b.header.height,b.header.elHash⟩ (rest.map laws.project) else none) = _
    rw [ite_eq_left (known b (by simp))]
    exact rest'

private theorem cut_take (p : BlockValidity.Header) (bs : List BlockValidity.Block) (n : Nat)
    (bound : n ≤ bs.length) :
    (BlockValidity.cuts p bs).getD n default = (BlockValidity.terminal p (bs.take n)).cut := by
  induction bs generalizing p n with
  | nil =>
    have zero : n = 0 := by simpa using bound
    subst n
    rfl
  | cons b rest ih =>
    cases n with
    | zero => rfl
    | succ n =>
      have bound' : n ≤ rest.length := by simpa using bound
      simpa [BlockValidity.cuts,BlockValidity.terminal,List.getD,List.take_succ_cons] using ih b.header n bound'

private theorem encoding_member {el : Primitives} (laws : ProjectionLaws el)
    {r : BlockValidity.Rules} {p : BlockValidity.Header} {bs : List BlockValidity.Block} {incoming : List Bytes}
    (valid : BlockValidity.Chain r p bs) (soundRules : laws.guestRules r)
    (parent : ∃ raw h, raw ∈ incoming ∧ el.readHeader raw = some h ∧ el.headerHash raw = p.elHash ∧
      h.height = p.height ∧ h.stateRoot = p.stateRoot)
    (members : ∀ b ∈ bs, (laws.project b).header ∈ incoming) :
    ∃ raw h, raw ∈ incoming ∧ el.readHeader raw = some h ∧
      el.headerHash raw = (BlockValidity.terminal p bs).elHash ∧
      h.height = (BlockValidity.terminal p bs).height ∧ h.stateRoot = (BlockValidity.terminal p bs).stateRoot := by
  induction bs generalizing p with
  | nil => exact parent
  | cons b rest ih =>
    apply ih valid.2 _ (fun x hx => members x (List.mem_cons_of_mem b hx))
    exact ⟨(laws.project b).header,_,members b (by simp),laws.fields r p b valid.1 soundRules,
      laws.headerBound r p b valid.1 soundRules,rfl,rfl⟩

private theorem stored_root {el : Primitives} {base : Nat} {tip : Point} {state : Bytes}
    {archive : List (Nat × Bytes)} {incoming : List Bytes} {p : BlockValidity.Header}
    (stored : Stored el base tip state archive)
    (separation : HeaderSeparation el (archive.map Prod.snd) incoming)
    (encoded : ∃ raw h, raw ∈ incoming ∧ el.readHeader raw = some h ∧ el.headerHash raw = p.elHash ∧
      h.height = p.height ∧ h.stateRoot = p.stateRoot)
    (hash : p.elHash = tip.elHash) : el.stateRoot state = p.stateRoot := by
  obtain ⟨raw,h,found,decoded,_,digest,root⟩ := stored_tip stored
  obtain ⟨other,fields,member,read,bound,_,stateRoot⟩ := encoded
  have same := separation raw (lookup_member found) other member (by rw [decoded]; simp)
    (by rw [read]; simp) (digest.trans (bound.trans hash).symm)
  rw [← same,decoded] at read
  cases Option.some.inj read
  exact root.trans stateRoot

private theorem record_height (s : State) (n : Nat) (present : (recordAt s n).isSome = true) :
    ((recordAt s n).getD default).height = n := by
  cases found : recordAt s n with
  | none => simp [found] at present
  | some cp =>
    have number := List.find?_some found
    simpa [found] using number

/-- The certificate's actual c is obtained from the original accepted landing's cut.
The saved archive and per-header crypto binding then derive overlap agreement and the
authenticated current state root. All inputs here are proof-side witnesses. -/
private theorem certified_prefix {el : Primitives} {laws : ProjectionLaws el} {s : Rebuilt} {l : Landing}
    (cert : Certification el laws s l) :
    let n := s.checkpoint.height-cert.parent.height
    let mid := BlockValidity.terminal cert.parent (cert.blocks.take n)
    BlockValidity.Chain cert.rules cert.parent (cert.blocks.take n) ∧
    BlockValidity.Chain cert.rules mid (cert.blocks.drop n) ∧
    mid.height = s.checkpoint.height ∧ mid.elHash = s.checkpoint.elHash ∧
    el.stateRoot s.state = mid.stateRoot ∧
    (s.archive.lookup cert.parent.height).map el.headerHash = some cert.parent.elHash ∧
    verifyOverlap el s.archive ⟨cert.parent.height,cert.parent.elHash⟩
      ((cert.blocks.take n).map laws.project) = some ⟨mid.height,mid.elHash⟩ := by
  dsimp only
  let n := s.checkpoint.height-cert.parent.height
  have input := Settlement.accepted_input cert.accepted cert.binding
  have allowed := (land_success cert.accepted).1.1.1
  have heights := BlockValidity.chain_height cert.valid.1
  have pg := (land_on_grid cert.accepted).1
  have hg := (land_on_grid cert.accepted).2.1
  rw [input,cert.grid] at pg hg
  have frontier := Settlement.accepted_frontier_from_valid_chain cert.accepted cert.valid cert.binding
    pg hg cert.grid cert.positive cert.stateValid.2.2.1.1 cert.stateValid.1
  have below := allowed.2.2.1
  have above := allowed.2.2.2.1
  rw [input] at below above
  change cert.parent.height ≤ cert.inbox.checkpoint.height at below
  change cert.inbox.checkpoint.height < (BlockValidity.terminal cert.parent cert.blocks).height at above
  have sync := cert.aligned.2.2
  have bound : n ≤ cert.blocks.length := by dsimp [n]; rw [sync]; omega
  have split := SigningBridge.valid_chain_split (before := cert.blocks.take n) (after := cert.blocks.drop n)
    (by simpa using cert.valid.1)
  have length : (cert.blocks.take n).length = n := List.length_take_of_le bound
  have midHeight := BlockValidity.chain_height split.1
  rw [length] at midHeight
  have mid : (BlockValidity.terminal cert.parent (cert.blocks.take n)).height = s.checkpoint.height := by
    rw [midHeight]
    dsimp [n]
    rw [sync]
    omega
  have cut := cut_take cert.parent cert.blocks n bound
  rw [← sync] at frontier
  rw [cut] at frontier
  have hash := congrArg Cut.elHash frontier
  change (BlockValidity.terminal cert.parent (cert.blocks.take n)).elHash = s.checkpoint.elHash at hash
  have terminalCut : (s.archive.lookup (BlockValidity.terminal cert.parent (cert.blocks.take n)).height).map
      el.headerHash = some (BlockValidity.terminal cert.parent (cert.blocks.take n)).elHash := by
    obtain ⟨raw,h,found,_,_,digest,_⟩ := stored_tip cert.stored
    rw [mid,hash,found]
    exact congrArg some digest
  have members : ∀ b ∈ cert.blocks, (laws.project b).header ∈
      laws.parentBytes cert.parent :: cert.blocks.map (fun b => (laws.project b).header) := by
    intro b member
    exact List.mem_cons_of_mem _ (List.mem_map.mpr ⟨b,member,rfl⟩)
  have before := fun b (member : b ∈ cert.blocks.take n) => members b (List.mem_of_mem_take member)
  obtain ⟨origin,known⟩ := overlap_backwards laws cert.stored split.1 cert.soundRules cert.separation before cert.base
    (by simpa only [mid] using Nat.le_refl s.checkpoint.height) terminalCut
  obtain ⟨ph,read,digest,number,root⟩ := laws.parent _ _ _ _ cert.valid cert.soundRules
  have encoded := encoding_member laws split.1 cert.soundRules
    ⟨laws.parentBytes cert.parent,ph,by simp,read,digest,number,root⟩ before
  exact ⟨split.1,split.2,mid,hash,stored_root cert.stored cert.separation encoded hash,
    origin,overlap_verified laws split.1 cert.soundRules known⟩

private theorem terminal_append (p : BlockValidity.Header) (a b : List BlockValidity.Block) :
    BlockValidity.terminal p (a ++ b) = BlockValidity.terminal (BlockValidity.terminal p a) b := by
  induction a generalizing p with
  | nil => rfl
  | cons head tail ih => exact ih head.header

private theorem chain_interval {r : BlockValidity.Rules} {p : BlockValidity.Header}
    {bs : List BlockValidity.Block} (valid : BlockValidity.Chain r p bs) :
    bs.map (fun b => b.header.height) = List.range' (p.height+1) bs.length := by
  induction bs generalizing p with
  | nil => rfl
  | cons b rest ih =>
    have height := (BlockValidity.valid_parent_links valid.1).1
    simp [ih valid.2,height,List.range'_succ]

private theorem certified_metadata {el : Primitives} {laws : ProjectionLaws el} {s : Rebuilt} {l : Landing}
    (cert : Certification el laws s l)
    (archived : (s.archive.lookup cert.parent.height).map el.headerHash = some cert.parent.elHash) :
    l.metadata s ∧ l.version = 6 ∧
    l.parent.height = cert.parent.height ∧ l.parent.elHash = cert.parent.elHash ∧
    l.input.parentHeight = cert.parent.height ∧ l.current = s.checkpoint ∧
    l.blobHashes = cert.hashes ∧ l.original = some cert.raw := by
  have input := Settlement.accepted_input cert.accepted cert.binding
  have fields := (landing_certificate (land_success cert.accepted).1).symm.trans cert.binding
  have hash := congrArg StatementData.parentHash fields
  have blobs := congrArg StatementData.blobHashes fields
  change ((recordAt cert.inbox l.input.parentHeight).getD default).elHash = cert.parent.elHash at hash
  change cert.environment.blobHashes = cert.hashes at blobs
  have parent : l.input.parentHeight = cert.parent.height := congrArg LandInput.parentHeight input
  rcases (land_success cert.accepted).1.1.1 with
    ⟨_,origin,below,above,_,_,_,_,present,scope,_⟩
  have number := record_height cert.inbox l.input.parentHeight present
  have metadata : l.metadata s := by
    rw [cert.projected]
    unfold Landing.metadata
    dsimp only [landingRecord]
    refine ⟨?_,cert.fresh,cert.aligned.1,cert.aligned.2.1,cert.aligned.2.2,
      origin,number,below,above,?_,?_⟩
    · simpa only [parent] using cert.base
    · simpa only [number] using scope
    · rw [number,parent]
      cases found : s.archive.lookup cert.parent.height with
      | none => simp [found] at archived
      | some raw => simp
  exact ⟨metadata,congrArg Landing.version cert.projected,
    (congrArg (fun x => x.parent.height) cert.projected).trans (number.trans parent),
    (congrArg (fun x => x.parent.elHash) cert.projected).trans hash,parent,
    (congrArg Landing.current cert.projected).trans cert.aligned.2.2.symm,
    (congrArg Landing.blobHashes cert.projected).trans blobs,congrArg Landing.original cert.projected⟩

/-- Actual accepted certificates with available original blobs reconstruct successfully.
Backward overlap agreement is derived from the accepted c cut, not assumed. The result
is the authenticated terminal EL state, and only the new (c,h] interval is applied. -/
theorem certified_success {el : Primitives} {laws : ProjectionLaws el} {s : Rebuilt} {l : Landing}
    (cert : Certification el laws s l) :
    ∃ out, Execution el ⟨s.checkpoint.height,s.checkpoint.elHash⟩ s.state
        ((cert.blocks.drop (s.checkpoint.height-cert.parent.height)).map laws.project) out ∧
      reconstructLanding el s l = some (finish s l out) ∧ step el s (.landing l) = some (finish s l out) ∧
      out.point = ⟨l.input.lastHeight,l.input.lastBlockHash⟩ ∧
      el.stateRoot out.state = l.input.lastStateRoot ∧
      out.applied = List.range' (s.checkpoint.height+1) (l.input.lastHeight-s.checkpoint.height) ∧
      Stored el s.baseHeight out.point out.state (out.headers.reverse ++ s.archive) := by
  obtain ⟨before,after,height,hash,root,origin,overlap⟩ := certified_prefix cert
  obtain ⟨metadata,version,parentHeight,parentHash,parent,current,blobs,original⟩ := certified_metadata cert origin
  let n := s.checkpoint.height-cert.parent.height
  have last : BlockValidity.terminal (BlockValidity.terminal cert.parent (cert.blocks.take n)) (cert.blocks.drop n) =
      BlockValidity.terminal cert.parent cert.blocks := by
    rw [← terminal_append,List.take_append_drop]
  dsimp only [n] at last
  obtain ⟨out,run,point,result,applied⟩ := projected_execution laws after cert.soundRules root
  have run' : Execution el ⟨s.checkpoint.height,s.checkpoint.elHash⟩ s.state
      ((cert.blocks.drop n).map laws.project) out := by simpa only [height,hash] using run
  have input := Settlement.accepted_input cert.accepted cert.binding
  have endpoint : out.point = ⟨l.input.lastHeight,l.input.lastBlockHash⟩ := by
    rw [input]
    simpa only [last,Settlement.statement] using point
  have terminalRoot : el.stateRoot out.state = l.input.lastStateRoot := by
    rw [input]
    simpa only [last,Settlement.statement] using result
  have interval : out.applied = List.range' (s.checkpoint.height+1) (l.input.lastHeight-s.checkpoint.height) := by
    have heights := BlockValidity.chain_height after
    have number : l.input.lastHeight = (BlockValidity.terminal cert.parent cert.blocks).height :=
      congrArg LandInput.lastHeight input
    have length : (cert.blocks.drop n).length = l.input.lastHeight-s.checkpoint.height := by
      rw [last,height] at heights
      dsimp only [n]
      omega
    dsimp only [n] at length
    rw [chain_interval after] at applied
    simpa only [height,length] using applied
  have available : cert.raw.map el.versionedHash = cert.hashes := by
    have eblobs := congrArg Landing.blobHashes cert.projected
    dsimp only [landingRecord] at eblobs
    exact cert.available.trans (eblobs.symm.trans blobs)
  have decoded := laws.payload _ _ _ _ _ cert.valid cert.soundRules available
  have length : (cert.blocks.map laws.project).length = l.input.lastHeight-l.input.parentHeight := by
    have heights := BlockValidity.chain_height cert.valid.1
    rw [List.length_map,input]
    change cert.blocks.length = (BlockValidity.terminal cert.parent cert.blocks).height-cert.parent.height
    omega
  have overlap' : verifyOverlap el s.archive ⟨l.parent.height,l.parent.elHash⟩
      ((cert.blocks.map laws.project).take (l.current.height-l.input.parentHeight)) =
      some ⟨l.current.height,l.current.elHash⟩ := by
    simpa only [parentHeight,parentHash,current,parent,← List.map_take,height,hash] using overlap
  have suffix : executeSuffix el ⟨l.current.height,l.current.elHash⟩ s.state
      ((cert.blocks.map laws.project).drop (l.current.height-l.input.parentHeight)) = some out := by
    simpa only [current,parent,← List.map_drop] using execution_succeeds run'
  have accepted : reconstructLanding el s l = some (finish s l out) := by
    unfold reconstructLanding
    rw [ite_eq_left ⟨metadata,version,by simpa only [parentHeight,parentHash] using origin⟩]
    simp only [original]
    change (if cert.raw.map el.versionedHash = l.blobHashes then _ else none) = _
    rw [ite_eq_left (available.trans blobs.symm)]
    rw [version,decoded]
    change (if (cert.blocks.map laws.project).length = l.input.lastHeight-l.input.parentHeight then _ else none) = _
    rw [ite_eq_left length,overlap']
    change (if (⟨l.current.height,l.current.elHash⟩ : Point) = ⟨l.current.height,l.current.elHash⟩ then _ else none) = _
    rw [ite_eq_left rfl,suffix]
    change (if out.point = ⟨l.input.lastHeight,l.input.lastBlockHash⟩ ∧ el.stateRoot out.state = l.input.lastStateRoot then _ else none) = _
    rw [ite_eq_left ⟨endpoint,terminalRoot⟩]
  exact ⟨out,run',accepted,by simp [step,cert.authenticated,accepted],endpoint,terminalRoot,interval,
    execution_stored cert.stored run'⟩

/-- A trace of genuine projected landings and authenticated ordinary recovery records
reconstructs by composition of the blockwise semantics, including competing frontiers. -/
theorem certified_trace_success {el : Primitives} {laws : ProjectionLaws el}
    {s t : Rebuilt} {records : List Record} (trace : ProjectionTrace el laws s records t) :
    reconstruct el s records = some t := by
  induction trace with
  | nil => rfl
  | @landing s l out records t certificate execution rest ih =>
    obtain ⟨result,run,_,accepted,_⟩ := certified_success certificate
    have same := Option.some.inj ((execution_succeeds execution).symm.trans (execution_succeeds run))
    subst result
    simp [reconstruct,accepted,ih]
  | recovery authentication fresh generation origin checkpoint height later rest ih =>
    simpa [reconstruct,step,authentication,recover,fresh,generation,origin,checkpoint,height,later] using ih

/-- Starting images are checked against authenticated full-header/state commitments and
fixed deployment configuration before becoming a saved history. -/
theorem initialized_stored {el : Primitives} {a : Start} {header state : Bytes} {s : Rebuilt}
    (accepted : initializeState el a header state = some s) :
    Stored el s.baseHeight ⟨s.checkpoint.height,s.checkpoint.elHash⟩ s.state s.archive ∧
      s.checkpoint = a.checkpoint ∧ el.stateRoot s.state = a.stateRoot := by
  cases auth : el.authenticateStart a with
  | false => simp [initializeState,auth] at accepted
  | true =>
    cases decoded : el.readHeader header with
    | none => simp [initializeState,auth,decoded] at accepted
    | some h =>
      simp only [initializeState,auth,Bool.true_eq_false,↓reduceIte,decoded] at accepted
      change (if _ then _ else none) = some s at accepted
      split at accepted
      · rename_i checked
        obtain ⟨_,_,height,hash,root,stateRoot⟩ := checked
        cases Option.some.inj accepted
        refine ⟨?_,rfl,stateRoot⟩
        rw [← height,← hash]
        exact .start decoded rfl (stateRoot.trans root.symm)
      · contradiction

/-- Missing original material cannot be replaced with a guessed empty batch. -/
theorem missing_original_rejected (el : Primitives) (s : Rebuilt) (l : Landing)
    (missing : l.original = none) : reconstructLanding el s l = none := by
  simp [reconstructLanding,missing]

/-- Version support is explicit and fixed to the public 0x06 format. -/
theorem unsupported_version_rejected (el : Primitives) (s : Rebuilt) (l : Landing)
    (unsupported : l.version ≠ 6) : reconstructLanding el s l = none := by
  simp [reconstructLanding,unsupported]

/-- Authentication failure prevents every state transition. -/
theorem unauthenticated_record_rejected (el : Primitives) (s : Rebuilt) (r : Record)
    (failed : el.authenticateRecord r = false) : step el s r = none := by
  simp [step,failed]

/-- Different original bytes/commitments cannot proceed to public decoding. -/
theorem blob_mismatch_rejected (el : Primitives) (s : Rebuilt) (l : Landing) (raw : List Bytes)
    (available : l.original = some raw) (wrong : raw.map el.versionedHash ≠ l.blobHashes) :
    reconstructLanding el s l = none := by
  simp [reconstructLanding,available,wrong]

/-- Parent linkage is independently checked for overlap and suffix headers. -/
theorem broken_parent_rejected (el : Primitives) (p : Point) (b : PublicBlock) (h : HeaderFields)
    (decoded : el.readHeader b.header = some h) (wrong : h.parentHash ≠ p.elHash) :
    nextPoint el p b = none := by
  simp [nextPoint,decoded,wrong]

/-- Every successfully verified overlap header has a saved matching EL hash. -/
theorem overlap_head_checked {el : Primitives} {archive : List (Nat × Bytes)} {p q : Point}
    {b : PublicBlock} {bs : List PublicBlock}
    (accepted : verifyOverlap el archive p (b :: bs) = some q) :
    ∃ next, nextPoint el p b = some next ∧ (archive.lookup next.height).map el.headerHash = some next.elHash := by
  cases point : nextPoint el p b with
  | none => simp [verifyOverlap,point] at accepted
  | some next =>
    simp only [verifyOverlap,point] at accepted
    change (if _ then _ else none) = some q at accepted
    split at accepted
    · exact ⟨next,rfl,by assumption⟩
    · contradiction

/-- Ordinary recovery changes the generation's fixed origin without applying an EL
block or clearing the saved overlap. The actual execution frontier remains c. -/
theorem recovery_preserves_execution {s t : Rebuilt} {r : RecoveryRecord} (accepted : recover s r = some t) :
    t.checkpoint = s.checkpoint ∧ t.state = s.state ∧ t.archive = s.archive ∧
    t.applied = s.applied ∧ t.origin = r.nextOrigin ∧ t.origin.height = s.checkpoint.height ∧
    t.generation = s.generation+1 := by
  unfold recover at accepted
  split at accepted
  · rename_i checked
    obtain ⟨_,_,_,checkpoint,height,_⟩ := checked
    cases Option.some.inj accepted
    exact ⟨rfl,rfl,rfl,rfl,rfl,height.trans (congrArg Checkpoint.height checkpoint.symm),rfl⟩
  · contradiction

/-- A certificate applies each new height once; overlap heights never occur in this
state-application list. This counts EL state applications, not hash-verification reads. -/
theorem certified_exactly_once {el : Primitives} {laws : ProjectionLaws el} {s : Rebuilt} {l : Landing}
    (cert : Certification el laws s l) :
    ∃ out, reconstructLanding el s l = some (finish s l out) ∧ out.applied.Nodup ∧
      ∀ h, h ∈ out.applied ↔ s.checkpoint.height < h ∧ h ≤ l.input.lastHeight := by
  obtain ⟨out,_,accepted,_,_,_,interval,_⟩ := certified_success cert
  refine ⟨out,accepted,?_,?_⟩
  · rw [interval]
    exact List.nodup_range'
  · intro h
    rw [interval,List.mem_range']
    simp only [Nat.one_mul]
    have current := cert.aligned.2.2
    have advance := (land_success cert.accepted).1.1.1.2.2.2.1
    rw [← current] at advance
    constructor
    · rintro ⟨i,less,equal⟩; omega
    · rintro ⟨above,below⟩
      exact ⟨h-(s.checkpoint.height+1),by omega,by omega⟩

/-- Public result authentication refers to the actual returned state and original Inbox
checkpoint, including its public Comet hash and cursor; no Comet history is replayed. -/
theorem certified_result {el : Primitives} {laws : ProjectionLaws el} {s : Rebuilt} {l : Landing}
    (cert : Certification el laws s l) :
    ∃ t, step el s (.landing l) = some t ∧ t.checkpoint = cert.after.checkpoint ∧
      el.stateRoot t.state = l.input.lastStateRoot ∧ t.generation = s.generation ∧ t.origin = s.origin ∧
      t.applied = s.applied ++ List.range' (s.checkpoint.height+1) (l.input.lastHeight-s.checkpoint.height) ∧
      Stored el t.baseHeight ⟨t.checkpoint.height,t.checkpoint.elHash⟩ t.state t.archive := by
  obtain ⟨out,_,_,accepted,point,root,interval,stored⟩ := certified_success cert
  have checkpoint : l.checkpoint = cert.after.checkpoint := by
    rw [(land_success cert.accepted).2]
    have generation := congrArg Landing.generation cert.projected
    have current := congrArg Landing.current cert.projected
    simp only [Landing.checkpoint,applyLanding,landedCheckpoint,generation,current,landingRecord]
  refine ⟨finish s l out,accepted,checkpoint,root,rfl,rfl,?_,?_⟩
  · exact congrArg (fun applied => s.applied ++ applied) interval
  · change Stored el s.baseHeight ⟨l.input.lastHeight,l.input.lastBlockHash⟩ out.state
      (out.headers.reverse ++ s.archive)
    rw [← point]
    exact stored

/-- Actual original ordinary recovery supplies precisely the public generation/origin
update. Canonical order permits multiple recovery transactions in the same L1 block. -/
theorem actual_recovery_projection {s : Rebuilt} {before after : Recovery.World}
    {request : Recovery.Request} {config : Recovery.Config} {next : Origin} {owner externalOK : Bool}
    (accepted : Recovery.recover before request config next owner externalOK = some after)
    (aligned : s.generation = before.inbox.generation ∧ s.origin = before.inbox.origin ∧
      s.checkpoint = before.inbox.checkpoint) (order : Nat) (fresh : s.order < order)
    (canonical : before.inbox.origin.l1Block ≤ next.l1Block) (evidence : Bytes) :
    recover s ⟨order,before.inbox.generation,before.inbox.origin,before.inbox.checkpoint,next,evidence⟩ =
      some { s with generation := after.inbox.generation, origin := after.inbox.origin, order := order } := by
  have fields := Recovery.recovery_fixes_origin accepted
  simp only [recover]
  rw [ite_eq_left ⟨fresh,aligned.1,aligned.2.1,aligned.2.2,fields.2.2.1,canonical⟩]
  simp only [fields.1,fields.2.1,aligned.1]

/-- Recovery cannot substitute a different settled frontier or a different fixed origin. -/
theorem wrong_recovery_origin_rejected (s : Rebuilt) (r : RecoveryRecord)
    (wrong : r.nextOrigin.height ≠ r.current.height) : recover s r = none := by
  simp [recover,wrong]

/-- Public generation and fixed-origin coordinates are mandatory, independently of EL
height and state. Old-generation blobs cannot become a new generation's continuation. -/
theorem wrong_generation_rejected (el : Primitives) (s : Rebuilt) (l : Landing)
    (wrong : s.generation ≠ l.generation) : reconstructLanding el s l = none := by
  simp [reconstructLanding,Landing.metadata,wrong]

theorem wrong_fixed_origin_rejected (el : Primitives) (s : Rebuilt) (l : Landing)
    (wrong : s.origin ≠ l.origin) : reconstructLanding el s l = none := by
  simp [reconstructLanding,Landing.metadata,wrong]

/-- Full original proof-range data is required even when only its suffix is executed. -/
theorem incomplete_range_rejected (el : Primitives) (s : Rebuilt) (l : Landing) (raw : List Bytes)
    (blocks : List PublicBlock) (available : l.original = some raw)
    (decoded : el.decodePayload l.version raw = some blocks)
    (wrong : blocks.length ≠ l.input.lastHeight-l.input.parentHeight) : reconstructLanding el s l = none := by
  simp [reconstructLanding,available,decoded,wrong]

/-- Across any number of certified overlapping landings and ordinary recoveries, the
application log appends exactly one contiguous new-height interval. Recoveries apply
no blocks; the original checkpoint is an execution coordinate, independent of origin. -/
theorem certified_trace_interval {el : Primitives} {laws : ProjectionLaws el}
    {s t : Rebuilt} {records : List Record} (trace : ProjectionTrace el laws s records t) :
    s.checkpoint.height ≤ t.checkpoint.height ∧
      t.applied = s.applied ++ List.range' (s.checkpoint.height+1) (t.checkpoint.height-s.checkpoint.height) := by
  induction trace with
  | nil => simp
  | @landing s l out records t certificate execution rest ih =>
    obtain ⟨result,run,_,_,_,_,interval,_⟩ := certified_success certificate
    have same := Option.some.inj ((execution_succeeds execution).symm.trans (execution_succeeds run))
    subst result
    have current := certificate.aligned.2.2
    have advance := (land_success certificate.accepted).1.1.1.2.2.2.1
    rw [← current] at advance
    rcases ih with ⟨bound,applications⟩
    change l.input.lastHeight ≤ t.checkpoint.height at bound
    change t.applied = (s.applied ++ out.applied) ++
      List.range' (l.input.lastHeight+1) (t.checkpoint.height-l.input.lastHeight) at applications
    refine ⟨by omega,?_⟩
    rw [applications,interval,List.append_assoc]
    congr 1
    have join : l.input.lastHeight+1 = s.checkpoint.height+1+(l.input.lastHeight-s.checkpoint.height) := by omega
    rw [join,List.range'_append_1]
    congr 1
    omega
  | recovery _ _ _ _ _ _ _ _ ih => exact ih

/-- Every returned landing state matches the authenticated public target, even before
using the certified-projection completeness theorem. This is a complementary rejection
property, not a substitute for certified_success. -/
theorem landing_result_checked {el : Primitives} {s t : Rebuilt} {l : Landing}
    (accepted : reconstructLanding el s l = some t) :
    t.checkpoint = l.checkpoint ∧ el.stateRoot t.state = l.input.lastStateRoot := by
  unfold reconstructLanding at accepted
  split at accepted
  · cases original : l.original with
    | none => simp [original] at accepted
    | some raw =>
      simp only [original] at accepted
      change (if _ then _ else none) = some t at accepted
      split at accepted
      · cases decoded : el.decodePayload l.version raw with
        | none => simp [decoded] at accepted
        | some blocks =>
          simp only [decoded] at accepted
          change (if _ then _ else none) = some t at accepted
          split at accepted
          · cases overlapResult : verifyOverlap el s.archive ⟨l.parent.height,l.parent.elHash⟩
                (blocks.take (l.current.height-l.input.parentHeight)) with
            | none => simp [overlapResult] at accepted
            | some point =>
              simp only [overlapResult] at accepted
              change (if _ then _ else none) = some t at accepted
              split at accepted
              · cases suffix : executeSuffix el point s.state (blocks.drop (l.current.height-l.input.parentHeight)) with
                | none => simp [suffix] at accepted
                | some out =>
                  simp only [suffix] at accepted
                  change (if _ then _ else none) = some t at accepted
                  split at accepted
                  · rename_i checked
                    cases Option.some.inj accepted
                    exact ⟨rfl,checked.2⟩
                  · contradiction
              · contradiction
          · contradiction
      · contradiction
  · contradiction

/-- The public entry point derives success from authenticated starting fields and a
certified semantic trace; an unchecked starting snapshot cannot bypass initialization. -/
theorem checked_public_reconstruction {el : Primitives} {laws : ProjectionLaws el}
    {a : Start} {header state : Bytes} {h : HeaderFields} {records : List Record} {t : Rebuilt}
    (authenticated : el.authenticateStart a = true) (decoded : el.readHeader header = some h)
    (checked : a.configuration = el.configuration ∧ a.ruleVersion = el.ruleVersion ∧
      h.height = a.checkpoint.height ∧ el.headerHash header = a.checkpoint.elHash ∧
      h.stateRoot = a.stateRoot ∧ el.stateRoot state = a.stateRoot)
    (trace : ProjectionTrace el laws
      ⟨a.generation,a.origin,a.checkpoint,h.height,state,[(h.height,header)],[],a.order⟩ records t) :
    reconstructPublic el a header state records = some t := by
  have initialized : initializeState el a header state =
      some ⟨a.generation,a.origin,a.checkpoint,h.height,state,[(h.height,header)],[],a.order⟩ := by
    simp only [initializeState,authenticated,Bool.true_eq_false,↓reduceIte,decoded]
    change (if _ then _ else none) = _
    rw [ite_eq_left checked]
  unfold reconstructPublic
  rw [initialized]
  exact certified_trace_success trace

end Etna.Design.Reconstruction
