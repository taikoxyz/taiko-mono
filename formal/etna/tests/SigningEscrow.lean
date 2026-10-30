import EtnaWitnesses.Regressions.SigningEscrow

open Etna.Design

-- RED target: arbitrary interleavings cannot invent a confirmation in the future.
example {w t : ProtocolState.World} (run : ProtocolState.Trace w t)
    (initial : ∀ id c, (w.registry.slots id).confirmedAt = some c → c ≤ w.l1Block) :
    ∀ id c, (t.registry.slots id).confirmedAt = some c → c ≤ t.l1Block := by
  exact SigningEscrow.trace_clocked run initial

-- RED target: covered confirmations survive arbitrary interleavings once the
-- explicit landing/rollback snapshot discipline is supplied.
example {w t : ProtocolState.World} (run : SigningEscrow.SnapshotTrace w t)
    (initial : SigningEscrow.Covered w) : SigningEscrow.Covered t := by
  exact SigningEscrow.trace_covered run initial

-- RED target: lifetime exclusion must survive withdrawal, reuse and recovery,
-- without assuming a current bond still contains the old key.
example {w t : ProtocolState.World} (run : ProtocolState.Trace w t)
    {key cutoff : Nat} (nonzero : key ≠ 0) (used : key ∈ w.registry.usedKeys)
    (excluded : SigningEscrow.Excluded key cutoff w.registry) :
    SigningEscrow.Excluded key cutoff t.registry := by
  exact SigningEscrow.trace_excluded run nonzero used excluded

-- RED target: even switching again, reopening sessions and signing in other
-- generations can never revive a retired generation.
example {s t : Signer.State} (run : SigningEscrow.SignerTrace s t)
    (r : Signer.Request) (signature : Hash) (persisted : Bool)
    (retired : r.generation ∈ s.retired) : Signer.sign t r signature persisted = none := by
  exact SigningEscrow.retired_generation_never_revives run r signature persisted retired

-- RED target: fresh registrations never duplicate a lifetime key, even after
-- release/reuse and recovery interleavings; establish it from empty, not Core.
example {w t : ProtocolState.World} (run : ProtocolState.Trace w t)
    (empty : w.registry = RegistryHistory.empty) : SigningEscrow.KeysWellFormed t.registry := by
  exact SigningEscrow.empty_trace_keys_well_formed run empty

-- RED target: cover even cutoffs between effective exit and eventual confirmation.
example {w t : ProtocolState.World} (run : ProtocolState.Trace w t)
    (core : ProtocolState.Core w) (empty : w.registry = RegistryHistory.empty) :
    SigningEscrow.ExitVisible t.registry := by
  exact SigningEscrow.empty_trace_exit_visible run core empty


-- These assertions exercise the two different limits: ordinary historical
-- verification after withdrawal, and future-height fixed power after punishment.
example :
    ProtocolState.Trace NonVacuity.world0 HistoricalEscrow.worldE ∧
    BlockValidity.Chain HistoricalEscrow.rules NonVacuity.genesisHeader HistoricalEscrow.blocks ∧
    (HistoricalEscrow.worldE.registry.slots 0).balance = 0 ∧
    Consensus.CommitValid HistoricalEscrow.historicalRules.consensus HistoricalEscrow.historicalRules.signature
      1 0 101 [NonVacuity.vote 0 1 101] := by
  refine ⟨HistoricalEscrow.ordinary_exit_trace,HistoricalEscrow.ordinary_rotation_chain,by decide +kernel,by decide +kernel⟩

example : (SigningEscrowRegression.afterBurn.registry.slots 2).balance = 0 ∧
    NonVacuity.member9 ∈ (Consensus.activeAt SigningEscrowRegression.rules.consensus 1).members := by
  rcases SigningEscrowRegression.current_voting_power_survives_full_slash with
    ⟨_,_,_,_,_,_,_,_,member,_,_,_,empty,_,_,_⟩
  exact ⟨empty,member⟩

example : Signer.sign (Signer.openSession SigningEscrowRegression.signer1 1 true true)
    ⟨FirstBatch.deployment,0,true,⟨3,0,2⟩,101⟩ 55 true = none := by
  decide +kernel
