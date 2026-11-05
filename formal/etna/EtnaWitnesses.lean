import EtnaWitnesses.NonVacuity.CurrentAgreement
import EtnaWitnesses.NonVacuity.CurrentRisk
import EtnaWitnesses.NonVacuity.CurrentSwitch
import EtnaWitnesses.NonVacuity.Current
import EtnaModel.SigningBridge
import EtnaModel.RegistryHistory
import EtnaModel.Consensus
import EtnaModel.BlockValidity
import EtnaModel.Signer
import EtnaModel.Common
import EtnaModel.Landing
import EtnaModel.Staking
import EtnaModel.Forced
import EtnaProofs.Landing
import EtnaProofs.Staking
import EtnaProofs.Forced
import EtnaProofs.Consensus
import EtnaModel.Encoding
import EtnaProofs.RegistryHistory
import EtnaModel
import EtnaStatements
import EtnaProofs.Headline.AccountableFinality
import EtnaProofs.ActualQueue
import EtnaProofs.Locking
import EtnaModel.Committee
import EtnaProofs

/-! Etna witnesses: kernel-checked regression traces over concrete Worlds, the non-vacuity
witness of the headline premises (`NonVacuity`) and scope counterexamples (`Counterexamples`):
runs, or concrete instances, that show what a premise or an open design issue leaves outside
H1–H3. -/
