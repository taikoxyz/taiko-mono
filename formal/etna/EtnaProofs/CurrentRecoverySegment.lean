import EtnaModel.CurrentRecoveryInterface
import EtnaProofs.Forced

/-! The first K blocks of the new generation after a plain recovery (reports/recoverability.md,
The path, step 6). `Recovery.segment` builds them on the batch parent `p` from `SegmentContext`
and proves each one `Blocks.Valid` under the closed certificate world's policy at reference `R+1`.

Every block anchors to the snapshot `s` at `R`. Its timestamp is `max (parent + 1) (time R)` (BFT
time 0), so block `i` is `i-1` seconds past its anchor. It commits in round 0 with votes from the
online members of the committee active at its height. Every cutoff is `R`: the anchors are all
`R` and the generation's origin block is `R`, so the initial committee and every normal one at an
epoch switch inside the segment elect from the registry at `R`. A block at a switch height carries
the normal record with `s`'s state root. The FI head entry is included when canonical and
executable at position zero; when due, it is skipped if non-canonical or its trial completes
empty; otherwise the block waits. The execution-liveness hypothesis supplies each header.

The policy's consensus context reads anchors from the segment's own headers. Since they all
anchor at the origin block, the context equals the one built from an empty archive, so the
blocks are built against that context first (`policy_archive`). -/
namespace Etna.Design.Current.Protocol.Recovery

/-! ### Election and committee records -/

/-- The election's result is the chosen members, whose keys are distinct. -/
private theorem election_chosen {unit minimum cutoff nMax : Nat} {entries members : List Committee.Entry}
    (elected : Committee.election unit minimum cutoff nMax entries = some members) :
    members = Committee.chosen unit minimum cutoff nMax entries ∧
      ((Committee.chosen unit minimum cutoff nMax entries).map Committee.Entry.key).Nodup := by
  unfold Committee.election at elected
  dsimp only at elected
  split at elected
  next guard =>
    cases Option.some.inj elected
    refine ⟨rfl,?_⟩
    have eligible := guard.2.2.2.2.1
    have sorted := ((List.mergeSort_perm _ Committee.rank).map Committee.Entry.key).nodup_iff.mpr eligible
    have taken := ((List.take_sublist nMax _).map Committee.Entry.key).nodup sorted
    exact ((List.mergeSort_perm _ _).map Committee.Entry.key).nodup_iff.mpr taken
  next => cases elected

/-- With every anchor at the origin block, a normal record's cutoff is the origin block. -/
private theorem normal_record {c : Consensus.Context} (anchors : ∀ h, c.anchorAt h = c.originBlock) (t : Nat) :
    Consensus.normal c t =
      ⟨t,c.originBlock,Committee.chosen c.unit c.minimum c.originBlock c.nMax (c.registry c.originBlock)⟩ := by
  unfold Consensus.normal Consensus.selected
  rw [anchors,Nat.max_self]

/-- Above generation 0 with every anchor at the origin block, the active committee at any height
is the one elected at the origin block, whether it is the initial or a normal record. -/
private theorem active_record {c : Consensus.Context} (generation : c.generation ≠ 0)
    (anchors : ∀ h, c.anchorAt h = c.originBlock) (h : Nat) :
    (Consensus.activeAt c h).cutoff = c.originBlock ∧
      (Consensus.activeAt c h).members =
        Committee.chosen c.unit c.minimum c.originBlock c.nMax (c.registry c.originBlock) := by
  simp only [Consensus.activeAt]
  split
  · rw [normal_record anchors]
    exact ⟨rfl,rfl⟩
  · simp [Consensus.initial,Consensus.selected,generation]

/-- A record elected at the origin block passes `ElectionValid` when that election succeeds. -/
private theorem record_valid {c : Consensus.Context} {record : Committee.Record} {members : List Committee.Entry}
    (cutoff : record.cutoff = c.originBlock)
    (chosen : record.members = Committee.chosen c.unit c.minimum c.originBlock c.nMax (c.registry c.originBlock))
    (elected : Committee.election c.unit c.minimum c.originBlock c.nMax (c.registry c.originBlock) = some members) :
    Consensus.ElectionValid c record := by
  unfold Consensus.ElectionValid
  rw [cutoff,chosen,← (election_chosen elected).1]
  exact elected

/-! ### The policy, its archive and the anchor snapshot -/

/-- With no archive, every anchor lookback is the origin block. -/
private theorem anchor_empty (cfg : Finality.Config) (h : Nat) : Finality.anchorAt cfg [] h = cfg.originBlock := by
  unfold Finality.anchorAt
  split <;> simp

