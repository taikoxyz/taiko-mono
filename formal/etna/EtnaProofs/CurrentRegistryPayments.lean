import EtnaModel.CurrentRegistryPayments
import EtnaProofs.CurrentRegistry
import EtnaProofs.Staking

namespace Etna.Design.Current.RegistryPayments
set_option maxRecDepth 20000

/-- Both principal projection and token state come from the same successful transaction. -/
theorem tx_success_details {env : PaymentEnvironment} {s t : State}
    {v : RegistryMachine.InboxView} {now caller : Nat} {action : RegistryMachine.Action}
    {receipts : List Payment}
    (ok : executeTransaction env s v now caller action = some (t,receipts)) :
    RegistryMachine.execute s.registry v now action = some t.registry ∧
    runTransfers env s.token (paymentIntents env s.registry caller action) = some t.token ∧
    receipts = paymentIntents env s.registry caller action ∧ callerMatches caller action = true := by
  unfold executeTransaction at ok
  split at ok
  next allowed =>
    obtain ⟨registry,hr,h⟩ := Option.bind_eq_some_iff.mp ok
    obtain ⟨token,ht,hpair⟩ := Option.map_eq_some_iff.mp h
    obtain ⟨rfl,rfl⟩ := Prod.mk.inj hpair
    exact ⟨hr,ht,rfl,allowed⟩
  next => simp at ok

theorem tx_success_projects {env : PaymentEnvironment} {s t : State}
    {v : RegistryMachine.InboxView} {now caller : Nat} {action : RegistryMachine.Action}
    {receipts : List Payment}
    (ok : executeTransaction env s v now caller action = some (t,receipts)) :
    RegistryMachine.execute s.registry v now action = some t.registry :=
  (tx_success_details ok).1

/-- A later payout failure cannot leave an earlier principal/flag/token edit committed. -/
theorem failure_atomic {env : PaymentEnvironment} {s : State}
    {v : RegistryMachine.InboxView} {now caller : Nat} {action : RegistryMachine.Action}
    (failed : executeTransaction env s v now caller action = none) :
    transact env s v now caller action = s := by simp [transact,failed]

theorem transfer_failure_reverts {env : PaymentEnvironment} {s : State}
    {v : RegistryMachine.InboxView} {now caller : Nat} {action : RegistryMachine.Action}
    (failed : runTransfers env s.token (paymentIntents env s.registry caller action) = none) :
    executeTransaction env s v now caller action = none := by
  unfold executeTransaction
  split
  · cases RegistryMachine.execute s.registry v now action <;> simp [failed]
  · rfl

/-- This bridge assumes successful concrete external transfers, not successful slashing.
All principal/evidence authorization remains checked by the inner execute function. -/
theorem principal_and_transfers_commit {env : PaymentEnvironment} {s : State}
    {v : RegistryMachine.InboxView} {now caller : Nat} {action : RegistryMachine.Action}
    {registry : RegistryMachine.State} {token : TokenState}
    (principal : RegistryMachine.execute s.registry v now action = some registry)
    (actor : callerMatches caller action = true)
    (transfers : runTransfers env s.token (paymentIntents env s.registry caller action) = some token) :
    executeTransaction env s v now caller action =
      some (⟨registry,token⟩,paymentIntents env s.registry caller action) := by
  simp [executeTransaction,actor,principal,transfers]

theorem withdraw_payment_exact (env : PaymentEnvironment) (s : RegistryMachine.State)
    (caller id embedded recipient : Nat) (b : Registry.Bond)
    (found : s.ledger.bonds id = some b) (positive : 0 < b.value.balance) :
    paymentIntents env s caller (.withdraw id embedded recipient) =
      [⟨env.registryAddress,recipient,b.value.balance,false⟩] := by
  simp [paymentIntents,found,Nat.ne_of_gt positive]

theorem slash_payments_exact (env : PaymentEnvironment) (s : RegistryMachine.State)
    (caller id : Nat) (a z : Staking.Vote) (sa sz : Hash) (b : Registry.Bond)
    (found : s.ledger.bonds id = some b) :
    paymentIntents env s caller (.slash id a z sa sz) =
      [⟨env.registryAddress,caller,Staking.fraction b.value.balance s.config.slashBountyBps,false⟩,
       ⟨env.registryAddress,env.slashSink,b.value.balance-Staking.fraction b.value.balance s.config.slashBountyBps,false⟩] := by
  simp [paymentIntents,found]

