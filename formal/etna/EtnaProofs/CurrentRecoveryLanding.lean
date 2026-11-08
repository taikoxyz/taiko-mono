import EtnaModel.CurrentRecoveryInterface
import EtnaStatements.Current
import EtnaProofs.Current
import EtnaProofs.CurrentEconomics
import EtnaProofs.CurrentFinality
import EtnaProofs.CurrentHistory
import EtnaProofs.CurrentLookback
import EtnaProofs.CurrentReference
import EtnaProofs.CurrentRecoveryPath
import EtnaProofs.CurrentRecoverySegment

/-! The landing half of the recovery path (design 4.3, steps 6-7). After `Recovery.prepare`
reaches `u` (one plain recovery at L1 block R, L1 advanced to R+2), the closed certificate world
`x := certificateWorld env u (R+1)` shows `u`'s storage, so `Recovery.segment` builds the new
generation's first K blocks on the batch parent `p`. Their statement is certified at reference
R+1 with archive root `p` and no prior headers, the image `prepare` registered implements every
block's ruleset, and the complete verifier accepts two proofs of it, so `land` accepts the
segment's landing from `c` to `c+K`. `Recovery.recoverable` (H4) composes `prepare` with this
landing. The reachable-state facts it needs beyond the existing journals are `Settled`: the rule
schedule fits its slots, and the genesis cutoff stays below every origin block. -/
namespace Etna.Design.Current.Protocol.Recovery
open Etna.Statements.Current

/-! ### Reachable-state facts -/

/-- `Rules.recover` keeps a fitting schedule, or installs `⟨rules,rules,0,0,0⟩` with
`rules < 2^48`. -/
private theorem recover_fits {s t : Rules.Schedule} {rules : Nat} (fits : Rules.fits s)
    (ok : Rules.recover s rules = some t) : Rules.fits t := by
  have zero : 0 < limit48 := by decide
  unfold Rules.recover at ok
  split at ok
  next =>
    cases Option.some.inj ok
    exact ⟨fits.1,fits.2.1,fits.2.2.1,zero,zero⟩
  next =>
    split at ok
    next guard =>
      cases Option.some.inj ok
      exact ⟨guard.2,guard.2,zero,zero,zero⟩
    next => simp at ok

/-- Facts of every reachable state that the landing needs and the existing journals do not give.
The rule schedule fits its 48-bit slots (`Blocks.Valid.schedule`). The genesis cutoff is the
deployment's (`recover` keeps it across upgrades); it lies below the block of Inbox
initialization and so below every later origin block (`Finality.Ready`). -/
private structure Settled (env : Environment) (w : World) : Prop where
  fits : Rules.fits w.schedule
  cutoff : w.inbox.genesisCutoff = env.parameters.genesisCutoff
  past : w.initialized = true → env.parameters.genesisCutoff < w.number
  origin : w.initialized = true → w.start.isSome = true →
    env.parameters.genesisCutoff < w.inbox.origin.l1Block

/-- A call that keeps the schedule, the cutoff, initialization, the start and the origin block,
and does not move L1 back, keeps `Settled`. -/
private theorem settled_frame {env : Environment} {w t : World} (held : Settled env w)
    (schedule : t.schedule = w.schedule) (cutoff : t.inbox.genesisCutoff = w.inbox.genesisCutoff)
    (initialized : t.initialized = w.initialized) (start : t.start = w.start)
    (origin : t.inbox.origin.l1Block = w.inbox.origin.l1Block) (number : w.number ≤ t.number) :
    Settled env t := by
  refine ⟨?_,?_,?_,?_⟩
  · rw [schedule]; exact held.fits
  · rw [cutoff]; exact held.cutoff
  · rw [initialized]; exact fun init => Nat.lt_of_lt_of_le (held.past init) number
  · rw [initialized,start,origin]; exact held.origin

/-- A start written at the current block keeps `Settled`: its origin block is the current one. -/
private theorem settled_write {env : Environment} {w : World} (held : Settled env w)
    {height hash root timestamp generation : Nat} :
    Settled env (writeStart w height hash root w.number timestamp generation) :=
  ⟨held.fits,held.cutoff,held.past,fun init _ => held.past init⟩

