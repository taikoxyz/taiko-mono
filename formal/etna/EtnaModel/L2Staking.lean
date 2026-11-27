import EtnaModel.Common

/-! Decoded L2 EtnaStaking transitions (§4.1, §4.2 and §4.4). Execution supplies the
caller, block context, cryptographic checks and token-call outcomes. Packed storage,
signature bytes, ERC-20 behavior and EVM system-call gas/receipt handling are external. -/
namespace Etna.Design.L2Staking

def noExit : Nat := limit48 - 1
def systemCaller : Nat := 2^160 - 2
def seatLimit : Nat := 128

structure Config where
  nMax : Nat
  minStake : Nat
  vpUnit : Nat
  missLimit : Nat
  missReleaseLimit : Nat
  missSlashBps : Nat
  withdrawalDelay : Nat
  slashBountyBps : Nat
  slashSink : Nat
  dao : Nat
  forfeitBps : Nat
  deriving DecidableEq, Repr

/-- Deployment constraints on the modeled parameters. The evidence window is a deployment
input expressed in L2 blocks. Token identity and its supply bound are external. -/
def Config.valid (c : Config) (unsettled evidenceWindow : Nat) : Bool :=
  decide (1 ≤ c.nMax ∧ c.nMax ≤ seatLimit ∧ 10^27 ≤ c.minStake * c.nMax ∧
    867361738 ≤ c.vpUnit ∧ c.vpUnit ≤ c.minStake ∧
    1 ≤ c.missLimit ∧ c.missLimit ≤ c.missReleaseLimit ∧ c.missReleaseLimit < 2^16 ∧
    0 < c.missSlashBps ∧ c.missSlashBps ≤ 10000 ∧
    unsettled + 2 + evidenceWindow ≤ c.withdrawalDelay ∧ c.slashBountyBps < 10000 ∧
    c.slashSink ≠ 0 ∧ 0 < c.forfeitBps ∧ c.forfeitBps ≤ 10000)

structure Key where
  ckAddr : Nat
  ckPrefix : Nat
  ckX : Nat
  deriving DecidableEq, Repr

structure Bond where
  key : Key
  owner : Nat
  effStake : Nat
  exitHeight : Nat := noExit
  withdrawn : Bool := false
  forfeited : Bool := false
  seat : Option Nat := none
  deriving DecidableEq, Repr

structure LiveSeat where
  bondId : Nat
  misses : Nat
  deriving DecidableEq, Repr

structure SeatMember where
  ckPrefix : Nat
  ckX : Nat
  power : Nat
  deriving DecidableEq, Repr

/-- The stored snapshot view. The index is the seat number and `none` is an all-zero record. -/
structure Snapshot where
  height : Nat := 0
  totalStake : Nat := 0
  seats : List (Option SeatMember) := List.replicate seatLimit none
  deriving DecidableEq, Repr

/-- `snapshot()`'s occupied entries with their seat numbers in ascending order. -/
def Snapshot.members (s : Snapshot) : List (Nat × SeatMember) :=
  s.seats.zipIdx.filterMap fun (record, index) ↦ record.map fun member ↦ (index, member)

structure State where
  config : Config
  /-- IDs are array indices. Withdrawal updates a bond in place and never removes its index. -/
  bonds : Array Bond := #[]
  seats : Array (Option LiveSeat)
  generation : Nat := 0
  snapshot : Snapshot := {}
  deriving DecidableEq, Repr

/-- Empty ledger for an already validated deployment. -/
def State.empty (config : Config) : State :=
  { config, seats := Array.replicate config.nMax none }

def bondAt (s : State) (id : Nat) : Option Bond := s.bonds[id]?

/-- Decoded `bondForKey`. `some 0` is a registered key and `none` is `(false, 0)`. -/
def bondForKey (s : State) (ckAddr : Nat) : Option Nat :=
  s.bonds.findIdx? (fun bond ↦ bond.key.ckAddr == ckAddr)

