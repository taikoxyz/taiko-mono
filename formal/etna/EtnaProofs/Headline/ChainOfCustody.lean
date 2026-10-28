import EtnaStatements
import EtnaProofs.Deployment
import EtnaProofs.Lifecycle

/-! The trace invariant behind H1, fund safety (`Etna.Statements.FundSafety`). Along every run
from the initialized World, some map gives each retained slot-285 record the header of its
block, hash-bound by `Premises.headerHashes`. Block 0's record gets block 0's header; every other
record sits on a lower retained parent record, joined to it by blocks valid under its
generation's built rules; every SignalService checkpoint names a record whose header carries its
state root.
- A landing adds one record. Its segment is the certified batch from the current checkpoint on:
  `Premises.verifierSound` makes the batch valid under the rules `Deployment.build` derives on the
  World (`Premises.hashSeparation`, `Premises.genesis`), and the batch's header at the checkpoint
  is the checkpoint record's own header (`Premises.headerSeparation`).
- Registration, registry edits, FI admission, fee sweeps and recovery keep records and signals.
- Rollback drops the records and signals above one height together, so every kept record keeps
  its lower parent and every kept signal keeps its record. -/
namespace Etna.Proofs
open Etna.Design Etna.Statements

/-- Every run is a protocol trace: a run's steps are `ProtocolState.Step`s. -/
theorem run_trace {env : Environment} {w0 w : ProtocolState.World} (run : Run env w0 w) :
    ProtocolState.Trace w0 w := by
  induction run with
  | refl => exact .refl _
  | landing _ _ time ok ih => exact .step ih (.landing time ok)
  | other _ change _ ih => exact .step ih change

/-- Conversely, `Run`'s side condition on non-landing steps excludes nothing: for an environment
that submits every landing `land` accepts on any World a trace from the initialized World
reaches, every such trace is a run. No environment satisfying `VerifierSound` submits all of
them (`land` also accepts forged landings; see `NoVerifierSoundness`), so this does not extend
the run-based claims to every trace; it shows that runs differ from traces only in which
landings the environment submits. A landing step is a run's landing step. Every other step leaves lastCheckpoint where it was or
moves it down: registration, registry edits, FI admission and fee sweeps keep the Inbox's
checkpoint, governance recovery keeps it (`Recovery.recovery_preserves_settled_prefix`), and a
verifier-failure rollback restores a retained record, which on every World a trace reaches sits
at or below the checkpoint (`Settlement.StateValid`, from `Deployment.genesis_trace_invariants`). -/
theorem trace_run {env : Environment} {w0 w : ProtocolState.World} {hash root : Hash}
    (init : Deployment.Genesis w0 hash root)
    (submitted : ∀ v i leaves e s, ProtocolState.Trace w0 v →
      Etna.Design.land v.inbox i leaves e = some s → env.submits v i leaves e)
    (trace : ProtocolState.Trace w0 w) : Run env w0 w := by
  induction trace with
  | refl => exact .refl _
  | step prior change ih =>
    have core := (Deployment.genesis_trace_invariants init prior).1
    cases change with
    | landing time ok => exact .landing ih (submitted _ _ _ _ _ prior ok) time ok
    | registration time ok => exact .other ih (.registration time ok) (Nat.le_refl _)
    | modification time callable ok => exact .other ih (.modification time callable ok) (Nat.le_refl _)
    | enqueue time blockRange timestampRange ok =>
      refine .other ih (.enqueue time blockRange timestampRange ok) ?_
      unfold Forced.enqueue at ok
      dsimp only at ok
      split at ok
      · cases ok
        exact Nat.le_refl _
      · contradiction
    | sweep time ok =>
      refine .other ih (.sweep time ok) ?_
      unfold Forced.sweep at ok
      split at ok
      · cases ok
        exact Nat.le_refl _
      · contradiction
    | recovery time ok =>
      refine .other ih (.recovery time ok) ?_
      exact Nat.le_of_eq (congrArg Checkpoint.height (Recovery.recovery_preserves_settled_prefix ok).1)
    | rollback trusted snapshot now time retained =>
      refine .other ih (.rollback trusted snapshot now time retained) ?_
      show trusted.height ≤ _
      exact core.inbox.settled.2.2.2.2 trusted (List.mem_of_find?_eq_some retained)

