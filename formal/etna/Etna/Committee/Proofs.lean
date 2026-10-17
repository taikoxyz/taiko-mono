module
public import Etna.Committee.Transition
@[expose] public section
namespace Etna.Committee

theorem starting_iff (s : Schedule) (h t : Nat) (length : 0 < s.length) :
    startingAt s h = some t ↔ h = H s t := by
  unfold startingAt sub H
  have nz : s.length ≠ 0 := by omega
  simp only [nz, ↓reduceIte]
  by_cases hh : 1 ≤ h
  · simp only [hh, ↓reduceIte, Option.bind_some]
    constructor
    · intro hs
      split_ifs at hs with hm
      · simp only [Option.some.injEq] at hs
        have hd := Nat.div_add_mod (h-1) s.length
        rw [hm, hs] at hd
        rw [Nat.mul_comm] at hd
        omega
    · intro he
      have hx : h-1=t*s.length := by omega
      simp [hx, nz]
  · simp only [hh, ↓reduceIte, Option.bind_none, reduceCtorEq, false_iff]
    omega

theorem switch_iff (s : Schedule) (h t : Nat) (length : 0 < s.length) :
    switchTarget s h = some t ↔ 0 < t ∧ h+2 = H s t ∧ h+2 ≤ max64 := by
  unfold switchTarget add checked
  by_cases hb : h+2 ≤ max64
  · simp only [hb, ↓reduceIte, Option.bind_some]
    cases hs : startingAt s (h+2) with
    | none =>
      simp only [Option.bind_none, reduceCtorEq, false_iff]
      intro ⟨_, ht, _⟩
      have := (starting_iff s (h+2) t length).mpr ht
      simp_all
    | some v =>
      have hv := (starting_iff s (h+2) v length).mp hs
      simp only [Option.bind_some]
      split_ifs with hz
      · simp only [false_iff]
        intro ⟨positive, ht, _⟩
        unfold H at hv ht
        subst v
        simp only [Nat.zero_mul, Nat.add_zero] at hv
        omega
      · simp only [Option.some.injEq]
        constructor
        · intro e; subst v; exact ⟨by omega, hv, trivial⟩
        · rintro ⟨_, ht, _⟩
          unfold H at hv ht
          nlinarith
  · simp [hb]

/-- COM-01: exact update height in the checked domain and D/S/H spacing. -/
theorem schedule_exact (s : Schedule) (t : Nat) (length : 3 ≤ s.length)
    (positive : 0 < t) (bounded : H s t ≤ max64) :
    D s t + 1 = S s t ∧ S s t+2 = H s t ∧
      ∀ h, switchTarget s h = some t ↔ h = S s t := by
  have ht : 3 ≤ H s t := by unfold H; nlinarith
  refine ⟨by unfold D S; omega, by unfold S; omega, ?_⟩
  intro h
  rw [switch_iff s h t (by omega)]
  unfold S
  omega

theorem epoch_range (s : Schedule) (t h : Nat) (length : 0 < s.length)
    (lower : H s t ≤ h) (upper : h < H s (t+1)) : epochOf s h = some t := by
  have nz : s.length ≠ 0 := by omega
  unfold epochOf div
  simp only [nz, ↓reduceIte, Option.some.injEq]
  apply Nat.div_eq_of_lt_le
  · unfold H at lower
    omega
  · unfold H at lower upper
    omega

/-- COM-03: lookups use outgoing until H, incoming from H. Missing pending never falls back. -/
theorem activation_exact (s : Schedule) (st : CommitteeState) (t h : Nat)
    (length : 0 < s.length) (lower : H s t ≤ h) (upper : h < H s (t+1)) :
    authority s st h = lookup st.records t := by
  simp [authority, epoch_range s t h length lower upper]

theorem missing_pending (s : Schedule) (st : CommitteeState) (t : Nat)
    (length : 0 < s.length) (missing : lookup st.records t = none) :
    authority s st (H s t) = none := by
  apply Eq.trans (activation_exact s st t (H s t) length (by omega) ?_) missing
  unfold H; nlinarith