/-- An archive whose headers all anchor at the origin block gives the same policy as no archive. -/
private theorem policy_archive {env : Environment} {x : World} {archive : List Header} {reference : Nat}
    (anchors : ∀ h ∈ archive, h.anchor.number = x.inbox.origin.l1Block) :
    policy env x archive reference = policy env x [] reference := by
  have same : Finality.anchorAt (config x) archive = Finality.anchorAt (config x) [] := by
    funext h
    rw [anchor_empty]
    unfold Finality.anchorAt
    split
    · rfl
    · rcases found : archive[h-(config x).originHeight-1]? with _ | header
      · rfl
      · exact anchors header (List.mem_of_getElem? found)
  unfold policy Finality.derive
  rw [same]

/-- Snapshots with distinct numbers are determined by their number. -/
private theorem number_unique : ∀ {l : List Snapshot}, (l.map Snapshot.number).Nodup →
    ∀ {a b : Snapshot}, a ∈ l → b ∈ l → a.number = b.number → a = b
  | [], _, _, _, ma, _, _ => absurd ma List.not_mem_nil
  | head :: rest, nodup, a, b, ma, mb, same => by
    rw [List.map_cons,List.nodup_cons] at nodup
    rcases List.mem_cons.mp ma with ha | ha
    · rcases List.mem_cons.mp mb with hb | hb
      · rw [ha,hb]
      · have listed : b.number ∈ rest.map Snapshot.number := List.mem_map_of_mem hb
        rw [← same,ha] at listed
        exact absurd listed nodup.1
    · rcases List.mem_cons.mp mb with hb | hb
      · have listed : a.number ∈ rest.map Snapshot.number := List.mem_map_of_mem ha
        rw [same,hb] at listed
        exact absurd listed nodup.1
      · exact number_unique nodup.2 ha hb same

/-- An anchor to a listed snapshot authenticates that very snapshot. -/
private theorem matching {env : Environment} {x : World} {s : Snapshot} (member : s ∈ x.history)
    (unique : (x.history.map Snapshot.number).Nodup) :
    matchingSnapshot env x (anchor env s) = some s := by
  unfold matchingSnapshot
  rcases found : x.history.find? (fun t => anchor env t == anchor env s) with _ | t
  · have listed : (x.history.find? fun t => anchor env t == anchor env s).isSome :=
      List.find?_isSome.mpr ⟨s,member,beq_self_eq_true _⟩
    rw [found] at listed
    cases listed
  · have same := List.find?_some found
    have same : anchor env t = anchor env s := beq_iff_eq.mp same
    rw [number_unique unique (List.mem_of_find?_eq_some found) member
      (congrArg BlockValidity.Anchor.number same)]

/-- The bounds `(parametersOf s).valid` gives: the configuration check, K ≤ 6, K ≤ U and the
minimum anchor age. -/
private theorem valid_params {s : Etna.Design.State} (valid : (parametersOf s).valid = true) :
    Committee.configOK s.gridK s.epochLen s.configuration.unsettled = true ∧ s.gridK ≤ 6 ∧
      s.gridK ≤ s.configuration.unsettled ∧ 1152 ≤ s.maxAnchorAge := by
  unfold Parameters.valid at valid
  rw [Bool.and_eq_true] at valid
  have rest := of_decide_eq_true valid.2
  have bounds := of_decide_eq_true valid.1
  exact ⟨valid.1,bounds.2.1,bounds.2.2.2.2.1,rest.2.1⟩

/-! ### Blocks -/

/-- The FI witness for queue entry `entry` at `index`, with the submitted bytes `raw` and the
execution body's first transaction `first`; its byte fields are those `PayloadFields` reads. -/
private def forcedWitness (bytes : ActualQueue.Primitives) (index : Nat) (entry : Forced.Entry)
    (raw : Blocks.Bytes) (first : Option Blocks.Bytes) : Forced.Witness :=
  ⟨index,entry,true,bytes.hashBytes raw,raw.length,bytes.canonical raw,first.map bytes.hashBytes,
    (first.map bytes.canonical).getD false,(first.map List.length).getD 0⟩

