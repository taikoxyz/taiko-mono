import EtnaWitnesses.NonVacuity.CurrentRecovery

/-! The premises of H1–H4 can hold of one switching deployment (reports/recoverability.md,
Joint witness). Mainnet takes over from the Unzen rollup, so this is the profile it needs:
one environment with an Unzen Inbox, a registry and an engine satisfy H1–H3's fifteen
`Premises` and H4's `RecoveryPremises` together, and a reachable initialized world in it
satisfies `LiveAt`. `live_recovers` then applies H4's proof (`Recovery.recoverable`) there.

It is `RecoveryNonVacuity`'s environment (the same `Encoding.headerHash`, physical-parent
decoder, catalogue definition, ideal classical verifier, online key and engine) with the
switching fields set:
- `core.unzenInbox` = 99, and `forkTime` = 1036, the time of L1 block 3;
- one legacy header `legacy` at S = 5 with timestamp 900, state root 55 and a hash-bound EL
  hash, the only header `unzenRoot` admits;
- `unzenNextProposal` = 2, and `unzenValid` accepts exactly one proof (77) of the final
  proposal 1, for `legacy`;
- `unzenParent` returns 0, the empty lane's finalized hash, so `unzenProve`'s link check passes
  from the empty lane. This makes `UnzenExtension` vacuous: its only valid proof has boundary 0,
  where the parent hash is 0, and no header with EL hash 0 is hash-bound (`Encoding.headerHash`
  is odd).
The reachable world `live` has `setOrigin` writing S = 5 with `legacy`'s hash and state root,
and no Unzen proof yet. So H4's path itself runs `unzenProve` and passes the first-landing
fence, including its check that the Unzen checkpoint is at S, on its way to a landing.
The proofs repeat `RecoveryNonVacuity`'s for this environment, whose theorems are private.
Commitments are ideal unbounded Nat codes, not Keccak. -/
namespace Etna.Design.Current.Protocol.RecoverySwitchNonVacuity
open Etna.Design Etna.Design.Current Protocol

/-- The legacy header's EL fields at S = 5: state root 55, timestamp 900 (before `forkTime`), a
zero anchor, and Etna's zero Comet hash, FI cursor and validator-state hash. -/
def legacyFields : Header := ⟨5,0,55,0,0,900,⟨0,0,0,0,0,0,0⟩,0⟩

/-- The Unzen Inbox's final header: `legacyFields` with its EL hash, so it is hash-bound. -/
def legacy : Header := { legacyFields with elHash := Encoding.headerHash legacyFields }

/-- `RecoveryNonVacuity.base` with the switching fields: Unzen Inbox 99, fork time 1036 (L1 block
3), final proposal 1, proven only by proof 77 of `legacy`, and a parent decoder that returns the
empty lane's finalized hash 0. -/
noncomputable def base : Environment := { RecoveryNonVacuity.base with
  core := ⟨NonVacuity.domain,7,8,99,1036,9⟩
  unzenNextProposal := 2
  unzenValid := fun proposal h proof => decide (proposal = 1 ∧ h = legacy ∧ proof = 77)
  unzenRoot := fun h => h = legacy
  unzenParent := fun _ _ _ _ => 0 }

open Classical in
/-- `base` with `RecoveryNonVacuity`'s ideal checker, reading certification under `base`. -/
noncomputable def env : Environment := { base with
  verify := fun _ _ image _ d => decide (∃ w, referenceHash base w d.input.l1ReferenceBlockNumber = d.referenceHash ∧
    ImageCertifies base w image d) }

/-- Register one bond for the online key at L1 block 0 (active from block 1), advance to block
2, initialize (a switching network, so no start is written), advance to the fork time at block
3, and let the origin writer set S = 5 from `legacy`. No Unzen proof has been submitted. -/
noncomputable def registered : World :=
  transact env (empty env RecoveryNonVacuity.registry) (.registry 8 (.register 7 8 NonVacuity.unit 1))
noncomputable def activated : World := transact env registered (.advance 2)
noncomputable def initialized : World := transact env activated (.initializeInbox 7)
noncomputable def forked : World := transact env initialized (.advance 3)
noncomputable def live : World := transact env forked (.setOrigin 8 5 legacy.elHash legacy.stateRoot)

