module
public import Etna.Committee.Schedule
@[expose] public section
namespace Etna.Committee
inductive Relation | absent (epoch : Nat) | equal (epoch : Nat) | conflict (epoch : Nat) | none
  deriving DecidableEq, Repr
inductive Failure
  | conflict (epoch : Nat) | unknown (epoch : Nat) | witness | empty | identity | certificate | backPressure | overflow
  deriving DecidableEq, Repr
structure Switch where
  outgoing : Nat
  incoming : Nat
  pruneBefore : Nat
  deriving DecidableEq, Repr
structure Plan where
  insertEpoch : Option Nat
  switch : Option Switch
  deriving DecidableEq, Repr

def plan (s : Schedule) (h : Nat) (r : Relation) (outgoing incoming : Bool) : Except Failure Plan :=
  match r with
  | .conflict t => .error (.conflict t)
  | _ =>
    let insert := match r with | .absent t | .equal t => some t | _ => none
    match switchTarget s h with
    | none => .ok ⟨insert, none⟩
    | some t =>
      if outgoing || insert == some (t-1) then
        if incoming || insert == some t then .ok ⟨insert, some ⟨t-1,t,t-1⟩⟩
        else .error (.unknown t)
      else .error (.unknown (t-1))

/-- Opaque hashes/keys are atoms. No injectivity of their construction is assumed. -/
abbrev Hash := Nat
structure Member where
  key : Nat
  power : Nat
  deriving DecidableEq, Repr
structure Record where
  epoch : Nat
  root : Hash
  cutoff : Nat
  members : List Member
  deriving DecidableEq, Repr
structure Anchor where
  blockHash : Hash
  stateRoot : Hash
  number : Nat
  checkpoint : Nat
  deriving DecidableEq, Repr
structure Snapshot where
  root : Hash
  cutoff : Nat
  entries : List Nat
  deriving DecidableEq, Repr
structure Witness where
  snapshot : Snapshot
  proof : List Nat
  deriving DecidableEq, Repr

/-- Explicit MPT and election boundaries. Soundness refers to storage at the committed
root and exact cutoff; derive is a deterministic function, not a supplied conclusion. -/
structure Authentication where
  stored : Hash → Nat → Option Snapshot
  verify : Hash → Nat → Snapshot → List Nat → Bool
  sound : ∀ root cutoff snapshot proof, verify root cutoff snapshot proof = true →
    stored root cutoff = some snapshot
  derive : Nat → Snapshot → Record

/-- Every listed vote has a position/key. Absent and nil votes never add block power.
Signature validity is an external relation over exact chain, height, block and key. -/
inductive VoteKind | absent | nil | block deriving DecidableEq, Repr
structure Vote where
  signer : Nat
  kind : VoteKind
  signature : List Nat
  deriving DecidableEq, Repr
structure Certificate where
  chain : Nat
  height : Nat
  blockHash : Hash
  votes : List Vote
  deriving DecidableEq, Repr
structure Crypto where
  valid : Nat → Nat → Hash → Nat → List Nat → Bool
  genuine : Nat → Nat → Hash → Nat → List Nat → Prop
  sound : ∀ chain height hash key signature, valid chain height hash key signature = true →
    genuine chain height hash key signature

def votePower (crypto : Crypto) (cert : Certificate) (members : List Member) (vote : Vote) : Nat :=
  if vote.kind = .block ∧ crypto.valid cert.chain cert.height cert.blockHash vote.signer vote.signature then
    ((members.find? (fun m => m.key == vote.signer)).map Member.power).getD 0 else 0
def signedPower (crypto : Crypto) (cert : Certificate) (r : Record) :=
  (cert.votes.map (votePower crypto cert r.members)).sum
def totalPower (r : Record) := (r.members.map Member.power).sum

def certificateOK (crypto : Crypto) (chain height blockHash : Nat) (r : Record) (cert : Certificate) : Bool :=
  decide (cert.chain = chain ∧ cert.height = height ∧ cert.blockHash = blockHash ∧
    (cert.votes.map Vote.signer).Nodup ∧ (r.members.map Member.key).Nodup ∧
    0 < totalPower r ∧ 3*signedPower crypto cert r > 2*totalPower r)

def incoming (a : Authentication) (s : Schedule) (parent : Anchor) (h : Nat)
    (w : Option Witness) : Except Failure (Option Record) :=
  match switchTarget s h, w with
  | none, none => .ok none
  | some t, some w =>
    if a.verify parent.stateRoot parent.number w.snapshot w.proof then
      let r := a.derive t w.snapshot
      if r.epoch = t ∧ r.root = w.snapshot.root ∧ r.cutoff = parent.number ∧ w.snapshot.cutoff = parent.number then
        if r.members = [] then .error .empty else .ok (some r)
      else .error .witness
    else .error .witness
  | _, _ => .error .witness

