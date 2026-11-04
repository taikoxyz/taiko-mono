import EtnaModel.CurrentFinality
import EtnaProofs.CurrentRegistry
import EtnaProofs.CurrentBlocks
import EtnaProofs.Locking
import EtnaProofs.Accountability

namespace Etna.Design.Current.Finality

theorem derive_preorigin_anchor (cfg : Config) (registry : RegistryMachine.State)
    (archive : List Blocks.Header) (h : Nat) (before : h ≤ cfg.originHeight) :
    (derive cfg registry archive).anchorAt h = cfg.originBlock := by
  simp [derive,anchorAt,before]

theorem derive_normal_preorigin_cutoff (cfg : Config) (registry : RegistryMachine.State)
    (archive : List Blocks.Header) (t : Nat) (before : t*cfg.epochLen-2 ≤ cfg.originHeight) :
    (Consensus.normal (derive cfg registry archive) t).cutoff = cfg.originBlock := by
  simp [Consensus.normal,Consensus.selected,derive,anchorAt,before]

theorem derive_generation_zero_target (cfg : Config) (registry : RegistryMachine.State)
    (archive : List Blocks.Header) (genesis : cfg.generation = 0) :
    (Consensus.initial (derive cfg registry archive)).targetEpoch = 0 := by
  simp [Consensus.initial,Consensus.selected,derive,genesis]

theorem build_success {adapters : Adapters} {cfg : Config} {registry : RegistryMachine.State}
    {archive : List Blocks.Header} {h : Nat} {context : Consensus.Context}
    (ok : build adapters cfg registry archive h = some context) :
    Ready cfg registry archive h ∧ Authentic adapters cfg registry archive ∧
      context = derive cfg registry archive := by
  unfold build at ok
  split at ok
  next checks => exact ⟨checks.1,checks.2,(Option.some.inj ok).symm⟩
  next => cases ok

theorem registry_from_raw_prefix {a b : RegistryMachine.State} {cut : Nat}
    (shared : a.history.filter (fun cp => decide (cp.block ≤ cut)) =
      b.history.filter (fun cp => decide (cp.block ≤ cut))) : registryAt a cut = registryAt b cut := by
  have heads := congrArg List.head? shared
  simp only [List.head?_filter] at heads
  simp only [registryAt,RegistryHistory.latestSnapshot,heads]

theorem anchor_prefix (cfg : Config) (common more : List Blocks.Header) (h : Nat)
    (covered : h-cfg.originHeight ≤ common.length) :
    anchorAt cfg (common ++ more) h = anchorAt cfg common h := by
  by_cases early : h ≤ cfg.originHeight
  · simp [anchorAt,early]
  · have index : h-cfg.originHeight-1 < common.length := by omega
    simp [anchorAt,early,List.getElem?_append_left index]

/-- D(t) lies at least three heights before the block choosing that epoch's authority. -/
theorem decision_lookback_before (cfg : Config) (h : Nat) : decisionLookback cfg h ≤ h-3 := by
  have bound := Nat.div_mul_le_self (h-1) cfg.epochLen
  unfold decisionLookback epoch
  omega

/-- At an ordinary rotation, the complete required archive ends no later than h−3. -/
theorem required_prefix_before (cfg : Config) (h : Nat)
    (normal : cfg.originHeight < epoch cfg h*cfg.epochLen-1)
    (after : cfg.originHeight < decisionLookback cfg h) :
    cfg.originHeight+requiredPrefix cfg h ≤ h-3 := by
  have bound := decision_lookback_before cfg h
  simp only [requiredPrefix,normal,ite_true]
  omega

theorem active_cutoff (cfg : Config) (registry : RegistryMachine.State) (archive : List Blocks.Header) (h : Nat) :
    (Consensus.activeAt (derive cfg registry archive) h).cutoff = cutoff cfg archive h := by
  by_cases normal : cfg.originHeight < (h-1)/cfg.epochLen*cfg.epochLen-1
  all_goals simp [Consensus.activeAt,Consensus.epoch,Consensus.switchHeight,Consensus.initial,
    Consensus.normal,Consensus.selected,derive,cutoff,decisionLookback,epoch,initialCutoff,normal]
  all_goals rfl