/-- The body of the segment block with header `h` on parent `q`: BFT time 0, round 0, votes from
the online members of the active committee, the normal record at a switch height, and the FI
witness for `slot` with the selected definition's singleton trial. -/
private def segmentBody (env : Environment) (x : World) (R : Nat) (keys : List Hash) (d : Blocks.Definition)
    (q h : Header) (slot : Option (Nat × Forced.Entry)) (raw : Blocks.Bytes) (first : Option Blocks.Bytes) :
    BlockValidity.Block where
  header := h
  parentHash := q.elHash
  lastBlockId := if q.height = (policy env x [] (R+1)).consensus.originHeight then none else some q.cometHash
  domain := (policy env x [] (R+1)).consensus.domain
  generation := (policy env x [] (R+1)).consensus.generation
  bftTime := 0
  feeShare := 100
  blockBytes := 0
  anchorWitness := decide (q.height = (policy env x [] (R+1)).consensus.originHeight)
  committeeWitness := if (h.height+1) % (policy env x [] (R+1)).consensus.epochLen = 0 then
    some ⟨Consensus.normal (policy env x [] (R+1)).consensus
      ((h.height+1)/(policy env x [] (R+1)).consensus.epochLen),h.anchor.stateRoot⟩ else none
  validatorsHash := env.committeeHash (Consensus.activeAt (policy env x [] (R+1)).consensus h.height)
  nextValidatorsHash := env.committeeHash (Consensus.activeAt (policy env x [] (R+1)).consensus (h.height+1))
  parentBeaconRoot := h.anchor.stateRoot
  round := 0
  votes := ((Consensus.activeAt (policy env x [] (R+1)).consensus h.height).members.filter
    fun e => keys.contains e.key).map fun e =>
      ⟨(policy env x [] (R+1)).consensus.domain,(policy env x [] (R+1)).consensus.generation,h.height,0,2,
        h.cometHash,e.key⟩
  forced := slot.map fun entry => forcedWitness d.bytes entry.1 entry.2 raw first
  singleton := d.bytes.buildSingleton q h raw

private def segmentBlock (env : Environment) (x : World) (R : Nat) (keys : List Hash) (d : Blocks.Definition)
    (q h : Header) (slot : Option (Nat × Forced.Entry)) (raw : Blocks.Bytes) (first : Option Blocks.Bytes)
    (txs : List Blocks.Bytes) : Block :=
  ⟨segmentBody env x R keys d q h slot raw first,x.schedule,raw,first,txs⟩

/-! ### Forced-inclusion steps (`Forced.step`'s three accepting cases) -/

private theorem step_closed {cursor tail anchor delay : Nat} {singleton : Forced.Singleton}
    (closed : tail ≤ cursor) : Forced.step cursor tail anchor delay none singleton = .accepted cursor := by
  simp [Forced.step,closed]

/-- A canonical entry included at position zero is consumed. -/
private theorem step_include {bytes : ActualQueue.Primitives} {cursor tail anchor delay : Nat}
    {e : Forced.Entry} {raw : Blocks.Bytes} {singleton : Forced.Singleton} (open_ : cursor < tail)
    (hashed : bytes.hashBytes raw = e.txHash) (short : raw.length ≤ 8192) (canonical : bytes.canonical raw = true) :
    Forced.step cursor tail anchor delay (some (forcedWitness bytes cursor e raw (some raw))) singleton =
      .accepted (cursor+1) := by
  simp [Forced.step,forcedWitness,Nat.not_le.mpr open_,hashed,canonical,Nat.not_lt.mpr short,short]

/-- A due entry that is non-canonical or whose trial completes empty is skipped. -/
private theorem step_skip {bytes : ActualQueue.Primitives} {cursor tail anchor delay : Nat}
    {e : Forced.Entry} {raw : Blocks.Bytes} {singleton : Forced.Singleton} (open_ : cursor < tail)
    (hashed : bytes.hashBytes raw = e.txHash) (short : raw.length ≤ 8192) (due : e.timestamp+delay ≤ anchor)
    (skippable : bytes.canonical raw = false ∨ singleton = .completedEmpty) :
    Forced.step cursor tail anchor delay (some (forcedWitness bytes cursor e raw none)) singleton =
      .accepted (cursor+1) := by
  rcases skippable with skippable | skippable
  · simp [Forced.step,forcedWitness,Nat.not_le.mpr open_,hashed,skippable,Nat.not_lt.mpr short,
      Nat.not_lt.mpr due]
  · cases canonical : bytes.canonical raw <;>
      simp [Forced.step,forcedWitness,Nat.not_le.mpr open_,hashed,skippable,canonical,Nat.not_lt.mpr short,
        Nat.not_lt.mpr due]

/-- An entry that is not yet due and not included leaves the cursor in place. -/
private theorem step_wait {bytes : ActualQueue.Primitives} {cursor tail anchor delay : Nat}
    {e : Forced.Entry} {raw : Blocks.Bytes} {singleton : Forced.Singleton} (open_ : cursor < tail)
    (hashed : bytes.hashBytes raw = e.txHash) (short : raw.length ≤ 8192) (early : anchor < e.timestamp+delay) :
    Forced.step cursor tail anchor delay (some (forcedWitness bytes cursor e raw none)) singleton =
      .accepted cursor := by
  simp [Forced.step,forcedWitness,Nat.not_le.mpr open_,hashed,Nat.not_lt.mpr short,early]

/-! ### One block -/

