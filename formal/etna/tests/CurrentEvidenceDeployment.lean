import EtnaModel.CurrentRegistry
open Etna.Design Etna.Design.Current
private def ledger : Registry.State := { nextId := 0,bonds := fun _ => none,slots := fun _ => none,keyId := fun _ => none,activationDelay := 1 }
-- Physical checks do not compare an external evidence window with the immutable delay.
example : RegistryMachine.Config.valid { withdrawalDelay := 1 } ledger = true := by decide +kernel
-- That physically permitted configuration does not satisfy a two-block evidence policy.
example : ¬ (2 ≤ (1 : Nat)) := by decide +kernel