structure CommitteeState where
  height : Nat
  blockHash : Hash
  anchor : Anchor
  records : List Record
  deriving DecidableEq, Repr

def lookup (records : List Record) (t : Nat) := records.find? (fun r => r.epoch == t)
def authority (s : Schedule) (st : CommitteeState) (h : Nat) :=
  (epochOf s h).bind (lookup st.records)

def relation (records : List Record) (r : Option Record) : Relation :=
  match r with
  | none => .none
  | some r => match lookup records r.epoch with
    | none => .absent r.epoch
    | some old => if old = r then .equal r.epoch else .conflict r.epoch

/-- Output retains complete old/new records, sufficient to construct the adapter's update union. -/
abbrev Updates := List (Record × Record)
structure BlockFacts where
  height : Nat
  chain : Nat
  parentHash : Hash
  blockHash : Hash
  anchor : Anchor
  witness : Option Witness
  certificate : Certificate
  deriving DecidableEq, Repr

/-- Named external acceptance relations bind the actual block/context. They are supplied
as evidence, not arbitrary proposition-valued flags. The reducer still checks certificate
identity, parent continuity, witness placement, root/cutoff, complete records and cap. -/
structure Context where
  schedule : Schedule
  chain : Nat
  cap : Nat
  auth : Authentication
  crypto : Crypto
  authenticatedAnchor : Hash → Anchor → Prop
  validPayload : Hash → Hash → Prop
structure AuthenticatedBlockFacts (ctx : Context) where
  facts : BlockFacts
  anchorEvidence : ctx.authenticatedAnchor facts.blockHash facts.anchor
  payloadEvidence : ctx.validPayload facts.parentHash facts.blockHash

def require (o : Option α) (error : Failure) : Except Failure α :=
  match o with | none => .error error | some x => .ok x

/-- Source ordering: authenticate/derive before mutation; conflict precedes required lookups.
Comet's update-at-h/activation-at-h+2 law remains an explicit external boundary. -/
def step (ctx : Context) (st : CommitteeState) (block : AuthenticatedBlockFacts ctx) :
    Except Failure (CommitteeState × Updates) := do
  let b := block.facts
  if b.height ≠ st.height+1 ∨ b.chain ≠ ctx.chain ∨ b.parentHash ≠ st.blockHash then throw .identity
  let current ← require (authority ctx.schedule st b.height) (.unknown ((epochOf ctx.schedule b.height).getD 0))
  if !certificateOK ctx.crypto ctx.chain b.height b.blockHash current b.certificate then throw .certificate
  let derived ← incoming ctx.auth ctx.schedule st.anchor b.height b.witness
  let target := switchTarget ctx.schedule b.height
  let p ← plan ctx.schedule b.height (relation st.records derived)
    (target.any fun t => (lookup st.records (t-1)).isSome)
    (target.any fun t => (lookup st.records t).isSome)
  let records := match derived with | none => st.records | some r => r :: st.records.filter (fun old => old.epoch != r.epoch)
  let updates ← match p.switch with
    | none => pure []
    | some sw => do
      let old ← require (lookup records sw.outgoing) (.unknown sw.outgoing)
      let new ← require (lookup records sw.incoming) (.unknown sw.incoming)
      if old.members = [] ∨ new.members = [] then throw .empty
      pure [(old,new)]
  if b.height - b.anchor.checkpoint > ctx.cap then throw .backPressure
  if b.height > max64 then throw .overflow
  let records := match p.switch with | none => records | some sw => records.filter (fun r => sw.pruneBefore ≤ r.epoch)
  return (⟨b.height,b.blockHash,b.anchor,records⟩,updates)

/-- Failure-short-circuiting fold; updates preserve block order across arbitrary cuts. -/
def replay (ctx : Context) : List (AuthenticatedBlockFacts ctx) → CommitteeState → Except Failure (CommitteeState × Updates)
  | [], st => .ok (st,[])
  | b::bs, st => do
    let (next, u) ← step ctx st b
    let (last, us) ← replay ctx bs next
    return (last,u++us)


/-- The external Comet semantics boundary: a returned update affects block h+2.
The record pair represents the deterministic validator update union, whose byte encoding
and application in Comet are adapter obligations, not part of the scalar Rust refinement. -/
def cometView (updateHeight : Nat) (outgoing incoming : Record) (height : Nat) : Record :=
  if height < updateHeight+2 then outgoing else incoming
structure CometAdapter where
  observed : Nat → Record → Record → Nat → Record
  appliesAfterTwo : ∀ updateHeight outgoing incoming height,
    observed updateHeight outgoing incoming height = cometView updateHeight outgoing incoming height
end Etna.Committee
