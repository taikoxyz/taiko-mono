import EtnaModel.L2StakingProtocol

namespace Etna.Design.L2StakingProtocol

theorem bound_caps_unsettled (unsettled checkpoint height : Nat)
    (accepted : withinUnsettled unsettled checkpoint height = true) :
    height - checkpoint ≤ unsettled := by
  simp only [withinUnsettled, Bool.and_eq_true, decide_eq_true_eq] at accepted
  omega

theorem target_unsettled_valid : validUnsettled targetUnsettled = true := by decide

theorem delay_covers_unsettled_and_evidence (config : L2Staking.Config)
    (unsettled evidenceWindow : Nat)
    (accepted : config.valid unsettled evidenceWindow = true) :
    unsettled + 2 + evidenceWindow ≤ config.withdrawalDelay := by
  simp only [L2Staking.Config.valid, decide_eq_true_eq] at accepted
  omega

theorem accepted_anchor_at_or_after_origin (origin : PerBlockCommittee.GenerationOrigin)
    (height anchorNumber : Nat) (carriesWitness : Bool)
    (accepted : anchorFitsOrigin origin height anchorNumber carriesWitness = true) :
    origin.l1Block ≤ anchorNumber := by
  simp only [anchorFitsOrigin, Bool.and_eq_true, decide_eq_true_eq] at accepted
  exact accepted.1.2

theorem threshold_requires_owner (owner caller : Nat) (settings next : FallbackSettings)
    (value : Nat) (accepted : setMinTotalStake owner caller settings value = some next) :
    caller = owner := by
  unfold setMinTotalStake at accepted
  split at accepted
  · rename_i checked
    exact checked.1
  · contradiction

theorem recorded_origin_uses_fallback_hash (inbox next : Inbox)
    (generation height l1Block timestamp : Nat)
    (accepted : recordOrigin inbox generation height l1Block timestamp = some next) :
    (next.originAt generation).map PerBlockCommittee.GenerationOrigin.fallbackKeysHash =
      some inbox.settings.keysHash := by
  unfold recordOrigin at accepted
  split at accepted
  · cases Option.some.inj accepted
    simp [Inbox.originAt]
  · contradiction

theorem recorded_origin_keeps_earlier (inbox next : Inbox)
    (generation old height l1Block timestamp : Nat) (distinct : old ≠ generation)
    (accepted : recordOrigin inbox generation height l1Block timestamp = some next) :
    next.originAt old = inbox.originAt old := by
  unfold recordOrigin at accepted
  split at accepted
  · cases accepted
    simp [Inbox.originAt, Ne.symm distinct]
  · contradiction

theorem advance_preserves_next_height (identity : ValidatorIdentity)
    (validators next : Current.ValidatorState.CommitState)
    (target : List PerBlockCommittee.Member)
    (advanced : advanceValidators identity validators target = some next) :
    next.height = validators.height + 1 ∧ next.current = validators.next := by
  unfold advanceValidators Current.ValidatorState.commit at advanced
  obtain ⟨_, _, advanced⟩ := Option.bind_eq_some_iff.mp advanced
  obtain ⟨_, _, advanced⟩ := Option.bind_eq_some_iff.mp advanced
  cases Option.some.inj advanced
  exact ⟨rfl, rfl⟩

private theorem overlap_bound (members : List PerBlockCommittee.Member) (a b : List Hash) :
    votingPower members a + votingPower members b ≤
      totalPower members + votingPower members (a.filter b.contains) := by
  induction members with
  | nil => simp [votingPower, totalPower]
  | cons member rest ih =>
    simp only [votingPower, totalPower, List.filter_cons, List.map_cons, List.sum_cons] at *
    have both : (List.filter b.contains a).contains member.key =
        (a.contains member.key && b.contains member.key) := by
      simp
    rw [both]
    cases a.contains member.key <;> cases b.contains member.key <;> simp_all <;> omega

/-- Quorum intersection over the selected set. Fallback key power contributes without
implying that the key has slashable collateral. -/
theorem strict_quorums_overlap (members : List PerBlockCommittee.Member) (a b : List Hash)
    (quorumA : 2 * totalPower members < 3 * votingPower members a)
    (quorumB : 2 * totalPower members < 3 * votingPower members b) :
    totalPower members < 3 * votingPower members (a.filter b.contains) := by
  have bound := overlap_bound members a b
  omega

end Etna.Design.L2StakingProtocol