/-- Common authenticated raw headers through D(t), and the same finalized slot snapshots
through the resulting cutoff, derive identical current committees despite different suffixes.
The two derived contexts themselves are never assumed equal. -/
theorem active_committee_prefix {cfg : Config} {registryA registryB : RegistryMachine.State}
    {common moreA moreB : List Blocks.Header} {h : Nat}
    (covered : requiredPrefix cfg h ≤ common.length)
    (registryPrefix : registryA.history.filter (fun cp => decide (cp.block ≤ cutoff cfg common h)) =
      registryB.history.filter (fun cp => decide (cp.block ≤ cutoff cfg common h))) :
    Consensus.activeAt (derive cfg registryA (common ++ moreA)) h =
      Consensus.activeAt (derive cfg registryB (common ++ moreB)) h := by
  have registry := registry_from_raw_prefix registryPrefix
  unfold Consensus.activeAt Consensus.epoch Consensus.switchHeight derive
  dsimp only
  by_cases normal : cfg.originHeight < (h-1)/cfg.epochLen*cfg.epochLen-1
  · have enough : decisionLookback cfg h-cfg.originHeight ≤ common.length := by
      simpa [requiredPrefix,epoch,normal] using covered
    have anchorA := anchor_prefix cfg common moreA (decisionLookback cfg h) enough
    have anchorB := anchor_prefix cfg common moreB (decisionLookback cfg h) enough
    simp only [normal,ite_true,Consensus.normal,Consensus.selected]
    simp only [decisionLookback,epoch] at anchorA anchorB
    rw [anchorA,anchorB]
    simpa [cutoff,decisionLookback,epoch,normal] using congrArg
      (fun es => Committee.Record.mk ((h-1)/cfg.epochLen)
        (max (anchorAt cfg common (decisionLookback cfg h)) cfg.originBlock)
        (Committee.chosen cfg.unit cfg.minimum
          (max (anchorAt cfg common (decisionLookback cfg h)) cfg.originBlock) cfg.nMax es)) registry
  · simp only [normal,ite_false,Consensus.initial,Consensus.selected]
    simpa [cutoff,epoch,normal,initialCutoff] using congrArg
      (fun es => Committee.Record.mk (if cfg.generation = 0 then 0 else cfg.originHeight/cfg.epochLen)
        (initialCutoff cfg) (Committee.chosen cfg.unit cfg.minimum (initialCutoff cfg) cfg.nMax es)) registry

/-- Actual local RoundStep rules and actual nonnil event attribution bridge two current
contexts only after the shared raw prefix derives their common committee. -/
theorem shared_prefix_agreement {cfg : Config} {registryA registryB : RegistryMachine.State}
    {common moreA moreB : List Blocks.Header} {h : Nat}
    (covered : requiredPrefix cfg h ≤ common.length)
    (registryPrefix : registryA.history.filter (fun cp => decide (cp.block ≤ cutoff cfg common h)) =
      registryB.history.filter (fun cp => decide (cp.block ≤ cutoff cfg common h)))
    {honest : Hash → Bool} {mode : Bool} {execution : Locking.Execution}
    {sigA sigB : Consensus.Vote → Prop}
    (rules : Locking.HonestRules cfg.unit
      (Consensus.activeAt (derive cfg registryA (common ++ moreA)) h).members honest mode execution)
    (minority : Locking.Minority cfg.unit
      (Consensus.activeAt (derive cfg registryA (common ++ moreA)) h).members honest)
    {ra rb a b : Nat} {votesA votesB : List Consensus.Vote}
    (attributedA : Locking.CommitAttribution execution ra a votesA)
    (attributedB : Locking.CommitAttribution execution rb b votesB)
    (validA : Consensus.CommitValid (derive cfg registryA (common ++ moreA)) sigA h ra a votesA)
    (validB : Consensus.CommitValid (derive cfg registryB (common ++ moreB)) sigB h rb b votesB) : a = b := by
  have committee := active_committee_prefix (moreA := moreA) (moreB := moreB) covered registryPrefix
  have lowerB := Locking.commitValid_bridge attributedB validB
  rw [← committee] at lowerB
  exact Locking.commit_agreement rules minority (Locking.commitValid_bridge attributedA validA) lowerB

