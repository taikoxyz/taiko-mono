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
  ⟨2, stakeFloor, stakeFloor, 3, 1000, 302402, 100, 21, 20, 1000⟩

private def adapters : L2Staking.Adapters :=
  ⟨fun _ _ _ ↦ true, fun _ _ ↦ none, fun _ ↦ true⟩

private def register : Option L2Staking.State := do
  let r ← L2Staking.execute (L2Staking.State.empty stakeConfig) adapters ⟨100, 200, 1, false⟩
    (.register ⟨3, 2, candidateKey % limit256⟩ stakeFloor 0)
  return r.state

private def finalizeFirst (systemSucceeds : Bool) (bitmap : Nat) : Option CommitState := do
  let inbox ← start initialInbox 100 20 200
  let inbox ← switchKey inbox
  let origin ← inbox.originAt 0
  let validators ← genesisValidators rules identity origin [initialKey]
  let staking ← register
  let result ← blockStart rules staking origin validators
    ⟨0, inbox.settings.anchor, inbox.settings.keys, [], bitmap, systemSucceeds⟩
  advanceValidators identity validators result.target

private def setKeys (validators : CommitState) : List Nat × List Nat :=
  (validators.current.members.map (·.key), validators.next.members.map (·.key))

-- At H=101 the first committee update leaves 102 on the fixed origin keys.
-- The newly written candidate, or the anchor's fallback on failure, signs 103.
example : (finalizeFirst true 0).map setKeys = some ([1], [3]) := by decide +kernel
example : (finalizeFirst false 0).map setKeys = some ([1], [2]) := by decide +kernel
example : (finalizeFirst true 1).isNone = true := by decide +kernel

example :
    (validUnsettled 0, validUnsettled 262144, validUnsettled 262145,
      withinUnsettled targetUnsettled 100 151300, withinUnsettled targetUnsettled 100 151301,
      { stakeConfig with withdrawalDelay := 302401 }.valid 151200 151200,
      stakeConfig.valid 151200 151200) =
    (false, true, false, true, false, false, true) := by decide

end Etna.Design.L2StakingProtocol.Tests
