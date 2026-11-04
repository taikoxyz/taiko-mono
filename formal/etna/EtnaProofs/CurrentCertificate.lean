import EtnaProofs.CurrentReference
import EtnaProofs.CurrentArchive
import EtnaProofs.CurrentFootprintHistory

namespace Etna.Design.Current.Protocol
set_option linter.unusedSimpArgs false
set_option maxHeartbeats 400000
set_option maxRecDepth 30000
set_option backward.isDefEq.respectTransparency false

private theorem latest_bounded (history : List RegistryHistory.Snapshot) {cutoff bound : Nat}
    (within : cutoff ≤ bound) :
    RegistryHistory.latestSnapshot (history.filter (fun cp => decide (cp.block ≤ bound))) cutoff =
      RegistryHistory.latestSnapshot history cutoff := by
  induction history with
  | nil => rfl
  | cons cp rest ih =>
    by_cases low : cp.block ≤ cutoff
    · have high : cp.block ≤ bound := Nat.le_trans low within
      simp [RegistryHistory.latestSnapshot,List.filter_cons,low,high]
    · by_cases high : cp.block ≤ bound
      · simpa [RegistryHistory.latestSnapshot,List.filter_cons,low,high] using ih
      · simpa [RegistryHistory.latestSnapshot,List.filter_cons,low,high] using ih

private theorem registry_at_same {a b : RegistryMachine.State} {reference cutoff : Nat}
    (same : a.history.filter (fun cp => decide (cp.block ≤ reference)) =
      b.history.filter (fun cp => decide (cp.block ≤ reference)))
    (within : cutoff ≤ reference) : Finality.registryAt a cutoff = Finality.registryAt b cutoff := by
  unfold Finality.registryAt
  rw [← latest_bounded a.history within,← latest_bounded b.history within,same]

private theorem selected_same {cfg : Finality.Config} {a b : RegistryMachine.State}
    {archive : List Header} {reference target cutoff : Nat}
    (same : a.history.filter (fun cp => decide (cp.block ≤ reference)) =
      b.history.filter (fun cp => decide (cp.block ≤ reference)))
    (within : cutoff ≤ reference) :
    Consensus.selected (Finality.derive cfg a archive) target cutoff =
      Consensus.selected (Finality.derive cfg b archive) target cutoff := by
  simp only [Consensus.selected,Finality.derive]
  rw [registry_at_same same within]

private theorem normal_same {cfg : Finality.Config} {a b : RegistryMachine.State}
    {archive : List Header} {reference : Nat}
    (same : a.history.filter (fun cp => decide (cp.block ≤ reference)) =
      b.history.filter (fun cp => decide (cp.block ≤ reference)))
    (origin : cfg.originBlock ≤ reference)
    (bounds : ∀ h ∈ archive, h.anchor.number ≤ reference) (target : Nat) :
    Consensus.normal (Finality.derive cfg a archive) target =
      Consensus.normal (Finality.derive cfg b archive) target := by
  apply selected_same same
  exact Nat.max_le.mpr ⟨Archive.anchor_bounded origin bounds _,origin⟩

private theorem active_same {cfg : Finality.Config} {a b : RegistryMachine.State}
    {archive : List Header} {reference : Nat}
    (same : a.history.filter (fun cp => decide (cp.block ≤ reference)) =
      b.history.filter (fun cp => decide (cp.block ≤ reference)))
    (genesis : cfg.genesisCutoff ≤ cfg.originBlock) (origin : cfg.originBlock ≤ reference)
    (bounds : ∀ h ∈ archive, h.anchor.number ≤ reference) (height : Nat) :
    Consensus.activeAt (Finality.derive cfg a archive) height =
      Consensus.activeAt (Finality.derive cfg b archive) height := by
  unfold Consensus.activeAt
  dsimp only [Consensus.epoch,Consensus.switchHeight,Finality.derive]
  by_cases normal : cfg.originHeight < (height-1)/cfg.epochLen*cfg.epochLen-1
  · simp only [normal,ite_true]
    exact normal_same same origin bounds _
  · simp only [normal,ite_false]
    unfold Consensus.initial
    dsimp only [Finality.derive]
    apply selected_same same
    split
    · exact Nat.le_trans genesis origin
    · exact origin