/-- Every accepted call keeps `Settled`. Only `scheduleRules`, `scheduleStop` and `recover` write
the schedule, and each checks or keeps `Rules.fits`. Only `recover` with an upgrade writes the
cutoff, and it must keep it. `initializeInbox` checks the cutoff is below the current block, and
every origin is written at the current block of an initialized Inbox. -/
private theorem execute_settled {env : Environment} {w t : World} {call : Call} (held : Settled env w)
    (unstarted : w.initialized = false → w.start = none) (ok : execute env w call = some t) :
    Settled env t := by
  cases call with
  | advance number =>
    change advance env w number = some t at ok
    unfold advance at ok
    split at ok
    next guard =>
      cases Option.some.inj ok
      exact settled_frame held rfl rfl rfl rfl rfl (Nat.le_of_lt guard.1)
    next => simp at ok
  | initializeInbox caller =>
    change initializeInbox env w caller = some t at ok
    unfold initializeInbox at ok
    split at ok
    next guard =>
      have below : env.parameters.genesisCutoff < w.number := guard.2.2.2.2.2.1
      split at ok
      next =>
        split at ok
        next =>
          cases Option.some.inj ok
          exact ⟨held.fits,held.cutoff,fun _ => below,fun _ _ => below⟩
        next => simp at ok
      next =>
        cases Option.some.inj ok
        refine ⟨held.fits,held.cutoff,fun _ => below,fun _ started => ?_⟩
        have started : w.start.isSome = true := started
        rw [unstarted guard.2.1] at started
        cases started
    next => simp at ok
  | setOrigin caller height hash root =>
    change setOrigin env w caller height hash root = some t at ok
    unfold setOrigin at ok
    split at ok
    next => cases Option.some.inj ok; exact settled_write held
    next => simp at ok
  | correctStart caller height hash root =>
    change correctStart env w caller height hash root = some t at ok
    unfold correctStart at ok
    obtain ⟨old,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    split at ok
    next => cases Option.some.inj ok; exact settled_write held
    next => simp at ok
  | registry caller action =>
    change registryCall env w caller action = some t at ok
    unfold registryCall at ok
    split at ok
    next =>
      obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact settled_frame held rfl rfl rfl rfl rfl (Nat.le_refl _)
    next => simp at ok
  | enqueue raw paid refund =>
    change enqueue env w raw paid refund = some t at ok
    unfold enqueue at ok
    split at ok
    next =>
      obtain ⟨inbox,inner,rfl⟩ := Option.map_eq_some_iff.mp ok
      unfold Forced.enqueue at inner
      dsimp only at inner
      split at inner
      next =>
        cases Option.some.inj inner
        exact settled_frame held rfl rfl rfl rfl rfl (Nat.le_refl _)
      next => simp at inner
    next => simp at ok
  | sweep transfer =>
    change sweep w transfer = some t at ok
    obtain ⟨inbox,inner,rfl⟩ := Option.map_eq_some_iff.mp ok
    unfold Forced.sweep at inner
    split at inner
    next =>
      cases Option.some.inj inner
      exact settled_frame held rfl rfl rfl rfl rfl (Nat.le_refl _)
    next => simp at inner
  | forcedETH amount =>
    cases Option.some.inj ok
    exact settled_frame held rfl rfl rfl rfl rfl (Nat.le_refl _)
  | scheduleRules caller rule time =>
    change Protocol.scheduleRules env w caller rule time = some t at ok
    obtain ⟨schedule,scheduled,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact ⟨(Rules.schedule_rules_result scheduled).2.2.2.2.2,held.cutoff,held.past,held.origin⟩
  | scheduleStop caller time grid =>
    change Protocol.scheduleStop env w caller time grid = some t at ok
    obtain ⟨schedule,scheduled,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact ⟨(Rules.schedule_stop_result scheduled).2.2.2.2.2,held.cutoff,held.past,held.origin⟩
  | recover request =>
    change Protocol.recover env w request = some t at ok
    unfold Protocol.recover at ok
    obtain ⟨start,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    dsimp only at ok
    cases upgrade : request.upgrade <;> simp only [upgrade,Option.isSome_none,Option.isSome_some,
      Option.getD_none,Option.getD_some,Bool.false_eq_true,↓reduceIte] at ok
    · split at ok
      next =>
        obtain ⟨schedule,recovered,ok⟩ := Option.bind_eq_some_iff.mp ok
        obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
        exact ⟨recover_fits held.fits recovered,held.cutoff,held.past,fun init _ => held.past init⟩
      next => simp at ok
    · split at ok
      next guard =>
        obtain ⟨-,-,-,-,-,-,-,-,-,-,-,-,-,-,upgraded⟩ := guard
        obtain ⟨-,-,-,-,-,-,keep⟩ := upgraded trivial
        obtain ⟨schedule,recovered,ok⟩ := Option.bind_eq_some_iff.mp ok
        obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
        exact ⟨recover_fits held.fits recovered,keep.trans held.cutoff,held.past,
          fun init _ => held.past init⟩
      next => simp at ok
  | invalidate caller nonce =>
    change invalidate env w caller nonce = some t at ok
    unfold invalidate at ok
    split at ok
    next =>
      cases Option.some.inj ok
      exact settled_frame held rfl rfl rfl rfl rfl (Nat.le_refl _)
    next => simp at ok
  | rollback caller trusted restored =>
    change Protocol.rollback env w caller trusted restored = some t at ok
    unfold Protocol.rollback at ok
    split at ok
    next =>
      obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact settled_frame held rfl rfl rfl rfl rfl (Nat.le_refl _)
    next => simp at ok
  | land a =>
    change Protocol.land env w a = some t at ok
    unfold Protocol.land at ok
    split at ok
    next =>
      cases Option.some.inj ok
      exact settled_frame held rfl rfl rfl rfl rfl (Nat.le_refl _)
    next => simp at ok
  | unzenProve proposal header proof =>
    change unzenProve env w proposal header proof = some t at ok
    unfold unzenProve at ok
    split at ok
    next =>
      cases Option.some.inj ok
      exact settled_frame held rfl rfl rfl rfl rfl (Nat.le_refl _)
    next => simp at ok
  | image caller image register | verifier caller version =>
    simp only [execute] at ok
    split at ok
    next =>
      cases Option.some.inj ok
      exact settled_frame held rfl rfl rfl rfl rfl (Nat.le_refl _)
    next => simp at ok
  | observe number =>
    change observe env w number = some t at ok
    obtain ⟨s,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact settled_frame held rfl rfl rfl rfl rfl (Nat.le_refl _)
  | importSnapshot candidate durable =>
    change nodeImport env w candidate durable = some t at ok
    unfold nodeImport at ok
    split at ok
    next => simp at ok
    next =>
      split at ok
      next =>
        obtain ⟨installed,_,rfl⟩ := Option.map_eq_some_iff.mp ok
        exact settled_frame held rfl rfl rfl rfl rfl (Nat.le_refl _)
      next => simp at ok
  | restart | openSigner _ | switchSigner _ =>
    cases Option.some.inj ok
    exact settled_frame held rfl rfl rfl rfl rfl (Nat.le_refl _)
  | sign message signature persisted =>
    obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact settled_frame held rfl rfl rfl rfl rfl (Nat.le_refl _)

