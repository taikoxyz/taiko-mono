import EtnaStatements.Current
import EtnaProofs.CurrentEncoding
import EtnaProofs.CurrentReference
import EtnaProofs.CurrentRecoveryLanding
import EtnaWitnesses.NonVacuity.Current

/-! The premises of H1–H4 can hold of one deployment (reports/recoverability.md, Joint witness):
one concrete environment, registry and engine satisfy H1–H3's fifteen `Premises` and H4's
`RecoveryPremises` together, and a reachable initialized world in it satisfies `LiveAt`. It
shows that the premises are jointly satisfiable, not the claims; `live_recovers` then applies
H4's proof (`Recovery.recoverable`) there, so the recovery path does reach an accepted landing
in this environment.

The environment is a new network (no Unzen inbox, so the Unzen premises and `LiveAt.unzen`
are vacuous) with one online key and a single catalogue definition:
- `headerHash` is the injective code of the EL fields (height, state root, timestamp, anchor).
  A child carries its parent's EL hash in its state root, and `headerHash` is injective, so
  `headerParent` decodes it back (classically). That gives every parent and producer choice a
  hash-bound, physically linked child (`ExecutionLive`).
- The definition accepts exactly the blocks whose Comet hash is the injective code of every
  other header field and whose EL hash is `headerHash`. Two valid children with one Comet hash
  are therefore one header (`CometHeaderBinding`, so `currentCodec`).
- The verifier is an ideal sound and complete checker, decided classically: it accepts a
  statement exactly when an image certifies it over the L1 prefix its reference hash commits
  to (`VerifierSound` and `ProofComplete`). It is not an oracle for a World.
- The online key signs every vote and the registry verifies every message under it; the
  engine attributes every precommit (`VoteAttribution` for every world).
Commitments are ideal unbounded Nat codes, not Keccak. -/
namespace Etna.Design.Current.Protocol.RecoveryNonVacuity
open Etna.Design Etna.Design.Current Protocol

/-- The only consensus key: it signs every vote and backs the only registered bond. -/
def onlineKey : Hash := 7

/-- Every header field except the Comet hash itself. -/
def cometTree (h : Header) : Encoding.Tree :=
  .node (Encoding.header h) (.node (.leaf h.elHash) (.node (.leaf h.cursor) (.leaf h.valStateHash)))

/-- The Comet hash of a valid block: an injective code of every other header field. -/
def cometCode (h : Header) : Hash := (cometTree h).code

/-- The single ruleset definition. Execution checks only the two header hashes; every payload
is accepted; the byte adapter hashes with the environment's transaction hash. -/
def definition : Blocks.Definition :=
  ⟨fun _ b => decide (b.header.cometHash = cometCode b.header ∧ b.header.elHash = Encoding.headerHash b.header),
    fun _ _ _ => true,NonVacuity.bytes⟩

open Classical in
/-- Physical parent decoding: the first half of the paired state root of the header with this
EL hash. That header's EL fields are unique since `Encoding.headerHash` is injective on them;
0 for a hash no such header has. -/
noncomputable def parentOf (hash : Hash) : Hash :=
  if found : ∃ parent k, ∃ h : Header, Encoding.headerHash h = hash ∧ h.stateRoot = Encoding.pair parent k then
    Classical.choose found else 0

def genesis : Header := { NonVacuity.genesisBase with elHash := Encoding.headerHash NonVacuity.genesisBase }