private theorem commit_same {cfg : Finality.Config} {a b : RegistryMachine.State}
    {archive : List Header} {reference : Nat}
    (same : a.history.filter (fun cp => decide (cp.block ≤ reference)) =
      b.history.filter (fun cp => decide (cp.block ≤ reference)))
    (genesis : cfg.genesisCutoff ≤ cfg.originBlock) (origin : cfg.originBlock ≤ reference)
    (bounds : ∀ h ∈ archive, h.anchor.number ≤ reference)
    {signature : Consensus.Vote → Prop} {height round hash : Nat} {votes : List Consensus.Vote}
    (valid : Consensus.CommitValid (Finality.derive cfg a archive) signature height round hash votes) :
    Consensus.CommitValid (Finality.derive cfg b archive) signature height round hash votes := by
  have active := active_same same genesis origin bounds height
  have cutBound : (Consensus.activeAt (Finality.derive cfg a archive) height).cutoff ≤ reference := by
    rw [Finality.active_cutoff]
    unfold Finality.cutoff Finality.initialCutoff
    split
    · exact Nat.max_le.mpr ⟨Archive.anchor_bounded origin bounds _,origin⟩
    · split
      · exact Nat.le_trans genesis origin
      · exact origin
  have lookup := registry_at_same same cutBound
  unfold Consensus.CommitValid Consensus.ElectionValid Consensus.VoteValid Consensus.signedPower at valid ⊢
  rw [← active]
  dsimp only [Finality.derive] at valid ⊢
  dsimp only [Finality.derive] at lookup
  rw [← lookup]
  exact valid

private theorem matching_lift {env : Environment} {source w : World}
    (past : source.history.IsPrefix w.history)
    {a : BlockValidity.Anchor} {s : Snapshot}
    (found : matchingSnapshot env source a = some s) :
    matchingSnapshot env w a = some s := by
  obtain ⟨later,shape⟩ := past
  unfold matchingSnapshot at found ⊢
  rw [← shape,List.find?_append,found]
  rfl

private theorem closed_reference {env : Environment} {w : World} {reference : Nat} :
    referenceHash env (certificateWorld env w reference) reference = referenceHash env w reference := by
  simp [referenceHash,referencePrefix,certificateWorld,List.take_take]

private theorem opening_lift {env : Environment} {source w : World}
    (past : source.history.IsPrefix w.history)
    {a : BlockValidity.Anchor} {f : Snapshot → Bool}
    (opened : ((matchingSnapshot env source a).map f).getD false = true) :
    ((matchingSnapshot env w a).map f).getD false = true := by
  cases found : matchingSnapshot env source a with
  | none => simp [found] at opened
  | some s => simpa [found,matching_lift past found] using opened

