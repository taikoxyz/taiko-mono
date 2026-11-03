import EtnaProofs.Current
import EtnaProofs.UpgradeBoundary
import EtnaProofs.Reconstruction
import EtnaProofs.ActualQueue
import EtnaProofs.Anchorless
import EtnaProofs.Locking
import EtnaProofs.TrustState
import EtnaProofs.CanonicalHistory
import EtnaProofs.Capital
import EtnaStatements
import EtnaProofs.Common
import EtnaProofs.Landing
import EtnaProofs.Encoding
import EtnaProofs.Budget
import EtnaProofs.Committee
import EtnaProofs.Fees
import EtnaProofs.Keys
import EtnaProofs.Staking
import EtnaProofs.Forced
import EtnaProofs.Recovery
import EtnaProofs.Signer
import EtnaProofs.Consensus
import EtnaProofs.BlockValidity
import EtnaProofs.Settlement
import EtnaProofs.RegistryHistory
import EtnaProofs.HistoricalContext
import EtnaProofs.ProtocolState
import EtnaProofs.Deployment
import EtnaProofs.Accountability
import EtnaProofs.Accounting
import EtnaProofs.SigningEscrow
import EtnaProofs.SigningPrefix
import EtnaProofs.SigningBridge
import EtnaProofs.BackPressure
import EtnaProofs.Permanence
import EtnaProofs.RoundSafety
import EtnaProofs.TrustedSnapshot
import EtnaProofs.TrustedRollback
import EtnaProofs.SlashedExclusion
import EtnaProofs.NormalSigning
import EtnaProofs.Lifecycle
import EtnaProofs.Contracts
import EtnaProofs.Derived
import EtnaProofs.Headline.AccountableFinality
import EtnaProofs.Headline.ChainOfCustody
import EtnaProofs.Headline.FundSafety
import EtnaProofs.Headline.ForcedInclusion
import EtnaProofs.Headline.AnchoredQueue
import EtnaProofs.Headline.Claims

/-! Etna proofs: the theorems about `EtnaModel`, including the pins in `EtnaProofs.Contracts`. -/

/-! Version scope: only Etna.Design.Current models the selected current rules. Other
declarations retain the archived pre-2026-11-03 semantics; their headline theorems are
not claims about the whole latest protocol. See README.md. -/