/-- Every field but the verifier. `env` adds a verifier that reads certification under `base`,
which avoids self-reference; certification reads no verifier, so both environments certify
the same statements. New network (`unzenInbox = 0`), owner 7, K = 1, epoch length 10, genesis
cutoff 1, one-seat committee with U = 10, maxAnchorAge 1152; L1 block n has time 12n + 1000. -/
noncomputable def base : Environment where
  core := ⟨NonVacuity.domain,7,8,0,2,9⟩
  parameters := ⟨1,10,1,⟨NonVacuity.unit,NonVacuity.unit,1,10⟩,1,1152,10,1,1,9⟩
  genesisHeader := genesis
  initialSigner := NonVacuity.initialSigner
  time := fun n => 12*n+1000
  stateRoot := Encoding.snapshotHash
  blockHash := Encoding.referenceHash
  headerHash := Encoding.headerHash
  committeeHash := fun _ => 1
  configHash := fun _ => 0
  signature := fun v => v.key = onlineKey
  txHash := NonVacuity.txHash
  unzenNextProposal := 1
  timestampOf := fun _ => 1
  catalogue := fun _ => some definition
  payload := fun blobs _ => decide (1 ≤ blobs.length ∧ blobs.length ≤ 6)
  verify := fun _ _ _ _ _ => false
  imageRules := fun _ => [0]
  unzenValid := fun _ _ _ => false
  unzenRoot := fun _ => False
  startImplementation := fun _ => true
  importValid := fun _ _ _ => true
  signBytes := fun _ => 0
  token := RegistryPayments.standardEnvironment 4 9
  initialToken := ⟨fun account => if account = 8 then NonVacuity.unit else 0,
    fun owner spender => if owner = 8 ∧ spender = 4 then NonVacuity.unit else 0⟩
  headerParent := parentOf

open Classical in
/-- An ideal checker for every verifier version, backend and proof byte string: it accepts `d`
for `image` exactly when `image` certifies `d` over the L1 prefix `d`'s reference hash commits
to. `ImageCertifies` reads no verifier, so `base` and the final environment agree on it. -/
noncomputable def env : Environment := { base with
  verify := fun _ _ image _ d => decide (∃ w, referenceHash base w d.input.l1ReferenceBlockNumber = d.referenceHash ∧
    ImageCertifies base w image d) }

/-- `NonVacuity.registry` (fresh, admits key 7 for owner 8 with stake `unit`) with a signature
verifier that accepts every message under the online key. -/
def registry : RegistryMachine.State := { NonVacuity.registry with verify := fun key _ _ => decide (key = onlineKey) }

/-- Register one bond for the online key at L1 block 0 (active from block 1), advance to block
2 and initialize at S = 0. -/
noncomputable def registered : World := transact env (empty env registry) (.registry 8 (.register 7 8 NonVacuity.unit 1))
noncomputable def activated : World := transact env registered (.advance 2)
noncomputable def live : World := transact env activated (.initializeInbox 7)

/-- A child's EL part: its state root carries the parent's EL hash and its EL hash is `headerHash`. -/
def elChild (parent : Header) (cursor timestamp : Nat) (anchor : BlockValidity.Anchor) : Header :=
  let fields : Header := ⟨parent.height+1,0,Encoding.pair parent.elHash 0,0,cursor,timestamp,anchor,0⟩
  { fields with elHash := Encoding.headerHash fields }
/-- The child of `parent` for these producer inputs: `elChild`, whose state root carries the
parent's EL hash and whose EL hash is `headerHash`, with the Comet hash coding the rest. -/
def child (parent : Header) (cursor timestamp : Nat) (anchor : BlockValidity.Anchor) : Header :=
  { elChild parent cursor timestamp anchor with cometHash := cometCode (elChild parent cursor timestamp anchor) }

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
private theorem verifier_sound : VerifierSound env (empty env registry) := by
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

/-! The primitive and consensus premises. -/

private theorem primitives : Custody.Primitives env := by
  refine ⟨rfl,?_,?_⟩
  · intro x y hx hy same
    exact Encoding.header_hash_separation (hx.trans (same.trans hy.symm))
  · intro proposal h proof accepted
    contradiction

private theorem registry_genesis : RegistryMachine.Genesis registry :=
  ⟨rfl,fun _ => rfl,fun _ => rfl,fun _ => rfl,rfl,rfl⟩

private theorem unzen_extension : Custody.UnzenExtension env env.unzenParent := by
  intro boundary proposal h proof parent earlier accepted
  cases accepted

private theorem fund_premises : Etna.Statements.Current.FundPremises env registry :=
  ⟨primitives,verifier_sound,reference_binding,registry_genesis,unzen_extension⟩

