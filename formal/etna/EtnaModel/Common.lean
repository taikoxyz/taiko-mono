import Std

/-! Specification state only. Hashes are opaque atoms; cryptographic binding,
L1 authentication, EL execution and EVM journaling are named external boundaries. -/
namespace Etna.Design

abbrev Hash := Nat

def limit48 : Nat := 2^48

/-- Allowed grid intervals: K is a protocol constant built into the Inbox and both guests,
1 ≤ K ≤ 6, its value fixed from measured proving capacity (§11). -/
def GridRange (k : Nat) : Prop := 1 ≤ k ∧ k ≤ 6
def limit256 : Nat := 2^256

structure Domain where
  l1ChainId : Nat
  l2ChainId : Nat
  inbox : Nat
  registry : Nat
  deriving DecidableEq, Repr

namespace Committee

/-- Registry entry as the election reads it (three storage words; no reward recipient).
`exitAt` is exitEffectiveL1; "no exit set" must compare above every snapshot. -/
structure Entry where
  key : Hash
  stake : Nat
  activeFrom : Nat
  exitAt : Nat
  deriving DecidableEq, Repr

/-- Committee record: target epoch, election cutoff and selected members. Defined with the
entry here so the Inbox state can carry the ghost committee-0 opening. -/
structure Record where
  targetEpoch : Nat
  cutoff : Nat
  members : List Entry
  deriving DecidableEq, Repr

end Committee

/-- Slot 290 generation origin: (startHeight, l1BlockNumber, l1Timestamp). -/
structure Origin where
  height : Nat
  l1Block : Nat
  timestamp : Nat
  deriving DecidableEq, Repr

/-- Slot 285 landing record, keyed by `height`, three storage words: the packed actual
parent c, generation and FI cursor, then the EL hash and the CometBFT hash. The state
root lives only in the SignalService checkpoint; the committee snapshot only in slot 284. -/
structure Checkpoint where
  height : Nat
  elHash : Hash
  cometHash : Hash
  cursor : Nat
  generation : Nat
  parent : Nat
  deriving DecidableEq, Repr, Inhabited

/-- SignalService checkpoint written by `land`: (height, hash, stateRoot). -/
structure Signal where
  height : Nat
  hash : Hash
  stateRoot : Hash
  deriving DecidableEq, Repr, Inhabited

/-- Decoded preimage of the initialized config commitment. This is ghost input from
an authenticated opening, not an assertion that these four fields have separate slots. -/
structure CommitteeConfig where
  unit : Nat
  minimum : Nat
  nMax : Nat
  unsettled : Nat
  deriving DecidableEq, Repr

/-- EtnaInbox state. There is no active/paused status, no withdrawal epoch, no landing
timestamp and no fee ledger: the ETH balance is the unswept FI fees plus forced-in ETH.
`feeAdmissions`, `forcedETH` and `swept` are ghost totals for conservation proofs. -/
structure State where
  domain : Domain
  committeeConfig : Hash
  /-- K: landings end only at heights that are multiples of it (6.1). -/
  gridK : Nat
  entered : Bool := false
  generation : Nat
  /-- Slot 292: monotone recovery-authorization nonce, never restored from history. -/
  recoveryNonce : Nat := 0
  origin : Origin
  origins : List (Nat × Origin)
  checkpoint : Checkpoint
  records : List Checkpoint
  head : Nat
  tail : Nat
  snapshot : Nat
  ethBalance : Nat
  feeAdmissions : Nat
  forcedETH : Nat
  swept : Nat
  signals : List Signal
  /-- Immutable initialized deployment values; zero defaults keep raw legacy fixtures
  usable, but deployed context construction validates the stored epoch/genesis schedule
  and the §10 initialization constraints (`Deployment.Constraints`). -/
  epochLen : Nat := 0
  genesisCutoff : Nat := 0
  committeeZero : Hash := 0
  configuration : CommitteeConfig := ⟨0,0,0,0⟩
  /-- Ghost authenticated opening of the slot-278 committee-0 record hash `committeeZero`,
  like `configuration` for `committeeConfig`; not an extra storage slot. -/
  committeeZeroRecord : Committee.Record := ⟨0,0,[]⟩
  /-- Slot 282 Inbox-initialized immutables, in seconds: forcedInclusionDelay, maxAnchorAge. -/
  forcedDelay : Nat := 0
  maxAnchorAge : Nat := 0
  /-- §11 Inbox immutables: maxBatchBlocks, the forced-inclusion fee (gwei) and doubling
  threshold, and the nonzero DAO treasury `protocolFeeRecipient`. `land`,
  `saveForcedInclusion` and `sweepProtocolFees` read them; no call input can choose them.
  The verifier's result stays an external landing input. -/
  maxBatchBlocks : Nat := 0
  forcedFee : Nat := 0
  forcedThreshold : Nat := 0
  protocolFeeRecipient : Nat := 0
  deriving DecidableEq, Repr

def recordAt (s : State) (h : Nat) : Option Checkpoint :=
  s.records.find? (fun r => r.height == h)

/-- Every wei that entered the Inbox (FI fees or forced transfers) is either still held
or was swept to the fixed treasury. -/
def FeeConserved (s : State) : Prop := s.feeAdmissions+s.forcedETH = s.ethBalance+s.swept

/-- At least one ZK proof, exactly two successful subproofs. Soundness is separate. -/
inductive Backend | sgx | risc0 | sp1 deriving DecidableEq, Repr

def dualOK (proofs : List (Backend × Bool)) : Bool :=
  decide (proofs.length = 2) && proofs.all Prod.snd &&
    proofs.any (fun p => p.1 != .sgx) && decide ((proofs.map Prod.fst).Nodup)

end Etna.Design
