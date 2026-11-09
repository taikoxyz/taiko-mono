import EtnaWitnesses.NonVacuity.CurrentAgreement
import EtnaWitnesses.NonVacuity.CurrentRisk
import EtnaWitnesses.NonVacuity.CurrentSwitch
import EtnaWitnesses.NonVacuity.Current
import EtnaWitnesses.NonVacuity.CurrentRecovery
import EtnaWitnesses.NonVacuity.CurrentRecoverySwitch
import EtnaWitnesses.Traps.RollbackGrid

/-! Etna witnesses: kernel-checked joint-premise realizations (`NonVacuity`): concrete
environments in which all fifteen premises hold together and the headline conclusions are
exercised nonvacuously. `NonVacuity.CurrentRecovery` is one environment that satisfies the
fifteen and H4's premises together, with a reachable world satisfying `LiveAt` from which H4's
proof reaches an accepted landing; `NonVacuity.CurrentRecoverySwitch` is the same for a switching
network, whose path proves the Unzen lane and passes the first-landing fence. `Traps` holds
reachable states that only a particular recovery leaves, and that way out, in environments that
satisfy no premise record. -/
