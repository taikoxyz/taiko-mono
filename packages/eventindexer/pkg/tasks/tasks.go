package tasks

var (
	TotalTransactions               = "total-transactions"
	TransactionsPerDay              = "transactions-per-day"
	TotalAccounts                   = "total-accounts"
	AccountsPerDay                  = "accounts-per-day"
	UniqueProposersPerDay           = "unique-proposers-per-day"
	TotalUniqueProposers            = "total-proposers"
	UniqueProversPerDay             = "unique-provers-per-day"
	TotalUniqueProvers              = "total-provers"
	TotalContractDeployments        = "total-contract-deployments"
	ContractDeploymentsPerDay       = "contract-deployments-per-day"
	TransitionProvedTxPerDay        = "transition-proved-tx-per-day"
	TotalTransitionProvedTx         = "total-transition-proved-tx"
	TransitionContestedTxPerDay     = "transition-contested-tx-per-day"
	TotalTransitionContestedTx      = "total-transition-contested-tx"
	ProposeBlockTxPerDay            = "propose-block-tx-per-day"
	TotalProposeBlockTx             = "total-propose-block-tx"
	BridgeMessagesSentPerDay        = "bridge-messages-sent-per-day"
	TotalBridgeMessagesSent         = "total-bridge-messages-sent"
	TotalProofRewards               = "total-proof-rewards"
	ProofRewardsPerDay              = "proof-rewards-per-day"
	TransitionProvedByTierPerDay    = "transition-proved-by-tier-per-day"
	TransitionContestedByTierPerDay = "transition-contested-by-tier-per-day"
	TotalTransitionProvedByTier     = "total-transition-proved-by-tier"
	TotalTransitionContestedByTier  = "total-transition-contested-by-tier"
)

var Tasks = []string{
	TotalTransactions,
	TransactionsPerDay,
	TotalAccounts,
	AccountsPerDay,
	UniqueProposersPerDay,
	TotalUniqueProposers,
	UniqueProversPerDay,
	TotalUniqueProvers,
	TotalContractDeployments,
	ContractDeploymentsPerDay,
	TransitionProvedTxPerDay,
	TotalTransitionProvedTx,
	TransitionContestedTxPerDay,
	TotalTransitionContestedTx,
	ProposeBlockTxPerDay,
	TotalProposeBlockTx,
	BridgeMessagesSentPerDay,
	TotalBridgeMessagesSent,
	TotalProofRewards,
	ProofRewardsPerDay,
	TotalTransitionProvedByTier,
	TotalTransitionContestedByTier,
	TransitionProvedByTierPerDay,
	TransitionContestedByTierPerDay,
}