/-- The segment's fixed inputs: the context and the snapshot `s` at `R`, holding `x`'s storage. -/
private structure Setup (env : Environment) (x : World) (p : Header) (R : Nat) (keys : List Hash)
    (image : Hash) (s : Snapshot) : Prop where
  context : SegmentContext env x p R keys image
  member : s ∈ x.history
  number : s.number = R
  inbox : s.inbox = x.inbox
  schedule : s.schedule = x.schedule
  queue : s.queue = x.queue
  registry : s.registryHistory = x.registry.registry.history

/-- A parent `i` blocks into the segment: at height `p.height+i`, its timestamp below the anchor's
time plus `i`, anchored to `s` once inside the segment, and its FI cursor between the head and
the tail, at most `i` entries past the head. -/
private structure Parent (env : Environment) (x : World) (p : Header) (s : Snapshot) (i : Nat) (q : Header) :
    Prop where
  height : q.height = p.height+i
  time : q.timestamp+1 ≤ s.timestamp+i
  anchored : 0 < i → q.anchor = anchor env s
  head : x.inbox.head ≤ q.cursor
  tail : q.cursor ≤ x.inbox.tail
  consumed : q.cursor-x.inbox.head ≤ i

/-- What `segment` states of each block. -/
private def Facts (env : Environment) (image : Hash) (R : Nat) (b : Block) : Prop :=
  HashBound env b.header ∧ env.headerParent b.header.elHash = b.body.parentHash ∧
    b.body.blockBytes ≤ 124000 ∧ b.header.anchor.number = R ∧ Blocks.selectedRules b ∈ env.imageRules image

section
variable {env : Environment} {x : World} {p : Header} {R : Nat} {keys : List Hash} {image : Hash} {s : Snapshot}

private theorem setup_time (setup : Setup env x p R keys image s) : s.timestamp = env.time R := by
  rw [setup.context.timed s setup.member,setup.number]

private theorem setup_matching (setup : Setup env x p R keys image s) :
    matchingSnapshot env x (anchor env s) = some s :=
  matching setup.member (by rw [setup.context.numbers]; exact List.nodup_range)

/-- `WitnessValid`: a switch-height block carries the normal record elected at `R` with `s`'s root. -/
private theorem witness_valid (setup : Setup env x p R keys image s) {d : Blocks.Definition} {q h : Header}
    {slot : Option (Nat × Forced.Entry)} {raw : Blocks.Bytes} {first : Option Blocks.Bytes}
    {txs : List Blocks.Bytes} (anchored : h.anchor = anchor env s) :
    Blocks.WitnessValid (policy env x [] (R+1)) (segmentBlock env x R keys d q h slot raw first txs) := by
  obtain ⟨-,rfl,-⟩ := setup.context.origin
  obtain ⟨-,members,elected,-⟩ := setup.context.committee
  have record := normal_record (c := (policy env x [] (x.inbox.origin.l1Block+1)).consensus)
    (anchor_empty _) ((h.height+1)/x.inbox.epochLen)
  unfold Blocks.WitnessValid
  split
  next switch =>
    have carried : (segmentBlock env x x.inbox.origin.l1Block keys d q h slot raw first txs).body.committeeWitness =
        some ⟨Consensus.normal (policy env x [] (x.inbox.origin.l1Block+1)).consensus
          ((h.height+1)/x.inbox.epochLen),h.anchor.stateRoot⟩ := ite_eq_left_iff.mpr (fun off => absurd switch off)
    rw [carried]
    refine ⟨rfl,rfl,?_,?_,?_⟩
    · show (Consensus.normal (policy env x [] (x.inbox.origin.l1Block+1)).consensus _).cutoff ≤ h.anchor.number
      rw [record,anchored]
      exact Nat.le_of_eq setup.number.symm
    · show (x.history.any fun t => env.stateRoot t == h.anchor.stateRoot && decide
        ((Consensus.normal (policy env x [] (x.inbox.origin.l1Block+1)).consensus _).members =
          Committee.chosen x.inbox.configuration.unit x.inbox.configuration.minimum
            (Consensus.normal (policy env x [] (x.inbox.origin.l1Block+1)).consensus _).cutoff
            x.inbox.configuration.nMax (((RegistryHistory.latestSnapshot t.registryHistory
              (Consensus.normal (policy env x [] (x.inbox.origin.l1Block+1)).consensus _).cutoff).map
                RegistryHistory.Snapshot.entries).getD []))) = true
      apply List.any_eq_true.mpr
      refine ⟨s,setup.member,?_⟩
      rw [Bool.and_eq_true,beq_iff_eq,decide_eq_true_eq,anchored,record,setup.registry]
      exact ⟨rfl,rfl⟩
    · exact record_valid (by rw [record]) (by rw [record]) elected
  next off => exact ite_eq_right_iff.mpr fun on => absurd on off

