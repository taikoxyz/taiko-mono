import EtnaModel.CurrentBridge
import EtnaProofs.CurrentCheckpointRisk
import EtnaProofs.CurrentUnzen

/-! The bridge's read path (EtnaModel.CurrentBridge): derived authorizations stay backed by a
checkpoint the L1 `SignalService` holds, and the L2 `SignalService` closes its checkpoint store
and reads EIP-4788 from `beaconRootsFrom` on. -/
namespace Etna.Design.Current.Bridge
open Protocol

/-- Every call keeps the Unzen checkpoints the L1 `SignalService` holds; only `unzenProve` adds
one. -/
private theorem execute_legacy_kept {env : Environment} {w t : World} {call : Protocol.Call}
    (ok : Protocol.execute env w call = some t) : ∀ s ∈ w.legacySignals, s ∈ t.legacySignals := by
  by_cases legacy : ∃ p h b, call = .unzenProve p h b
  · obtain ⟨p,h,b,rfl⟩ := legacy
    change Protocol.unzenProve env w p h b = some t at ok
    unfold Protocol.unzenProve at ok
    split at ok
    next =>
      cases Option.some.inj ok
      intro s member
      exact List.mem_append_left _ member
    next => cases ok
  · rw [(Custody.execute_unzen_frame (fun p h b eq => legacy ⟨p,h,b,eq⟩) ok).2.2]
    exact fun _ member => member

private theorem backed_keep {verify : Hash → Hash → Hash → Bool} {w t : World} {b : State}
    (held : Backed verify w b) (legacy : ∀ s ∈ w.legacySignals, s ∈ t.legacySignals)
    (signals : ∀ s ∈ w.inbox.signals, s ∈ t.inbox.signals) : Backed verify t b := by
  intro a member
  obtain ⟨⟨s,retained,height,root⟩,proof⟩ := held a member
  refine ⟨⟨s,?_,height,root⟩,proof⟩
  rcases List.mem_append.mp retained with old | etna
  · exact List.mem_append_left _ (legacy s old)
  · exact List.mem_append_right _ (signals s etna)

private theorem prove_backed {verify : Hash → Hash → Hash → Bool} {w : World} {slot : Hash}
    {height : Nat} {proof : Hash} {a : Authorization} (ok : prove verify w slot height proof = some a) :
    (∃ s ∈ w.legacySignals ++ w.inbox.signals, s.height = a.height ∧ s.stateRoot = a.root) ∧
      ∃ proof, verify a.root a.slot proof = true := by
  unfold prove checkpointRoot at ok
  cases hit : (w.legacySignals ++ w.inbox.signals).find? (·.height == height) with
  | none => simp [hit] at ok
  | some s =>
    simp only [hit,Option.map_some,Option.bind_some] at ok
    split at ok
    next valid =>
      cases ok
      exact ⟨⟨s,List.mem_of_find?_eq_some hit,by simpa using List.find?_some hit,rfl⟩,proof,valid⟩
    next => cases ok

private theorem settle_backed {verify : Hash → Hash → Hash → Bool} {w : World} {b c : State}
    {a : Authorization} {delivered : Bool} (held : Backed verify w b)
    (backed : (∃ s ∈ w.legacySignals ++ w.inbox.signals, s.height = a.height ∧ s.stateRoot = a.root) ∧
      ∃ proof, verify a.root a.slot proof = true)
    (ok : settle b a delivered = some c) : Backed verify w c := by
  unfold settle at ok
  split at ok
  next => cases ok
  next =>
    split at ok
    next =>
      cases ok
      exact held
    next =>
      cases ok
      intro x member
      simp only [List.mem_append,List.mem_cons] at member
      rcases member with old | rfl | old
      · exact held x (List.mem_append_left _ old)
      · exact backed
      · exact held x (List.mem_append_right _ old)

