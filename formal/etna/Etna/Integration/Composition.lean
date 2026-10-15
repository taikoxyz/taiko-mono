module
public import Etna.Common.Assumptions
public import Etna.FI.Proofs
public import Etna.Committee.Proofs
public import Etna.Landing.Proofs
@[expose] public section
set_option maxHeartbeats 4000000
namespace Etna.Integration

/-- Exact decoded block identity shared by FI and committee validation. Payload/header and
blob decoding authenticity remain external; the reducer checks both rules on this one item. -/
structure Block (ctx : Committee.Context) where
  committee : Committee.AuthenticatedBlockFacts ctx
  envelope : FI.Bytes
  attributes : Nat
  stateRoot : Word256
  hashBound : committee.facts.blockHash < 2^256

structure State where
  committee : Committee.CommitteeState
  cursor : Nat
  stateRoot : Word256

/-- Concrete authenticated views, indexed by the actual header/anchor identity. These
functions are semantic boundaries, not booleans asserting the desired conservation result.
The payload view binds canonical envelope bytes, execution attributes and terminal root. -/
structure Authentication (ctx : Committee.Context) where
  inbox : Nat
  delay : Word64
  codec : FI.Codec
  fiAuthentication : Nat → FI.Authentication
  execution : FI.Execution
  payload : Nat → Option (FI.Bytes × Nat × Word256)
  root : Nat → Nat
  timestamp : Nat → Nat
  anchorNumber : Nat → Nat
  anchorCheckpoint : Nat → Nat
  /-- Authenticated genesis/configuration commitment at the exact deployment identities. -/
  genesis : Word256 → Word64 → Landing.Address → Landing.Address → Word64 → Word256 →
    Option (Committee.Schedule × Nat × Word64 × Nat)
  tail : Nat → Nat → Nat
  checkpoint : Nat → Nat → Option State
  decodeBlobs : List Word256 → Option (List (Block ctx))
  ancestor : Nat → Nat → Prop

/-- Each step carries the actual successful FI/COM executions and concrete shared input
links. FI's per-step authentication parent may vary; its root/time/tail views must agree
with this batch's one authenticated L1 view and its Inbox/genesis configuration. -/
structure JointStep {ctx : Committee.Context} (a : Authentication ctx)
    (before after : State) (block : Block ctx) (consumed : Option Nat)
    (updates : Committee.Updates) where
  fi : FI.ValidStep before.cursor after.cursor consumed
  authentication : fi.authentication = a.fiAuthentication before.committee.blockHash
  committee : Committee.step ctx before.committee block.committee = .ok (after.committee, updates)
  parent : fi.context.parent = before.committee.blockHash
  anchor : fi.context.anchorHash = block.committee.facts.anchor.blockHash
  root : fi.context.stateRoot = block.committee.facts.anchor.stateRoot
  anchorNumber : block.committee.facts.anchor.number = a.anchorNumber fi.context.anchorHash
  anchorCheckpoint : block.committee.facts.anchor.checkpoint = a.anchorCheckpoint fi.context.anchorHash
  inbox : fi.context.inbox = a.inbox
  delay : fi.context.delay = a.delay
  attributes : fi.context.attributes = block.attributes
  payload : a.payload block.committee.facts.blockHash = some (block.envelope, block.attributes, block.stateRoot)
  decoding : a.codec.decodeEnvelope block.envelope = some (fi.witness, fi.transactions)
  codec : fi.codec = a.codec
  execution : fi.execution = a.execution
  authenticatedRoot : fi.authentication.committedRoot = a.root
  authenticatedTime : fi.authentication.anchorTime = a.timestamp
  authenticatedTail : fi.authentication.queueTail = a.tail
  stateRoot : after.stateRoot = block.stateRoot

inductive JointTrace {ctx : Committee.Context} (a : Authentication ctx) :
    State → List (Block ctx) → List (Option Nat) → Committee.Updates → State → Prop where
  | nil (state) : JointTrace a state [] [] [] state
  | cons {before middle after block blocks consumed consumptions updates laterUpdates} :
    JointStep a before middle block consumed updates →
    JointTrace a middle blocks consumptions laterUpdates after →
    JointTrace a before (block::blocks) (consumed::consumptions) (updates++laterUpdates) after