/-! The verifier and the L1 commitment. -/

private theorem reference_binding : ReferenceBinding env := by
  intro a b number same
  change Encoding.referenceHash a number = Encoding.referenceHash b number at same
  exact Encoding.list_injective Encoding.snapshot (fun h => Encoding.snapshot_eq.mp h)
    (Encoding.tree_code_injective (Encoding.pair_injective same).1)

private theorem certifies_base (w : World) (image : Hash) (d : StatementData) :
    ImageCertifies env w image d = ImageCertifies base w image d := rfl

/-- A certified statement's reference hash is the world's commitment to its own prefix. -/
private theorem certified_reference {w : World} {image : Hash} {d : StatementData}
    (cert : ImageCertifies env w image d) :
    referenceHash env w d.input.l1ReferenceBlockNumber = d.referenceHash := by
  obtain ⟨archive,p,bs,⟨⟨_,_,bound,_⟩,_,_⟩,_⟩ := cert
  have closed : referencePrefix (certificateWorld env w d.input.l1ReferenceBlockNumber) d.input.l1ReferenceBlockNumber =
      referencePrefix w d.input.l1ReferenceBlockNumber := by
    simp [referencePrefix,certificateWorld,List.take_take]
  rw [congrArg StatementData.referenceHash bound]
  change referenceHash env w _ =
    referenceHash env (certificateWorld env w d.input.l1ReferenceBlockNumber) d.input.l1ReferenceBlockNumber
  unfold referenceHash
  rw [closed]

open Classical in
private theorem verifier_sound : VerifierSound env (empty env RecoveryNonVacuity.registry) := by
  refine ⟨fun _ => True,?_,?_⟩
  · intro proofs accepted
    cases proofs with
    | nil => simp [dualOK] at accepted
    | cons proof rest => exact ⟨proof,List.mem_cons_self,True.intro⟩
  · intro w _ a t proof _ _ _ verified
    change decide (∃ other, referenceHash base other a.input.l1ReferenceBlockNumber =
      referenceHash env w a.input.l1ReferenceBlockNumber ∧
      ImageCertifies base other proof.image (statement env w a)) = true at verified
    obtain ⟨other,hash,cert⟩ := of_decide_eq_true verified
    rw [← certifies_base] at cert
    exact image_certificate_transport rfl (reference_binding _ _ _ hash) cert

open Classical in
private theorem proof_complete : Etna.Statements.Current.ProofComplete env := by
  refine ⟨0,fun w image d cert => ⟨[⟨.sgx,image,0⟩,⟨.sp1,image,0⟩],rfl,?_⟩⟩
  intro p member
  have accepted : env.verify 0 p.backend image p.bytes d = true := by
    change decide (∃ other, referenceHash base other d.input.l1ReferenceBlockNumber = d.referenceHash ∧
      ImageCertifies base other image d) = true
    exact decide_eq_true ⟨w,certified_reference cert,cert⟩
  simp only [List.mem_cons,List.not_mem_nil,or_false] at member
  rcases member with rfl | rfl <;> exact ⟨rfl,accepted⟩

/-! The primitive and Unzen premises. -/

private theorem legacy_bound : HashBound env legacy := rfl

private theorem primitives : Custody.Primitives env := by
  refine ⟨rfl,?_,?_⟩
  · intro x y hx hy same
    exact Encoding.header_hash_separation (hx.trans (same.trans hy.symm))
  · intro proposal h proof valid
    change decide (proposal = 1 ∧ h = legacy ∧ proof = 77) = true at valid
    obtain ⟨_,rfl,_⟩ := of_decide_eq_true valid
    exact ⟨rfl,legacy_bound,by decide⟩

private theorem registry_genesis : RegistryMachine.Genesis RecoveryNonVacuity.registry :=
  ⟨rfl,fun _ => rfl,fun _ => rfl,fun _ => rfl,rfl,rfl⟩

