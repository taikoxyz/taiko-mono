import EtnaProofs.SigningPrefix
import EtnaWitnesses.Counterexamples.HistoricalEscrow

open Etna.Design

-- Selection order is derived from a successful build, with no cutoff-order premise.
example {s : State} {registry : RegistryHistory.State}
    {cfg : HistoricalContext.Parameters} {archive : List Nat} {ctx : Consensus.Context}
    {checkpoint request : Nat}
    (built : HistoricalContext.build s registry cfg archive = some ctx)
    (order : checkpoint ≤ request) :
    (Consensus.activeAt ctx checkpoint).cutoff ≤ (Consensus.activeAt ctx request).cutoff := by
  exact SigningPrefix.built_active_cutoff_monotone built order

-- The accepted-batch endpoint, rather than a freely supplied snapshot predicate,
-- provides the lower endpoint for a subsequent request on the same built context.
example {s t : State} {i : LandInput} {leaves : List Leaf} {e : LandingEnv}
    {r : BlockValidity.Rules} {p : BlockValidity.Header} {bs : List BlockValidity.Block}
    {blobs : List Hash} {registry : RegistryHistory.State}
    {cfg : HistoricalContext.Parameters} {archive : List Nat} {h : Nat}
    (accepted : land s i leaves e = some t) (valid : Settlement.BatchValid r p bs blobs)
    (binding : e.certificate = Settlement.statement r p bs blobs)
    (built : HistoricalContext.build s registry cfg archive = some r.consensus)
    (later : i.lastHeight ≤ h) :
    t.snapshot ≤ (Consensus.activeAt r.consensus h).cutoff := by
  exact SigningPrefix.accepted_land_cutoff_bound accepted valid binding built later

-- An actual prior schedule may still contain a pending update. Announcing the
-- new record agrees with activeAt at the delayed activation when its old authority fits.
example (ctx : Consensus.Context) (t : Nat) (previous : Committee.Schedule)
    (positive : 0 < t) (length : 3 ≤ ctx.epochLen)
    (occurred : ctx.originHeight < Consensus.switchHeight ctx t)
    (governing : Committee.authority previous (Consensus.switchHeight ctx t) =
      Consensus.activeAt ctx (Consensus.switchHeight ctx t)) :
    Committee.authority
      (Committee.announce previous (Consensus.switchHeight ctx t) (Consensus.normal ctx t))
      (Consensus.switchHeight ctx t+2) =
      Consensus.activeAt ctx (Consensus.switchHeight ctx t+2) := by
  exact (SigningPrefix.switch_schedule_agrees ctx t previous positive length occurred governing).2.2

-- Genesis uses its own cutoff through the ordinary switch and its following block.
-- The normal cutoff starts only at S(1)+2 = 11.
example (s : State) (registry : RegistryHistory.State)
    (cfg : HistoricalContext.Parameters) (archive : List Nat)
    (genesis : s.generation = 0) (origin : s.origin.height = 0) (length : cfg.epochLen = 10) :
    (Consensus.activeAt (HistoricalContext.derive s registry cfg archive) 9).cutoff = cfg.genesisCutoff ∧
    (Consensus.activeAt (HistoricalContext.derive s registry cfg archive) 10).cutoff = cfg.genesisCutoff ∧
    (Consensus.activeAt (HistoricalContext.derive s registry cfg archive) 11).cutoff =
      max (HistoricalContext.anchorAt archive 8) s.origin.l1Block := by
  simp [HistoricalContext.derive,Consensus.activeAt,Consensus.epoch,Consensus.switchHeight,
    Consensus.initial,Consensus.normal,Consensus.selected,genesis,origin,length]

-- A recovery at height 5 occurs in the middle of the epoch. Its initial cutoff R
-- remains active at heights 9 and 10, and the actual later switch takes effect at 11.
example (s : State) (registry : RegistryHistory.State)
    (cfg : HistoricalContext.Parameters) (archive : List Nat)
    (recovery : s.generation = 2) (origin : s.origin.height = 5) (length : cfg.epochLen = 10) :
    (Consensus.activeAt (HistoricalContext.derive s registry cfg archive) 9).cutoff = s.origin.l1Block ∧
    (Consensus.activeAt (HistoricalContext.derive s registry cfg archive) 10).cutoff = s.origin.l1Block ∧
    (Consensus.activeAt (HistoricalContext.derive s registry cfg archive) 11).cutoff =
      max (HistoricalContext.anchorAt archive 8) s.origin.l1Block := by
  simp [HistoricalContext.derive,Consensus.activeAt,Consensus.epoch,Consensus.switchHeight,
    Consensus.initial,Consensus.normal,Consensus.selected,recovery,origin,length]

-- A switch equal to the recovery origin did not occur within the new generation.
-- Its pending old-generation update is cancelled, even at the nominal activation.
example (s : State) (registry : RegistryHistory.State)
    (cfg : HistoricalContext.Parameters) (archive : List Nat)
    (recovery : s.generation = 2) (origin : s.origin.height = 9) (length : cfg.epochLen = 10) :
    (Consensus.activeAt (HistoricalContext.derive s registry cfg archive) 11).cutoff = s.origin.l1Block ∧
    (Consensus.activeAt (HistoricalContext.derive s registry cfg archive) 20).cutoff = s.origin.l1Block ∧
    (Consensus.activeAt (HistoricalContext.derive s registry cfg archive) 21).cutoff =
      max (HistoricalContext.anchorAt archive 18) s.origin.l1Block := by
  simp [HistoricalContext.derive,Consensus.activeAt,Consensus.epoch,Consensus.switchHeight,
    Consensus.initial,Consensus.normal,Consensus.selected,recovery,origin,length]

-- The concrete ordinary exit/rotation fixture is a genuine accepted chain, not an
-- arbitrary stored-snapshot assertion. Its snapshot 24 bounds the next selection.
example : HistoricalEscrow.worldC.inbox.snapshot ≤
    (Consensus.activeAt HistoricalEscrow.rules.consensus 13).cutoff := by
  have built : HistoricalContext.build HistoricalEscrow.worldB.inbox HistoricalEscrow.worldB.registry
      (Deployment.parameters HistoricalEscrow.worldB.inbox HistoricalEscrow.worldB.inbox.configuration)
      HistoricalEscrow.archive = some HistoricalEscrow.rules.consensus := by
    unfold HistoricalContext.build
    rw [ite_eq_left (by decide +kernel)]
    rfl
  exact SigningPrefix.accepted_land_cutoff_bound
    (show land HistoricalEscrow.worldB.inbox HistoricalEscrow.statement.input
      HistoricalEscrow.leaves HistoricalEscrow.landingEnv = some HistoricalEscrow.worldC.inbox by decide +kernel)
    ⟨HistoricalEscrow.ordinary_rotation_chain,by decide +kernel⟩ rfl built (by decide +kernel)

open Etna.Design in
example (s : State) (oldRegistry newRegistry : RegistryHistory.State)
    (cfg : HistoricalContext.Parameters) (archive more : List Nat) (h : Nat) (covered : h < archive.length) :
    (Consensus.activeAt (HistoricalContext.derive s oldRegistry cfg archive) h).cutoff =
      (Consensus.activeAt (HistoricalContext.derive s newRegistry cfg (archive ++ more)) h).cutoff :=
  SigningPrefix.extended_archive_cutoff s oldRegistry newRegistry cfg archive more h covered
