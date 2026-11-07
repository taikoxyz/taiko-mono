import EtnaModel.Committee

/-! Decoded specification authorization. Registry snapshots/anchor history and the
signature predicate are authenticated input boundaries, not cryptographic implementations.
`Entry.key` is the abstract consensus-key identity and stands for its set key (4.3, spec L180:
keccak256 of the L2 chain id and the compressed key, fixed per key); elections order by it. Raw
recovery entryKey values must decode to this identity. This module does not prove Comet's locking protocol. -/
namespace Etna.Design.Consensus

structure Context where
  domain : Domain
  generation : Nat
  originHeight : Nat
  originBlock : Nat
  genesisCutoff : Nat
  epochLen : Nat
  unit : Nat
  minimum : Nat
  nMax : Nat
  registry : Nat → List Committee.Entry
  anchorAt : Nat → Nat

def epoch (c : Context) (h : Nat) : Nat := (h-1)/c.epochLen
def switchHeight (c : Context) (t : Nat) : Nat := t*c.epochLen-1

def selected (c : Context) (target cutoff : Nat) : Committee.Record :=
  ⟨target,cutoff,Committee.chosen c.unit c.minimum cutoff c.nMax (c.registry cutoff)⟩

def initial (c : Context) : Committee.Record :=
  selected c (if c.generation = 0 then 0 else c.originHeight/c.epochLen)
    (if c.generation = 0 then c.genesisCutoff else c.originBlock)

def normal (c : Context) (t : Nat) : Committee.Record :=
  selected c t (max (c.anchorAt (t*c.epochLen-2)) c.originBlock)

/-- A switch activates only if S(t) actually occurred after this generation's origin.
This cancels old pending updates and handles a recovery first block equal to S(t). -/
def activeAt (c : Context) (h : Nat) : Committee.Record :=
  let t := epoch c h
  if c.originHeight < switchHeight c t then normal c t else initial c

def ElectionValid (c : Context) (r : Committee.Record) : Prop :=
  Committee.election c.unit c.minimum r.cutoff c.nMax (c.registry r.cutoff) = some r.members

instance (c : Context) (r : Committee.Record) : Decidable (ElectionValid c r) :=
  inferInstanceAs (Decidable (_ = _))

structure Vote where
  domain : Domain
  generation : Nat
  height : Nat
  round : Nat
  kind : Nat
  blockId : Hash
  key : Hash
  deriving DecidableEq, Repr

/-- Count only selected members whose identities are present; duplicate votes cannot add
power, and CommitValid additionally rejects duplicate signer identities. -/
def signedPower (c : Context) (members : List Committee.Entry) (keys : List Hash) : Nat :=
  Committee.totalPower c.unit (members.filter (fun e => keys.contains e.key))

def VoteValid (c : Context) (signature : Vote → Prop) (h round block : Nat) (v : Vote) : Prop :=
  v.domain = c.domain ∧ v.generation = c.generation ∧ v.height = h ∧ v.round = round ∧
  v.kind = 2 ∧ v.blockId = block ∧ v.key ∈ ((activeAt c h).members.map Committee.Entry.key) ∧ signature v

instance (c : Context) (signature : Vote → Prop) [DecidablePred signature]
    (h round block : Nat) (v : Vote) : Decidable (VoteValid c signature h round block v) :=
  inferInstanceAs (Decidable (_ ∧ _))

def CommitValid (c : Context) (signature : Vote → Prop) (h round block : Nat) (votes : List Vote) : Prop :=
  c.originHeight < h ∧ ElectionValid c (activeAt c h) ∧
  (votes.map Vote.key).Nodup ∧ (∀ v ∈ votes, VoteValid c signature h round block v) ∧
  2*Committee.totalPower c.unit (activeAt c h).members <
    3*signedPower c (activeAt c h).members (votes.map Vote.key)

instance (c : Context) (signature : Vote → Prop) [DecidablePred signature]
    (h round block : Nat) (votes : List Vote) : Decidable (CommitValid c signature h round block votes) :=
  inferInstanceAs (Decidable (_ ∧ _))

end Etna.Design.Consensus
