import EtnaModel.Deployment
import EtnaWitnesses.Regressions.SecondBatch

namespace Etna.Design.ReviewFixes
open Etna.Design

/-- Realistic §10 values: vp_unit 1e9 ≥ 867,361,738, s_min 1 TAIKO, n_max 3, U 100; stake 1 TAIKO. -/
def cfg : Deployment.Config := ⟨1000000000,1000000000000000000,3,100⟩
def registry : RegistryHistory.State :=
  (RegistryHistory.register SecondBatch.emptyRegistry 7 51 1000000000000000000 10).getD SecondBatch.emptyRegistry
def keyNine : RegistryHistory.State :=
  (RegistryHistory.register SecondBatch.emptyRegistry 9 51 1000000000000000000 10).getD SecondBatch.emptyRegistry
def zeroRecord : Committee.Record := ⟨0,12,[Staking.toEntry (registry.slots 0)]⟩
def inbox : State :=
  { SecondBatch.sourceInbox with
    epochLen := 3,genesisCutoff := 12,committeeZero := 12,
    configuration := cfg,committeeZeroRecord := zeroRecord,forcedDelay := 60,maxAnchorAge := 1200 }
def configHash (words : List Encoding.Word) : Hash :=
  if words = Deployment.words inbox cfg then 77 else 78
def world : ProtocolState.World :=
  { SecondBatch.initialWorld with
    inbox := inbox,registry := registry,adapters := ⟨configHash,fun _ => 12,SecondBatch.recoveryConfig⟩ }

def built := Deployment.build world cfg SecondBatch.archive SecondBatch.historicalRules

theorem configured_context_builds : built.isSome = true := by decide +kernel

theorem substituted_unit_rejected :
    (Deployment.build world { cfg with unit := 999999999 } SecondBatch.archive
      SecondBatch.historicalRules).isNone = true := by decide +kernel

theorem substituted_u_rejected :
    (Deployment.build world { cfg with unsettled := 101 } SecondBatch.archive
      SecondBatch.historicalRules).isNone = true := by decide +kernel

theorem substituted_genesis_record_rejected :
    (Deployment.build { world with adapters := ⟨configHash,fun _ => 13,SecondBatch.recoveryConfig⟩ } cfg SecondBatch.archive
      SecondBatch.historicalRules).isNone = true := by decide +kernel

theorem substituted_minimum_rejected :
    (Deployment.build world { cfg with minimum := 1000000000000000001 } SecondBatch.archive
      SecondBatch.historicalRules).isNone = true := by decide +kernel

theorem substituted_nmax_rejected :
    (Deployment.build world { cfg with nMax := 4 } SecondBatch.archive
      SecondBatch.historicalRules).isNone = true := by decide +kernel

def builtRules : BlockValidity.Rules := built.getD SecondBatch.historicalRules
instance : DecidablePred builtRules.signature := fun _ => inferInstanceAs (Decidable True)

theorem stored_fields_override_template :
    builtRules.consensus.epochLen = 3 ∧ builtRules.consensus.genesisCutoff = 12 ∧
    builtRules.consensus.unit = 1000000000 ∧ builtRules.consensus.minimum = 1000000000000000000 ∧
    builtRules.consensus.nMax = 3 ∧ builtRules.unsettled = 100 ∧ builtRules.committeeConfig = 77 ∧
    builtRules.maxAnchorAge = 1200 ∧ builtRules.forcedDelay = 60 := by decide +kernel

theorem configured_valid_batch : Settlement.BatchValid builtRules SecondBatch.parentHeader [SecondBatch.historicalBlock] [111] :=
  ⟨by decide +kernel,by decide +kernel⟩

theorem old_signatures_check_only_old_key : SecondBatch.verifyEvidence 7 SecondBatch.oldA 101 = true ∧
    SecondBatch.verifyEvidence 8 SecondBatch.oldA 101 = false := by decide +kernel

theorem old_signatures_rejected_after_slot_reuse :
    (RegistryHistory.edit SecondBatch.reused SecondBatch.settled 0 17
      (.slash SecondBatch.oldA SecondBatch.oldB 101 102)).isNone = true := by decide +kernel

theorem current_key_signatures_accepted_after_slot_reuse :
    ((RegistryHistory.edit SecondBatch.reused SecondBatch.settled 0 17
      (.slash SecondBatch.oldA SecondBatch.oldB 201 202)).map (fun s => (s.slots 0).stake)) = some 0 := by decide +kernel

def constant : ProtocolState.World := { world with adapters := ⟨fun _ => 77,fun _ => 12,SecondBatch.recoveryConfig⟩ }

