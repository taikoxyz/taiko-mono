import EtnaModel.PerBlockCommittee
import EtnaModel.L2Staking
import EtnaModel.CurrentValidatorState

/-! Decoded generation authority, backlog bound and validator state for Etna with
L2 staking. Canonical L1 state and ordinary Inbox/EL execution are inputs. -/
namespace Etna.Design.L2StakingProtocol

open PerBlockCommittee (Anchor GenerationOrigin Rules)
open Etna.Design.Current

def maxUnsettled : Nat := 262144
def targetUnsettled : Nat := 151200

def validUnsettled (unsettled : Nat) : Bool :=
  decide (1 ≤ unsettled ∧ unsettled ≤ maxUnsettled)

def withinUnsettled (unsettled checkpoint height : Nat) : Bool :=
  validUnsettled unsettled && decide (height ≤ checkpoint + unsettled)

/-- Authorized decoded fallback settings. The key list supplies an opening of the anchor hash. -/
structure FallbackSettings where
  keys : List Hash
  keysHash : Hash
  minTotalStake : Nat
  deriving DecidableEq, Repr

def FallbackSettings.anchor (settings : FallbackSettings) : Anchor :=
  { minTotalStake := settings.minTotalStake, fallbackKeysHash := settings.keysHash }

def setFallbackKeys (rules : Rules) (owner caller : Nat) (settings : FallbackSettings)
    (keys : List Hash) : Option FallbackSettings :=
  let keysHash := rules.hashFallbackKeys keys
  if caller = owner ∧ keysHash < limit256 ∧ PerBlockCommittee.validFallbackKeys rules keys then
    some { settings with keys, keysHash }
  else none

def setMinTotalStake (owner caller : Nat) (settings : FallbackSettings) (value : Nat) :
    Option FallbackSettings :=
  if caller = owner ∧ value < limit256 then some { settings with minTotalStake := value }
  else none

/-- The authority slice of the Inbox. Landing supplies the checkpoint used by a recovery. -/
structure Inbox where
  owner : Nat
  settings : FallbackSettings
  generation : Option Nat := none
  recoveryNonce : Nat := 0
  origins : List (Nat × GenerationOrigin) := []
  deriving DecidableEq, Repr

def Inbox.originAt (inbox : Inbox) (generation : Nat) : Option GenerationOrigin :=
  (inbox.origins.find? (fun entry => entry.1 == generation)).map Prod.snd

def recordOrigin (inbox : Inbox) (generation height l1Block timestamp : Nat) : Option Inbox :=
  if (inbox.originAt generation).isNone then
    let origin : GenerationOrigin :=
      { height, l1Block, timestamp, fallbackKeysHash := inbox.settings.keysHash }
    some { inbox with generation := some generation, origins := (generation, origin) :: inbox.origins }
  else none

/-- Called after the decoded start write's authorization and start-data checks. -/
def start (inbox : Inbox) (height l1Block timestamp : Nat) : Option Inbox :=
  if inbox.generation.isNone then recordOrigin inbox 0 height l1Block timestamp else none

structure RecoveryAuthorization where
  generation : Nat
  checkpoint : Nat
  nonce : Nat
  validUntil : Nat
  deriving DecidableEq, Repr

/-- The origin and nonce transition for a plain recovery. Branches that edit the FI queue or
replace a verifier are outside this projection. -/
def recover (inbox : Inbox) (caller checkpoint l1Block timestamp : Nat)
    (authorization : RecoveryAuthorization) : Option Inbox := do
  let generation ← inbox.generation
  if caller = inbox.owner ∧ authorization.generation = generation ∧
      authorization.checkpoint = checkpoint ∧ authorization.nonce = inbox.recoveryNonce ∧
      timestamp ≤ authorization.validUntil ∧ generation + 1 < limit48 ∧
      inbox.recoveryNonce + 1 < limit256 then
    let next ← recordOrigin inbox (generation + 1) checkpoint l1Block timestamp
    return { next with recoveryNonce := inbox.recoveryNonce + 1 }
  else none

