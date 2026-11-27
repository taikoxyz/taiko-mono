import EtnaProofs.L2StakingProtocol

namespace Etna.Design.L2StakingProtocol.Tests

open PerBlockCommittee (compressedKey forceFallback)
open Current.ValidatorState (CommitState)

private def initialKey : Hash := compressedKey 2 1
private def laterKey : Hash := compressedKey 2 2
private def candidateKey : Hash := compressedKey 2 3

private def rules : PerBlockCommittee.Rules where
  validPoint := fun _ ↦ true
  hashFallbackKeys := fun keys ↦ (keys.map (· % limit256)).sum

private def identity : ValidatorIdentity where
  keyId := (· % limit256)
  address := (· % limit256)

private def initialInbox : Inbox :=
  { owner := 20, settings := ⟨[initialKey], 1, 1⟩ }

private def switchKey (inbox : Inbox) : Option Inbox := do
  let settings ← setFallbackKeys rules inbox.owner inbox.owner inbox.settings [laterKey]
  return { inbox with settings }

private def restarted : Option Inbox := do
  let started ← start initialInbox 100 20 200
  let changed ← switchKey started
  recoverWithFallback changed 20 111 27 270 ⟨0, 111, 0, 280⟩

-- Recovery latches the fallback hash in the new origin and keeps the old origin.
example : (do
    let inbox ← restarted
    let startOrigin ← inbox.originAt 0
    let recoveryOrigin ← inbox.originAt 1
    return (startOrigin.fallbackKeysHash, recoveryOrigin.fallbackKeysHash,
      recoveryOrigin.height, recoveryOrigin.l1Block, inbox.settings.minTotalStake,
      inbox.recoveryNonce)) = some (1, 2, 111, 27, forceFallback, 1) := by decide

example : (do
    let inbox ← restarted
    recoverWithFallback inbox 20 111 28 271 ⟨0, 111, 0, 280⟩) = none := by decide

example : (do
    let inbox ← restarted
    let origin ← inbox.originAt 1
    return (anchorFitsOrigin origin 112 26 true, anchorFitsOrigin origin 112 27 false,
      anchorFitsOrigin origin 112 27 true, anchorFitsOrigin origin 113 27 false)) =
    some (false, false, true, true) := by decide

private def stakeFloor : Nat := 10^27 / 2

private def stakeConfig : L2Staking.Config :=
  ⟨2, stakeFloor, stakeFloor, 3, 9, 1000, 302402, 100, 21, 20, 1000⟩

private def adapters : L2Staking.Adapters :=
  ⟨fun _ _ _ ↦ true, fun _ _ ↦ none, fun _ ↦ true⟩

private def register : Option L2Staking.State := do
  let r ← L2Staking.execute (L2Staking.State.empty stakeConfig) adapters ⟨100, 200, 1, false⟩
    (.register ⟨3, 2, candidateKey % limit256⟩ stakeFloor 0)
  return r.state

private def finalizeFirst (stakingCall : StakingCallOutcome) (bitmap : Nat) : Option CommitState := do
  let inbox ← start initialInbox 100 20 200
  let inbox ← switchKey inbox
  let origin ← inbox.originAt 0
  let validators ← genesisValidators rules identity origin [initialKey]
  let staking ← register
  let result ← blockStart rules staking origin validators
    ⟨0, inbox.settings.anchor, inbox.settings.keys, [], bitmap, stakingCall⟩
  advanceValidators identity validators result.target

private def setKeys (validators : CommitState) : List Nat × List Nat :=
  (validators.current.members.map (·.key), validators.next.members.map (·.key))

-- At H=101 the first committee update leaves 102 on the fixed origin keys.
-- The newly written candidate, or the anchor's fallback on failure, signs 103.
example : (finalizeFirst .applied 0).map setKeys = some ([1], [3]) := by decide +kernel
example : (finalizeFirst .reverted 0).map setKeys = some ([1], [2]) := by decide +kernel
example : (finalizeFirst .noCode 0).map setKeys = some ([1], [2]) := by decide +kernel
example : (finalizeFirst .executionFault 0).isNone = true := by decide +kernel
example : (finalizeFirst .applied 1).isNone = true := by decide +kernel

private def fallbackKeys : List Hash := [initialKey, laterKey, candidateKey, compressedKey 2 4]

private def checkpointWithMiss : Option L2Staking.State := do
  let registered ← register
  return L2Staking.onBlockStart registered 100 L2Staking.systemCaller 0 1 true

private def seatZeroMisses (state : L2Staking.State) : Option Nat :=
  (L2Staking.liveSeat state 0).map L2Staking.LiveSeat.misses

private def recoveryMissCounts (firstCall : StakingCallOutcome) (miss : Bool) :
    Option (Option Nat × Option Nat × Bool) := do
  let keys := fallbackKeys
  let origin : PerBlockCommittee.GenerationOrigin := ⟨100, 20, 200, rules.hashFallbackKeys keys⟩
  let settings : FallbackSettings := ⟨keys, rules.hashFallbackKeys keys, stakeFloor⟩
  let validators ← genesisValidators rules identity origin keys
  let checkpoint ← checkpointWithMiss
  let first ← blockStart rules checkpoint origin validators
    ⟨1, settings.anchor, keys, [], 0, firstCall⟩
  let validators ← advanceValidators identity validators first.target
  let flags := validators.last.members.map fun member ↦
    if miss && member.key == 3 then 1 else PerBlockCommittee.commitFlag
  let second ← blockStart rules first.staking origin validators
    ⟨1, settings.anchor, keys, flags, if miss then 1 else 0, .applied⟩
  return (seatZeroMisses first.staking, seatZeroMisses second.staking,
    decide (first.staking = checkpoint))