/-- Evidence remains executable against every future issued bond carrying this key,
including positive displaced or forfeited bonds and bonds in later recovery generations. -/
theorem evidence_future_liability {first : RegistryMachine.World} {key : Hash}
    {a b : Staking.Vote} {sa sb : Hash}
    (initialized : first.inbox.initialized = true)
    (rate : first.registry.config.slashBountyBps < 10000)
    (auth : RegistryMachine.Evidence first.registry first.inbox key a b sa sb) :
    FutureLiability first key a b sa sb := by
  intro later trace id current issued found keySame live positive free
  have stable := RegistryMachine.trace_stable trace
  have evidence := RegistryMachine.evidence_monotone stable.registry.verify stable.domain stable.generation auth
  rw [← keySame] at evidence
  exact RegistryMachine.slash_enabled issued found (stable.initialized initialized) free live positive
    (by simpa [stable.registry.config] using rate) evidence

/-- The retained-id form is the closed registry's permanent identity persistence theorem. -/
theorem evidence_retained_id {first later : RegistryMachine.World}
    (trace : RegistryMachine.Trace first later) {id : Nat} {original current : Registry.Bond}
    (issued : id < first.registry.ledger.nextId) (found : first.registry.ledger.bonds id = some original)
    (initialized : first.inbox.initialized = true) {a b : Staking.Vote} {sa sb : Hash}
    (auth : RegistryMachine.Evidence first.registry first.inbox original.value.key a b sa sb)
    (present : later.registry.ledger.bonds id = some current)
    (live : current.value.released = false) (positive : 0 < current.value.balance)
    (free : later.inbox.entered = false) (rate : first.registry.config.slashBountyBps < 10000) :
    ∃ next, RegistryMachine.execute later.registry later.inbox later.now (.slash id a b sa sb) = some next :=
  RegistryMachine.evidence_stays_slashable trace issued found initialized auth present live positive free rate

