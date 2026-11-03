import EtnaModel.CurrentRegistry

/-! Atomic token boundary for the current registry. RegistryMachine is the principal
projection; this module commits it only together with successful token transfers. -/
namespace Etna.Design.Current.RegistryPayments

structure Payment where
  source : Nat
  recipient : Nat
  amount : Nat
  /-- Incoming deposits use transferFrom under the registry's approval. -/
  pull : Bool := false
  deriving DecidableEq, Repr

structure TokenState where
  balances : Nat → Nat
  allowances : Nat → Nat → Nat

/-- Immutable deployment addresses and token adapter. The adapter receives concrete
payment intents, not a caller-selected success flag. -/
structure PaymentEnvironment where
  registryAddress : Nat
  slashSink : Nat
  transfer : TokenState → Payment → Option TokenState

structure State where
  registry : RegistryMachine.State
  token : TokenState

/-- The outer authenticated caller must match every embedded caller field. Permissionless
operations use the outer caller directly (in particular for the double-sign bounty). -/
def callerMatches (caller : Nat) : RegistryMachine.Action → Bool
  | .register _ embedded _ _ | .requestExit _ embedded | .topUp _ embedded _
  | .withdraw _ embedded _ | .forfeit _ embedded _ _ _
  | .exclude embedded _ _ | .recheck embedded _ => caller == embedded
  | .activateTopUp _ | .confirm _ | .slash _ _ _ _ _ => true

/-- Exact transfer amounts are derived from the pre-call principal and fixed rates.
No payment is made for zero-balance withdrawal (STAKE-4.1-27). -/
def paymentIntents (env : PaymentEnvironment) (s : RegistryMachine.State)
    (caller : Nat) : RegistryMachine.Action → List Payment
  | .register _ _ amount _ | .topUp _ _ amount => [⟨caller,env.registryAddress,amount,true⟩]
  | .withdraw id _ recipient =>
      match s.ledger.bonds id with
      | none => []
      | some b => if b.value.balance = 0 then []
        else [⟨env.registryAddress,recipient,b.value.balance,false⟩]
  | .slash id _ _ _ _ =>
      match s.ledger.bonds id with
      | none => []
      | some b =>
        let bounty := Staking.fraction b.value.balance s.config.slashBountyBps
        [⟨env.registryAddress,caller,bounty,false⟩,
         ⟨env.registryAddress,env.slashSink,b.value.balance-bounty,false⟩]
  | .forfeit id _ _ _ _ =>
      match s.ledger.bonds id with
      | none => []
      | some b => [⟨env.registryAddress,env.slashSink,
          Staking.forfeitPenalty b.value.balance s.config.forfeitBps,false⟩]
  | _ => []

/-- Intermediate token states are private to the transaction and discarded on failure. -/
def runTransfers (env : PaymentEnvironment) (token : TokenState) : List Payment → Option TokenState
  | [] => some token
  | payment :: rest => (env.transfer token payment).bind fun next => runTransfers env next rest

/-- A successful result emits the exact pre-state-derived intents. Failure returns no
registry, token state or receipts, including after a later transfer fails. -/
def executeTransaction (env : PaymentEnvironment) (s : State)
    (v : RegistryMachine.InboxView) (now caller : Nat) (action : RegistryMachine.Action) :
    Option (State × List Payment) :=
  if callerMatches caller action then
    (RegistryMachine.execute s.registry v now action).bind fun registry =>
      let payments := paymentIntents env s.registry caller action
      (runTransfers env s.token payments).map fun token => (⟨registry,token⟩,payments)
  else none

/-- Failed EVM transactions stutter atomically, including lifetime forfeiture flags. -/
def transact (env : PaymentEnvironment) (s : State)
    (v : RegistryMachine.InboxView) (now caller : Nat) (action : RegistryMachine.Action) : State :=
  ((executeTransaction env s v now caller action).map Prod.fst).getD s

/-- Concrete standard-token balance/approval semantics. Real token correctness and
availability refine this adapter; an insufficient balance or allowance rejects. -/
def standardTransfer (registryAddress : Nat) (s : TokenState) (p : Payment) : Option TokenState :=
  if p.amount ≤ s.balances p.source ∧
      (p.pull = false ∨ p.amount ≤ s.allowances p.source registryAddress) then
    some {
      balances := fun account =>
        if account = p.recipient then
          if account = p.source then s.balances account else s.balances account+p.amount
        else if account = p.source then s.balances account-p.amount else s.balances account,
      allowances := fun owner spender =>
        if p.pull = true ∧ owner = p.source ∧ spender = registryAddress then
          s.allowances owner spender-p.amount else s.allowances owner spender }
  else none

def standardEnvironment (registryAddress slashSink : Nat) : PaymentEnvironment :=
  ⟨registryAddress,slashSink,standardTransfer registryAddress⟩

end Etna.Design.Current.RegistryPayments