/-- `CommitValid`: in round 0 the online members of the committee elected at `R` sign. -/
private theorem commit_valid (setup : Setup env x p R keys image s) {d : Blocks.Definition} {q h : Header}
    {slot : Option (Nat × Forced.Entry)} {raw : Blocks.Bytes} {first : Option Blocks.Bytes}
    (above : x.inbox.origin.height < h.height) :
    Consensus.CommitValid (policy env x [] (R+1)).consensus env.signature h.height 0 h.cometHash
      (segmentBody env x R keys d q h slot raw first).votes := by
  obtain ⟨-,rfl,generation⟩ := setup.context.origin
  obtain ⟨signed,members,elected,quorum⟩ := setup.context.committee
  have active := active_record (c := (policy env x [] (x.inbox.origin.l1Block+1)).consensus)
    (Nat.pos_iff_ne_zero.mp generation) (anchor_empty _) h.height
  have chosen := election_chosen elected
  have listed : (Consensus.activeAt (policy env x [] (x.inbox.origin.l1Block+1)).consensus h.height).members =
      members := active.2.trans chosen.1.symm
  have voters : (segmentBody env x x.inbox.origin.l1Block keys d q h slot raw first).votes.map Consensus.Vote.key =
      ((Consensus.activeAt (policy env x [] (x.inbox.origin.l1Block+1)).consensus h.height).members.filter
        fun e => keys.contains e.key).map Committee.Entry.key := by
    show List.map _ (List.map _ _) = _
    rw [List.map_map]
    rfl
  refine ⟨above,record_valid active.1 active.2 elected,?_,?_,?_⟩
  · rw [voters,listed]
    exact (List.filter_sublist.map Committee.Entry.key).nodup (chosen.1 ▸ chosen.2)
  · intro v voted
    obtain ⟨e,member,rfl⟩ := List.mem_map.mp voted
    have present := List.mem_filter.mp member
    exact ⟨rfl,rfl,rfl,rfl,rfl,rfl,List.mem_map_of_mem present.1,signed _ (List.contains_iff_mem.mp present.2)⟩
  · unfold Consensus.signedPower
    rw [voters,listed]
    have same : (members.filter fun e => ((members.filter fun e => keys.contains e.key).map
        Committee.Entry.key).contains e.key) = members.filter fun e => keys.contains e.key := by
      apply List.filter_congr
      intro e _
      apply Bool.eq_iff_iff.mpr
      rw [List.contains_iff_mem,List.contains_iff_mem,List.mem_map]
      constructor
      · rintro ⟨f,kept,same⟩
        rw [← same]
        exact List.contains_iff_mem.mp (List.mem_filter.mp kept).2
      · intro online
        exact ⟨e,List.mem_filter.mpr ⟨‹_›,List.contains_iff_mem.mpr online⟩,rfl⟩
    rw [same]
    exact quorum

