import EtnaProofs.Accounting
import EtnaWitnesses.Regressions.Accounting

/-! These regressions catch discarded payout results, counting activation as a second
deposit, failed-call deposits, and principal resurrection when a released slot is reused. -/
namespace Etna.Design.Accounting.Tests


example {first last : ProtocolState.World} (zero : ReleasedZero first.registry)
    (run : ProtocolState.Trace first last) :
    ∃ f, Trace first last f ∧ held first.registry+f.deposits =
      held last.registry+f.withdrawals+f.bounty+f.sink :=
  protocol_trajectory_conservation zero run

example {s : RegistryHistory.State} (run : RegistryHistory.Trace RegistryHistory.empty s) :
    SlotGood s := slot_good_from_empty run

end Etna.Design.Accounting.Tests