/-- Strict overlap carries individually authenticated same-round evidence for every
intersecting member, together with its complete future closed-trace liability. -/
theorem same_round_accountability {c : Consensus.Context} {signature : Consensus.Vote → Prop}
    {h round a b : Nat} {votesA votesB : List Consensus.Vote} {first : RegistryMachine.World}
    (validA : Consensus.CommitValid c signature h round a votesA)
    (validB : Consensus.CommitValid c signature h round b votesB) (conflict : a ≠ b)
    (refinement : SignatureRefinement first.registry signature)
    (domain : first.inbox.domain = c.domain) (generation : c.generation ≤ first.inbox.generation)
    (initialized : first.inbox.initialized = true) (rate : first.registry.config.slashBountyBps < 10000) :
    Committee.totalPower c.unit (Consensus.activeAt c h).members <
      3*Committee.totalPower c.unit (overlap c h votesA votesB) ∧
    ∀ entry ∈ overlap c h votesA votesB, ∃ va ∈ votesA, ∃ vb ∈ votesB,
      va.key = entry.key ∧ vb.key = entry.key ∧ ∃ sa sb,
      RegistryMachine.Evidence first.registry first.inbox entry.key
        (Accountability.evidence va) (Accountability.evidence vb) sa sb ∧
      FutureLiability first entry.key (Accountability.evidence va) (Accountability.evidence vb) sa sb := by
  refine ⟨Accountability.conflicting_commits_overlap validA validB,?_⟩
  intro entry mem
  obtain ⟨_,both⟩ := List.mem_filter.mp mem
  simp only [Bool.and_eq_true,List.contains_iff_mem] at both
  obtain ⟨va,inA,keyA⟩ := List.mem_map.mp both.1
  obtain ⟨vb,inB,keyB⟩ := List.mem_map.mp both.2
  have aValid := validA.2.2.2.1 va inA
  have bValid := validB.2.2.2.1 vb inB
  obtain ⟨sa,authA⟩ := refinement va aValid.2.2.2.2.2.2.2
  obtain ⟨sb,authB⟩ := refinement vb bValid.2.2.2.2.2.2.2
  rw [keyA] at authA
  rw [keyB] at authB
  have evidence : RegistryMachine.Evidence first.registry first.inbox entry.key
      (Accountability.evidence va) (Accountability.evidence vb) sa sb := by
    refine ⟨authA,authB,?_⟩
    apply decide_eq_true
    simp only [Accountability.evidence]
    refine ⟨aValid.1.trans domain.symm,bValid.1.trans domain.symm,
      aValid.2.1.trans bValid.2.1.symm,Nat.le_trans (Nat.le_of_eq aValid.2.1) generation,
      aValid.2.2.1.trans bValid.2.2.1.symm,aValid.2.2.2.1.trans bValid.2.2.2.1.symm,
      aValid.2.2.2.2.1.trans bValid.2.2.2.2.1.symm,Or.inr aValid.2.2.2.2.1,?_⟩
    rw [aValid.2.2.2.2.2.1,bValid.2.2.2.2.2.1]
    exact conflict
  exact ⟨va,inA,vb,inB,keyA,keyB,sa,sb,evidence,evidence_future_liability initialized rate evidence⟩

theorem cutoff_prefix (cfg : Config) (common more : List Blocks.Header) (h : Nat)
    (covered : requiredPrefix cfg h ≤ common.length) :
    cutoff cfg (common ++ more) h = cutoff cfg common h := by
  by_cases normal : cfg.originHeight < epoch cfg h*cfg.epochLen-1
  · have enough : decisionLookback cfg h-cfg.originHeight ≤ common.length := by
      simpa [requiredPrefix,normal] using covered
    simp only [cutoff,normal,ite_true,anchor_prefix cfg common more _ enough]
  · simp [cutoff,normal]

/-- Transport every concrete vote/election/quorum check using shared raw inputs, without
assuming equality of complete contexts or a finality conclusion. -/
theorem commit_valid_transport {cfg : Config} {registryA registryB : RegistryMachine.State}
    {common moreA moreB : List Blocks.Header} {h : Nat}
    (covered : requiredPrefix cfg h ≤ common.length)
    (registryPrefix : registryA.history.filter (fun cp => decide (cp.block ≤ cutoff cfg common h)) =
      registryB.history.filter (fun cp => decide (cp.block ≤ cutoff cfg common h)))
    {signature : Consensus.Vote → Prop} {round value : Nat} {votes : List Consensus.Vote}
    (valid : Consensus.CommitValid (derive cfg registryB (common ++ moreB)) signature h round value votes) :
    Consensus.CommitValid (derive cfg registryA (common ++ moreA)) signature h round value votes := by
  have committee := active_committee_prefix (moreA := moreA) (moreB := moreB) covered registryPrefix
  have registry := registry_from_raw_prefix registryPrefix
  have cutA := (active_cutoff cfg registryA (common ++ moreA) h).trans (cutoff_prefix cfg common moreA h covered)
  have cutB := (active_cutoff cfg registryB (common ++ moreB) h).trans (cutoff_prefix cfg common moreB h covered)
  refine ⟨valid.1,?_,valid.2.2.1,?_,?_⟩
  · have elected := valid.2.1
    change Committee.election cfg.unit cfg.minimum
      (Consensus.activeAt (derive cfg registryB (common ++ moreB)) h).cutoff cfg.nMax
      (registryAt registryB (Consensus.activeAt (derive cfg registryB (common ++ moreB)) h).cutoff) =
      some (Consensus.activeAt (derive cfg registryB (common ++ moreB)) h).members at elected
    change Committee.election cfg.unit cfg.minimum
      (Consensus.activeAt (derive cfg registryA (common ++ moreA)) h).cutoff cfg.nMax
      (registryAt registryA (Consensus.activeAt (derive cfg registryA (common ++ moreA)) h).cutoff) =
      some (Consensus.activeAt (derive cfg registryA (common ++ moreA)) h).members
    rw [cutB] at elected
    rw [cutA,registry,committee]
    exact elected
  · intro vote member
    have v := valid.2.2.2.1 vote member
    refine ⟨v.1,v.2.1,v.2.2.1,v.2.2.2.1,v.2.2.2.2.1,v.2.2.2.2.2.1,?_,v.2.2.2.2.2.2.2⟩
    rw [committee]
    exact v.2.2.2.2.2.2.1
  · change 2*Committee.totalPower cfg.unit (Consensus.activeAt (derive cfg registryA (common ++ moreA)) h).members <
      3*Committee.totalPower cfg.unit ((Consensus.activeAt (derive cfg registryA (common ++ moreA)) h).members.filter
        (fun e => (votes.map Consensus.Vote.key).contains e.key))
    rw [committee]
    exact valid.2.2.2.2