/-- Vacuous: a valid proof is of proposal 1, so its boundary is 0, where `unzenParent` returns 0;
no hash-bound header has EL hash 0, because `Encoding.headerHash` is odd. -/
private theorem unzen_extension : Custody.UnzenExtension env env.unzenParent := by
  intro boundary proposal h proof parent _ _ bound same
  have zero : Encoding.headerHash parent = 0 := (bound.trans same.symm : _)
  have odd : ∀ a b : Encoding.Tree, (Encoding.Tree.node a b).code ≠ 0 := fun a b => by
    simp [Encoding.Tree.code]
  exact (odd (.node (.leaf parent.height) (.leaf parent.stateRoot))
    (.node (.leaf parent.timestamp) (Encoding.anchor parent.anchor)) zero).elim

private theorem fund_premises : Etna.Statements.Current.FundPremises env RecoveryNonVacuity.registry :=
  ⟨primitives,verifier_sound,reference_binding,registry_genesis,unzen_extension⟩

/-- LIMIT-12-9, START-10-5 here: `legacy` is the only header the final proof authenticates, and
every header that starts at it is hash-bound, since `Encoding.headerHash` reads only the EL
fields `StartsAt` fixes. -/
private theorem unzen_start : Etna.Statements.Current.UnzenStartUsable env := by
  intro _ h proof valid
  change decide (2-1 = 1 ∧ h = legacy ∧ proof = 77) = true at valid
  obtain ⟨_,rfl,_⟩ := of_decide_eq_true valid
  refine ⟨by decide,by decide,by decide +kernel,by decide,rfl,?_⟩
  intro s ⟨height,hash,root,time,anchor,_⟩
  change Encoding.headerHash s = s.elHash
  rw [hash]
  unfold Encoding.headerHash Encoding.header
  rw [height,root,time,anchor]
  rfl

/-! The consensus premises. -/

private theorem signature_refinement : Finality.SignatureRefinement RecoveryNonVacuity.registry env.signature := by
  intro vote online
  exact ⟨0,decide_eq_true online⟩

private theorem signature_sound : Finality.SignatureSound RecoveryNonVacuity.registry env.signature := by
  intro key vote sig accepted
  exact (of_decide_eq_true accepted : key = RecoveryNonVacuity.onlineKey)

private theorem comet_code_injective {x y : Header} (codes : RecoveryNonVacuity.cometCode x = RecoveryNonVacuity.cometCode y)
    (comet : x.cometHash = y.cometHash) : x = y := by
  obtain ⟨h1,e1,s1,m1,c1,t1,a1,v1⟩ := x
  obtain ⟨h2,e2,s2,m2,c2,t2,a2,v2⟩ := y
  have trees := Encoding.tree_code_injective codes
  simp only [RecoveryNonVacuity.cometTree,Encoding.header,Encoding.quad,Encoding.Tree.node.injEq,
    Encoding.Tree.leaf.injEq,Encoding.anchor_eq] at trees
  simp_all

private theorem codec_sound (w : World) : ProtocolFinality.CodecSound env w := by
  intro archiveA archiveB referenceA referenceB parent x y validX validY same
  have ex : decide (x.header.cometHash = RecoveryNonVacuity.cometCode x.header ∧
      x.header.elHash = Encoding.headerHash x.header) = true := validX.execution
  have ey : decide (y.header.cometHash = RecoveryNonVacuity.cometCode y.header ∧
      y.header.elHash = Encoding.headerHash y.header) = true := validY.execution
  exact comet_code_injective ((of_decide_eq_true ex).1.symm.trans (same.trans (of_decide_eq_true ey).1)) same

private theorem vote_attribution (w : World) : ProtocolFinality.VoteAttribution NonVacuity.engine env w := by
  intro origin blocks reference height chain pair member vote present
  trivial

private theorem clock (m n : Nat) (less : m < n) : env.time m < env.time n := by
  change 12*m+1000 < 12*n+1000
  omega

private theorem catalogue_hash : Etna.Statements.Current.CatalogueHash env := by
  intro id selected present
  change some RecoveryNonVacuity.definition = some selected at present
  cases present
  rfl