def recoverWithFallback (inbox : Inbox) (caller checkpoint l1Block timestamp : Nat)
    (authorization : RecoveryAuthorization) : Option Inbox := do
  let settings ← setMinTotalStake inbox.owner caller inbox.settings (limit256 - 1)
  recover { inbox with settings } caller checkpoint l1Block timestamp authorization

/-- The block number of the L1 anchor after witness authentication. The first block witnesses
its own anchor; later blocks may keep the one authenticated for their parent. -/
def anchorFitsOrigin (origin : GenerationOrigin) (height anchorNumber : Nat)
    (carriesWitness : Bool) : Bool :=
  decide (origin.height < height ∧ origin.l1Block ≤ anchorNumber) &&
    (height != origin.height + 1 || carriesWitness)

/-- Storage words written by the decoded staking implementation. The committee decoder also
accepts arbitrary authenticated words when checking externally supplied state. -/
def snapshotWords (snapshot : L2Staking.Snapshot) : PerBlockCommittee.Snapshot where
  heightWord := snapshot.height
  totalStake := snapshot.totalStake
  seats := snapshot.seats.map fun slot ↦
    match slot with
    | none => default
    | some member => PerBlockCommittee.packSnapshotSeat member.ckPrefix member.ckX member.power

def liveSeatWord (staking : L2Staking.State) (address : Nat) : Nat :=
  (L2Staking.seatForKey staking address).elim 0 (fun seat ↦ 1 + 256 * seat)

/-- The stock arithmetic operates on decoded key identities and validator addresses.
The adapter supplies a lossless 256-bit label for a compressed public key in this run. -/
structure ValidatorIdentity where
  keyId : Hash → Hash
  address : Hash → Nat

def genesisValidators (rules : Rules) (identity : ValidatorIdentity)
    (origin : GenerationOrigin) (originKeys : List Hash) : Option ValidatorState.CommitState := do
  let members ← PerBlockCommittee.fallback rules origin.fallbackKeysHash originKeys
  ValidatorState.genesis origin.height
    (members.map fun m ↦ ⟨identity.keyId m.key, identity.address m.key, m.power, 0⟩)

structure BlockStartInput where
  generation : Nat
  anchor : Anchor
  fallbackKeys : List Hash
  parentCommitFlags : List Nat
  extraDataMissBitmap : Nat
  stakingCallSucceeded : Bool

structure BlockStartResult where
  staking : L2Staking.State
  target : List PerBlockCommittee.Member

/-- The stake state supplied here is the parent's post-state. The snapshot read by the
selection is the one left by this block's system call and frozen for normal transactions. -/
def blockStart (rules : Rules) (staking : L2Staking.State) (origin : GenerationOrigin)
    (validators : ValidatorState.CommitState) (input : BlockStartInput) : Option BlockStartResult := do
  let height := validators.height + 1
  let bitmap ← PerBlockCommittee.missBitmap (height == origin.height + 1)
    (validators.last.members.map ValidatorState.Validator.address) input.parentCommitFlags
    (liveSeatWord staking)
  if bitmap != input.extraDataMissBitmap then none else do
    let next := L2Staking.onBlockStart staking height L2Staking.systemCaller input.generation
      bitmap input.stakingCallSucceeded
    let target ← PerBlockCommittee.decision rules height (snapshotWords next.snapshot)
      input.anchor input.fallbackKeys
    return ⟨next, target⟩

/-- Apply H's changes to the validator set for H+1. Stock CometBFT places the result
in NextValidators for H+2 and retains the old NextValidators for H+1. -/
def advanceValidators (identity : ValidatorIdentity) (validators : ValidatorState.CommitState)
    (target : List PerBlockCommittee.Member) : Option ValidatorState.CommitState :=
  let next := target.map fun m ↦
    ({ key := identity.keyId m.key, address := identity.address m.key, power := m.power,
       priority := 0 } : ValidatorState.Validator)
  ValidatorState.commit validators (ValidatorState.changesFor validators.next.members next)

def votingPower (members : List PerBlockCommittee.Member) (keys : List Hash) : Nat :=
  ((members.filter (fun member ↦ keys.contains member.key)).map PerBlockCommittee.Member.power).sum

def totalPower (members : List PerBlockCommittee.Member) : Nat :=
  (members.map PerBlockCommittee.Member.power).sum

end Etna.Design.L2StakingProtocol