theorem fi_projection {ctx : Committee.Context} {a : Authentication ctx}
    {before after blocks consumed updates} (trace : JointTrace a before blocks consumed updates after) :
    FI.ValidTrace before.cursor consumed after.cursor := by
  induction trace with
  | nil => exact .nil _
  | cons step _ ih => exact .cons step.fi ih

theorem committee_projection {ctx : Committee.Context} {a : Authentication ctx}
    {before after blocks consumed updates} (trace : JointTrace a before blocks consumed updates after) :
    Committee.replay ctx (blocks.map Block.committee) before.committee = .ok (after.committee, updates) := by
  induction trace with
  | nil => rfl
  | cons step _ ih => simp [Committee.replay, step.committee, ih, Bind.bind, Except.bind, Pure.pure, Except.pure]

theorem trace_lengths {ctx : Committee.Context} {a : Authentication ctx}
    {before after blocks consumed updates} (trace : JointTrace a before blocks consumed updates after) :
    consumed.length = blocks.length := by
  induction trace with
  | nil => rfl
  | cons _ _ ih => simpa using ih

/-- Height progression is extracted from the actual checked Committee.step branch. -/
theorem step_height {ctx : Committee.Context} {before after : Committee.CommitteeState}
    {block : Committee.AuthenticatedBlockFacts ctx} {updates}
    (accepted : Committee.step ctx before block = .ok (after, updates)) :
    after.height = before.height + 1 ∧ after.blockHash = block.facts.blockHash ∧
      after.anchor = block.facts.anchor ∧ after.height ≤ Committee.max64 := by
  unfold Committee.step at accepted
  simp only [Bind.bind, Except.bind, Pure.pure, Except.pure,
    MonadExcept.throw, throwThe, MonadExceptOf.throw] at accepted
  split at accepted
  · contradiction
  · rename_i identity
    have identity' : block.facts.height = before.height + 1 := by simp_all
    repeat' (split at accepted <;> try simp_all)
    all_goals rw [← accepted.1]; exact ⟨rfl, rfl, rfl, by change before.height + 1 ≤ Committee.max64; omega⟩

theorem trace_height {ctx : Committee.Context} {a : Authentication ctx}
    {before after blocks consumed updates} (trace : JointTrace a before blocks consumed updates after) :
    after.committee.height = before.committee.height + blocks.length := by
  induction trace with
  | nil => simp
  | cons step _ ih =>
    have h := (step_height step.committee).1
    simp only [List.length_cons]
    omega

theorem trace_height_bound {ctx : Committee.Context} {a : Authentication ctx}
    {before after blocks consumed updates} (trace : JointTrace a before blocks consumed updates after)
    (initial : before.committee.height ≤ Committee.max64) : after.committee.height ≤ Committee.max64 := by
  induction trace with
  | nil => exact initial
  | cons step _ ih => exact ih (step_height step.committee).2.2.2

theorem trace_count {ctx : Committee.Context} {a : Authentication ctx}
    {before after blocks consumed updates} (trace : JointTrace a before blocks consumed updates after) :
    after.cursor = before.cursor + FI.consumptionCount consumed ∧
    FI.consumptionCount consumed ≤ blocks.length := by
  exact ⟨FI.fi07_trace_count (fi_projection trace), by
    simpa [trace_lengths trace] using FI.fi07_count_le_blocks consumed⟩

theorem trace_append {ctx : Committee.Context} {a : Authentication ctx}
    {before middle after xs ys cs ds us vs}
    (left : JointTrace a before xs cs us middle) (right : JointTrace a middle ys ds vs after) :
    JointTrace a before (xs++ys) (cs++ds) (us++vs) after := by
  induction left with
  | nil => exact right
  | cons step _ ih => simpa [List.append_assoc] using JointTrace.cons step (ih right)

/-- Arbitrary finite contiguous cuts, retaining both histories and all ordered record pairs. -/
inductive Cuts {ctx : Committee.Context} (a : Authentication ctx) :
    State → List (List (Block ctx)) → List (Option Nat) → Committee.Updates → State → Prop where
  | nil (state) : Cuts a state [] [] [] state
  | cons {before middle after blocks parts consumed later updates laterUpdates} :
    JointTrace a before blocks consumed updates middle →
    Cuts a middle parts later laterUpdates after →
    Cuts a before (blocks::parts) (consumed++later) (updates++laterUpdates) after