-- A reverted or no-code first call preserves the entire modeled staking state.
-- The next applied call uses the fallback key's LastCommit flag.
example : recoveryMissCounts .applied true = some (some 0, some 1, false) ∧
    recoveryMissCounts .reverted false = some (some 1, some 0, true) ∧
    recoveryMissCounts .reverted true = some (some 1, some 2, true) ∧
    recoveryMissCounts .noCode true = some (some 1, some 2, true) := by decide +kernel

private def reseatBeforeRetry : Option (Option Nat × Option Nat × Option Nat) := do
  let checkpoint ← checkpointWithMiss
  let reverted := L2Staking.onBlockStart checkpoint 101 L2Staking.systemCaller 1 0 false
  let exited ← L2Staking.execute reverted adapters ⟨101, 201, 1, false⟩ (.requestExit 0)
  let reseated ← L2Staking.execute exited.state adapters ⟨101, 201, 4, false⟩
    (.register ⟨4, 2, 4⟩ stakeFloor 0)
  return (seatZeroMisses reverted, L2Staking.bondInSeat reseated.state 0,
    seatZeroMisses reseated.state)

-- A new occupant starts at zero even before the first applied call in the new generation.
example : reseatBeforeRetry = some (some 1, some 1, some 0) := by decide +kernel

private def finalizeSecond (miss : Bool) (fallbackKey : Hash := laterKey) :
    Option ((List Nat × List Nat) × Option Nat) := do
  let keys := fallbackKeys
  let origin : PerBlockCommittee.GenerationOrigin := ⟨100, 20, 200, rules.hashFallbackKeys keys⟩
  let settings : FallbackSettings :=
    ⟨[fallbackKey], rules.hashFallbackKeys [fallbackKey], stakeFloor⟩
  let validators ← genesisValidators rules identity origin keys
  let config := { stakeConfig with missLimit := 1, missReleaseLimit := 1 }
  let registered ← L2Staking.execute (L2Staking.State.empty config) adapters ⟨100, 200, 1, false⟩
    (.register ⟨3, 2, candidateKey % limit256⟩ (2 * stakeFloor) 0)
  let first ← blockStart rules registered.state origin validators
    ⟨0, settings.anchor, settings.keys, [], 0, .applied⟩
  let validators ← advanceValidators identity validators first.target
  let flags := validators.last.members.map fun member ↦
    if miss && member.key == 3 then 1 else PerBlockCommittee.commitFlag
  let second ← blockStart rules first.staking origin validators
    ⟨0, settings.anchor, settings.keys, flags, if miss then 1 else 0, .applied⟩
  let advanced ← advanceValidators identity validators second.target
  return (setKeys advanced, L2Staking.seatForKey second.staking 3)

-- At H=102 one of four parent signers misses. Its penalty leaves it above minStake, but
-- the release removes its whole stake from the snapshot. H+1 stays on the candidate.
example : finalizeSecond true = some (([3], [2]), none) := by decide +kernel
example : finalizeSecond false = some (([3], [3]), some 0) := by decide +kernel
-- A released bond's key can still sign H+2 as a fallback key.
example : finalizeSecond true candidateKey = some (([3], [3]), none) := by decide +kernel

private def penaltyUpdates (stake : Nat) (previousCallApplied : Bool := true) :
    Option (Nat × List PerBlockCommittee.Member) := do
  let config := { stakeConfig with missLimit := 1 }
  let registered ← L2Staking.execute (L2Staking.State.empty config) adapters
    ⟨99, 199, 1, false⟩ (.register ⟨3, 2, candidateKey % limit256⟩ stake 0)
  let stored := L2Staking.onBlockStart registered.state 100 L2Staking.systemCaller 0 0 true
  let before := L2Staking.onBlockStart stored 101 L2Staking.systemCaller 0 0 previousCallApplied
  let after := L2Staking.onBlockStart before 102 L2Staking.systemCaller 0 1 true
  let settings : FallbackSettings := ⟨[laterKey], 2, stakeFloor⟩
  let next ← PerBlockCommittee.decision rules 101 (snapshotWords before.snapshot)
    settings.anchor settings.keys
  let target ← PerBlockCommittee.decision rules 102 (snapshotWords after.snapshot)
    settings.anchor settings.keys
  return (after.snapshot.totalStake, PerBlockCommittee.validatorUpdates next target)

-- Hold the anchor settings fixed and keep the candidate usable on both heights.
-- A penalty changes the snapshot total even if both snapshots yield the same voting power.
example : penaltyUpdates (5 * stakeFloor / 4) = some (9 * stakeFloor / 8, []) ∧
    penaltyUpdates (2 * stakeFloor) = some (9 * stakeFloor / 5, [⟨candidateKey, 1⟩]) := by
  decide +kernel

-- After a reverted H-1 call, unchanged candidate power still allows a switch from fallback.
example : penaltyUpdates (5 * stakeFloor / 4) false =
    some (9 * stakeFloor / 8, [⟨candidateKey, 1⟩, ⟨laterKey, 0⟩]) := by decide +kernel

example :
    (validUnsettled 0, validUnsettled 262144, validUnsettled 262145,
      withinUnsettled targetUnsettled 100 151300, withinUnsettled targetUnsettled 100 151301,
      { stakeConfig with withdrawalDelay := 302401 }.valid 151200 151200,
      stakeConfig.valid 151200 151200) =
    (false, true, false, true, false, false, true) := by decide

end Etna.Design.L2StakingProtocol.Tests