private theorem valid_live {env : Environment} {source w : World} {reference : Nat} {archive : List Header}
    (fp : CertificateStorage source w reference)
    (past : source.history.IsPrefix w.history)
    (genesis : (config source).genesisCutoff ≤
      (config source).originBlock)
    (origin : (config source).originBlock ≤ reference)
    (bounds : ∀ h ∈ archive, h.anchor.number ≤ reference)
    {p : Header} {b : Block}
    (valid : Blocks.Valid (policy env source archive reference) p b) :
    Blocks.Valid (policy env w archive reference) p b := by
  have grid : source.inbox.gridK = w.inbox.gridK := congrArg Parameters.gridK fp.parameters
  have age : source.inbox.maxAnchorAge = w.inbox.maxAnchorAge := congrArg Parameters.maxAnchorAge fp.parameters
  have delay : source.inbox.forcedDelay = w.inbox.forcedDelay := congrArg Parameters.forcedDelay fp.parameters
  have unsettled : source.inbox.configuration.unsettled = w.inbox.configuration.unsettled := congrArg (fun x : Parameters => x.committee.unsettled) fp.parameters
  have active (height : Nat) :
      Consensus.activeAt (policy env source archive reference).consensus height =
        Consensus.activeAt (policy env w archive reference).consensus height := by
    change Consensus.activeAt (Finality.derive (config source) source.registry.registry archive) height =
      Consensus.activeAt (Finality.derive (config w) w.registry.registry archive) height
    rw [← fp.configuration]
    exact active_same fp.registry genesis origin bounds height
  constructor
  · simpa only [policy,Finality.derive,← fp.configuration,← grid,← unsettled] using valid.config
  · simpa only [policy,Finality.derive,← fp.configuration] using valid.floor
  · have header := valid.header
    unfold Blocks.HeaderValid at header ⊢
    rw [← active b.header.height,← active (b.header.height+1)]
    simpa only [policy,Finality.derive,← fp.configuration] using header
  · constructor
    · simpa only [Blocks.ParentAnchorValid,policy,Finality.derive,← fp.configuration] using valid.anchor.parent
    · simpa only [policy,Finality.derive,← fp.configuration] using valid.anchor.origin
    · exact valid.anchor.reference
    · exact valid.anchor.numberRange
    · simpa only [policy,Finality.derive,← fp.configuration] using valid.anchor.generation
    · exact valid.anchor.timestamp
    · simpa only [policy,← age] using valid.anchor.age
    · simpa only [policy,← unsettled] using valid.anchor.pressure
    · simpa only [policy,Finality.derive,← fp.configuration] using valid.anchor.history
    · obtain ⟨s,found⟩ := Option.isSome_iff_exists.mp valid.anchor.authenticated
      exact Option.isSome_iff_exists.mpr ⟨s,matching_lift past found⟩
  · have witness := valid.witness
    unfold Blocks.WitnessValid at witness ⊢
    simp only [policy,Finality.derive,← fp.configuration] at witness ⊢
    by_cases switched : (b.header.height+1) % (config source).epochLen = 0
    · simp only [switched,ite_true] at witness ⊢
      cases carried : b.body.committeeWitness with
      | none => simp [carried] at witness
      | some wit =>
        simp only [carried] at witness
        dsimp only at witness ⊢
        have normal := normal_same (cfg := config source) (archive := archive)
          fp.registry origin bounds ((b.header.height+1)/(config source).epochLen)
        refine ⟨witness.1.trans normal,witness.2.1,witness.2.2.1,?_,?_⟩
        · obtain ⟨s,member,opened⟩ := List.any_eq_true.mp witness.2.2.2.1
          refine List.any_eq_true.mpr ⟨s,past.subset member,?_⟩
          have unit : source.inbox.configuration.unit = w.inbox.configuration.unit := congrArg Finality.Config.unit fp.configuration
          have minimum : source.inbox.configuration.minimum = w.inbox.configuration.minimum := congrArg Finality.Config.minimum fp.configuration
          have maximum : source.inbox.configuration.nMax = w.inbox.configuration.nMax := congrArg Finality.Config.nMax fp.configuration
          simpa only [← unit,← minimum,← maximum] using opened
        · have within := Nat.le_trans witness.2.2.1 valid.anchor.reference
          have lookup := registry_at_same fp.registry within
          have elected := witness.2.2.2.2
          unfold Consensus.ElectionValid at elected ⊢
          dsimp only at elected ⊢
          rw [← lookup]
          exact elected
    · simpa only [switched,ite_false] using witness
  · have commit := valid.commit
    change Consensus.CommitValid (Finality.derive (config w) w.registry.registry archive)
      env.signature b.header.height b.body.round b.header.cometHash b.body.votes
    rw [← fp.configuration]
    exact commit_same fp.registry genesis origin bounds commit
  · simpa only [policy,← delay] using valid.forced
  · exact valid.selected
  · exact valid.schedule
  · exact opening_lift past valid.scheduleOpening
  · simpa only [policy,← fp.start] using valid.notStopped
  · exact valid.execution
  · exact valid.payload
  · exact valid.positionZero
  · exact valid.fields
  · intro wit carried
    exact opening_lift past (valid.storage wit carried)
  · have domain : source.inbox.domain = w.inbox.domain := congrArg Finality.Config.domain fp.configuration
    have unit : source.inbox.configuration.unit = w.inbox.configuration.unit := congrArg Finality.Config.unit fp.configuration
    have minimum : source.inbox.configuration.minimum = w.inbox.configuration.minimum := congrArg Finality.Config.minimum fp.configuration
    have maximum : source.inbox.configuration.nMax = w.inbox.configuration.nMax := congrArg Finality.Config.nMax fp.configuration
    change w.inbox.committeeConfig = env.configHash (Encoding.configWords w.inbox.domain.l2ChainId
      w.inbox.domain.registry w.inbox.configuration.unit w.inbox.configuration.minimum w.inbox.configuration.nMax
      w.inbox.configuration.unsettled)
    rw [← fp.committee,← domain,← unit,← minimum,← maximum,← unsettled]
    exact valid.configuration
  · rfl