private theorem signature_refinement : Finality.SignatureRefinement registry env.signature := by
  intro vote online
  exact ⟨0,decide_eq_true online⟩

private theorem signature_sound : Finality.SignatureSound registry env.signature := by
  intro key vote sig accepted
  exact (of_decide_eq_true accepted : key = onlineKey)

private theorem comet_code_injective {x y : Header} (codes : cometCode x = cometCode y)
    (comet : x.cometHash = y.cometHash) : x = y := by
  obtain ⟨h1,e1,s1,m1,c1,t1,a1,v1⟩ := x
  obtain ⟨h2,e2,s2,m2,c2,t2,a2,v2⟩ := y
  have trees := Encoding.tree_code_injective codes
  simp only [cometTree,Encoding.header,Encoding.quad,Encoding.Tree.node.injEq,Encoding.Tree.leaf.injEq,
    Encoding.anchor_eq] at trees
  simp_all

private theorem codec_sound (w : World) : ProtocolFinality.CodecSound env w := by
  intro archiveA archiveB referenceA referenceB parent x y validX validY same
  have ex : decide (x.header.cometHash = cometCode x.header ∧ x.header.elHash = Encoding.headerHash x.header) = true :=
    validX.execution
  have ey : decide (y.header.cometHash = cometCode y.header ∧ y.header.elHash = Encoding.headerHash y.header) = true :=
    validY.execution
  exact comet_code_injective ((of_decide_eq_true ex).1.symm.trans (same.trans (of_decide_eq_true ey).1)) same

private theorem vote_attribution (w : World) : ProtocolFinality.VoteAttribution NonVacuity.engine env w := by
  intro origin blocks reference height chain pair member vote present
  trivial

private theorem clock (m n : Nat) (less : m < n) : env.time m < env.time n := by
  change 12*m+1000 < 12*n+1000
  omega

private theorem catalogue_hash : Etna.Statements.Current.CatalogueHash env := by
  intro id selected present
  change some definition = some selected at present
  cases present
  rfl

private theorem premises : Etna.Statements.Current.Premises env registry NonVacuity.engine :=
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

private theorem unzen_start : Etna.Statements.Current.UnzenStartUsable env := by
  intro switching
  exact (switching rfl).elim

private theorem recovery_premises : Etna.Statements.Current.RecoveryPremises env registry :=
  { toFundPremises := fund_premises, recoveryClock := clock, recoveryCatalogueHash := catalogue_hash,
    proofComplete := proof_complete, payloadLive := payload_live, unzenStart := unzen_start }

/-! Execution liveness: every parent and producer choice has a hash-bound, linked child. -/

private theorem child_root (parent : Header) (cursor timestamp : Nat) (anchor : BlockValidity.Anchor) :
    (child parent cursor timestamp anchor).stateRoot = Encoding.pair parent.elHash 0 := rfl

private theorem child_bound (parent : Header) (cursor timestamp : Nat) (anchor : BlockValidity.Anchor) :
    HashBound env (child parent cursor timestamp anchor) := rfl

private theorem child_parent (parent : Header) (cursor timestamp : Nat) (anchor : BlockValidity.Anchor) :
    env.headerParent (child parent cursor timestamp anchor).elHash = parent.elHash := by
  have found : ∃ p k, ∃ h : Header, Encoding.headerHash h = (child parent cursor timestamp anchor).elHash ∧
      h.stateRoot = Encoding.pair p k :=
    ⟨parent.elHash,0,child parent cursor timestamp anchor,child_bound parent cursor timestamp anchor,
      child_root parent cursor timestamp anchor⟩
  change parentOf (child parent cursor timestamp anchor).elHash = parent.elHash
  rw [parentOf,dite_eq_left found]
  obtain ⟨k,h,hash,root⟩ := Classical.choose_spec found
  have fields := Encoding.header_hash_separation (hash.trans (child_bound parent cursor timestamp anchor).symm)
  rw [child_root] at fields
  exact (Encoding.pair_injective (root.symm.trans fields.2.1)).1