/-- The two current histories may differ above the authenticated decision prefix.
Every overlapping key receives evidence and future liability for their common authority. -/
theorem shared_prefix_accountability {cfg : Config} {registryA registryB : RegistryMachine.State}
    {common moreA moreB : List Blocks.Header} {h : Nat}
    (covered : requiredPrefix cfg h ≤ common.length)
    (registryPrefix : registryA.history.filter (fun cp => decide (cp.block ≤ cutoff cfg common h)) =
      registryB.history.filter (fun cp => decide (cp.block ≤ cutoff cfg common h)))
    {signature : Consensus.Vote → Prop} {round a b : Nat} {votesA votesB : List Consensus.Vote}
    {first : RegistryMachine.World}
    (validA : Consensus.CommitValid (derive cfg registryA (common ++ moreA)) signature h round a votesA)
    (validB : Consensus.CommitValid (derive cfg registryB (common ++ moreB)) signature h round b votesB)
    (conflict : a ≠ b) (refinement : SignatureRefinement first.registry signature)
    (domain : first.inbox.domain = cfg.domain) (generation : cfg.generation ≤ first.inbox.generation)
    (initialized : first.inbox.initialized = true) (rate : first.registry.config.slashBountyBps < 10000) :
    Accountable first (derive cfg registryA (common ++ moreA)) h votesA votesB :=
  same_round_accountability validA (commit_valid_transport covered registryPrefix validB)
    conflict refinement domain generation initialized rate

theorem required_prefix_eq (cfg : Config) (h : Nat) :
    requiredPrefix cfg h = decisionLookback cfg h-cfg.originHeight := by
  unfold requiredPrefix decisionLookback
  split
  · rfl
  · omega

theorem required_prefix_monotone (cfg : Config) {a b : Nat} (order : a ≤ b) :
    requiredPrefix cfg a ≤ requiredPrefix cfg b := by
  rw [required_prefix_eq,required_prefix_eq]
  unfold decisionLookback epoch
  exact Nat.sub_le_sub_right (Nat.sub_le_sub_right
    (Nat.mul_le_mul_right cfg.epochLen (Nat.div_le_div_right (Nat.sub_le_sub_right order 1))) 2) cfg.originHeight