private theorem execute_backed {verify : Hash → Hash → Hash → Bool} {w : World} {b c : State}
    {call : Call} (held : Backed verify w b) (ok : execute verify w b call = some c) : Backed verify w c := by
  cases call with
  | receive slot height proof =>
    obtain ⟨a,proved,rfl⟩ := Option.map_eq_some_iff.mp ok
    intro x member
    simp only [List.mem_append,List.mem_cons] at member
    rcases member with (rfl | old) | old
    · exact prove_backed proved
    · exact held x (List.mem_append_left _ old)
    · exact held x (List.mem_append_right _ old)
  | process slot height proof delivered =>
    obtain ⟨a,proved,settled⟩ := Option.bind_eq_some_iff.mp ok
    exact settle_backed held (prove_backed proved) settled
  | processCached slot delivered =>
    obtain ⟨a,found,settled⟩ := Option.bind_eq_some_iff.mp ok
    exact settle_backed held (held a (List.mem_append_left _ (List.mem_of_find?_eq_some found))) settled
  | retry slot delivered =>
    obtain ⟨a,found,rfl⟩ := Option.map_eq_some_iff.mp ok
    split
    · intro x member
      simp only [List.mem_append] at member
      rcases member with old | erased
      · exact held x (List.mem_append_left _ old)
      · exact held x (List.mem_append_right _ (List.mem_of_mem_erase erased))
    · exact held

/-- One step keeps the read path backed. A rollback that voids checkpoints revokes every derived
authorization in the same upgrade; every other call keeps each checkpoint
(`CheckpointRisk.execute_retains`), and a bridge call only adds what it proves. -/
private theorem run_backed_trace {env : Environment} {registry : RegistryMachine.State}
    {verify : Hash → Hash → Hash → Bool} {first last : World × State}
    (genesis : RegistryMachine.Genesis registry) (primitive : Custody.Primitives env)
    (sound : VerifierSound env (empty env registry)) (run : Run env verify first last)
    (start : first = (empty env registry,{})) :
    Backed verify last.1 last.2 ∧ Trace env (empty env registry) last.1 := by
  induction run with
  | refl =>
    subst start
    refine ⟨fun a member => ?_,.refl _⟩
    simp at member
  | step prior change ih =>
    obtain ⟨held,reach⟩ := ih
    cases change with
    | call w b call =>
      have reach : Trace env (empty env registry) w := reach
      have held : Backed verify w b := held
      refine ⟨?_,.step reach (.call _ call)⟩
      show Backed verify (transact env w call) (if rolledBack env w call then revoke b else b)
      split
      · intro a member
        simp [revoke] at member
      · rename_i revoked
        cases ok : Protocol.execute env w call with
        | none => simpa only [transact,ok,Option.getD_none] using held
        | some t =>
          simp only [transact,ok,Option.getD_some]
          have ordinary : CheckpointRisk.OrdinaryCall call := by
            cases call with
            | rollback caller trusted snapshot =>
              exact revoked (by simp only [rolledBack]; exact Option.isSome_iff_exists.mpr ⟨t,ok⟩)
            | _ => trivial
          have kept := CheckpointRisk.execute_retains (Journal.trace_frontier_shape reach)
            (Custody.trace_coherent genesis primitive sound reach) ordinary ok
          exact backed_keep held (execute_legacy_kept ok) kept.1
    | node b after validated => exact ⟨held,.step reach (.node after validated)⟩
    | bridge w call ok => exact ⟨execute_backed held ok,reach⟩

/-- RECOV-8-27 and RECOV-8-27a on the read path: along every run of the protocol machine with the
L1 `SignalService` and Bridge alongside, every signal a call may use without checking a
checkpoint, cached as received or held by a `RETRIABLE` message, was proven under the Merkle
adapter against the state root of a checkpoint the L1 `SignalService` still holds. -/
theorem run_backed {env : Environment} {registry : RegistryMachine.State}
    {verify : Hash → Hash → Hash → Bool} {w : World} {b : State}
    (genesis : RegistryMachine.Genesis registry) (primitive : Custody.Primitives env)
    (sound : VerifierSound env (empty env registry))
    (run : Run env verify (empty env registry,{}) (w,b)) : Backed verify w b :=
  (run_backed_trace genesis primitive sound run rfl).1

/-- RECOV-8-27a, vectors 27a.a and 27a.c: after the revocation, an empty proof for any signal and
a retry of any message are refused until the signal is proven again. -/
theorem revoked_needs_proof (verify : Hash → Hash → Hash → Bool) (w : World) (b : State) (slot : Hash)
    (delivered : Bool) :
    execute verify w (revoke b) (.processCached slot delivered) = none ∧
      execute verify w (revoke b) (.retry slot delivered) = none := by
  simp [execute,revoke]