/-- One block on parent `q` from header `h`, which executes under the selected definition `d`
with the segment's timestamp and anchor, given its forced-inclusion step. -/
private theorem assemble (setup : Setup env x p R keys image s) {i : Nat} {q : Header}
    (room : i < x.inbox.gridK) (parent : Parent env x p s i q) {d : Blocks.Definition}
    (cat : env.catalogue (Rules.select x.schedule (max (max (q.timestamp+1) 0) s.timestamp)) = some d)
    (implemented : Rules.select x.schedule (max (max (q.timestamp+1) 0) s.timestamp) ∈ env.imageRules image)
    {cursor : Nat} {raw : Blocks.Bytes} {txs : List Blocks.Bytes} {h : Header}
    (exec : Executes env d q cursor (max (max (q.timestamp+1) 0) s.timestamp) (anchor env s) raw txs h)
    {slot : Option (Nat × Forced.Entry)} {first : Option Blocks.Bytes}
    (stored : ∀ entry, slot = some entry → entry ∈ x.queue)
    (step : Forced.step q.cursor x.inbox.tail s.timestamp x.inbox.forcedDelay
      (slot.map fun entry => forcedWitness d.bytes entry.1 entry.2 raw first) (d.bytes.buildSingleton q h raw) =
        .accepted cursor)
    (zero : first = txs.head?) (bound : cursor ≤ x.inbox.tail) :
    ∃ b : Block, Blocks.Valid (policy env x [] (R+1)) q b ∧ Parent env x p s (i+1) b.header ∧
      env.headerParent b.header.elHash = q.elHash ∧ Facts env image R b := by
  obtain ⟨height,cursorEq,stamp,anchored,bound',linked,accepts⟩ := exec
  have accepted := accepts (segmentBody env x R keys d q h slot raw first) rfl rfl rfl
    (congrArg BlockValidity.Anchor.stateRoot anchored)
  obtain ⟨configured,small,unsettled,age⟩ := valid_params setup.context.params.1
  have number := setup.number
  have time := setup_time setup
  obtain ⟨-,windowLimit,numberLimit⟩ := setup.context.time
  obtain ⟨originHeight,originBlock,_⟩ := setup.context.origin
  have checkpoint : p.height = x.inbox.checkpoint.height := setup.context.parent.1.1
  have moved := Forced.step_one_or_zero step
  have defn : Blocks.definition (policy env x [] (R+1)) (segmentBlock env x R keys d q h slot raw first txs) = d := by
    show (env.catalogue (Rules.select x.schedule h.timestamp)).getD _ = d
    rw [stamp,cat]
    rfl
  have tail : (anchor env s).tail = x.inbox.tail := by
    show s.inbox.tail = _
    rw [setup.inbox]
  refine ⟨segmentBlock env x R keys d q h slot raw first txs,⟨configured,?_,?_,?_,witness_valid setup anchored,
    commit_valid setup ?_,?_,?_,setup.context.fits,?_,?_,?_,?_,zero,?_,?_,setup.context.params.2,rfl⟩,?_,linked,?_⟩
  · show x.inbox.origin.height ≤ q.height
    rw [parent.height]
    omega
  · refine ⟨height,rfl,rfl,rfl,rfl,?_,?_,rfl,Nat.zero_le _,rfl,rfl,rfl⟩
    · show h.timestamp < limit256
      have early := parent.time
      rw [stamp]
      omega
    · show h.timestamp = max (max (q.timestamp+1) 0) h.anchor.timestamp
      rw [stamp,anchored]
      rfl
  · refine ⟨?_,?_,?_,?_,?_,?_,?_,?_,?_,?_⟩
    · unfold Blocks.ParentAnchorValid
      split
      next first => exact decide_eq_true first
      next later =>
        have inside : 0 < i := by
          have : q.height ≠ x.inbox.origin.height := later
          rw [parent.height,originHeight] at this
          omega
        have parentAnchor := parent.anchored inside
        show q.anchor.number ≤ h.anchor.number ∧ Finality.anchorAt (config x) [] q.height = q.anchor.number ∧
          decide (q.height = x.inbox.origin.height) = decide (q.anchor.number ≠ h.anchor.number) ∧
          (q.anchor.number = h.anchor.number → q.anchor = h.anchor)
        rw [parentAnchor,anchored,anchor_empty]
        refine ⟨Nat.le_refl _,?_,?_,fun _ => rfl⟩
        · show x.inbox.origin.l1Block = s.number
          rw [originBlock,setup.number]
        · simp only [ne_eq,not_true_eq_false,decide_false,decide_eq_false_iff_not]
          exact later
    · show x.inbox.origin.l1Block ≤ h.anchor.number
      rw [anchored]
      exact Nat.le_of_eq (originBlock.trans setup.number.symm)
    · show h.anchor.number ≤ R+1
      rw [anchored]
      show s.number ≤ R+1
      omega
    · show h.anchor.number < limit48
      rw [anchored]
      show s.number < limit48
      omega
    · show h.anchor.generation = x.inbox.generation
      rw [anchored]
      show s.inbox.generation = _
      rw [setup.inbox]
    · show h.anchor.timestamp ≤ h.timestamp
      rw [anchored,stamp]
      show s.timestamp ≤ _
      omega
    · show h.timestamp-h.anchor.timestamp ≤ x.inbox.maxAnchorAge
      have early := parent.time
      rw [anchored,stamp]
      show _-s.timestamp ≤ _
      omega
    · show h.height-h.anchor.checkpointHeight ≤ x.inbox.configuration.unsettled
      rw [anchored]
      show h.height-s.inbox.checkpoint.height ≤ _
      rw [setup.inbox,height,parent.height]
      omega
    · show Finality.anchorAt (config x) [] h.height = h.anchor.number
      rw [anchor_empty,anchored]
      exact originBlock.trans setup.number.symm
    · show (matchingSnapshot env x h.anchor).isSome = true
      rw [anchored,setup_matching setup]
      rfl
  · show x.inbox.origin.height < h.height
    rw [height,parent.height,originHeight]
    omega
  · show Forced.step q.cursor h.anchor.tail h.anchor.timestamp x.inbox.forcedDelay _ _ = .accepted h.cursor
    rw [anchored,cursorEq,tail]
    exact step
  · rw [defn]
    show env.catalogue (Rules.select x.schedule h.timestamp) = some d
    rw [stamp]
    exact cat
  · show ((matchingSnapshot env x h.anchor).map fun s => decide (s.schedule = x.schedule)).getD false = true
    rw [anchored,setup_matching setup]
    simp [setup.schedule]
  · show Rules.stopped x.schedule _ q.height q.timestamp = false
    simp [Rules.stopped,setup.context.stop]
  · rw [defn]
    exact accepted.1
  · rw [defn]
    exact accepted.2
  · intro w carried
    rw [defn]
    obtain ⟨entry,-,rfl⟩ := Option.map_eq_some_iff.mp carried
    exact ⟨rfl,rfl,rfl,rfl,rfl,rfl,rfl⟩
  · intro w carried
    obtain ⟨entry,listed,rfl⟩ := Option.map_eq_some_iff.mp carried
    show ((matchingSnapshot env x h.anchor).map fun s => decide ((entry.1,entry.2) ∈ s.queue) && true).getD false = true
    rw [anchored,setup_matching setup]
    simp [setup.queue,stored entry listed]
  · show Parent env x p s (i+1) h
    have early := parent.time
    have low := parent.head
    have high := parent.consumed
    refine ⟨by rw [height,parent.height]; omega,by rw [stamp]; omega,fun _ => anchored,?_,?_,?_⟩ <;>
      rw [cursorEq] <;> omega
  · refine ⟨bound',linked,Nat.zero_le _,?_,?_⟩
    · show h.anchor.number = R
      rw [anchored]
      exact setup.number
    · show Rules.select x.schedule h.timestamp ∈ _
      rw [stamp]
      exact implemented