/-- A complete terminal decision prefix covers every earlier per-block committee query. -/
theorem ready_earlier {cfg : Config} {registry : RegistryMachine.State} {archive : List Blocks.Header}
    {a b : Nat} (order : a ≤ b) (ready : Ready cfg registry archive b) : Ready cfg registry archive a := by
  rcases ready with ⟨epoch,floor,heights,generations,anchors,history,covered,initial⟩
  exact ⟨epoch,floor,heights,generations,anchors,history,
    Nat.le_trans (required_prefix_monotone cfg order) covered,initial⟩

theorem agreement_get {xs ys : List Blocks.Header} (agreed : HeaderAgreement xs ys)
    {n : Nat} {a b : Blocks.Header} (ha : xs[n]? = some a) (hb : ys[n]? = some b) : a = b := by
  induction xs generalizing ys n with
  | nil => simp at ha
  | cons x xs ih =>
    cases ys with
    | nil => simp at hb
    | cons y ys =>
      cases n with
      | zero =>
        have xa := Option.some.inj ha
        have yb := Option.some.inj hb
        exact xa.symm.trans (agreed.1.trans yb)
      | succ n => exact ih agreed.2 ha hb

theorem agreement_take {xs ys : List Blocks.Header} (agreed : HeaderAgreement xs ys) :
    xs.take (min xs.length ys.length) = ys.take (min xs.length ys.length) := by
  induction xs generalizing ys with
  | nil => simp
  | cons x xs ih =>
    cases ys with
    | nil => simp
    | cons y ys =>
      have tail := ih agreed.2
      have len : min (xs.length+1) (ys.length+1) = min xs.length ys.length+1 := by omega
      simp only [List.length_cons,len,List.take_succ_cons]
      rw [agreed.1,tail]

/-- At the next candidate after an already equal prefix, authority queries only that
prefix (in fact D≤h−3). No future candidate header is used to choose its own authority. -/
theorem next_required_prefix (cfg : Config) (prior : List Blocks.Header) (parent : Blocks.Header)
    (height : parent.height = cfg.originHeight+prior.length) :
    requiredPrefix cfg (parent.height+1) ≤ prior.length := by
  rw [required_prefix_eq]
  have before := decision_lookback_before cfg (parent.height+1)
  omega

private theorem chains_after_prefix {cfg : Config} {registry : RegistryMachine.State}
    {engine : Engine} {policyA policyB : Blocks.GenerationPolicy}
    (binding : CometHeaderBinding policyA policyB)
    (prior : List Blocks.Header) (parent : Blocks.Header)
    (as bs : List Blocks.Block)
    (height : parent.height = cfg.originHeight+prior.length)
    (contextA : policyA.consensus = derive cfg registry (prior ++ as.map Blocks.Block.header))
    (contextB : policyB.consensus = derive cfg registry (prior ++ bs.map Blocks.Block.header))
    (validA : Blocks.Chain policyA parent as) (validB : Blocks.Chain policyB parent bs)
    (honesty : ChainHonesty engine cfg policyA parent as)
    (attrA : ChainAttribution engine cfg parent as) (attrB : ChainAttribution engine cfg parent bs) :
    HeaderAgreement (as.map Blocks.Block.header) (bs.map Blocks.Block.header) := by
  induction as generalizing bs prior parent with
  | nil => trivial
  | cons a restA ih =>
    cases bs with
    | nil => trivial
    | cons b restB =>
      have firstA := validA.1
      have firstB := validB.1
      have nextA := firstA.header.1
      have nextB := firstB.header.1
      have sameHeight : b.header.height = a.header.height := nextB.trans nextA.symm
      have covered : requiredPrefix cfg a.header.height ≤ prior.length := by
        rw [nextA]
        exact next_required_prefix cfg prior parent height
      obtain ⟨rules,minority⟩ := honesty (parent,a) (by simp [Blocks.pairs])
      rw [contextA] at rules minority
      have voteA := attrA (parent,a) (by simp [Blocks.pairs])
      have voteB := attrB (parent,b) (by simp [Blocks.pairs])
      have commitA := firstA.commit
      have commitB := firstB.commit
      rw [contextA] at commitA
      rw [contextB,sameHeight] at commitB
      rw [sameHeight] at voteB
      have hashes : a.header.cometHash = b.header.cometHash :=
        shared_prefix_agreement covered rfl rules minority voteA voteB commitA commitB
      have same := binding parent a b firstA firstB hashes
      refine ⟨same,?_⟩
      have tailB : Blocks.Chain policyB a.header restB := by rw [same]; exact validB.2
      have attrTailA : ChainAttribution engine cfg a.header restA := by
        intro pair mem
        exact attrA pair (List.mem_cons_of_mem _ mem)
      have attrTailB : ChainAttribution engine cfg a.header restB := by
        rw [same]
        intro pair mem
        exact attrB pair (List.mem_cons_of_mem _ mem)
      have honestTail : ChainHonesty engine cfg policyA a.header restA := by
        intro pair mem
        exact honesty pair (List.mem_cons_of_mem _ mem)
      apply ih (prior := prior ++ [a.header]) (parent := a.header) (bs := restB)
        (by simp only [List.length_append,List.length_singleton]; omega)
        ?_ ?_ validA.2 tailB honestTail attrTailA attrTailB
      · simpa only [List.append_assoc,List.singleton_append,List.map_cons] using contextA
      · simp only [List.map_cons] at contextB
        rw [← same] at contextB
        simpa only [List.append_assoc,List.singleton_append] using contextB