/-- Every reachable state is `Settled`; the initial one has the zero schedule, the deployment's
cutoff and an uninitialized Inbox. -/
private theorem trace_settled {env : Environment} {registry : RegistryMachine.State} {w : World}
    (trace : Trace env (empty env registry) w) : Settled env w := by
  induction trace with
  | refl =>
    exact ⟨(by decide : Rules.fits ⟨0,0,0,0,0⟩),rfl,(fun absent => nomatch absent),(fun absent => nomatch absent)⟩
  | @step before after prior change ih =>
    cases change with
    | call call =>
      cases ok : execute env before call with
      | none => simpa only [transact,ok,Option.getD_none] using ih
      | some result =>
        simpa only [transact,ok,Option.getD_some] using
          execute_settled ih (Journal.trace_frontier_shape prior).uninitialized ok
    | node after validated => exact settled_frame ih rfl rfl rfl rfl rfl (Nat.le_refl _)

/-! ### The closed certificate world -/

/-- After L1 reaches R+2 with the snapshots from R on showing `u`'s storage, the closed
certificate world at reference R+1 reads `u`'s whole history and shows `u`'s storage. -/
private theorem closed_world {env : Environment} {u : World} {R : Nat}
    (complete : u.history.map Snapshot.number = List.range (R+2))
    (closed : ∀ s ∈ u.history, R ≤ s.number → s.inbox = u.inbox ∧ s.schedule = u.schedule ∧
      s.queue = u.queue ∧ s.registryHistory = u.registry.registry.history ∧ s.start = u.start) :
    referencePrefix u (R+1) = u.history ∧ (certificateWorld env u (R+1)).inbox = u.inbox ∧
      (certificateWorld env u (R+1)).schedule = u.schedule ∧ (certificateWorld env u (R+1)).queue = u.queue ∧
      (certificateWorld env u (R+1)).registry.registry.history = u.registry.registry.history ∧
      (certificateWorld env u (R+1)).start = u.start ∧ (certificateWorld env u (R+1)).history = u.history := by
  have length : u.history.length = R+2 := by
    simpa only [List.length_map,List.length_range] using congrArg List.length complete
  have whole : referencePrefix u (R+1) = u.history := List.take_of_length_le (Nat.le_of_eq length)
  have last := congrArg List.getLast? complete
  rw [List.getLast?_map,List.getLast?_range] at last
  obtain ⟨s,found,number⟩ : ∃ s, u.history.getLast? = some s ∧ s.number = R+1 := by
    cases found : u.history.getLast? with
    | none => rw [found] at last; simp at last
    | some s =>
      rw [found] at last
      simp only [Option.map_some,Nat.succ_ne_zero,ite_false,Option.some.injEq] at last
      exact ⟨s,rfl,last⟩
  obtain ⟨inbox,schedule,queue,registry,start⟩ := closed s (List.mem_of_getLast? found) (by omega)
  refine ⟨whole,?_,?_,?_,?_,?_,?_⟩ <;>
    simp only [certificateWorld,whole,found,Option.getD_some,inbox,schedule,queue,registry,start]