/-- One more block on any parent inside the segment. Its header comes from `ExecutionLive` of the
definition selected at its timestamp; the FI head entry is included, skipped or waited on as
`Forced.step` allows. -/
private theorem next_block (hash : ∀ id d, env.catalogue id = some d → d.bytes.hashBytes = env.txHash)
    (setup : Setup env x p R keys image s) {i : Nat} {q : Header} (room : i < x.inbox.gridK)
    (parent : Parent env x p s i q) :
    ∃ b : Block, Blocks.Valid (policy env x [] (R+1)) q b ∧ Parent env x p s (i+1) b.header ∧
      env.headerParent b.header.elHash = q.elHash ∧ Facts env image R b := by
  obtain ⟨⟨d,cat,live⟩,implemented⟩ := setup.context.rules (max (max (q.timestamp+1) 0) s.timestamp)
  obtain ⟨-,present,raws⟩ := setup.context.queue
  have later : q.timestamp < max (max (q.timestamp+1) 0) s.timestamp := by omega
  by_cases open_ : q.cursor < x.inbox.tail
  · obtain ⟨e,queued⟩ := present q.cursor parent.head open_
    obtain ⟨raw,hashed,short⟩ := raws _ _ queued
    have hashed : d.bytes.hashBytes raw = e.txHash := by rw [hash _ _ cat]; exact hashed
    have stored : ∀ entry, some (q.cursor,e) = some entry → entry ∈ x.queue := by
      rintro _ ⟨⟩
      exact queued
    obtain ⟨quiet,quietExec,choice⟩ :=
      live q (q.cursor+1) (max (max (q.timestamp+1) 0) s.timestamp) (anchor env s) raw later
    obtain ⟨still,stillExec,-⟩ := live q q.cursor (max (max (q.timestamp+1) 0) s.timestamp) (anchor env s) raw later
    have skip : e.timestamp+x.inbox.forcedDelay ≤ s.timestamp →
        (d.bytes.canonical raw = false ∨ d.bytes.buildSingleton q quiet raw = .completedEmpty) →
        ∃ b : Block, Blocks.Valid (policy env x [] (R+1)) q b ∧ Parent env x p s (i+1) b.header ∧
          env.headerParent b.header.elHash = q.elHash ∧ Facts env image R b := fun due skippable =>
      assemble setup room parent cat implemented quietExec (slot := some (q.cursor,e)) (first := none)
        stored (step_skip open_ hashed short due skippable) rfl open_
    have wait : s.timestamp < e.timestamp+x.inbox.forcedDelay →
        ∃ b : Block, Blocks.Valid (policy env x [] (R+1)) q b ∧ Parent env x p s (i+1) b.header ∧
          env.headerParent b.header.elHash = q.elHash ∧ Facts env image R b := fun early =>
      assemble setup room parent cat implemented stillExec (slot := some (q.cursor,e)) (first := none)
        stored (step_wait open_ hashed short early) rfl (Nat.le_of_lt open_)
    cases canonical : d.bytes.canonical raw
    · by_cases due : e.timestamp+x.inbox.forcedDelay ≤ s.timestamp
      · exact skip due (.inl canonical)
      · exact wait (Nat.lt_of_not_le due)
    · rcases choice canonical short with ⟨h,exec⟩ | empty
      · exact assemble setup room parent cat implemented exec (slot := some (q.cursor,e)) (first := some raw)
          stored (step_include open_ hashed short canonical) rfl open_
      · by_cases due : e.timestamp+x.inbox.forcedDelay ≤ s.timestamp
        · exact skip due (.inr empty)
        · exact wait (Nat.lt_of_not_le due)
  · obtain ⟨quiet,quietExec,-⟩ := live q q.cursor (max (max (q.timestamp+1) 0) s.timestamp) (anchor env s) [] later
    exact assemble setup room parent cat implemented quietExec (slot := none) (first := none)
      (fun _ absent => nomatch absent) (step_closed (Nat.le_of_not_lt open_)) rfl parent.tail