private theorem chain_live {env : Environment} {source w : World} {reference : Nat} {archive : List Header}
    (fp : CertificateStorage source w reference) (past : source.history.IsPrefix w.history)
    (genesis : (config source).genesisCutoff ≤ (config source).originBlock)
    (origin : (config source).originBlock ≤ reference)
    (bounds : ∀ h ∈ archive, h.anchor.number ≤ reference) {p : Header} {bs : List Block}
    (chain : Blocks.Chain (policy env source archive reference) p bs) :
    Blocks.Chain (policy env w archive reference) p bs := by
  induction bs generalizing p with
  | nil => trivial
  | cons b rest ih => exact ⟨valid_live fp past genesis origin bounds chain.1,ih chain.2⟩

private theorem ready_live {source w : World} {reference : Nat} {archive : List Header}
    (fp : CertificateStorage source w reference) (origin : (config source).originBlock ≤ reference)
    {height : Nat} (ready : Finality.Ready (config source) source.registry.registry archive height) :
    Finality.Ready (config w) w.registry.registry archive height := by
  rw [← fp.configuration]
  rcases ready with ⟨epoch,floor,heights,generations,anchors,history,covered,initial⟩
  refine ⟨epoch,floor,heights,generations,anchors,fp.ordered,covered,?_⟩
  have within : Finality.initialCutoff (config source) ≤ reference := by
    unfold Finality.initialCutoff
    split
    · exact Nat.le_trans floor origin
    · exact origin
  have latest : RegistryHistory.latestSnapshot source.registry.registry.history (Finality.initialCutoff (config source)) =
      RegistryHistory.latestSnapshot w.registry.registry.history (Finality.initialCutoff (config source)) := by
    rw [← latest_bounded source.registry.registry.history within,← latest_bounded w.registry.registry.history within,fp.registry]
  rw [← latest]
  exact initial