/-- The live seat, including changes made by transactions in this block. -/
def seatOfBond (s : State) (id : Nat) : Option Nat := (bondAt s id).bind Bond.seat

def seatForKey (s : State) (ckAddr : Nat) : Option Nat :=
  (bondForKey s ckAddr).bind (seatOfBond s)

def liveSeat (s : State) (seat : Nat) : Option LiveSeat := s.seats[seat]?.join

/-- Decoded `bondInSeat`. Out-of-bounds and empty seats both read as `none`. -/
def bondInSeat (s : State) (seat : Nat) : Option Nat := (liveSeat s seat).map LiveSeat.bondId

def eligible (c : Config) (bond : Bond) : Bool :=
  decide (bond.withdrawn = false ∧ bond.exitHeight = noExit ∧ c.minStake ≤ bond.effStake)

private def writeBond (s : State) (id : Nat) (bond : Bond) : State :=
  { s with bonds := s.bonds.setIfInBounds id bond }

private def writeSeat (s : State) (seat : Nat) (occupant : Option LiveSeat) : State :=
  { s with seats := s.seats.setIfInBounds seat occupant }

private def releaseSeat (s : State) (id : Nat) (bond : Bond) : State :=
  let updated := writeBond s id { bond with seat := none }
  match bond.seat with
  | none => updated
  | some seat => writeSeat updated seat none

/-- The lowest vacancy receives a new occupant with zero misses. An existing occupant keeps
its own seat and counter. A full table fails the operation that needs a new seat. -/
private def seatEligibleBond (s : State) (id : Nat) (bond : Bond) : Option State := do
  if eligible s.config bond && bond.seat.isNone then
    let seat ← s.seats.findIdx? Option.isNone
    let updated := writeBond s id { bond with seat := some seat }
    pure (writeSeat updated seat (some ⟨id, 0⟩))
  else
    pure (writeBond s id bond)

def roundedPenalty (balance bps : Nat) : Nat := (balance * bps + 9999) / 10000

/-- Decoded canonical vote block identity. Absent hashes are empty byte strings.
A present zero is a 32-byte all-zero hash. Nil has two absent hashes and total zero. -/
structure VoteBlockId where
  blockHash : Option Hash
  partsTotal : Nat
  partsHash : Option Hash
  deriving DecidableEq, Repr

structure Vote where
  kind : Nat
  height : Nat
  round : Nat
  blockId : VoteBlockId
  timestampSeconds : Int
  timestampNanos : Int
  generation : Nat
  deriving DecidableEq, Repr

inductive Transfer where
  | receive (payer amount : Nat)
  | pay (to amount : Nat)
  deriving DecidableEq, Repr

/-- External execution adapters fixed by the deployment. Registration checks canonical
key decoding, ckAddr derivation and owner-bound PoP. Vote recovery uses this deployment's
domain and checks the vote field widths, canonical sign bytes and signature encoding.
Token validation covers every requested transfer of the configured L2 TAIKO token and
returns false if the transaction must revert. -/
structure Adapters where
  registerOK : Nat → Key → Hash → Bool
  recoverVote : Vote → Hash → Option Nat
  transfersOK : List Transfer → Bool

structure Context where
  height : Nat
  timestamp : Nat
  caller : Nat
  entered : Bool := false
  deriving DecidableEq, Repr

inductive Action where
  | register (key : Key) (amount : Nat) (pop : Hash)
  | topUp (bondId amount : Nat)
  | requestExit (bondId : Nat)
  | withdraw (bondId to : Nat)
  | slashDoubleSign (bondId : Nat) (a b : Vote) (sigA sigB : Hash)
  | forfeit (bondId : Nat) (incidentId : Hash) (validUntil : Nat)
  deriving DecidableEq, Repr

structure Forfeiture where
  bondId : Nat
  incidentId : Hash
  balanceBefore : Nat
  penalty : Nat
  deriving DecidableEq, Repr