private theorem premises : Etna.Statements.Current.Premises env RecoveryNonVacuity.registry NonVacuity.engine :=
  { toFundPremises := fund_premises
    currentStandardToken := rfl
    currentSignatureAgreement := signature_refinement
    currentBountyBound := by decide
    currentCodec := fun w _ => codec_sound w
    currentVoteAttribution := fun w _ => vote_attribution w
    currentClock := clock
    currentCatalogueHash := catalogue_hash
    currentSignatureSound := signature_sound
    currentSelfAllowance := by decide
    currentEvidenceWindow := by decide }

/-! H4's further premises. -/

private theorem payload_live : Etna.Statements.Current.PayloadLive env := by
  intro bs _ _
  exact ⟨[0],by decide,by decide,rfl⟩

private theorem recovery_premises : Etna.Statements.Current.RecoveryPremises env RecoveryNonVacuity.registry :=
  { toFundPremises := fund_premises, recoveryClock := clock, recoveryCatalogueHash := catalogue_hash,
    proofComplete := proof_complete, payloadLive := payload_live, unzenStart := unzen_start }

/-! Execution liveness: every parent and producer choice has a hash-bound, linked child. -/

private theorem child_root (parent : Header) (cursor timestamp : Nat) (anchor : BlockValidity.Anchor) :
    (RecoveryNonVacuity.child parent cursor timestamp anchor).stateRoot = Encoding.pair parent.elHash 0 := rfl

private theorem child_bound (parent : Header) (cursor timestamp : Nat) (anchor : BlockValidity.Anchor) :
    HashBound env (RecoveryNonVacuity.child parent cursor timestamp anchor) := rfl

private theorem child_parent (parent : Header) (cursor timestamp : Nat) (anchor : BlockValidity.Anchor) :
    env.headerParent (RecoveryNonVacuity.child parent cursor timestamp anchor).elHash = parent.elHash := by
  have found : ∃ p k, ∃ h : Header,
      Encoding.headerHash h = (RecoveryNonVacuity.child parent cursor timestamp anchor).elHash ∧
      h.stateRoot = Encoding.pair p k :=
    ⟨parent.elHash,0,RecoveryNonVacuity.child parent cursor timestamp anchor,child_bound parent cursor timestamp anchor,
      child_root parent cursor timestamp anchor⟩
  change RecoveryNonVacuity.parentOf (RecoveryNonVacuity.child parent cursor timestamp anchor).elHash = parent.elHash
  rw [RecoveryNonVacuity.parentOf,dite_eq_left found]
  obtain ⟨k,h,hash,root⟩ := Classical.choose_spec found
  have fields := Encoding.header_hash_separation (hash.trans (child_bound parent cursor timestamp anchor).symm)
  rw [child_root] at fields
  exact (Encoding.pair_injective (root.symm.trans fields.2.1)).1

private theorem child_executes (parent : Header) (cursor timestamp : Nat) (anchor : BlockValidity.Anchor)
    (raw : Blocks.Bytes) (txs : List Blocks.Bytes) :
    Executes env RecoveryNonVacuity.definition parent cursor timestamp anchor raw txs
      (RecoveryNonVacuity.child parent cursor timestamp anchor) := by
  refine ⟨rfl,rfl,rfl,rfl,child_bound parent cursor timestamp anchor,child_parent parent cursor timestamp anchor,?_⟩
  intro body header _ _ _
  refine ⟨?_,rfl⟩
  change decide (body.header.cometHash = RecoveryNonVacuity.cometCode body.header ∧
    body.header.elHash = Encoding.headerHash body.header) = true
  rw [header]
  exact decide_eq_true ⟨rfl,rfl⟩

private theorem ruleset_live (m : Nat) : RulesetLive env m := by
  refine ⟨RecoveryNonVacuity.definition,rfl,?_⟩
  intro parent cursor timestamp anchor raw _
  exact ⟨RecoveryNonVacuity.child parent cursor timestamp anchor,child_executes parent cursor timestamp anchor raw [],
    fun _ _ => .inl ⟨_,child_executes parent cursor timestamp anchor raw [raw]⟩⟩

/-! The reachable world and `LiveAt`. -/

