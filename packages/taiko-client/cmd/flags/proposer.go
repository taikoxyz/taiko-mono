package flags

import (
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-client/internal/version"
)

// Required flags used by proposer.
var (
	L1ProposerPrivKey = &cli.StringFlag{
		Name:     "l1.proposerPrivKey",
		Usage:    "Private key of the L1 proposer, who will send TaikoL1.proposeBlock transactions",
		Required: true,
		Category: proposerCategory,
	}
	ProverEndpoints = &cli.StringFlag{
		Name:     "proverEndpoints",
		Usage:    "Comma-delineated list of prover endpoints proposer should query when attempting to propose a block",
		Required: true,
		Category: proposerCategory,
	}
	L2SuggestedFeeRecipient = &cli.StringFlag{
		Name:     "l2.suggestedFeeRecipient",
		Usage:    "Address of the proposed block's suggested L2 fee recipient",
		Required: true,
		Category: proposerCategory,
	}
	ProposerAssignmentHookAddress = &cli.StringFlag{
		Name:     "assignmentHookAddress",
		Usage:    "Address of the AssignmentHook contract",
		Required: true,
		Category: proposerCategory,
	}
)

// Optional flags used by proposer.
var (
	// Tier fee related.
	OptimisticTierFee = &cli.Uint64Flag{
		Name:     "tierFee.optimistic",
		Usage:    "Initial tier fee (in wei) paid to prover to generate an optimistic proofs",
		Category: proposerCategory,
	}
	SgxTierFee = &cli.Uint64Flag{
		Name:     "tierFee.sgx",
		Usage:    "Initial tier fee (in wei) paid to prover to generate a SGX proofs",
		Category: proposerCategory,
	}
	TierFeePriceBump = &cli.Uint64Flag{
		Name:     "tierFee.pricebump",
		Usage:    "Price bump percentage when no prover wants to accept the block at initial fee",
		Value:    10,
		Category: proposerCategory,
	}
	MaxTierFeePriceBumps = &cli.Uint64Flag{
		Name:     "tierFee.maxPriceBumps",
		Usage:    "If nobody accepts block at initial tier fee, how many iterations to increase tier fee before giving up",
		Category: proposerCategory,
		Value:    3,
	}
	// Proposing epoch related.
	ProposeInterval = &cli.DurationFlag{
		Name:     "epoch.interval",
		Usage:    "Time interval to propose L2 pending transactions",
		Category: proposerCategory,
		Value:    0,
	}
	ProposeEmptyBlocksInterval = &cli.DurationFlag{
		Name:     "epoch.emptyBlockInterval",
		Usage:    "Time interval to propose empty blocks",
		Category: proposerCategory,
		Value:    0,
	}
	// Proposing metadata related.
	ExtraData = &cli.StringFlag{
		Name:     "extraData",
		Usage:    "Block extra data set by the proposer (default = client version)",
		Value:    version.CommitVersion(),
		Category: proposerCategory,
	}
	// Transactions pool related.
	TxPoolLocals = &cli.StringSliceFlag{
		Name:     "txpool.locals",
		Usage:    "Comma separated accounts to treat as locals (priority inclusion)",
		Category: proposerCategory,
	}
	TxPoolLocalsOnly = &cli.BoolFlag{
		Name:     "txpool.localsOnly",
		Usage:    "If set to true, proposer will only propose transactions of local accounts",
		Value:    false,
		Category: proposerCategory,
	}
	MaxProposedTxListsPerEpoch = &cli.Uint64Flag{
		Name:     "txpool.maxTxListsPerEpoch",
		Usage:    "Maximum number of transaction lists which will be proposed inside one proposing epoch",
		Value:    1,
		Category: proposerCategory,
	}
	// Transaction related.
	ProposeBlockTxGasLimit = &cli.Uint64Flag{
		Name:     "tx.gasLimit",
		Usage:    "Gas limit will be used for TaikoL1.proposeBlock transactions",
		Category: proposerCategory,
	}
	ProposeBlockTxReplacementMultiplier = &cli.Uint64Flag{
		Name:     "tx.replacementMultiplier",
		Value:    2,
		Usage:    "Gas tip multiplier when replacing a TaikoL1.proposeBlock transaction with same nonce",
		Category: proposerCategory,
	}
	ProposeBlockTxGasTipCap = &cli.Uint64Flag{
		Name:     "tx.gasTipCap",
		Usage:    "Gas tip cap (in wei) for a TaikoL1.proposeBlock transaction when doing the transaction replacement",
		Category: proposerCategory,
	}
	ProposeBlockIncludeParentMetaHash = &cli.BoolFlag{
		Name:     "includeParentMetaHash",
		Usage:    "Include parent meta hash when proposing block",
		Value:    false,
		Category: proposerCategory,
	}
	BlobAllowed = &cli.BoolFlag{
		Name:  "l1.blobAllowed",
		Usage: "Send EIP-4844 blob transactions when proposing blocks",
		Value: false,
	}
	L1BlockBuilderTip = &cli.Uint64Flag{
		Name:     "l1.blockBuilderTip",
		Usage:    "Amount you wish to tip the L1 block builder",
		Value:    0,
		Category: proposerCategory,
	}
)

// ProposerFlags All proposer flags.
var ProposerFlags = MergeFlags(CommonFlags, []cli.Flag{
	L2HTTPEndpoint,
	TaikoTokenAddress,
	L1ProposerPrivKey,
	L2SuggestedFeeRecipient,
	ProposeInterval,
	TxPoolLocals,
	TxPoolLocalsOnly,
	ExtraData,
	ProposeEmptyBlocksInterval,
	MaxProposedTxListsPerEpoch,
	ProposeBlockTxGasLimit,
	ProposeBlockTxReplacementMultiplier,
	ProposeBlockTxGasTipCap,
	ProverEndpoints,
	OptimisticTierFee,
	SgxTierFee,
	TierFeePriceBump,
	MaxTierFeePriceBumps,
	ProposeBlockIncludeParentMetaHash,
	ProposerAssignmentHookAddress,
	BlobAllowed,
	L1BlockBuilderTip,
})
