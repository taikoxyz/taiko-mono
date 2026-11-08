import EtnaWitnesses.NonVacuity.CurrentAgreement
import EtnaWitnesses.NonVacuity.CurrentRisk
import EtnaWitnesses.NonVacuity.CurrentSwitch
import EtnaWitnesses.NonVacuity.Current
import EtnaWitnesses.NonVacuity.CurrentRecovery
import EtnaWitnesses.Traps.RollbackGrid

/-! Etna witnesses: kernel-checked joint-premise realizations (`NonVacuity`): concrete
environments in which all fifteen premises hold together and the headline conclusions are
exercised nonvacuously. `NonVacuity.CurrentRecovery` is one environment that satisfies the
fifteen and H4's premises together, with a reachable world satisfying `LiveAt`. `Traps` holds
reachable states that a liveness hypothesis must exclude, in environments that satisfy no
premise record. -/