private theorem statement_live {env : Environment} {source w : World} {reference : Nat} {archive : List Header}
    (fp : CertificateStorage source w reference)
    (genesis : (config source).genesisCutoff ≤ (config source).originBlock)
    (origin : (config source).originBlock ≤ reference)
    (bounds : ∀ h ∈ archive, h.anchor.number ≤ reference)
    (referenceHash : Protocol.referenceHash env source reference = Protocol.referenceHash env w reference)
    (p : Header) (bs : List Block) (blobs : List Hash) :
    Blocks.statement (policy env source archive reference) p bs blobs =
      Blocks.statement (policy env w archive reference) p bs blobs := by
  have active : Consensus.activeAt (policy env source archive reference).consensus (Blocks.terminal p bs).height =
      Consensus.activeAt (policy env w archive reference).consensus (Blocks.terminal p bs).height := by
    change Consensus.activeAt (Finality.derive (config source) source.registry.registry archive) _ =
      Consensus.activeAt (Finality.derive (config w) w.registry.registry archive) _
    rw [← fp.configuration]
    exact active_same fp.registry genesis origin bounds _
  have grid : source.inbox.gridK = w.inbox.gridK := congrArg Parameters.gridK fp.parameters
  unfold Blocks.statement
  dsimp only
  rw [active]
  simp only [policy,Finality.derive,fp.configuration,fp.committee,grid,referenceHash]

/-- Raw live storage and bounded historical selection inputs derive the operational
certificate. Neither live block validity nor an active committee equality is a premise. -/
theorem batch_certificate_live {env : Environment} {w : World} {d : StatementData}
    {archive : List Header} {p : Header} {bs : List Block}
    (cert : BatchCertificate env w d archive p bs)
    (fp : CertificateFootprint env w d.input.l1ReferenceBlockNumber) :
    LiveBatchCertificate env w d archive p bs := by
  obtain ⟨checked,_,_⟩ := cert
  obtain ⟨ready,valid,binding,hashp,hashes,start,auth⟩ := checked
  have archiveData := auth
  obtain ⟨_,_,_,_,_,_,_,_,_,_,origin,bounds⟩ := archiveData
  refine ⟨ready_live fp origin ready,⟨chain_live fp (List.take_prefix _ _) ready.2.1 origin bounds valid.1,valid.2⟩,
    binding.trans (statement_live fp ready.2.1 origin bounds closed_reference p bs _),hashp,hashes,?_,?_⟩
  · simpa only [fp.start] using start
  · simpa only [certificate_world_idempotent,fp.configuration] using auth

/-- Binding the actual submitted statement to its reference-local certificate fixes the
closed generation. Actual history then supplies the live storage used by that guest. -/
theorem certified_statement_footprint {env : Environment} {registry : RegistryMachine.State}
    {w : World} {a : Landing} (genesis : RegistryMachine.Genesis registry)
    (reach : Trace env (empty env registry) w)
    (cert : Certifies env w (statement env w a)) :
    CertificateFootprint env w a.input.l1ReferenceBlockNumber := by
  obtain ⟨archive,p,bs,checked,complete,origin⟩ := cert
  have binding := checked.2.2.1
  change (referencePrefix w a.input.l1ReferenceBlockNumber).map Snapshot.number =
    List.range (a.input.l1ReferenceBlockNumber+1) at complete
  change (certificateOrigin (certificateWorld env w a.input.l1ReferenceBlockNumber)).isSome = true at origin
  change statement env w a = Blocks.statement
    (policy env (certificateWorld env w a.input.l1ReferenceBlockNumber) archive a.input.l1ReferenceBlockNumber)
    p bs a.blobs at binding
  have lastNumber : ((referencePrefix w a.input.l1ReferenceBlockNumber).getLast?.map Snapshot.number) =
      some a.input.l1ReferenceBlockNumber := by
    rw [← List.getLast?_map,complete,List.getLast?_range]
    simp
  obtain ⟨s,last,number⟩ := Option.map_eq_some_iff.mp lastNumber
  have member : s ∈ w.history := (List.take_subset _ _) (List.mem_of_getLast? last)
  obtain ⟨before,prior,later,inbox,start⟩ := closed_snapshot_provenance reach s member
  have sourceInbox : (certificateWorld env w a.input.l1ReferenceBlockNumber).inbox = before.inbox := by
    simpa only [certificateWorld,last,Option.getD_some] using inbox
  have sourceStart : (certificateWorld env w a.input.l1ReferenceBlockNumber).start = before.start := by
    simpa only [certificateWorld,last,Option.getD_some] using start
  have generation := congrArg StatementData.generation binding
  change w.inbox.generation = (certificateWorld env w a.input.l1ReferenceBlockNumber).inbox.generation at generation
  rw [sourceInbox] at generation
  have started : before.start.isSome = true := by
    cases absent : before.start with
    | some _ => rfl
    | none =>
      have records := trace_unstarted_records prior absent
      simp only [certificateOrigin,recordAt] at origin
      rw [sourceInbox,records] at origin
      cases origin
  have parameters := Economics.trace_same_generation_parameters later generation
  have configuration := trace_same_generation_config prior later started generation
  have committee := congrArg StatementData.config binding
  change w.inbox.committeeConfig = (certificateWorld env w a.input.l1ReferenceBlockNumber).inbox.committeeConfig at committee
  constructor
  · change config (certificateWorld env w a.input.l1ReferenceBlockNumber) = config w
    simpa only [config,sourceInbox] using configuration.symm
  · change parametersOf (certificateWorld env w a.input.l1ReferenceBlockNumber).inbox = parametersOf w.inbox
    rw [sourceInbox]; exact parameters.symm
  · exact committee.symm
  · rw [sourceStart]; exact (trace_started_metadata prior later started generation).1.symm
  · have history := (Economics.closed_registry_history reach s member).2
    simp only [certificateWorld,last,Option.getD_some]
    change s.registryHistory.filter (fun cp => decide (cp.block ≤ a.input.l1ReferenceBlockNumber)) = _
    rw [← number]
    exact history.symm
  · exact (Economics.registry_history_time genesis reach).1