structure Result where
  state : State
  transfers : List Transfer := []
  registeredId : Option Nat := none
  forfeiture : Option Forfeiture := none
  deriving DecidableEq, Repr

/-- Match the complete vote identities and the recovered signer to the permanently issued
bond. The votes may use a historical generation and need no committee membership proof. -/
def doubleSign (s : State) (adapters : Adapters) (id : Nat) (a b : Vote)
    (sigA sigB : Hash) : Bool :=
  decide ((a.kind = 1 ∨ a.kind = 2) ∧ a.kind = b.kind ∧ a.height = b.height ∧
    a.round = b.round ∧ a.generation = b.generation ∧ a.generation ≤ s.generation ∧
    a.blockId ≠ b.blockId) &&
  match adapters.recoverVote a sigA, adapters.recoverVote b sigB with
  | some x, some y => decide (x ≠ 0 ∧ x = y ∧ bondForKey s x = some id)
  | _, _ => false

private def transact (s : State) (adapters : Adapters) (ctx : Context) : Action → Option Result
  | .register key amount pop => do
      let id := s.bonds.size
      if amount < s.config.minStake || limit256 ≤ amount || limit256 ≤ id ||
          (bondForKey s key.ckAddr).isSome || !adapters.registerOK ctx.caller key pop then none
      else
        let bond := { key, owner := ctx.caller, effStake := amount : Bond }
        let updated ← seatEligibleBond { s with bonds := s.bonds.push bond } id bond
        pure {
          state := updated
          transfers := [.receive ctx.caller amount]
          registeredId := some id }
  | .topUp id amount => do
      let bond ← bondAt s id
      let balance := bond.effStake + amount
      if ctx.caller = bond.owner ∧ bond.withdrawn = false ∧ bond.exitHeight = noExit ∧
          0 < amount ∧ balance < limit256 then
        let updated ← seatEligibleBond s id { bond with effStake := balance }
        pure { state := updated, transfers := [.receive ctx.caller amount] }
      else none
  | .requestExit id => do
      let bond ← bondAt s id
      if ctx.caller = bond.owner ∧ bond.withdrawn = false ∧ bond.exitHeight = noExit ∧
          ctx.height < noExit then
        pure { state := releaseSeat s id { bond with exitHeight := ctx.height } }
      else none
  | .withdraw id recipient => do
      let bond ← bondAt s id
      if bond.withdrawn = false ∧ bond.exitHeight ≠ noExit ∧
          bond.exitHeight + s.config.withdrawalDelay ≤ ctx.height ∧
          (bond.effStake = 0 ∨ ctx.caller = bond.owner) then
        let updated := writeBond s id { bond with owner := 0, effStake := 0, withdrawn := true }
        let transfers := if bond.effStake = 0 then [] else [.pay recipient bond.effStake]
        pure { state := updated, transfers }
      else none
  | .slashDoubleSign id a b sigA sigB => do
      let bond ← bondAt s id
      if bond.withdrawn = false ∧ 0 < bond.effStake ∧ doubleSign s adapters id a b sigA sigB then
        let bounty := bond.effStake * s.config.slashBountyBps / 10000
        let updated := releaseSeat s id
          { bond with effStake := 0, exitHeight := min bond.exitHeight ctx.height }
        let reward := if bounty = 0 then [] else [.pay ctx.caller bounty]
        pure { state := updated,
               transfers := reward ++ [.pay s.config.slashSink (bond.effStake - bounty)] }
      else none
  | .forfeit id incidentId validUntil => do
      let bond ← bondAt s id
      if ctx.caller = s.config.dao ∧ bond.withdrawn = false ∧ bond.forfeited = false ∧
          ctx.timestamp ≤ validUntil ∧ 0 < bond.effStake then
        let penalty := roundedPenalty bond.effStake s.config.forfeitBps
        let updated := releaseSeat s id { bond with
          effStake := bond.effStake - penalty
          exitHeight := min bond.exitHeight ctx.height
          forfeited := true }
        pure {
          state := updated
          transfers := [.pay s.config.slashSink penalty]
          forfeiture := some ⟨id, incidentId, bond.effStake, penalty⟩ }
      else none