theorem arbitrary_cuts {ctx : Committee.Context} {a : Authentication ctx}
    {before after parts consumed updates} (cuts : Cuts a before parts consumed updates after) :
    JointTrace a before parts.flatten consumed updates after := by
  induction cuts with
  | nil => exact .nil _
  | cons trace _ ih => exact trace_append trace ih

/-- Computed output carried by a guest batch; no supplied head/count equation. -/
structure BatchSummary (ctx : Committee.Context) where
  parent : State
  terminal : State
  blocks : List (Block ctx)
  consumed : List (Option Nat)
  updates : Committee.Updates

def BatchSummary.blockCount (batch : BatchSummary ctx) : Nat := batch.blocks.length

def summaryStatement (base : Landing.LandStatement) (batch : BatchSummary ctx) : Landing.LandStatement :=
  { base with
    parentHeight := Landing.natWord batch.parent.committee.height,
    parentHash := Landing.natWord batch.parent.committee.blockHash,
    lastHeight := Landing.natWord batch.terminal.committee.height,
    lastBlockHash := Landing.natWord batch.terminal.committee.blockHash,
    lastStateRoot := Landing.natWord batch.terminal.stateRoot.val,
    headBefore := Landing.natWord batch.parent.cursor,
    headAfter := Landing.natWord batch.terminal.cursor }

/-- Real guest validity must establish this concrete relation. Initial checkpoint/committee
history, canonical payload/blob decoding and L1 ancestry are explicit authentication gaps.
The public statement's other eleven words are fixed by the actual captured Landing context.
No Dummy provider, True guest relation or global Keccak injectivity is an instance here. -/
structure ValidBatch {ctx : Committee.Context} (a : Authentication ctx)
    (w : Landing.World) (i : Landing.LandInput) (x : Landing.ExternalOutcomes)
    (statement : Landing.LandStatement) (batch : BatchSummary ctx) : Prop where
  trace : JointTrace a batch.parent batch.blocks batch.consumed batch.updates batch.terminal
  nonempty : batch.blocks ≠ []
  checkpoint : a.checkpoint w.checkpoint.height w.checkpoint.blockHash.val = some batch.parent
  parentHeight : batch.parent.committee.height = w.checkpoint.height
  parentHash : batch.parent.committee.blockHash = w.checkpoint.blockHash.val
  parentCursor : batch.parent.cursor = w.head.val
  inbox : a.inbox = w.inbox.val
  genesis : a.genesis w.l1ChainId w.l2ChainId w.inbox w.registry w.generation w.config =
    some (ctx.schedule, ctx.cap, a.delay, ctx.chain)
  decoded : a.decodeBlobs (Landing.actualBlobs x.environment) = some batch.blocks
  ancestry : ∀ block ∈ batch.blocks, a.ancestor block.committee.facts.anchor.blockHash
    (match Landing.referenceHash x.environment i.reference with | .ok (_, hash) => hash.val | .error _ => 0)
  statement : statement = summaryStatement (Landing.computedStatement w i x) batch

/-- A specialized soundness premise, binding acceptance of the actual statement to ValidBatch.
A deployment needs a real verifier/guest argument to construct this value. -/
structure GuestSoundness {ctx : Committee.Context} (a : Authentication ctx)
    (w : Landing.World) (i : Landing.LandInput) (x : Landing.ExternalOutcomes) where
  sound : x.verifierReturnsNormally = true →
    ∃ batch, ValidBatch a w i x (Landing.computedStatement w i x) batch

theorem successful_verifier (w : Landing.World) (i : Landing.LandInput) (x : Landing.ExternalOutcomes)
    (accepted : (Landing.execLandSteps w i x).error = none) : x.verifierReturnsNormally = true := by
  have checks := Landing.successful_checks w i x accepted
  simp only [Landing.execLandSteps, checks.1, checks.2] at accepted
  simp only [Landing.execChecked, Landing.finish, Landing.Journal.update, Landing.Journal.current] at accepted
  split_ifs at accepted <;> simp_all