theorem image_certificate_live {env : Environment} {w : World} {image : Hash} {d : StatementData}
    (cert : ImageCertifies env w image d)
    (footprint : CertificateFootprint env w d.input.l1ReferenceBlockNumber) : LiveCertifies env w d := by
  obtain ⟨archive,p,bs,checked,_⟩ := cert
  exact ⟨archive,p,bs,batch_certificate_live checked footprint⟩

/-- The authenticated actual governing cutoff is no later than the reference. -/
theorem live_certificate_snapshot_bound {env : Environment} {w : World} {d : StatementData}
    (cert : LiveCertifies env w d) : d.input.activeCommitteeSnapshot ≤ d.input.l1ReferenceBlockNumber := by
  obtain ⟨archive,p,bs,ready,_,binding,_,_,_,auth⟩ := cert
  have same := congrArg (fun x : StatementData => x.input.activeCommitteeSnapshot) binding
  change d.input.activeCommitteeSnapshot = (Consensus.activeAt (policy env w archive d.input.l1ReferenceBlockNumber).consensus
    (Blocks.terminal p bs).height).cutoff at same
  rw [same]
  exact Archive.active_cutoff_bounded auth ready

theorem certificate_snapshot_bound {env : Environment} {w : World} {d : StatementData}
    (cert : Certifies env w d) : d.input.activeCommitteeSnapshot ≤ d.input.l1ReferenceBlockNumber := by
  obtain ⟨archive,p,bs,checked,_,_⟩ := cert
  exact live_certificate_snapshot_bound ⟨archive,p,bs,checked⟩

theorem certificate_origin_present {env : Environment} {w : World} {d : StatementData}
    (cert : Certifies env w d) :
    (certificateOrigin (certificateWorld env w d.input.l1ReferenceBlockNumber)).isSome = true := by
  obtain ⟨_,_,_,_,_,origin⟩ := cert
  exact origin

theorem certificate_prefix_complete {env : Environment} {w : World} {d : StatementData}
    (cert : Certifies env w d) :
    (referencePrefix w d.input.l1ReferenceBlockNumber).map Snapshot.number =
      List.range (d.input.l1ReferenceBlockNumber+1) := by
  obtain ⟨_,_,_,_,complete,_⟩ := cert
  exact complete

end Etna.Design.Current.Protocol