/-- A suffix of a valid chain is valid: after the first `k` blocks, the remaining blocks are valid
from the header at position `k` (the proof origin for `k = 0`, else block `k`'s header). That
header carries the `k`-th cut and height `q.height + k`, and the suffix ends at the same terminal
header. -/
theorem chain_suffix {r : BlockValidity.Rules} :
    ∀ {q : BlockValidity.Header} {bs : List BlockValidity.Block} (k : Nat), BlockValidity.Chain r q bs →
      k ≤ bs.length → ∃ x ∈ q :: bs.map BlockValidity.Block.header,
        x.cut = (BlockValidity.cuts q bs).getD k default ∧ x.height = q.height+k ∧
        BlockValidity.Chain r x (bs.drop k) ∧ BlockValidity.terminal x (bs.drop k) = BlockValidity.terminal q bs := by
  intro q bs
  induction bs generalizing q with
  | nil =>
    intro k _ bound
    have zero : k = 0 := by simpa using bound
    subst zero
    exact ⟨q,List.mem_singleton_self _,rfl,rfl,trivial,rfl⟩
  | cons b rest ih =>
    intro k ok bound
    cases k with
    | zero => exact ⟨q,List.mem_cons_self,rfl,rfl,ok,rfl⟩
    | succ k =>
      obtain ⟨x,mem,cut,height,chain,last⟩ := ih k ok.2 (by simpa using bound)
      have step := (BlockValidity.valid_parent_links ok.1).1
      refine ⟨x,List.mem_cons_of_mem _ mem,?_,?_,chain,last⟩
      · rw [cut]
        rfl
      · omega

/-- Along a nonempty valid chain every header, the proof origin included, is hash-bound when
the rules' EL relation binds the headers it accepts: if `r.executionValid p b` makes `p`'s and
`b`'s EL hashes `hash` of those headers, then each header of the chain has EL hash `hash` of
itself. -/
theorem chain_headers_bound {r : BlockValidity.Rules} {hash : BlockValidity.Header → Hash}
    (binds : ∀ p b, r.executionValid p b = true → p.elHash = hash p ∧ b.header.elHash = hash b.header) :
    ∀ {q : BlockValidity.Header} {bs : List BlockValidity.Block}, BlockValidity.Chain r q bs → bs ≠ [] →
      ∀ x ∈ q :: bs.map BlockValidity.Block.header, x.elHash = hash x := by
  intro q bs
  induction bs generalizing q with
  | nil => exact fun _ empty => absurd rfl empty
  | cons b rest ih =>
    intro ok _ x mem
    have both := binds q b ok.1.2.2.2.2.2.2.2.1
    rcases List.mem_cons.mp mem with rfl | later
    · exact both.1
    · cases rest with
      | nil =>
        rw [List.map_cons,List.map_nil,List.mem_singleton] at later
        rw [later]
        exact both.2
      | cons c more => exact ih ok.2 (List.cons_ne_nil _ _) x later

/-- The trace invariant: H1's body for World `w`, plus each record's header is hash-bound. -/
private def ChainOfCustody (env : Environment) (w0 w : ProtocolState.World) : Prop :=
  ∃ H : Checkpoint → BlockValidity.Header,
    (∀ child ∈ w.inbox.records, HeaderOf H child ∧ (H child).elHash = env.headerHash (H child) ∧
      (child = w0.inbox.checkpoint ∧ H child = env.genesisHeader ∨
        ∃ parent ∈ w.inbox.records, parent.height = child.parent ∧ parent.height < child.height ∧
          Extends env w0 w child.generation (H parent) (H child))) ∧
    ∀ g ∈ w.inbox.signals, ∃ child ∈ w.inbox.records, child.height = g.height ∧ child.elHash = g.hash ∧
      (H child).stateRoot = g.stateRoot

/-- The initialized World: its one record is block 0's, given block 0's header, and its one
signal is block 0's state root (`Premises.genesis`, `Premises.headerHashes`). -/
private theorem chain_of_custody_genesis {env : Environment} {w0 : ProtocolState.World}
    (premises : Premises w0 env) : ChainOfCustody env w0 w0 := by
  obtain ⟨⟨_,checkpoint,records,signals,_⟩,height,comet,cursor⟩ := premises.genesis
  refine ⟨fun _ => env.genesisHeader,?_,?_⟩
  · intro child mem
    rw [records,List.mem_singleton] at mem
    subst mem
    refine ⟨⟨?_,?_⟩,premises.headerHashes.2,Or.inl ⟨rfl,rfl⟩⟩
    · rw [checkpoint,height]
    · rw [checkpoint]
      simp only [BlockValidity.Header.cut,comet,cursor]
  · intro g mem
    rw [signals,List.mem_singleton] at mem
    subst mem
    refine ⟨w0.inbox.checkpoint,?_,?_,?_,rfl⟩
    · rw [records]
      exact List.mem_singleton_self _
    · rw [checkpoint]
    · rw [checkpoint]

/-- Custody survives a step that keeps some records and signals, when each kept record keeps
every lower-height record it had and each kept signal keeps the records at its height, and every
run into the old World extends to the new one. -/
private theorem chain_of_custody_restrict {env : Environment} {w0 w t : ProtocolState.World}
    (custody : ChainOfCustody env w0 w) (records : ∀ c ∈ t.inbox.records, c ∈ w.inbox.records)
    (parents : ∀ c ∈ t.inbox.records, ∀ p ∈ w.inbox.records, p.height < c.height → p ∈ t.inbox.records)
    (signals : ∀ g ∈ t.inbox.signals, g ∈ w.inbox.signals ∧
      ∀ c ∈ w.inbox.records, c.height = g.height → c ∈ t.inbox.records)
    (legs : ∀ w', Run env w' w → Run env w' t) : ChainOfCustody env w0 t := by
  obtain ⟨H,held,named⟩ := custody
  refine ⟨H,?_,?_⟩
  · intro child mem
    obtain ⟨header,bound,origin⟩ := held child (records child mem)
    refine ⟨header,bound,?_⟩
    rcases origin with genesis | ⟨parent,old,link,lower,w',r,bs,first,second,generation,built,chain,last⟩
    · exact Or.inl genesis
    · exact Or.inr ⟨parent,parents child mem parent old lower,link,lower,w',r,bs,first,legs w' second,generation,
        built,chain,last⟩
  · intro g mem
    obtain ⟨old,kept⟩ := signals g mem
    obtain ⟨child,present,height,hash,root⟩ := named g old
    exact ⟨child,kept child present height,height,hash,root⟩

/-- Every step that does not advance lastCheckpoint keeps custody. Registration, registry edits,
FI admission and fee sweeps leave the Inbox's records and signals as they are; recovery keeps
them (`Recovery.recovery_preserves_settled_prefix`); rollback drops the records and signals
above the restored height together. A landing always advances lastCheckpoint. -/
private theorem chain_of_custody_other {env : Environment} {w0 w t : ProtocolState.World}
    (custody : ChainOfCustody env w0 w) (change : ProtocolState.Step w t)
    (settled : t.inbox.checkpoint.height ≤ w.inbox.checkpoint.height)
    (legs : ∀ w', Run env w' w → Run env w' t) : ChainOfCustody env w0 t := by
  have frame : t.inbox.records = w.inbox.records → t.inbox.signals = w.inbox.signals → ChainOfCustody env w0 t :=
    fun records signals => chain_of_custody_restrict custody (fun _ mem => records ▸ mem)
      (fun _ _ _ old _ => records ▸ old) (fun _ mem => ⟨signals ▸ mem,fun _ old _ => records ▸ old⟩) legs
  cases change with
  | landing _ ok => exact absurd settled (Nat.not_le_of_lt (land_extends_checkpoint ok).1)
  | registration => exact frame rfl rfl
  | modification => exact frame rfl rfl
  | enqueue _ _ _ ok =>
    unfold Forced.enqueue at ok
    dsimp only at ok
    split at ok
    · cases ok
      exact frame rfl rfl
    · contradiction
  | sweep _ ok =>
    unfold Forced.sweep at ok
    split at ok
    · cases ok
      exact frame rfl rfl
    · contradiction
  | recovery _ ok =>
    have kept := Recovery.recovery_preserves_settled_prefix ok
    exact frame kept.2.1 kept.2.2.2.2.1
  | rollback trusted snapshot now _ _ =>
    apply chain_of_custody_restrict custody
    · intro c mem
      exact (List.mem_filter.mp mem).1
    · intro c mem p old lower
      have kept := of_decide_eq_true (List.mem_filter.mp mem).2
      exact List.mem_filter.mpr ⟨old,decide_eq_true (by omega)⟩
    · intro g mem
      have kept := of_decide_eq_true (List.mem_filter.mp mem).2
      exact ⟨(List.mem_filter.mp mem).1,fun c old same => List.mem_filter.mpr ⟨old,decide_eq_true (by omega)⟩⟩
    · exact legs

/-- A submitted landing that the Inbox accepts on a World some run reaches is certified on that
World by the deployment's own rules: its certificate is the statement of a batch valid under
rules that `Deployment.build` derives on the World from the stored configuration, the
environment's relations, some anchor archive and some reference block (`Built`). Two proofs, one
sound (`Premises.verifierSound`), certify it on the guest's view; the guest's openings of the
stored config and committee-0 commitments are the stored ones (`Premises.hashSeparation`, and
committee 0 recomputed from the registry snapshot at genesisCutoff, which no step changes). -/
theorem submitted_landing_certified {env : Environment} {w0 w : ProtocolState.World} {s : State}
    {i : LandInput} {leaves : List Leaf} {e : LandingEnv} (premises : Premises w0 env) (run : Run env w0 w)
    (submitted : env.submits w i leaves e) (ok : Etna.Design.land w.inbox i leaves e = some s) :
    ∃ r p bs blobs, Built env w r ∧ Settlement.BatchValid r p bs blobs ∧
      e.certificate = Settlement.statement r p bs blobs := by
  obtain ⟨sound,cover,approve⟩ := premises.verifierSound
  have dual := (land_success ok).1.2.1
  obtain ⟨⟨backend,flag⟩,mem,good⟩ := cover e.proofs dual
  have accepted : flag = true := by
    have all : ∀ x ∈ e.proofs, x.2 = true := by
      simp only [dualOK,Bool.and_eq_true,List.all_eq_true] at dual
      exact dual.1.1.2
    exact all _ mem
  subst accepted
  obtain ⟨cfg,zero,archive,r,p,bs,blobs,representable,built,valid,binding⟩ :=
    approve backend w i leaves e s good submitted ok mem
  have trace := run_trace run
  obtain ⟨_,_,_,_,snapshot⟩ := Deployment.genesis_trace_invariants premises.genesis.1 trace
  obtain ⟨domain,committee,_,_,cutoff,_,configuration,zeroRecord,_,_,_,_,_,_,adapters,_⟩ :=
    ProtocolState.trace_preserves_immutables trace
  obtain ⟨_,_,opened,genesisZero,_⟩ := Deployment.build_success built
  -- The guest's config opening is the stored configuration (hash separation at w0).
  have fixed : cfg = w.inbox.configuration := by
    rw [configuration]
    apply premises.hashSeparation cfg representable
    have same : Deployment.words w0.inbox cfg = Deployment.words w.inbox cfg := by
      simp only [Deployment.words,domain]
    rw [same,← adapters,← committee]
    exact opened.symm
  subst fixed
  -- Committee 0 recomputed from the unchanged genesis-cutoff registry snapshot is the stored one.
  have zeroFixed : zero = w.inbox.committeeZeroRecord := by
    obtain ⟨_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,target,cutoffZero,elected,_⟩ := premises.genesis.1
    have recomputed : Deployment.genesis (guestView w w.inbox.configuration zero).inbox
        (guestView w w.inbox.configuration zero).registry w.inbox.configuration archive = zero := genesisZero
    have registry : HistoricalContext.registryAt w.registry w.inbox.genesisCutoff =
        HistoricalContext.registryAt w0.registry w0.inbox.genesisCutoff := by
      simp only [HistoricalContext.registryAt,snapshot]
    rw [← recomputed]
    show (⟨0,w.inbox.genesisCutoff,Committee.chosen w.inbox.configuration.unit w.inbox.configuration.minimum
      w.inbox.genesisCutoff w.inbox.configuration.nMax (HistoricalContext.registryAt w.registry w.inbox.genesisCutoff)⟩ :
        Committee.Record) = _
    rw [registry,cutoff,configuration,zeroRecord,← Committee.election_chosen elected,← target,← cutoffZero]
  subst zeroFixed
  exact ⟨r,p,bs,blobs,⟨archive,_,_,built⟩,valid,binding⟩

/-- The last header of a chain is one of its headers. -/
private theorem terminal_mem : ∀ (q : BlockValidity.Header) (bs : List BlockValidity.Block),
    BlockValidity.terminal q bs ∈ q :: bs.map BlockValidity.Block.header
  | q, [] => List.mem_singleton_self q
  | _, b :: rest => List.mem_cons_of_mem _ (terminal_mem b.header rest)

/-- Two hash-bound headers with the same cut are the same header: the cut gives the EL hash,
CometBFT hash and FI cursor, and equal EL hashes give the height, stateRoot, timestamp and anchor
(`Premises.headerSeparation`). This is where two segments join. -/
private theorem bound_headers_eq {hash : BlockValidity.Header → Hash}
    (separation : ∀ h₁ h₂, hash h₁ = hash h₂ →
      h₁.height = h₂.height ∧ h₁.stateRoot = h₂.stateRoot ∧ h₁.timestamp = h₂.timestamp ∧ h₁.anchor = h₂.anchor)
    {x y : BlockValidity.Header} (boundX : x.elHash = hash x) (boundY : y.elHash = hash y) (cut : x.cut = y.cut) :
    x = y := by
  have fields : x.elHash = y.elHash ∧ x.cometHash = y.cometHash ∧ x.cursor = y.cursor := by
    simpa [BlockValidity.Header.cut] using cut
  obtain ⟨height,root,time,anchor⟩ := separation x y (boundX.symm.trans (fields.1.trans boundY))
  obtain ⟨xh,xe,xs,xc,xu,xt,xa⟩ := x
  obtain ⟨yh,ye,ys,yc,yu,yt,ya⟩ := y
  simp only at height root time anchor fields
  simp only [height,root,time,anchor,fields]

/-- A submitted landing keeps custody. Its certified batch runs from proof origin p to the new
checkpoint h; the suffix from the current checkpoint c is valid from the batch's header at c,
which is hash-bound and has the checkpoint record's cut, so it is that record's header. The new
record gets the batch's last header; the old records keep theirs (all lie at or below c < h). -/
private theorem chain_of_custody_landing {env : Environment} {w0 w : ProtocolState.World} {s : State}
    {i : LandInput} {leaves : List Leaf} {e : LandingEnv} (premises : Premises w0 env) (prior : Run env w0 w)
    (custody : ChainOfCustody env w0 w) (submitted : env.submits w i leaves e) (time : w.l1Block ≤ e.blockNumber)
    (ok : Etna.Design.land w.inbox i leaves e = some s) :
    ChainOfCustody env w0 (ProtocolState.landed w s e.blockNumber) := by
  obtain ⟨H,held,named⟩ := custody
  obtain ⟨r,p,bs,blobs,built,valid,binding⟩ := submitted_landing_certified premises prior submitted ok
  have step : Run env w (ProtocolState.landed w s e.blockNumber) := .landing (.refl w) submitted time ok
  -- The built rules use the environment's EL relation and the World's K.
  have rules : r.executionValid = env.executionValid ∧ r.gridK = w.inbox.gridK := by
    obtain ⟨_,_,_,construction⟩ := built
    obtain ⟨_,_,_,_,_,_,_,_,_,rfl⟩ := Deployment.build_success construction
    exact ⟨rfl,rfl⟩
  obtain ⟨core,constraints,_⟩ := Deployment.genesis_trace_invariants premises.genesis.1 (run_trace prior)
  obtain ⟨record,cursor,⟨grid,_⟩,_,below⟩ := core.inbox.settled
  have positive : 0 < w.inbox.gridK := (of_decide_eq_true constraints.1).1
  have input := Settlement.accepted_input ok binding
  subst input
  obtain ⟨⟨⟨⟨_,_,parentBelow,advance,_,parentGrid,lastGrid,_⟩,_⟩,_,_⟩,rfl⟩ := land_success ok
  have advance' : w.inbox.checkpoint.height < (BlockValidity.terminal p bs).height := advance
  have frontier := Settlement.accepted_frontier_from_valid_chain ok valid binding (by rw [rules.2]; exact parentGrid)
    (by rw [rules.2]; exact lastGrid) rules.2.symm positive grid record
  have heights := BlockValidity.chain_height valid.1
  obtain ⟨x,present,cut,_,chain,last⟩ :=
    chain_suffix (w.inbox.checkpoint.height-p.height) valid.1 (by change p.height ≤ _ at parentBelow; omega)
  have nonempty : bs ≠ [] := by
    rintro rfl
    exact absurd advance' (Nat.not_lt_of_le parentBelow)
  have bound := chain_headers_bound (hash := env.headerHash) (by rw [rules.1]; exact premises.headerHashes.1)
    valid.1 nonempty
  have current : w.inbox.checkpoint ∈ w.inbox.records := List.mem_of_find?_eq_some record
  obtain ⟨⟨_,currentCut⟩,currentBound,_⟩ := held w.inbox.checkpoint current
  -- The batch's header at c is the checkpoint record's header.
  have join : x = H w.inbox.checkpoint :=
    bound_headers_eq premises.headerSeparation (bound x present) currentBound
      (by rw [cut,frontier,currentCut,cursor])
  -- The new record is above every old one, so the map can change there alone.
  have fresh : ∀ y ∈ w.inbox.records, y ≠ landedCheckpoint w.inbox (Settlement.statement r p bs blobs).input := by
    intro y mem same
    have lower := below y mem
    rw [same] at lower
    exact absurd advance' (Nat.not_lt_of_le lower)
  obtain ⟨H',newHeader,oldHeader⟩ : ∃ H' : Checkpoint → BlockValidity.Header,
      H' (landedCheckpoint w.inbox (Settlement.statement r p bs blobs).input) = BlockValidity.terminal p bs ∧
      ∀ y ∈ w.inbox.records, H' y = H y :=
    ⟨fun y => if y = landedCheckpoint w.inbox (Settlement.statement r p bs blobs).input then
      BlockValidity.terminal p bs else H y,ite_eq_left rfl,fun y mem => ite_eq_right (fresh y mem)⟩
  refine ⟨H',?_,?_⟩
  · intro child mem
    rcases List.mem_cons.mp mem with rfl | old
    · refine ⟨⟨?_,?_⟩,?_,Or.inr ⟨w.inbox.checkpoint,List.mem_cons_of_mem _ current,rfl,advance',?_⟩⟩
      · rw [newHeader]
        rfl
      · rw [newHeader]
        rfl
      · rw [newHeader]
        exact bound _ (terminal_mem p bs)
      · rw [oldHeader _ current,newHeader,← join]
        exact ⟨w,r,bs.drop (w.inbox.checkpoint.height-p.height),prior,step,rfl,built,chain,last⟩
    · obtain ⟨⟨height,childCut⟩,childBound,origin⟩ := held child old
      refine ⟨⟨?_,?_⟩,?_,?_⟩
      · rw [oldHeader child old]
        exact height
      · rw [oldHeader child old]
        exact childCut
      · rw [oldHeader child old]
        exact childBound
      rcases origin with ⟨genesis,header⟩ | ⟨parent,older,link,lower,w',r',bs',first,second,generation,built',
        chain',last'⟩
      · exact Or.inl ⟨genesis,(oldHeader child old).trans header⟩
      · refine Or.inr ⟨parent,List.mem_cons_of_mem _ older,link,lower,?_⟩
        rw [oldHeader child old,oldHeader parent older]
        exact ⟨w',r',bs',first,.landing second submitted time ok,generation,built',chain',last'⟩
  · intro g mem
    rcases List.mem_append.mp mem with old | new
    · obtain ⟨child,present,height,hash,root⟩ := named g old
      refine ⟨child,List.mem_cons_of_mem _ present,height,hash,?_⟩
      rw [oldHeader child present]
      exact root
    · rw [List.mem_singleton] at new
      subst new
      refine ⟨_,List.mem_cons_self,rfl,rfl,?_⟩
      rw [newHeader]
      rfl

/-- H1's trace invariant: along every run from the initialized World, some map `H` gives each
retained record its block's header (`HeaderOf`), hash-bound (`(H c).elHash = env.headerHash
(H c)`); block 0's record gets block 0's header, and every other record has a lower retained
parent whose header blocks valid under its generation's built rules extend to its own; and every
SignalService checkpoint names a record whose header carries its state root. This is
`Etna.Statements.FundSafety`'s body plus the hash binding. -/
theorem chain_of_custody {env : Environment} {w0 : ProtocolState.World} (premises : Premises w0 env)
    {w : ProtocolState.World} (run : Run env w0 w) :
    ∃ H : Checkpoint → BlockValidity.Header,
      (∀ child ∈ w.inbox.records, HeaderOf H child ∧ (H child).elHash = env.headerHash (H child) ∧
        (child = w0.inbox.checkpoint ∧ H child = env.genesisHeader ∨
          ∃ parent ∈ w.inbox.records, parent.height = child.parent ∧ parent.height < child.height ∧
            Extends env w0 w child.generation (H parent) (H child))) ∧
      ∀ g ∈ w.inbox.signals, ∃ child ∈ w.inbox.records, child.height = g.height ∧ child.elHash = g.hash ∧
        (H child).stateRoot = g.stateRoot := by
  suffices custody : ChainOfCustody env w0 w from custody
  induction run with
  | refl => exact chain_of_custody_genesis premises
  | landing prior submitted time ok ih => exact chain_of_custody_landing premises prior ih submitted time ok
  | other _ change settled ih =>
    exact chain_of_custody_other ih change settled (fun _ leg => .other leg change settled)

end Etna.Proofs