/-- COM-02: committed parent's root/cutoff uniquely identify the authenticated snapshot;
the candidate anchor is not an input to this reducer. -/
theorem parent_anchor_unique (a : Authentication) (s : Schedule) (p : Anchor)
    (h t : Nat) (w : Witness) (r : Record) (switch : switchTarget s h = some t)
    (accepted : incoming a s p h (some w) = .ok (some r)) :
    a.stored p.stateRoot p.number = some w.snapshot ∧ r = a.derive t w.snapshot ∧
    r.epoch = t ∧ r.root = w.snapshot.root ∧ r.cutoff = p.number ∧
    w.snapshot.cutoff = p.number ∧ r.members ≠ [] := by
  unfold incoming at accepted
  simp only [switch] at accepted
  split_ifs at accepted with verified fields empty; simp_all
  exact a.sound _ _ _ _ verified

theorem nonswitch_witness_rejected (a : Authentication) (s : Schedule) (p : Anchor)
    (h : Nat) (w : Witness) (hs : switchTarget s h = none) :
    incoming a s p h (some w) = .error .witness := by simp [incoming, hs]

theorem different_snapshot_rejected (a : Authentication) (s : Schedule) (p : Anchor)
    (h t : Nat) (w : Witness) (stored : Snapshot) (r : Record)
    (switch : switchTarget s h = some t) (known : a.stored p.stateRoot p.number = some stored)
    (different : stored ≠ w.snapshot) : incoming a s p h (some w) ≠ .ok (some r) := by
  intro accepted
  have hroot := (parent_anchor_unique a s p h t w r switch accepted).1
  rw [known] at hroot
  exact different (Option.some.inj hroot)

/-- COM-04: identity, signer uniqueness and strict quorum; signature semantics are explicit. -/
theorem certificate_authority (crypto : Crypto) (chain h hash : Nat) (r : Record) (cert : Certificate)
    (accepted : certificateOK crypto chain h hash r cert = true) :
    cert.chain = chain ∧ cert.height = h ∧ cert.blockHash = hash ∧
    (cert.votes.map Vote.signer).Nodup ∧ (r.members.map Member.key).Nodup ∧
    0 < totalPower r ∧ 3*signedPower crypto cert r > 2*totalPower r := by
  simpa [certificateOK] using accepted

theorem nil_absent_zero (crypto : Crypto) (cert : Certificate) (members : List Member) (v : Vote)
    (kind : v.kind ≠ .block) : votePower crypto cert members v = 0 := by simp [votePower, kind]

theorem counted_signature (crypto : Crypto) (cert : Certificate) (members : List Member) (v : Vote)
    (counted : 0 < votePower crypto cert members v) :
    v.kind = .block ∧ crypto.valid cert.chain cert.height cert.blockHash v.signer v.signature = true := by
  unfold votePower at counted
  split_ifs at counted with valid
  · exact valid
  · omega

theorem equal_two_thirds_rejected (crypto : Crypto) (chain h hash : Nat) (r : Record) (cert : Certificate)
    (equal : 3*signedPower crypto cert r = 2*totalPower r) :
    certificateOK crypto chain h hash r cert = false := by
  simp [certificateOK, equal]

/-- COM-05: arbitrary contiguous cuts, including all D/S/S+1/H cuts; errors also compose. -/
theorem batch_cut_equivalent (ctx : Context) (xs ys : List (AuthenticatedBlockFacts ctx)) (st : CommitteeState) :
    replay ctx (xs++ys) st = (do
      let (middle,u) ← replay ctx xs st
      let (last,v) ← replay ctx ys middle
      pure (last,u++v)) := by
  induction xs generalizing st with
  | nil => cases hy : replay ctx ys st <;> simp [replay, hy, Bind.bind, Except.bind, Pure.pure, Except.pure]
  | cons b bs ih =>
    simp only [List.cons_append, replay]
    cases hs : step ctx st b with
    | error e => simp [Bind.bind, Except.bind]
    | ok pair =>
      rcases pair with ⟨next,u⟩
      simp only [ih]
      cases hr : replay ctx bs next with
      | error e => simp [hr, Bind.bind, Except.bind]
      | ok pair =>
        rcases pair with ⟨middle,v⟩
        cases hy : replay ctx ys middle <;> simp [hr, hy, Bind.bind, Except.bind, Pure.pure, Except.pure, List.append_assoc]

