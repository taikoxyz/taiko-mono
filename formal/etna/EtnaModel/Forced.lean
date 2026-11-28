import EtnaModel.Common

namespace Etna.Design.Forced

structure Entry where
  txHash : Hash
  timestamp : Nat
  l1Block : Nat
  deriving DecidableEq, Repr

structure Witness where
  index : Nat
  stored : Entry
  storageAuthenticated : Bool
  rawHash : Hash
  rawBytes : Nat
  canonical : Bool
  firstHash : Option Hash
  firstCanonical : Bool
  firstBytes : Nat
  deriving DecidableEq, Repr

inductive Singleton | unavailable | completedRetained | completedEmpty | inconsistent
  deriving DecidableEq, Repr
inductive Result | accepted (cursor : Nat) | waiting | rejected
  deriving DecidableEq, Repr

/-- Canonical parsing/signatures, storage authentication, and singleton context matching
are adapter boundaries. A transient failure is not a completed-empty result. Eligibility
ignores fees: a low-fee transaction simply builds an empty singleton block. -/
def step (cursor tail anchor delay : Nat) (w : Option Witness) (execution : Singleton) : Result :=
  if cursor ≥ tail then
    if w.isNone then .accepted cursor else .rejected
  else match w with
  | none => .rejected
  | some w =>
    if w.index ≠ cursor ∨ !w.storageAuthenticated ∨ w.rawBytes > 8192 ∨
      (w.rawBytes ≠ 0 ∧ w.rawHash ≠ w.stored.txHash) then .rejected
    else if w.firstHash = some w.stored.txHash ∧ w.firstCanonical = true ∧ w.firstBytes ≤ 8192 then
      .accepted (cursor+1)
    else if anchor < w.stored.timestamp+delay then .accepted cursor
    else if w.rawHash ≠ w.stored.txHash ∨ w.rawBytes > 8192 then .rejected
    else if w.canonical = false then .accepted (cursor+1)
    else match execution with
      | .unavailable => .waiting
      | .completedRetained | .inconsistent => .rejected
      | .completedEmpty => .accepted (cursor+1)

/-- Admission formula is in gwei; actual accounting uses wei. -/
def admissionFee (base threshold pending : Nat) : Nat := base*(threshold+pending)/threshold*1000000000

/-- The only payable entry point: the fee stays in the Inbox, overpayment is refunded in
the same transaction (or the whole call reverts). The fee and doubling threshold are the
Inbox's own immutables (§11); the caller supplies only the transaction and its payment. -/
def enqueue (s : State) (rawBytes paid : Nat) (refundOK : Bool) : Option State :=
  let fee := admissionFee s.forcedFee s.forcedThreshold (s.tail-s.head)
  if s.entered = false ∧ s.forcedThreshold > 0 ∧ rawBytes ≤ 8192 ∧ s.head ≤ s.tail ∧
     s.tail+1 < limit48 ∧ fee ≤ paid ∧
     s.ethBalance+fee < limit256 ∧ (paid = fee ∨ refundOK = true) then
    some { s with
      tail := s.tail+1,feeAdmissions := s.feeAdmissions+fee,ethBalance := s.ethBalance+fee }
  else none

/-- `sweepProtocolFees()`: anyone may call; the whole ETH balance goes to the Inbox's
immutable, nonzero `protocolFeeRecipient`; a failed transfer reverts everything. There is no
caller, recipient, owner or amount argument, and queue/landing progress is not consulted. -/
def sweep (s : State) (transferOK : Bool) : Option State :=
  if s.entered = false ∧ s.protocolFeeRecipient ≠ 0 ∧ transferOK = true then
    some { s with ethBalance := 0,swept := s.swept+s.ethBalance }
  else none

/-- ETH forced in (selfdestruct/coinbase) is not FI revenue but is swept with the rest. -/
def extraETH (s : State) (amount : Nat) : State :=
  { s with ethBalance := s.ethBalance+amount,forcedETH := s.forcedETH+amount }

/-- Empty hash is an opaque fixed atom, not a reclaimable historical fee field. -/
def clear (emptyHash : Hash) (e : Entry) : Entry := { e with txHash := emptyHash }

end Etna.Design.Forced