/-! ### The L2 `SignalService` -/

private theorem run_saved {c : L2Config} {first last : Nat × List Saved} (run : L2Run c first last) :
    first.1 ≤ last.1 ∧ (∀ s ∈ last.2, s ∈ first.2 ∨
      (s.caller = c.syncer ∧ checkpointsOpen c s.savedAt = true ∧ s.root ≠ 0 ∧ first.1 ≤ s.savedAt)) := by
  induction run with
  | refl => exact ⟨Nat.le_refl _,fun s member => .inl member⟩
  | call prior later caller blockId root ok ih =>
    obtain ⟨early,kept⟩ := ih
    unfold save at ok
    split at ok
    next guard =>
      cases ok
      refine ⟨Nat.le_trans early later,fun s member => ?_⟩
      rcases List.mem_cons.mp member with rfl | old
      · exact .inr ⟨guard.1,guard.2.1,guard.2.2,Nat.le_trans early later⟩
      · exact kept s old
    next => cases ok
  | skip prior later ih => exact ⟨Nat.le_trans ih.1 later,ih.2⟩

/-- ANCHORLESS section 8, checkpoint cutoff: every checkpoint an L2 `SignalService` run saves from
an empty store was saved by the authorized syncer while the store was open, so on L2 before
`beaconRootsFrom`, and has a nonzero root. A public anchor key used after the fork forges none. -/
theorem saved_before_fork {c : L2Config} {start now : Nat} {store : List Saved}
    (run : L2Run c (start,[]) (now,store)) :
    ∀ s ∈ store, s.caller = c.syncer ∧ checkpointsOpen c s.savedAt = true ∧ s.root ≠ 0 := by
  intro s member
  rcases (run_saved run).2 s member with absent | ⟨caller,open_,root,_⟩
  · cases absent
  · exact ⟨caller,open_,root⟩

/-- ANCHORLESS sections 4 and 8: from `beaconRootsFrom` on, the L2 `SignalService`'s checkpoint
store gains nothing. -/
theorem store_closed {c : L2Config} {now later : Nat} {store final : List Saved}
    (fork : c.beaconRootsFrom ≠ 0) (after : c.beaconRootsFrom ≤ now)
    (run : L2Run c (now,store) (later,final)) : ∀ s ∈ final, s ∈ store := by
  intro s member
  rcases (run_saved run).2 s member with old | ⟨_,open_,_,since⟩
  · exact old
  · simp only [checkpointsOpen,Bool.or_eq_true,beq_iff_eq,decide_eq_true_eq] at open_
    omega

/-- ANCHORLESS section 4, root resolution after the fork: an L2 block at or after
`beaconRootsFrom` resolves a proof's root only from the EIP-4788 entry for a `blockId` at or
after the fork, never from the checkpoint store, and never as zero. -/
theorem root_after_fork (c : L2Config) (beacon : Nat → Option Hash) (store : List Saved)
    {timestamp blockId : Nat} {r : Hash} (fork : c.beaconRootsFrom ≠ 0) (after : c.beaconRootsFrom ≤ timestamp)
    (resolved : stateRoot c beacon store timestamp blockId = some r) :
    c.beaconRootsFrom ≤ blockId ∧ beacon blockId = some r ∧ r ≠ 0 ∧
      ∀ other : List Saved, stateRoot c beacon other timestamp blockId = some r := by
  have closed : checkpointsOpen c timestamp = false := by
    simp only [checkpointsOpen,Bool.or_eq_false_iff,beq_eq_false_iff_ne,ne_eq,decide_eq_false_iff_not]
    omega
  unfold stateRoot at resolved ⊢
  simp only [closed,Bool.false_eq_true,↓reduceIte] at resolved ⊢
  split at resolved
  next early =>
    obtain ⟨root,found,ok⟩ := Option.bind_eq_some_iff.mp resolved
    split at ok
    next => cases ok
    next nonzero =>
      cases ok
      refine ⟨early,found,nonzero,fun _ => ?_⟩
      simp only [early,↓reduceIte,found,Option.bind_some,nonzero]
  next => cases resolved

end Etna.Design.Current.Bridge