/-- COM-06 compares successful results of the same authenticated history and durable checkpoint.
It makes no termination/availability assertion about external fetches or cold Finalize. -/
theorem replay_deterministic (ctx : Context) (xs ys : List (AuthenticatedBlockFacts ctx))
    (st middle onlineFinal crashFinal : CommitteeState) (u v all : Updates)
    (checkpoint : replay ctx xs st = .ok (middle,u))
    (reopened : replay ctx ys middle = .ok (crashFinal,v))
    (online : replay ctx (xs++ys) st = .ok (onlineFinal,all)) :
    onlineFinal = crashFinal ∧ all = u++v := by
  rw [batch_cut_equivalent] at online
  simpa [checkpoint, reopened, Bind.bind, Except.bind, Pure.pure, Except.pure] using online.symm

/-- COM-07 is conditional on an accepted switch and its authenticated landed checkpoint. -/
theorem backpressure_switch_bound (s : Schedule) (t cap checkpoint : Nat)
    (positive : 0 < t) (length : cap+3 ≤ s.length)
    (accepted : S s t-checkpoint ≤ cap) : checkpoint > H s (t-1) := by
  have gap : H s t = H s (t-1)+s.length := by
    have ht : t-1+1=t := by omega
    unfold H
    nlinarith
  unfold S at accepted
  omega

def unsettledCap (dMax margin : Nat) : Option Nat := sub dMax margin

theorem invalid_difference_rejected (dMax margin : Nat) (h : dMax < margin) :
    unsettledCap dMax margin = none := by simp [unsettledCap, sub, Nat.not_le.mpr h]

theorem cap_overflow_rejected (s : Schedule) (cap : Nat) (length : 3 ≤ s.length)
    (overflow : max64 < cap+3) : validate s cap = .error .shorterThanCap := by
  simp [validate, add, checked, Nat.not_lt.mpr length, Nat.not_le.mpr overflow]


/-- Authentication soundness applies to each positively counted signature's exact context. -/
theorem counted_signature_genuine (crypto : Crypto) (cert : Certificate) (members : List Member) (v : Vote)
    (counted : 0 < votePower crypto cert members v) :
    crypto.genuine cert.chain cert.height cert.blockHash v.signer v.signature :=
  crypto.sound _ _ _ _ _ (counted_signature crypto cert members v counted).2

/-- A successful contiguous switch consumes precisely the committed D(t) parent state. -/
theorem derivation_parent_is_D (s : Schedule) (t parent : Nat) (length : 3 ≤ s.length)
    (positive : 0 < t) (bounded : H s t ≤ max64)
    (switch : switchTarget s (parent+1) = some t) : parent = D s t := by
  obtain ⟨hd, _, exactHeight⟩ := schedule_exact s t length positive bounded
  have := (exactHeight (parent+1)).mp switch
  omega

/-- The accepted-step inequality is derived from the actual guard, not stored in facts. -/
theorem step_backpressure (ctx : Context) (st next : CommitteeState)
    (b : AuthenticatedBlockFacts ctx) (updates : Updates)
    (accepted : step ctx st b = .ok (next,updates)) :
    b.facts.height-b.facts.anchor.checkpoint ≤ ctx.cap := by
  by_contra hover
  have hp : b.facts.height-b.facts.anchor.checkpoint > ctx.cap := by omega
  unfold step at accepted
  simp only [Bind.bind, Except.bind, Pure.pure, Except.pure, MonadExcept.throw, throwThe, MonadExceptOf.throw, hp] at accepted
  repeat' (split at accepted <;> try simp_all)