private theorem child_executes (parent : Header) (cursor timestamp : Nat) (anchor : BlockValidity.Anchor)
    (raw : Blocks.Bytes) (txs : List Blocks.Bytes) :
    Executes env definition parent cursor timestamp anchor raw txs (child parent cursor timestamp anchor) := by
  refine ⟨rfl,rfl,rfl,rfl,child_bound parent cursor timestamp anchor,child_parent parent cursor timestamp anchor,?_⟩
  intro body header _ _ _
  refine ⟨?_,rfl⟩
  change decide (body.header.cometHash = cometCode body.header ∧ body.header.elHash = Encoding.headerHash body.header) = true
  rw [header]
  exact decide_eq_true ⟨rfl,rfl⟩

private theorem ruleset_live (m : Nat) : RulesetLive env m := by
  refine ⟨definition,rfl,?_⟩
  intro parent cursor timestamp anchor raw _
  exact ⟨child parent cursor timestamp anchor,child_executes parent cursor timestamp anchor raw [],
    fun _ _ => .inl ⟨_,child_executes parent cursor timestamp anchor raw [raw]⟩⟩

/-! The reachable world and `LiveAt`. -/

private theorem live_trace : Trace env (empty env registry) live :=
  .step (.step (.step (.refl _) (.call _ (.registry 8 (.register 7 8 NonVacuity.unit 1)))) (.call _ (.advance 2)))
    (.call _ (.initializeInbox 7))

private theorem live_start : live.start = some ⟨0,genesis.elHash,genesis.stateRoot⟩ := by
  decide +kernel

/-- The online key's bond, active from L1 block 1, is the whole committee at cutoff 100. -/
private theorem committee_live : CommitteeLive env live 100 [onlineKey] := by
  refine ⟨fun v member => List.mem_singleton.mp member,[⟨onlineKey,NonVacuity.unit,1,Staking.noExit⟩],?_,?_⟩
  · decide +kernel
  · decide +kernel

private theorem live_at : Etna.Statements.Current.LiveAt env live := by
  refine ⟨?_,by decide +kernel,by decide +kernel,by decide +kernel,by decide +kernel,
    ⟨100,[onlineKey],by decide +kernel,by decide +kernel,by decide +kernel,by decide +kernel,committee_live⟩,
    .inl ⟨ruleset_live _,ruleset_live _,0,by decide +kernel,by decide +kernel⟩,?_⟩
  · intro start started
    rw [live_start] at started
    cases started
    decide +kernel
  · intro switching
    exact (switching rfl).elim

/-- The premises of H1–H4 can hold of one deployment (reports/recoverability.md, Joint witness): one
environment, registry and engine satisfy H1–H3's `Premises` and H4's `RecoveryPremises` together,
with a reachable initialized world that satisfies `LiveAt`. -/
theorem all_premises_satisfiable :
    ∃ e registry engine w, Etna.Statements.Current.Premises e registry engine ∧
      Etna.Statements.Current.RecoveryPremises e registry ∧
      Trace e (empty e registry) w ∧ w.initialized = true ∧ Etna.Statements.Current.LiveAt e w :=
  ⟨env,registry,NonVacuity.engine,live,premises,recovery_premises,live_trace,by decide +kernel,live_at⟩

/-- H4 at the joint witness: this environment and registry meet `RecoveryPremises`, `live` is
reachable, initialized and meets `LiveAt`, and `Recovery.recoverable` gives `RecoverableAt` there,
a rollback-free path with one plain recovery to a state where `land` accepts a landing. -/
theorem live_recovers :
    Etna.Statements.Current.RecoveryPremises env registry ∧ Trace env (empty env registry) live ∧
      live.initialized = true ∧ Etna.Statements.Current.LiveAt env live ∧
      Etna.Statements.Current.RecoverableAt env live :=
  have initialized : live.initialized = true := by decide +kernel
  ⟨recovery_premises,live_trace,initialized,live_at,
    Recovery.recoverable env registry recovery_premises live live_trace initialized live_at⟩

end Etna.Design.Current.Protocol.RecoveryNonVacuity