/-! ### Segment facts -/

/-- Every block of a chain is valid on some parent. -/
private theorem chain_valid {r : Blocks.Policy} :
    ∀ {q : Header} {bs : List Block}, Blocks.Chain r q bs → ∀ b ∈ bs, ∃ parent, Blocks.Valid r parent b
  | _, [], _, _, absent => nomatch absent
  | q, b :: rest, ⟨valid,chain⟩, c, member => by
    rcases List.mem_cons.mp member with rfl | member
    · exact ⟨q,valid⟩
    · exact chain_valid chain c member

/-- A list of equal numbers is sorted. -/
private theorem constant_sorted {R : Nat} : ∀ {l : List Nat}, (∀ n ∈ l, n = R) → l.Pairwise (· ≤ ·)
  | [], _ => List.Pairwise.nil
  | n :: rest, equal => by
    refine List.Pairwise.cons (fun m member => ?_) (constant_sorted fun m member => equal m (List.mem_cons_of_mem _ member))
    rw [equal n List.mem_cons_self,equal m (List.mem_cons_of_mem _ member)]
    exact Nat.le_refl _

/-- With every archived anchor at the origin block, every anchor lookback is the origin block. -/
private theorem anchor_origin {cfg : Finality.Config} {archive : List Header}
    (anchors : ∀ h ∈ archive, h.anchor.number = cfg.originBlock) (n : Nat) :
    Finality.anchorAt cfg archive n = cfg.originBlock := by
  unfold Finality.anchorAt
  split
  · rfl
  · rcases found : archive[n-cfg.originHeight-1]? with _ | header
    · rfl
    · exact anchors header (List.mem_of_getElem? found)

/-- Above generation 0, with every archived anchor at the origin block, the committee active
at any height was elected at the origin block (the recovery committee and every normal one). -/
private theorem cutoff_origin {cfg : Finality.Config} {archive : List Header} (generation : cfg.generation ≠ 0)
    (anchors : ∀ h ∈ archive, h.anchor.number = cfg.originBlock) (height : Nat) :
    Finality.cutoff cfg archive height = cfg.originBlock := by
  unfold Finality.cutoff Finality.initialCutoff
  simp only [anchor_origin anchors,Nat.max_self,generation,ite_false,ite_self]

/-- One segment of K blocks above the origin needs at most K archived headers for its decision. -/
private theorem required_prefix {cfg : Finality.Config} {K : Nat} (grid : 0 < K) :
    Finality.requiredPrefix cfg (cfg.originHeight+K) ≤ K := by
  unfold Finality.requiredPrefix Finality.decisionLookback Finality.epoch
  have below := Nat.div_mul_le_self (cfg.originHeight+K-1) cfg.epochLen
  generalize (cfg.originHeight+K-1)/cfg.epochLen*cfg.epochLen = m at *
  split <;> omega

/-- A successful election over the registry at `cutoff` means a snapshot exists there. -/
private theorem elected_snapshot {registry : RegistryMachine.State} {unit minimum cutoff nMax : Nat}
    {members : List Committee.Entry}
    (elected : Committee.election unit minimum cutoff nMax (Finality.registryAt registry cutoff) = some members) :
    (RegistryHistory.latestSnapshot registry.history cutoff).isSome = true := by
  cases found : RegistryHistory.latestSnapshot registry.history cutoff with
  | some _ => rfl
  | none =>
    unfold Finality.registryAt at elected
    rw [found] at elected
    simp [Committee.election,Committee.chosen] at elected

/-- The next grid point above a grid point. -/
private theorem grid_next {start K height : Nat} (on : Start.onGrid start K height = true) :
    Start.onGrid start K (height+K) = true := by
  unfold Start.onGrid at on ⊢
  obtain ⟨positive,below,rest⟩ := of_decide_eq_true on
  apply decide_eq_true
  refine ⟨positive,by omega,?_⟩
  rw [show height+K-start = height-start+K by omega,Nat.add_mod_right]
  exact rest