/-- Record conflicts are rejected before any switch lookup or insertion plan. -/
theorem conflict_rejected (s : Schedule) (h t : Nat) (outgoing incoming : Bool) :
    plan s h (.conflict t) outgoing incoming = .error (.conflict t) := rfl

/-- At a non-switch height no scalar update can be emitted, even if an adapter supplies a record. -/
theorem no_nonswitch_updates (s : Schedule) (h : Nat) (r : Relation) (outgoing incoming : Bool)
    (p : Plan) (hs : switchTarget s h = none) (accepted : plan s h r outgoing incoming = .ok p) :
    p.switch = none := by
  cases r <;> simp [plan, hs] at accepted <;> cases accepted <;> rfl



/-- Both checked intermediate stages imply the exact H/D values on the valid domain. -/
theorem checked_schedule_domain (s : Schedule) (t : Nat) (length : 3 ≤ s.length)
    (positive : 0 < t) (bounded : H s t ≤ max64) :
    first s t = some (H s t) ∧ parentHeight s t = some (D s t) := by
  have mulBound : t*s.length ≤ max64 := by unfold H at bounded; omega
  have firstEq : first s t = some (H s t) := by
    unfold first mul add checked
    simp only [mulBound, ↓reduceIte, Option.bind_some]
    have hb : t*s.length+1 ≤ max64 := by unfold H at bounded; omega
    simp [hb, H, Nat.add_comm]
  refine ⟨firstEq, ?_⟩
  have nz : t ≠ 0 := by omega
  have hb : 3 ≤ H s t := by unfold H; nlinarith
  simp [parentHeight, nz, firstEq, sub, hb, D]

/-- The one-block-before/exact-H pair exposes the Comet h+2 adapter obligation explicitly. -/
theorem activation_boundary (s : Schedule) (st : CommitteeState) (t : Nat)
    (length : 0 < s.length) (positive : 0 < t) :
    authority s st (H s t-1) = lookup st.records (t-1) ∧
    authority s st (H s t) = lookup st.records t := by
  have gap : H s t = H s (t-1)+s.length := by
    have ht : t-1+1=t := by omega
    unfold H; nlinarith
  have ht : t-1+1=t := by omega
  constructor
  · apply activation_exact s st (t-1) _ length
    · omega
    · rw [ht]; unfold H; omega
  · apply activation_exact s st t _ length (by omega)
    unfold H; nlinarith

/-- A missing activation record fails before certificate verification; old authority is not reused. -/
theorem step_missing_authority (ctx : Context) (st : CommitteeState) (b : AuthenticatedBlockFacts ctx)
    (height : b.facts.height = st.height+1) (chain : b.facts.chain = ctx.chain)
    (parent : b.facts.parentHash = st.blockHash)
    (missing : authority ctx.schedule st b.facts.height = none) :
    step ctx st b = .error (.unknown ((epochOf ctx.schedule b.facts.height).getD 0)) := by
  have missing' : authority ctx.schedule st (st.height+1) = none := by simpa only [height] using missing
  simp [step, height, chain, parent, missing', require, Bind.bind, Except.bind]


/-- External Comet behavior is an explicit semantic law; S+2=H is proved from the schedule. -/
theorem comet_activation_exact (adapter : CometAdapter) (s : Schedule) (t h : Nat)
    (outgoing incoming : Record) (length : 3 ≤ s.length) (positive : 0 < t)
    (bounded : H s t ≤ max64) :
    adapter.observed (S s t) outgoing incoming h =
      if h < H s t then outgoing else incoming := by
  rw [adapter.appliesAfterTwo]
  unfold cometView
  rw [(schedule_exact s t length positive bounded).2.1]
end Etna.Committee