theorem constant_hash_cannot_substitute_configuration :
    (Deployment.build constant { cfg with unit := 999999999 } SecondBatch.archive
      SecondBatch.historicalRules).isNone = true := by decide +kernel

/-- Replaces the reviewer's W1: under constant config and record hashes, the key-7 State
still rejects a key-9 genesis registry, whose recomputed committee 0 differs. -/
theorem constant_record_hash_binds_committee_zero :
    (Deployment.build constant cfg SecondBatch.archive SecondBatch.historicalRules).isSome = true ∧
    (Deployment.build { constant with registry := keyNine } cfg SecondBatch.archive
      SecondBatch.historicalRules).isNone = true ∧
    Deployment.genesis inbox registry cfg SecondBatch.archive ≠ Deployment.genesis inbox keyNine cfg SecondBatch.archive := by
  decide +kernel

/-- Replaces W3: slot-282 values come from the State, not the template, and §10 bounds hold. -/
theorem template_immutables_ignored :
    ((Deployment.build world cfg SecondBatch.archive
      { SecondBatch.historicalRules with maxAnchorAge := 0,forcedDelay := 0 }).map
        (fun r => (r.maxAnchorAge,r.forcedDelay))) = some (1200,60) := by decide +kernel

def withInbox (s : State) : ProtocolState.World := { world with inbox := s }

theorem initialization_constraints_enforced :
    (Deployment.build (withInbox { inbox with forcedDelay := 0 }) cfg SecondBatch.archive
      SecondBatch.historicalRules).isNone = true ∧
    (Deployment.build (withInbox { inbox with maxAnchorAge := 1151 }) cfg SecondBatch.archive
      SecondBatch.historicalRules).isNone = true ∧
    (Deployment.build (withInbox { inbox with epochLen := 2 }) cfg SecondBatch.archive
      SecondBatch.historicalRules).isNone = true ∧
    (Deployment.build (withInbox { inbox with gridK := 3 }) cfg SecondBatch.archive
      SecondBatch.historicalRules).isNone = true := by decide +kernel

/-- Below-floor vp_unit and s_min < vp_unit fail even with a self-consistent opening. -/
def lowUnit : Deployment.Config := { cfg with unit := 10,minimum := 10 }
def lowMinimum : Deployment.Config := { cfg with minimum := 999999999 }
def openedWorld (c : Deployment.Config) : ProtocolState.World :=
  { constant with inbox := { inbox with configuration := c } }

theorem unit_floor_and_minimum_enforced :
    (Deployment.build (openedWorld lowUnit) lowUnit SecondBatch.archive SecondBatch.historicalRules).isNone = true ∧
    (Deployment.build (openedWorld lowMinimum) lowMinimum SecondBatch.archive SecondBatch.historicalRules).isNone = true := by
  decide +kernel

/-- Replaces W5: recovery has no L/vp_unit/s_min/n_max parameters. The stored L gates it and
the stored configuration elects R's committee: raising stored s_min above the only stake
leaves the recovery committee empty, while the unchanged deployment elects key 7. -/
def recoverOn (s : State) : Option ProtocolState.World :=
  ProtocolState.recover { SecondBatch.initialWorld with inbox := s } SecondBatch.recoveryRequest
    SecondBatch.recoveryOrigin true true

/-- Recovery from c = 6: the new committee's target epoch is c / stored L. -/
def recoverAtSix (l : Nat) : Option ProtocolState.World :=
  ProtocolState.recover
    { SecondBatch.initialWorld with
      inbox := { SecondBatch.sourceInbox with epochLen := l,checkpoint := { FirstBatch.genesisRecord with height := 6 } } }
    ⟨0,6,[],[],0,limit256-1⟩ ⟨6,20,20⟩ true true

theorem recovery_reads_stored_deployment :
    (recoverOn { SecondBatch.sourceInbox with epochLen := 2 }).isNone = true ∧
    ((recoverOn SecondBatch.sourceInbox).map (fun w => w.schedule.current.members.map Committee.Entry.key)) = some [7] ∧
    ((recoverOn { SecondBatch.sourceInbox with configuration := ⟨10,101,3,3600⟩ }).map
      (fun w => w.schedule.current.members)) = some [] ∧
    ((recoverAtSix 3).map (fun w => w.schedule.current.targetEpoch)) = some 2 ∧
    ((recoverAtSix 6).map (fun w => w.schedule.current.targetEpoch)) = some 1 := by
  decide +kernel

end Etna.Design.ReviewFixes