private theorem live_trace : Trace env (empty env RecoveryNonVacuity.registry) live :=
  .step (.step (.step (.step (.step (.refl _) (.call _ (.registry 8 (.register 7 8 NonVacuity.unit 1))))
    (.call _ (.advance 2))) (.call _ (.initializeInbox 7))) (.call _ (.advance 3)))
    (.call _ (.setOrigin 8 5 legacy.elHash legacy.stateRoot))

private theorem live_start : live.start = some ⟨5,legacy.elHash,legacy.stateRoot⟩ := by
  decide +kernel

/-- The online key's bond, active from L1 block 1, is the whole committee at cutoff 100. -/
private theorem committee_live : CommitteeLive env live 100 [RecoveryNonVacuity.onlineKey] := by
  refine ⟨fun v member => List.mem_singleton.mp member,
    [⟨RecoveryNonVacuity.onlineKey,NonVacuity.unit,1,Staking.noExit⟩],?_,?_⟩
  · decide +kernel
  · decide +kernel

/-- `LiveAt` by `LiveRules`' first case: c = S = 5 is on the K = 1 grid and the current rulesets
are live. `LiveAt.unzen` holds by its second case: the lane is unproven, and proof 77 of the
final proposal for `legacy` is valid and links to the empty lane's finalized hash. -/
private theorem live_at : Etna.Statements.Current.LiveAt env live := by
  refine ⟨by decide +kernel,by decide +kernel,by decide +kernel,by decide +kernel,
    ⟨100,[RecoveryNonVacuity.onlineKey],by decide +kernel,by decide +kernel,by decide +kernel,by decide +kernel,
      committee_live⟩,
    .inl ⟨?_,ruleset_live _,ruleset_live _,0,by decide +kernel,by decide +kernel⟩,?_⟩
  · intro start started
    rw [live_start] at started
    cases started
    decide +kernel
  · intro _
    exact .inr ⟨legacy,77,by decide +kernel,by decide +kernel,by decide +kernel⟩

/-- The premises of H1–H4 can hold of one switching deployment (reports/recoverability.md, Joint
witness): one environment with an Unzen Inbox, a registry and an engine satisfy H1–H3's
`Premises` and H4's `RecoveryPremises` together, with a reachable initialized world that
satisfies `LiveAt`, in which the origin writer has set a start S > 0 and the Unzen lane has no
checkpoint yet, so the path must prove the lane before the first landing. -/
theorem all_premises_satisfiable :
    ∃ e registry engine w, Etna.Statements.Current.Premises e registry engine ∧
      Etna.Statements.Current.RecoveryPremises e registry ∧
      Trace e (empty e registry) w ∧ w.initialized = true ∧ Etna.Statements.Current.LiveAt e w ∧
      e.core.unzenInbox ≠ 0 ∧ (∃ s, w.start = some s ∧ 0 < s.height) ∧ w.unzen.checkpointExists = false :=
  ⟨env,RecoveryNonVacuity.registry,NonVacuity.engine,live,premises,recovery_premises,live_trace,by decide +kernel,
    live_at,by decide,⟨_,live_start,by decide⟩,by decide +kernel⟩

/-- H4 at the switching joint witness: this environment and registry meet `RecoveryPremises`,
`live` is reachable, initialized and meets `LiveAt`, and `Recovery.recoverable` gives
`RecoverableAt` there, a rollback-free path to a state where `land` accepts a landing. Nothing
has landed and the lane is unproven at `live`, so that landing is the first one, at c = S: the
path runs `unzenProve` and the landing passes the first-landing fence. -/
theorem live_recovers :
    Etna.Statements.Current.RecoveryPremises env RecoveryNonVacuity.registry ∧
      Trace env (empty env RecoveryNonVacuity.registry) live ∧
      live.initialized = true ∧ Etna.Statements.Current.LiveAt env live ∧
      Etna.Statements.Current.RecoverableAt env live :=
  have initialized : live.initialized = true := by decide +kernel
  ⟨recovery_premises,live_trace,initialized,live_at,
    Recovery.recoverable env RecoveryNonVacuity.registry recovery_premises live live_trace initialized live_at⟩

end Etna.Design.Current.Protocol.RecoverySwitchNonVacuity