/-- No grid point lies strictly between `c` and `c+K`. -/
private theorem no_leaves {K c : Nat} (grid : 0 < K) : gridCount K c (c+K) = 0 := by
  unfold gridCount
  rw [Nat.add_sub_cancel_left,Nat.div_self grid]

/-! ### The landing -/

/-- The landing of the recovered generation's first segment (design 4.3, step 7): parent and
origin at the current checkpoint `c`, last height `c+K` with the terminal `last`'s hashes, state
root and FI cursor, reference block `R+1`, committee snapshot `R`, no leaves
(`gridCount K c (c+K) = 0`), the blobs and the proofs. -/
private def segmentLanding (u : World) (last : Header) (R : Nat) (blobs : List Hash) (proofs : List Proof) :
    Landing :=
  ⟨⟨u.inbox.checkpoint.height,u.inbox.checkpoint.height+u.inbox.gridK,last.elHash,last.cometHash,
    last.valStateHash,last.stateRoot,R+1,last.cursor,R⟩,[],blobs,proofs⟩

/-- The landing's statement is the segment's statement under the closed world's policy. -/
private theorem segment_statement {env : Environment} {u x : World} {p : Header} {bs : List Block}
    {R : Nat} {blobs : List Hash} {proofs : List Proof}
    (inbox : x.inbox = u.inbox) (reference : referenceHash env x (R+1) = referenceHash env u (R+1))
    (record : recordAt u.inbox u.inbox.checkpoint.height = some u.inbox.checkpoint)
    (parent : Custody.HeaderOf u.inbox.checkpoint p)
    (last : (Blocks.terminal p bs).height = p.height+u.inbox.gridK) (grid : 0 < u.inbox.gridK)
    (generation : u.inbox.generation ≠ 0) (origin : u.inbox.origin.l1Block = R)
    (anchors : ∀ h ∈ bs.map Blocks.Block.header, h.anchor.number = R) :
    statement env u (segmentLanding u (Blocks.terminal p bs) R blobs proofs) =
      Blocks.statement (policy env x (bs.map Blocks.Block.header) (R+1)) p bs blobs := by
  obtain ⟨height,cut⟩ := parent
  have cutoff : (Consensus.activeAt (policy env x (bs.map Blocks.Block.header) (R+1)).consensus
      (Blocks.terminal p bs).height).cutoff = R := by
    change (Consensus.activeAt (Finality.derive (config x) x.registry.registry (bs.map Blocks.Block.header))
      (Blocks.terminal p bs).height).cutoff = R
    rw [Finality.active_cutoff,cutoff_origin]
    · change x.inbox.origin.l1Block = R
      rw [inbox,origin]
    · change x.inbox.generation ≠ 0
      rw [inbox]
      exact generation
    · intro h member
      change h.anchor.number = x.inbox.origin.l1Block
      rw [inbox,origin]
      exact anchors h member
  have leaves : gridLeaves (policy env x (bs.map Blocks.Block.header) (R+1)).gridK p.height
      (Blocks.terminal p bs).height (Blocks.cuts p bs) = [] := by
    change gridLeaves x.inbox.gridK p.height (Blocks.terminal p bs).height (Blocks.cuts p bs) = []
    unfold gridLeaves
    rw [inbox,last,no_leaves grid]
    rfl
  have el : p.elHash = u.inbox.checkpoint.elHash := congrArg Cut.elHash cut
  have comet : p.cometHash = u.inbox.checkpoint.cometHash := congrArg Cut.cometHash cut
  have cursor : p.cursor = u.inbox.checkpoint.cursor := congrArg Cut.cursor cut
  have val : p.valStateHash = u.inbox.checkpoint.valStateHash := congrArg Cut.valStateHash cut
  unfold statement segmentLanding Blocks.statement tableHash
  dsimp only
  rw [cutoff,leaves]
  dsimp only [policy,Finality.derive,config]
  rw [record,inbox,reference,last,height]
  simp only [Option.getD_some,el,comet,cursor,val]

/-- The two proofs `ProofComplete` gives, with the registered image, pass `land`'s proof check. -/
private theorem proofs_accepted {env : Environment} {u : World} {a : Landing} {image : Hash}
    (registered : image ∈ u.images) (dual : dualOK (a.proofs.map fun q => (q.backend,true)) = true)
    (valid : ∀ q ∈ a.proofs, q.image = image ∧
      env.verify u.verifier q.backend image q.bytes (statement env u a) = true) :
    proofsAccepted env u a = true := by
  unfold proofsAccepted
  rw [List.map_congr_left (g := fun q => (q.backend,true)) ?_]
  · exact dual
  · intro q member
    obtain ⟨same,verified⟩ := valid q member
    rw [same,verified]
    simp [registered]

/-! ### The landing after recovery -/