/-- Successful transactions expose their effects atomically and preserve the snapshot and
stored generation. Failure is `none`, so the caller keeps the original state. -/
def execute (s : State) (adapters : Adapters) (ctx : Context)
    (action : Action) : Option Result := do
  if ctx.entered then none
  else
    let result ← transact s adapters ctx action
    if result.transfers.isEmpty || adapters.transfersOK result.transfers then
      let updated := { s with bonds := result.state.bonds, seats := result.state.seats }
      pure { result with state := updated }
    else none

private def countMiss (bitmap : Nat) (s : State) (seat : Nat) : State :=
  match liveSeat s seat with
  | none => s
  | some occupant =>
      let misses := if bitmap.testBit seat then occupant.misses + 1 else 0
      writeSeat s seat (some { occupant with misses })

private def penalize (prior : State × List Transfer) (seat : Nat) : State × List Transfer :=
  let (s, transfers) := prior
  match liveSeat s seat with
  | none => prior
  | some occupant =>
      if occupant.misses = 0 || occupant.misses % s.config.missLimit != 0 then prior
      else
        match bondAt s occupant.bondId with
        | none => prior
        | some bond =>
            let penalty := roundedPenalty bond.effStake s.config.missSlashBps
            let bond := { bond with effStake := bond.effStake - penalty }
            let updated := if eligible s.config bond then
              writeBond s occupant.bondId bond
            else releaseSeat s occupant.bondId bond
            (updated, .pay s.config.slashSink penalty :: transfers)

private def releaseMissedSeat (s : State) (seat : Nat) : State :=
  match liveSeat s seat with
  | some occupant =>
      if s.config.missReleaseLimit ≤ occupant.misses then
        match bondAt s occupant.bondId with
        | some bond => releaseSeat s occupant.bondId bond
        | none => s
      else s
  | none => s

/-- Record the live seats and pad the storage view to 128 records. -/
def buildSnapshot (s : State) (height : Nat) : Snapshot :=
  let count := min s.config.nMax seatLimit
  let bonds := (List.range count).map fun seat ↦
    (bondInSeat s seat).bind (bondAt s)
  let totalStake := (bonds.map fun bond ↦ (bond.map Bond.effStake).getD 0).sum
  let records := bonds.map fun bond ↦ bond.map fun member ↦
    ⟨member.key.ckPrefix, member.key.ckX, member.effStake / s.config.vpUnit⟩
  { height, totalStake, seats := records ++ List.replicate (seatLimit - count) none }

/-- The decoded system call over the parent's live seats. Count first, apply sink-only
penalties and release seats, then record the snapshot at this height. `systemSucceeded`
means the EL committed the staking code's changes, including token calls and storage writes. -/
def blockStartTransition (s : State) (height caller generation missBitmap : Nat)
    (systemSucceeded : Bool) : Option Result :=
  if systemSucceeded && decide (caller = systemCaller ∧ height < limit48 ∧
      generation < limit48 ∧ missBitmap < 2^128) then
    let seats := List.range s.config.nMax
    let counted := seats.foldl (countMiss missBitmap) { s with generation }
    let (penalized, transfers) := seats.foldl penalize (counted, [])
    let released := seats.foldl releaseMissedSeat penalized
    some {
      state := { released with snapshot := buildSnapshot released height }
      transfers := transfers.reverse }
  else none

/-- EL block-start failure is a no-op. The unchanged snapshot height is available to committee
selection even if later transactions change the live state. -/
def onBlockStart (s : State) (height caller generation missBitmap : Nat)
    (systemSucceeded : Bool) : State :=
  let transition := blockStartTransition s height caller generation missBitmap systemSucceeded
  (transition.map Result.state).getD s

end Etna.Design.L2Staking