/-- The remaining `n` blocks from a parent `i` blocks into the segment. -/
private theorem build (hash : ∀ id d, env.catalogue id = some d → d.bytes.hashBytes = env.txHash)
    (setup : Setup env x p R keys image s) :
    ∀ n i (q : Header), i+n ≤ x.inbox.gridK → Parent env x p s i q →
      ∃ bs : List Block, bs.length = n ∧ Blocks.Chain (policy env x [] (R+1)) q bs ∧
        Parent env x p s (i+n) (Blocks.terminal q bs) ∧ Archive.Linked env.headerParent q (bs.map Blocks.Block.header) ∧
        ∀ b ∈ bs, Facts env image R b
  | 0, _, _, _, parent => ⟨[],rfl,trivial,parent,trivial,fun _ absent => nomatch absent⟩
  | n+1, i, q, room, parent => by
    obtain ⟨b,valid,next,link,facts⟩ := next_block hash setup (by omega) parent
    obtain ⟨bs,length,chain,last,linked,rest⟩ := build hash setup n (i+1) b.header (by omega) next
    refine ⟨b :: bs,by rw [List.length_cons,length],⟨valid,chain⟩,?_,⟨valid.header.1,link,linked⟩,?_⟩
    · rw [show i+(n+1) = i+1+n by omega]
      exact last
    · intro c member
      rcases List.mem_cons.mp member with rfl | member
      · exact facts
      · exact rest c member

end

/-- The first K blocks of the new generation after a plain recovery at L1 block `R`
(reports/recoverability.md, The path, step 6): from the batch parent `p`, a valid chain under the
closed certificate world's policy at reference `R+1`, archived by its own headers. It ends at height
`p.height+K` with an FI cursor at most K entries past the head and not past the tail; it is
physically linked from `p`; and every block is hash-bound, anchored at `R`, within the block size
bound and selects a ruleset `image` implements. -/
theorem segment {env : Environment} {x : World} {p : Header} {R : Nat} {keys : List Hash} {image : Hash}
    (hash : ∀ id d, env.catalogue id = some d → d.bytes.hashBytes = env.txHash)
    (context : SegmentContext env x p R keys image) :
    ∃ bs : List Block, bs.length = x.inbox.gridK ∧
      Blocks.Chain (policy env x (bs.map Blocks.Block.header) (R+1)) p bs ∧
      (Blocks.terminal p bs).height = p.height+x.inbox.gridK ∧
      x.inbox.head ≤ (Blocks.terminal p bs).cursor ∧ (Blocks.terminal p bs).cursor ≤ x.inbox.tail ∧
      (Blocks.terminal p bs).cursor-x.inbox.head ≤ x.inbox.gridK ∧
      Archive.Linked env.headerParent p (bs.map Blocks.Block.header) ∧
      ∀ b ∈ bs, HashBound env b.header ∧ env.headerParent b.header.elHash = b.body.parentHash ∧
        b.body.blockBytes ≤ 124000 ∧ b.header.anchor.number = R ∧
        Blocks.selectedRules b ∈ env.imageRules image := by
  obtain ⟨s,member,number,inbox,schedule,queue,registry,-⟩ := context.closed
  have setup : Setup env x p R keys image s := ⟨context,member,number,inbox,schedule,queue,registry⟩
  have first : Parent env x p s 0 p := by
    have time := setup_time setup
    have before := context.time.1
    refine ⟨rfl,by omega,fun absent => absurd absent (Nat.lt_irrefl 0),?_,?_,?_⟩ <;>
      rw [context.parent.2.2]
    · exact Nat.le_refl _
    · exact context.queue.1
    · omega
  obtain ⟨bs,length,chain,last,linked,facts⟩ := build hash setup x.inbox.gridK 0 p (by omega) first
  have anchors : ∀ h ∈ bs.map Blocks.Block.header, h.anchor.number = x.inbox.origin.l1Block := by
    intro h listed
    obtain ⟨b,member,rfl⟩ := List.mem_map.mp listed
    exact (facts b member).2.2.2.1.trans context.origin.2.1.symm
  rw [Nat.zero_add] at last
  refine ⟨bs,length,(policy_archive anchors).symm ▸ chain,last.height,last.head,last.tail,last.consumed,linked,
    fun b member => facts b member⟩

end Etna.Design.Current.Protocol.Recovery