theorem forfeit_payment_exact (env : PaymentEnvironment) (s : RegistryMachine.State)
    (caller id embedded key incident validUntil : Nat) (b : Registry.Bond)
    (found : s.ledger.bonds id = some b) :
    paymentIntents env s caller (.forfeit id embedded key incident validUntil) =
      [⟨env.registryAddress,env.slashSink,Staking.forfeitPenalty b.value.balance s.config.forfeitBps,false⟩] := by
  simp [paymentIntents,found]

theorem deposit_payment_exact (env : PaymentEnvironment) (s : RegistryMachine.State)
    (caller id embedded amount key pop : Nat) :
    paymentIntents env s caller (.register key embedded amount pop) =
      [⟨caller,env.registryAddress,amount,true⟩] ∧
    paymentIntents env s caller (.topUp id embedded amount) =
      [⟨caller,env.registryAddress,amount,true⟩] := ⟨rfl,rfl⟩

/-- Standard outgoing transfers are available when their source has sufficient balance.
The lower bound also covers self-transfers without assuming distinct destinations. -/
theorem standard_outgoing_available (registryAddress : Nat) (s : TokenState) (p : Payment)
    (outgoing : p.pull = false) (funded : p.amount ≤ s.balances p.source) :
    ∃ t, standardTransfer registryAddress s p = some t ∧
      s.balances p.source-p.amount ≤ t.balances p.source := by
  unfold standardTransfer
  simp only [funded,outgoing,true_or,and_self,↓reduceIte]
  refine ⟨_,rfl,?_⟩
  dsimp only
  split
  · simp
  · simp

/-- Concrete standard-token availability suffices for both fixed-rate slash payouts.
This is a token balance condition, independent of registry authorization or evidence. -/
theorem standard_slash_transfers_available (registryAddress sink caller balance bountyBps : Nat)
    (token : TokenState) (rate : bountyBps ≤ 10000)
    (funded : balance ≤ token.balances registryAddress) :
    ∃ t, runTransfers (standardEnvironment registryAddress sink) token
      [⟨registryAddress,caller,Staking.fraction balance bountyBps,false⟩,
       ⟨registryAddress,sink,balance-Staking.fraction balance bountyBps,false⟩] = some t := by
  have bounded := Staking.fraction_bounded balance bountyBps rate
  obtain ⟨mid,hm,hleft⟩ := standard_outgoing_available registryAddress token
    ⟨registryAddress,caller,Staking.fraction balance bountyBps,false⟩ rfl
    (Nat.le_trans bounded funded)
  have enough : balance-Staking.fraction balance bountyBps ≤ mid.balances registryAddress := by
    dsimp only at hleft
    omega
  obtain ⟨last,hl,_⟩ := standard_outgoing_available registryAddress mid
    ⟨registryAddress,sink,balance-Staking.fraction balance bountyBps,false⟩ rfl enough
  exact ⟨last,by simp [runTransfers,standardEnvironment,hm,hl]⟩

/-- H2's liability bridge with the external token availability premise made explicit. -/
theorem evidence_stays_transaction_slashable {env : PaymentEnvironment}
    {first later : RegistryMachine.World} (trace : RegistryMachine.Trace first later)
    {id : Nat} {original current : Registry.Bond}
    (issued : id < first.registry.ledger.nextId)
    (found : first.registry.ledger.bonds id = some original)
    (initialized : first.inbox.initialized = true)
    {a b : Staking.Vote} {sa sb : Hash}
    (auth : RegistryMachine.Evidence first.registry first.inbox original.value.key a b sa sb)
    (present : later.registry.ledger.bonds id = some current)
    (live : current.value.released = false) (positive : 0 < current.value.balance)
    (free : later.inbox.entered = false)
    (rate : first.registry.config.slashBountyBps ≤ 10000)
    (token : TokenState) (caller : Nat)
    (available : ∃ token', runTransfers env token
      (paymentIntents env later.registry caller (.slash id a b sa sb)) = some token') :
    ∃ result, executeTransaction env ⟨later.registry,token⟩ later.inbox later.now caller
      (.slash id a b sa sb) = some result := by
  obtain ⟨registry,hr⟩ := RegistryMachine.evidence_stays_slashable trace issued found initialized
    auth present live positive free rate
  obtain ⟨token',ht⟩ := available
  exact ⟨_,principal_and_transfers_commit hr rfl ht⟩

end Etna.Design.Current.RegistryPayments