/-- LAND-07: one authenticated block history drives FI consumption, committee/certificate
history, checked height progress and the committed Landing interval/payment. This is a
conditional specification composition; EVM bytecode and genuine guest soundness are external. -/
theorem compose_trace_landing {ctx : Committee.Context} (a : Authentication ctx)
    (w : Landing.World) (i : Landing.LandInput) (x : Landing.ExternalOutcomes)
    (guest : GuestSoundness a w i x)
    (accepted : (Landing.execLandSteps w i x).error = none) :
    ∃ batch, ValidBatch a w i x (Landing.computedStatement w i x) batch ∧
      (Landing.runTransaction w (Landing.execLandSteps w i x)).world.head.val =
        w.head.val + FI.consumptionCount batch.consumed ∧
      FI.consumptionCount batch.consumed ≤ batch.blockCount ∧
      i.lastHeight.val = w.checkpoint.height + batch.blockCount ∧
      Committee.replay ctx (batch.blocks.map Block.committee) batch.parent.committee =
        .ok (batch.terminal.committee, batch.updates) ∧
      (Landing.execLandSteps w i x).journal.current.transfers = w.transfers ++
        (if i.headAfter ≠ w.head ∧ 0 < Landing.fees w.fee w.head.val i.headAfter.val * 1000000000 then
          [⟨i.recipient, Landing.fees w.fee w.head.val i.headAfter.val * 1000000000⟩] else []) := by
  obtain ⟨batch, valid⟩ := guest.sound (successful_verifier w i x accepted)
  have count := trace_count valid.trace
  have small := FI.fi07_trace_bound (before := batch.parent.cursor)
    (by rw [valid.parentCursor]; have h := w.head.isLt; omega) (fi_projection valid.trace)
  have words := congrArg Landing.LandStatement.headAfter valid.statement
  have heads : i.headAfter.val = batch.terminal.cursor :=
    Landing.natWord_injective _ _ (by have h := i.headAfter.isLt; omega) (by omega) words
  refine ⟨batch, valid, ?_, count.2, ?_, committee_projection valid.trace,
    (Landing.recipient_bound w i x accepted).2⟩
  · rw [Landing.committed_head w i x accepted, heads, count.1, valid.parentCursor]
  · have progress : w.checkpoint.height < i.lastHeight.val := by
      have checked := (Landing.successful_checks w i x accepted).1
      unfold Landing.validate at checked
      split_ifs at checked; simp_all
    have terminalBound := trace_height_bound valid.trace (by
      rw [valid.parentHeight]; have h := i.lastHeight.isLt; unfold Committee.max64; omega)
    have lastWords := congrArg Landing.LandStatement.lastHeight valid.statement
    have height : i.lastHeight.val = batch.terminal.committee.height :=
      Landing.natWord_injective _ _ (by have h := i.lastHeight.isLt; omega)
        (by unfold Committee.max64 at terminalBound; omega) lastWords
    rw [height]
    simpa [BatchSummary.blockCount, valid.parentHeight] using trace_height valid.trace

/-- Recover the bounded reducer cursor from the actual eighteen-word public statement. -/
theorem valid_batch_head {ctx : Committee.Context} {a : Authentication ctx}
    {w : Landing.World} {i : Landing.LandInput} {x : Landing.ExternalOutcomes}
    {batch : BatchSummary ctx} (valid : ValidBatch a w i x (Landing.computedStatement w i x) batch) :
    i.headAfter.val = batch.terminal.cursor := by
  have small := FI.fi07_trace_bound (before := batch.parent.cursor)
    (by rw [valid.parentCursor]; have h := w.head.isLt; omega) (fi_projection valid.trace)
  have words := congrArg Landing.LandStatement.headAfter valid.statement
  exact Landing.natWord_injective i.headAfter.val batch.terminal.cursor
    (by have h := i.headAfter.isLt; omega) (by omega) words

/-- Cut-independent fee arithmetic uses the same authenticated immutable retained entries. -/
inductive FeeCuts (fee : Nat → Word64) : Nat → List Nat → Nat → Nat → Prop where
  | nil (head) : FeeCuts fee head [] head 0
  | cons {before middle after heads paid} : before ≤ middle →
    FeeCuts fee middle heads after paid →
    FeeCuts fee before (middle::heads) after (Landing.fees fee before middle + paid)

