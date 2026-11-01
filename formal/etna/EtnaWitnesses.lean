import EtnaWitnesses.Regressions.CanonicalHistory
import EtnaWitnesses.Regressions.Capital
import EtnaWitnesses.Regressions.StakingAlignment
import EtnaProofs
import EtnaWitnesses.Regressions.Examples
import EtnaWitnesses.Regressions.FirstBatch
import EtnaWitnesses.Regressions.SecondBatch
import EtnaWitnesses.Regressions.ThirdBatch
import EtnaWitnesses.Regressions.FourthBatch
import EtnaWitnesses.Regressions.FifthBatch
import EtnaWitnesses.Headline.FundSafetyRun
import EtnaWitnesses.NonVacuity.Premises
import EtnaWitnesses.Counterexamples.NoVerifierSoundness
import EtnaWitnesses.Counterexamples.UntrustedRollback
import EtnaWitnesses.Counterexamples.RecoveryCapture
import EtnaWitnesses.Counterexamples.ForcedPoisonResubmit
import EtnaWitnesses.Counterexamples.AnchorTail
import EtnaWitnesses.Counterexamples.StaleDaoAuthorization
import EtnaWitnesses.Counterexamples.HistoricalEscrow
import EtnaWitnesses.Regressions.SigningBridge
import EtnaWitnesses.Regressions.NormalSigning
import EtnaWitnesses.Counterexamples.SigningViewLag
import EtnaWitnesses.Regressions.Accounting
import EtnaWitnesses.Regressions.SigningEscrow
import EtnaWitnesses.Regressions.Trajectory
import EtnaWitnesses.Regressions.TrustedSnapshot
import EtnaWitnesses.Regressions.OrdinaryTrace
import EtnaWitnesses.Regressions.AnchorHonesty
import EtnaWitnesses.Regressions.TrustedRollback
import EtnaWitnesses.Regressions.SlashedExclusion

/-! Etna witnesses: kernel-checked regression traces over concrete Worlds, the non-vacuity
witness of the headline premises (`NonVacuity`) and scope counterexamples (`Counterexamples`):
runs, or concrete instances, that show what a premise or an open design issue leaves outside
H1–H3. -/
