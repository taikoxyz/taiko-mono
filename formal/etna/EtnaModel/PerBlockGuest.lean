import EtnaModel.PerBlockCommittee

/-! Decoded landing-proof validator openings and commit checks. The fixed generation origin
and the slot 285 checkpoint are authenticated inputs. The adapters open header and state
commitments and verify canonical secp256k1eth vote signatures. -/
namespace Etna.Design.PerBlockGuest
open PerBlockCommittee

structure ProofCheckpoint where
  height : Nat
  elHash : Hash
  cometHash : Hash
  deriving DecidableEq, Repr

structure CometHeader where
  height : Nat
  validatorsHash : Hash
  nextValidatorsHash : Hash
  deriving DecidableEq, Repr

structure BoundaryRules where
  committee : Rules
  /-- Open the header at an authenticated checkpoint's CometBFT hash. -/
  openCometHeader : Hash → Option CometHeader
  /-- Open staking post-state under the checkpoint EL header and read its anchor, as in
  PROOF-6.2-12b and PROOF-6.2-47. The arguments are the checkpoint height and EL hash. -/
  openParentDecision : Nat → Hash → Option DecisionInput
  /-- Stock validator commitment in the order supplied, over keys and powers. -/
  hashValidatorSet : List Member → Hash

structure ValidatorOpenings where
  current : List Member
  next : List Member
  deriving DecidableEq, Repr

structure BoundarySets where
  parent : Option (List Member)
  first : List Member
  second : List Member
  deriving DecidableEq, Repr

def openValidators (rules : BoundaryRules) (expected : Hash) (members : List Member) :
    Option (List Member) :=
  if rules.hashValidatorSet members = expected ∧ validMembers rules.committee members then
    some members
  else none

/-- Open the sets signing p, p+1 and p+2 at an authenticated proof checkpoint p. -/
def boundarySets (rules : BoundaryRules) (origin : GenerationOrigin) (originKeys : List Hash)
    (p : ProofCheckpoint) (openings : ValidatorOpenings) : Option BoundarySets := do
  if p.height = origin.height then
    let initial ← fallback rules.committee origin.fallbackKeysHash originKeys
    return ⟨none, initial, initial⟩
  else if origin.height < p.height then
    let header ← rules.openCometHeader p.cometHash
    if header.height ≠ p.height then none else do
      let parent ← openValidators rules header.validatorsHash openings.current
      let first ← (if p.height = origin.height + 1 then
          fallback rules.committee origin.fallbackKeysHash originKeys
        else openValidators rules header.nextValidatorsHash openings.next)
      let input ← rules.openParentDecision p.height p.elHash
      let second ←
        decision rules.committee p.height input.snapshot input.anchor input.fallbackKeys
      return ⟨some parent, first, second⟩
  else none

/-- A full CometBFT block identity, including the committed part-set identity. -/
structure BlockId where
  hash : Hash
  partSetTotal : Nat
  partSetHash : Hash
  deriving DecidableEq, Repr

structure Vote where
  key : Hash
  voteType : Nat
  height : Nat
  round : Nat
  blockId : Option BlockId
  timestamp : Nat
  signature : List UInt8
  deriving DecidableEq, Repr

structure Commit where
  height : Nat
  round : Nat
  blockId : BlockId
  votes : List Vote
  deriving DecidableEq, Repr

/-- The adapter verifies the vote under its key, signed over the canonical vote fields
including its own timestamp and the supplied generation chain ID. -/
abbrev VerifyVote := String → Vote → Bool

def counts (verify : VerifyVote) (chainId : String) (commit : Commit) (vote : Vote) : Bool :=
  (vote.voteType == 2) && (vote.height == commit.height) && (vote.round == commit.round) &&
    (vote.blockId == some commit.blockId) && verify chainId vote

/-- A member contributes its voting power at most once, even if several submitted entries
match it. Entries from outside the signing set have no voting power. -/
def signingMembers (verify : VerifyVote) (chainId : String) (members : List Member)
    (commit : Commit) : List Member :=
  members.filter (fun member ↦
    commit.votes.any (fun vote ↦ vote.key == member.key && counts verify chainId commit vote))

def votingPower (members : List Member) : Nat := (members.map Member.power).sum

def validCommit (rules : Rules) (verify : VerifyVote) (chainId : String) (height : Nat)
    (headerHash : Hash) (members : List Member) (commit : Commit) : Bool :=
  validMembers rules members &&
    decide (commit.height = height ∧ 0 < height ∧ height < limit48 ∧ commit.round < 2^31 ∧
      commit.blockId.hash = headerHash ∧ 0 < commit.blockId.partSetTotal ∧
        commit.blockId.partSetTotal < 2^32) &&
    decide (2 * votingPower members <
      3 * votingPower (signingMembers verify chainId members commit))

/-- The two signing sets agree on each member's key and assigned power. -/
def sameSigningSet (current next : List Member) : Bool :=
  current.all next.contains && next.all current.contains

def commitRequired (terminal : Bool) (current next : List Member) : Bool :=
  terminal || !sameSigningSet current next

/-- At interior heights with unchanged signing sets, ancestry supplies the authentication. -/
def checkRequiredCommit (rules : Rules) (verify : VerifyVote) (chainId : String) (height : Nat)
    (headerHash : Hash) (terminal : Bool) (current next : List Member) (commit : Option Commit) :
    Bool :=
  if commitRequired terminal current next then
    commit.any (validCommit rules verify chainId height headerHash current)
  else true

end Etna.Design.PerBlockGuest