/-- From `Prepared`, the recovered generation's first K-block segment lands from the current
checkpoint `c` to `c+K`. -/
private theorem lands {env : Environment} {registry : RegistryMachine.State} {w u : World} {p : Header}
    {R : Nat} {keys : List Hash} {image : Hash} (premises : RecoveryPremises env registry)
    (prepared : Prepared env registry w u p R keys image) :
    ∃ a t, land env u a = some t ∧ u.inbox.checkpoint.height < t.inbox.checkpoint.height := by
  have reach := prepared.reachable
  have journal := Journal.trace_invariant reach
  have settled := trace_settled reach
  obtain ⟨start,written,onGrid,room,implementation⟩ := prepared.grid
  -- The generation's origin block R is above the genesis cutoff (`Finality.Ready`).
  have genesis : u.inbox.genesisCutoff ≤ R := by
    rw [settled.cutoff,← prepared.recovered.2.2]
    exact Nat.le_of_lt (settled.origin prepared.initialized (by rw [written]; rfl))
  obtain ⟨-,record,cursor⟩ := Journal.trace_frontier_record reach (by rw [written]; rfl)
  have complete : u.history.map Snapshot.number = List.range (R+2) := by
    rw [journal.complete,prepared.number.1]
  obtain ⟨whole,inbox,schedule,queue,history,started,snapshots⟩ :=
    closed_world (env := env) complete prepared.closed
  have reference : referenceHash env (certificateWorld env u (R+1)) (R+1) = referenceHash env u (R+1) := by
    simp only [referenceHash,referencePrefix,certificateWorld,List.take_take,Nat.min_self]
  have same : certificateWorld env (certificateWorld env u (R+1)) (R+1) = certificateWorld env u (R+1) :=
    certificate_world_idempotent
  -- `x` is the closed certificate world at reference R+1.
  obtain ⟨x,world⟩ : ∃ x, certificateWorld env u (R+1) = x := ⟨_,rfl⟩
  rw [world] at inbox schedule queue history started snapshots reference same
  obtain ⟨parent,bound⟩ := prepared.parent
  have height : p.height = u.inbox.checkpoint.height := parent.1
  have generation : u.inbox.generation ≠ 0 := Nat.pos_iff_ne_zero.mp prepared.recovered.1
  have valid := prepared.params.1
  have bounds : Committee.configOK u.inbox.gridK u.inbox.epochLen u.inbox.configuration.unsettled = true ∧
      0 < u.inbox.forcedDelay ∧ 1152 ≤ u.inbox.maxAnchorAge ∧ u.inbox.gridK ≤ u.inbox.maxBatchBlocks := by
    unfold Parameters.valid at valid
    rw [Bool.and_eq_true] at valid
    have rest := of_decide_eq_true valid.2
    exact ⟨valid.1,rest.1,rest.2.1,rest.2.2.1⟩
  have checked := bounds.1
  unfold Committee.configOK at checked
  have checked := of_decide_eq_true checked
  have grid : 0 < u.inbox.gridK := checked.1
  have registryAt : ∀ cutoff, Finality.registryAt x.registry.registry cutoff =
      Finality.registryAt u.registry.registry cutoff := by
    intro cutoff
    unfold Finality.registryAt
    rw [history]
  have committee : CommitteeLive env x R keys := by
    have live := prepared.committee
    unfold CommitteeLive at live ⊢
    rw [inbox,registryAt]
    exact live
  -- Step 1: the segment context of the closed world.
  have context : SegmentContext env x p R keys image := by
    refine
      { origin := ?_, parent := ?_, closed := ?_, numbers := ?_, timed := ?_, time := ?_,
        params := ?_, grid := ?_, stop := ?_, fits := ?_, rules := ?_, committee := committee, queue := ?_ }
    · rw [inbox,height]
      exact ⟨prepared.recovered.2.1,prepared.recovered.2.2,prepared.recovered.1⟩
    · rw [inbox]
      exact ⟨parent,bound,(congrArg Cut.cursor parent.2).trans cursor⟩
    · have listed : R ∈ u.history.map Snapshot.number := by
        rw [complete]
        exact List.mem_range.mpr (by omega)
      obtain ⟨s,member,number⟩ := List.mem_map.mp listed
      obtain ⟨sInbox,sSchedule,sQueue,sRegistry,sStart⟩ := prepared.closed s member (by omega)
      refine ⟨s,?_,number,?_,?_,?_,?_,?_⟩
      · rw [snapshots]; exact member
      · rw [inbox]; exact sInbox
      · rw [schedule]; exact sSchedule
      · rw [queue]; exact sQueue
      · rw [history]; exact sRegistry
      · rw [started]; exact sStart
    · rw [snapshots]; exact complete
    · intro s member
      rw [snapshots] at member
      exact (journal.snapshots s member).1
    · rw [inbox]
      exact ⟨prepared.parentTime.1,prepared.parentTime.2,by have := prepared.number.2; omega⟩
    · rw [inbox]; exact prepared.params
    · rw [started,inbox,height]
      exact ⟨start,written,onGrid,room⟩
    · rw [schedule]; exact prepared.stop
    · rw [schedule]; exact settled.fits
    · rw [schedule]; exact prepared.rules
    · rw [inbox,queue]
      refine ⟨(Journal.trace_record_shape reach).bounded,?_,prepared.queue⟩
      intro i _ below
      have listed : i ∈ u.queue.map Prod.fst := by
        rw [journal.queue.indexed]
        exact List.mem_range.mpr below
      obtain ⟨⟨j,e⟩,member,rfl⟩ := List.mem_map.mp listed
      exact ⟨e,member⟩
  -- Step 2: the segment and its blobs.
  obtain ⟨bs,length,chain,last,head,tail,consumed,linked,facts⟩ :=
    segment premises.recoveryCatalogueHash context
  rw [inbox] at length last head tail consumed
  obtain ⟨blobs,fewest,most,payload⟩ := premises.payloadLive bs (by rw [length]; exact checked.2.1)
    (fun b member => (facts b member).2.2.1)
  have anchors : ∀ h ∈ bs.map Blocks.Block.header, h.anchor.number = R := by
    intro h listed
    obtain ⟨b,member,rfl⟩ := List.mem_map.mp listed
    exact (facts b member).2.2.2.1
  have statementEq : ∀ proofs, statement env u (segmentLanding u (Blocks.terminal p bs) R blobs proofs) =
      Blocks.statement (policy env x (bs.map Blocks.Block.header) (R+1)) p bs blobs := fun _ =>
    segment_statement inbox reference record parent last grid generation prepared.recovered.2.2 anchors
  -- Step 3: the certificate, with archive root `p` and no prior headers.
  have origin : certificateOrigin x = some u.inbox.checkpoint := by
    change recordAt x.inbox x.inbox.origin.height = _
    rw [inbox,prepared.recovered.2.1]
    exact record
  have originHeight : (config x).originHeight = p.height := by
    change x.inbox.origin.height = p.height
    rw [inbox,prepared.recovered.2.1,height]
  have originBlock : (config x).originBlock = R := by
    change x.inbox.origin.l1Block = R
    rw [inbox,prepared.recovered.2.2]
  have epoch : 3 ≤ (config x).epochLen := by
    change 3 ≤ x.inbox.epochLen
    rw [inbox]
    exact checked.2.2.1
  have ready : Finality.Ready (config x) x.registry.registry (bs.map Blocks.Block.header)
      (Blocks.terminal p bs).height := by
    obtain ⟨members,elected,-⟩ := prepared.committee.2
    refine ⟨epoch,?_,?_,?_,?_,?_,?_,?_⟩
    · rw [originBlock]
      change x.inbox.genesisCutoff ≤ R
      rw [inbox]
      exact genesis
    · rw [originHeight]
      have heights := Archive.linked_heights linked
      rw [List.map_cons,List.range'_succ] at heights
      exact (List.cons.inj heights).2
    · intro h listed
      obtain ⟨b,member,rfl⟩ := List.mem_map.mp listed
      obtain ⟨q,valid⟩ := chain_valid chain b member
      exact ⟨valid.anchor.generation,Nat.le_of_eq (originBlock.trans (facts b member).2.2.2.1.symm)⟩
    · apply constant_sorted (R := R)
      intro n listed
      obtain ⟨h,headers,rfl⟩ := List.mem_map.mp listed
      exact anchors h headers
    · rw [history]
      exact (Economics.registry_history_time premises.currentRegistryGenesis reach).1
    · rw [last,← originHeight,List.length_map,length]
      exact required_prefix grid
    · have nonzero : (config x).generation ≠ 0 := by
        change x.inbox.generation ≠ 0
        rw [inbox]
        exact generation
      have initial : Finality.initialCutoff (config x) = R := by
        simp only [Finality.initialCutoff,nonzero,↓reduceIte,originBlock]
      rw [initial,history]
      exact elected_snapshot elected
  have authenticated : Archive.Authenticated env.headerHash env.headerParent (config x)
      (certificateOriginCut (certificateWorld env x (R+1))) (R+1) (bs.map Blocks.Block.header) p bs := by
    refine ⟨p,[],originHeight.symm,?_,bound,rfl,rfl,linked,?_,?_,?_,?_⟩
    · rw [same]
      unfold certificateOriginCut
      rw [origin]
      exact parent.2
    · intro h listed
      obtain ⟨b,member,rfl⟩ := List.mem_map.mp listed
      exact (facts b member).1
    · intro b member
      exact (facts b member).2.1
    · rw [originBlock]
      exact Nat.le_succ R
    · intro h listed
      rw [anchors h listed]
      exact Nat.le_succ R
  have live : LiveBatchCertificate env x (statement env u (segmentLanding u (Blocks.terminal p bs) R blobs []))
      (bs.map Blocks.Block.header) p bs := by
    refine ⟨ready,⟨chain,payload⟩,statementEq [],bound,fun b member => (facts b member).1,?_,authenticated⟩
    intro switching atStart
    rw [started,written] at atStart
    exact implementation switching atStart
  have certified : ImageCertifies env u image
      (statement env u (segmentLanding u (Blocks.terminal p bs) R blobs [])) := by
    refine ⟨bs.map Blocks.Block.header,p,bs,?_,fun b member => (facts b member).2.2.2.2⟩
    show LiveBatchCertificate env (certificateWorld env u (R+1)) _ (bs.map Blocks.Block.header) p bs ∧
      (referencePrefix u (R+1)).map Snapshot.number = List.range (R+1+1) ∧
      (certificateOrigin (certificateWorld env u (R+1))).isSome = true
    rw [world,whole,origin]
    exact ⟨live,complete,rfl⟩
  -- Step 4: the proofs and the landing checks.
  obtain ⟨proofs,dual,verified⟩ := prepared.proofs.2 u image _ certified
  have checks : LandingChecks env u (segmentLanding u (Blocks.terminal p bs) R blobs proofs) := {
    initialized := prepared.initialized
    started := by rw [written]; rfl
    entered := prepared.entered
    origin := Nat.le_of_eq prepared.recovered.2.1
    parentBeforeFrontier := Nat.le_refl _
    progress := Nat.lt_add_of_pos_right grid
    height := room
    parentGrid := by rw [written]; exact onGrid
    lastGrid := by rw [written]; exact grid_next onGrid
    frontierGrid := by rw [written]; exact onGrid
    batchSize := by
      change u.inbox.checkpoint.height+u.inbox.gridK-u.inbox.checkpoint.height ≤ u.inbox.maxBatchBlocks
      rw [Nat.add_sub_cancel_left]
      exact bounds.2.2.2
    record := by
      change (recordAt u.inbox u.inbox.checkpoint.height).isSome = true
      rw [record]; rfl
    generation := Or.inr prepared.recovered.2.1.symm
    leafCount := (no_leaves grid).symm
    frontier := fun below => absurd below (Nat.lt_irrefl _)
    cursor := by rw [record]; exact cursor
    head := head
    tail := tail
    service := by
      change (Blocks.terminal p bs).cursor-u.inbox.head ≤
        u.inbox.checkpoint.height+u.inbox.gridK-u.inbox.checkpoint.height
      rw [Nat.add_sub_cancel_left]
      exact consumed
    reference := by
      change R+1 < u.number
      rw [prepared.number.1]
      exact Nat.lt_succ_self _
    referenceAge := by
      change u.number-(R+1) ≤ 8191
      rw [prepared.number.1]
      omega
    blobs := ⟨fewest,most⟩
    unzen := prepared.fence
    proofs := proofs_accepted prepared.proofs.1 dual verified }
  refine ⟨segmentLanding u (Blocks.terminal p bs) R blobs proofs,
    landed u (segmentLanding u (Blocks.terminal p bs) R blobs proofs),?_,Nat.lt_add_of_pos_right grid⟩
  unfold land
  rw [ite_eq_left checks]

/-! ### H4 -/

/-- H4, recoverability (design 4.3). From every reachable, initialized state satisfying `LiveAt`,
under `RecoveryPremises`, a `RecoveryTrace` (no rollback; one plain recovery with no exclusions,
no FI blanking and no upgrade) reaches a state where `land` accepts the recovered generation's
first K-block segment from the current checkpoint `c` to `c+K`. If anything had landed before,
the recovery kept `c`, so the new checkpoint is above the starting one. -/
theorem recoverable : Etna.Statements.Current.Recoverability := by
  intro env registry premises w trace initialized live
  obtain ⟨u,p,R,keys,image,prepared⟩ := prepare premises trace initialized live
  obtain ⟨a,t,ok,above⟩ := lands premises prepared
  refine ⟨u,a,t,prepared.path,ok,fun landed => ?_⟩
  rw [← prepared.progress landed]
  exact above

end Etna.Design.Current.Protocol.Recovery