/-- Complete current-generation chains derive their authorities from their own entire
header archives. Equal prefixes are proved inductively, not supplied: a first divergence
would share the D(t) authority, and actual honest locking forces its Comet hashes equal.
The canonical decoder/deterministic execution boundary then gives full header equality. -/
theorem full_chain_agreement {cfg : Config} {registry : RegistryMachine.State}
    {engine : Engine} {policyA policyB : Blocks.GenerationPolicy} {origin : Blocks.Header}
    {as bs : List Blocks.Block}
    (originHeight : origin.height = cfg.originHeight)
    (contextA : policyA.consensus = derive cfg registry (as.map Blocks.Block.header))
    (contextB : policyB.consensus = derive cfg registry (bs.map Blocks.Block.header))
    (validA : Blocks.Chain policyA origin as) (validB : Blocks.Chain policyB origin bs)
    (binding : CometHeaderBinding policyA policyB)
    (honesty : ChainHonesty engine cfg policyA origin as)
    (attrA : ChainAttribution engine cfg origin as) (attrB : ChainAttribution engine cfg origin bs) :
    HeaderAgreement (as.map Blocks.Block.header) (bs.map Blocks.Block.header) :=
  chains_after_prefix binding [] origin as bs (by simpa using originHeight)
    contextA contextB validA validB honesty attrA attrB

/-- Pointwise form for every overlapping full header, irrespective of batch length. -/
theorem full_chain_header_at {cfg : Config} {registry : RegistryMachine.State}
    {engine : Engine} {policyA policyB : Blocks.GenerationPolicy} {origin : Blocks.Header}
    {as bs : List Blocks.Block}
    (originHeight : origin.height = cfg.originHeight)
    (contextA : policyA.consensus = derive cfg registry (as.map Blocks.Block.header))
    (contextB : policyB.consensus = derive cfg registry (bs.map Blocks.Block.header))
    (validA : Blocks.Chain policyA origin as) (validB : Blocks.Chain policyB origin bs)
    (binding : CometHeaderBinding policyA policyB)
    (honesty : ChainHonesty engine cfg policyA origin as)
    (attrA : ChainAttribution engine cfg origin as) (attrB : ChainAttribution engine cfg origin bs)
    {n : Nat} {a b : Blocks.Header}
    (atA : (as.map Blocks.Block.header)[n]? = some a)
    (atB : (bs.map Blocks.Block.header)[n]? = some b) : a = b :=
  agreement_get (full_chain_agreement originHeight contextA contextB validA validB binding honesty attrA attrB) atA atB

end Etna.Design.Current.Finality