theorem fee_cuts_exact {fee : Nat → Word64} {before after heads paid}
    (cuts : FeeCuts fee before heads after paid) : before ≤ after ∧ paid = Landing.fees fee before after := by
  induction cuts with
  | nil => simp [Landing.fees]
  | cons monotone _ ih =>
    exact ⟨Nat.le_trans monotone ih.1, by rw [ih.2, Landing.fee_interval_add fee _ _ _ monotone ih.1]⟩

/-- Model execution preserves retained queue fee entries; actual callbacks need the named
Landing.CallbackFrame relation already exposed by the landing boundary. -/
theorem landing_fee_frame (w : Landing.World) (i : Landing.LandInput) (x : Landing.ExternalOutcomes)
    (accepted : (Landing.execLandSteps w i x).error = none) :
    (Landing.runTransaction w (Landing.execLandSteps w i x)).world.fee = w.fee := by
  have checks := Landing.successful_checks w i x accepted
  simp only [Landing.runTransaction, accepted, Option.isSome_none, Bool.false_eq_true, ↓reduceIte]
  simp only [Landing.execLandSteps, checks.1, checks.2]
  simp [Landing.execChecked, Landing.finish, Landing.Journal.update, Landing.Journal.current]
  split_ifs <;> rfl

/-- Any finite sequence of successful landed pieces of the same authenticated history.
The guest must establish each concrete ValidBatch; the fee amount is computed per call. -/
inductive LandedCuts {ctx : Committee.Context} (a : Authentication ctx) :
    Landing.World → State → List (List (Block ctx)) → List (Option Nat) → Committee.Updates →
    Landing.World → State → Nat → Prop where
  | nil (w state) : LandedCuts a w state [] [] [] w state 0
  | cons {w before middle final after blocks parts consumed later updates laterUpdates paid}
      (i : Landing.LandInput) (x : Landing.ExternalOutcomes)
      (valid : ValidBatch a w i x (Landing.computedStatement w i x)
        ⟨before,middle,blocks,consumed,updates⟩)
      (accepted : (Landing.execLandSteps w i x).error = none)
      (rest : LandedCuts a (Landing.runTransaction w (Landing.execLandSteps w i x)).world
        middle parts later laterUpdates final after paid) :
      LandedCuts a w before (blocks::parts) (consumed++later) (updates++laterUpdates) final after
        (Landing.fees w.fee w.head.val i.headAfter.val + paid)

/-- LAND-07 over arbitrary many actual successful cuts: join the same joint history,
derive the final head and telescope fees on retained entries. Amounts here are gwei;
Landing.fees_exact_once binds each interval's positive payment instruction in wei. -/
theorem landed_cuts_compose {ctx : Committee.Context} {a : Authentication ctx}
    {w before parts consumed updates final after paid}
    (cuts : LandedCuts a w before parts consumed updates final after paid) :
    JointTrace a before parts.flatten consumed updates after ∧
    final.head.val = w.head.val + FI.consumptionCount consumed ∧
    paid = Landing.fees w.fee w.head.val final.head.val := by
  induction cuts with
  | nil => exact ⟨JointTrace.nil _, by simp [FI.consumptionCount], by simp [Landing.fees]⟩
  | @cons w before middle final after blocks parts consumed later updates laterUpdates paid i x valid accepted rest ih =>
    have head := Landing.committed_head w i x accepted
    have count := trace_count valid.trace
    have bound := (Landing.fees_exact_once w i x accepted).2.1
    have endBound : i.headAfter.val ≤ final.head.val := by rw [head] at ih; omega
    refine ⟨trace_append valid.trace ih.1, ?_, ?_⟩
    · have headCount : i.headAfter.val = w.head.val + FI.consumptionCount consumed := by
        rw [valid_batch_head valid, count.1, valid.parentCursor]
      rw [ih.2.1, head, headCount]
      simp [FI.consumptionCount, List.filter_append, Nat.add_assoc]
    · rw [ih.2.2, landing_fee_frame w i x accepted, head]
      exact (Landing.fee_interval_add w.fee _ _ _ bound endBound).symm
end Etna.Integration
