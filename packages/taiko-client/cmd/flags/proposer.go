package flags

import (
	"github.com/urfave/cli/v2"
)

// Required flags used by proposer.
var (
	TaikoWrapperAddress = &cli.StringFlag{
		Name:     "taikoWrapper",
		Usage:    "TaikoWrapper contract `address`",
		Required: true,
		Category: proposerCategory,
		EnvVars:  []string{"TAIKO_WRAPPER"},
	}
	ForcedInclusionStoreAddress = &cli.StringFlag{
		Name:     "forcedInclusionStore",
		Usage:    "ForcedInclusionStore contract `address`",
		Required: true,
		EnvVars:  []string{"FORCED_INCLUSION_STORE"},
	}
	L1ProposerPrivKey = &cli.StringFlag{
		Name:     "l1.proposerPrivKey",
		Usage:    "Private key of the L1 proposer, who will send TaikoL1.proposeBlock transactions",
		Required: true,
		Category: proposerCategory,
		EnvVars:  []string{"L1_PROPOSER_PRIV_KEY"},
	}
	L2SuggestedFeeRecipient = &cli.StringFlag{
		Name:     "l2.suggestedFeeRecipient",
		Usage:    "Address of the proposed block's suggested L2 fee recipient",
		Required: true,
		Category: proposerCategory,
		EnvVars:  []string{"L2_SUGGESTED_FEE_RECIPIENT"},
	}
)

// Optional flags used by proposer.
var (
	// Proposing epoch related.
	ProposeInterval = &cli.DurationFlag{
		Name:     "epoch.interval",
		Usage:    "Time interval to propose L2 pending transactions",
		Category: proposerCategory,
		Value:    0,
		EnvVars:  []string{"EPOCH_INTERVAL"},
	}
	MinGasUsed = &cli.Uint64Flag{
		Name:     "epoch.minGasUsed",
		Usage:    "Minimum gas used for a transactions list to propose",
		Category: proposerCategory,
		Value:    0,
		EnvVars:  []string{"EPOCH_MIN_GAS_USED"},
	}
	MinTxListBytes = &cli.Uint64Flag{
		Name:     "epoch.minTxListBytes",
		Usage:    "Minimum bytes for a transactions list to propose",
		Category: proposerCategory,
		Value:    0,
		EnvVars:  []string{"EPOCH_MIN_TX_LIST_BYTES"},
	}
	MinTip = &cli.Float64Flag{
		Name:     "epoch.minTip",
		Usage:    "Minimum tip (in GWei) for a transaction to propose",
		Category: proposerCategory,
		Value:    0,
		EnvVars:  []string{"EPOCH_MIN_TIP"},
	}
	MinProposingInternal = &cli.DurationFlag{
		Name:     "epoch.minProposingInterval",
		Usage:    "Minimum time interval to force proposing a block, even if there are no transaction in mempool",
		Category: proposerCategory,
		Value:    0,
		EnvVars:  []string{"EPOCH_MIN_PROPOSING_INTERNAL"},
	}
	AllowZeroInterval = &cli.Uint64Flag{
		Name:     "epoch.allowZeroInterval",
		Usage:    "If set, after this many epochs, proposer will allow propose zero tip transactions once",
		Category: proposerCategory,
		Value:    0,
		EnvVars:  []string{"EPOCH_ALLOW_ZERO_INTERVAL"},
	}
	// Transactions pool related.
	TxPoolLocals = &cli.StringSliceFlag{
		Name:     "txPool.locals",
		Usage:    "Comma separated accounts to treat as locals (priority inclusion)",
		Category: proposerCategory,
		EnvVars:  []string{"TX_POOL_LOCALS"},
	}
	TxPoolLocalsOnly = &cli.BoolFlag{
		Name:     "txPool.localsOnly",
		Usage:    "If set to true, proposer will only propose transactions of local accounts",
		Value:    false,
		Category: proposerCategory,
		EnvVars:  []string{"TX_POOL_LOCALS_ONLY"},
	}
	MaxProposedTxListsPerEpoch = &cli.Uint64Flag{
		Name:     "txPool.maxTxListsPerEpoch",
		Usage:    "Maximum number of transaction lists which will be proposed inside one proposing epoch",
		Value:    1,
		Category: proposerCategory,
		EnvVars:  []string{"TX_POOL_MAX_TX_LISTS_PER_EPOCH"},
	}
	// Transaction related.
	BlobAllowed = &cli.BoolFlag{
		Name:    "l1.blobAllowed",
		Usage:   "Send EIP-4844 blob transactions when proposing blocks",
		Value:   false,
		EnvVars: []string{"L1_BLOB_ALLOWED"},
	}
	FallbackToCalldata = &cli.BoolFlag{
		Name:     "l1.fallbackToCalldata",
		Usage:    "If set to true, proposer will use calldata as DA when blob fee is more expensive than using calldata",
		Value:    false,
		Category: proposerCategory,
		EnvVars:  []string{"L1_FALLBACK_TO_CALLDATA"},
	}
	RevertProtectionEnabled = &cli.BoolFlag{
		Name: "l1.revertProtection",
		Usage: "Enable revert protection within your ProverSet contract, " +
			"this is effective only if your PBS service supports revert protection",
		Value:    false,
		Category: proposerCategory,
		EnvVars:  []string{"L1_REVERT_PROTECTION"},
	}
)

// ProposerFlags All proposer flags.
var ProposerFlags = MergeFlags(CommonFlags, []cli.Flag{
	L2HTTPEndpoint,
	L2AuthEndpoint,
	JWTSecret,
	TaikoTokenAddress,
	TaikoWrapperAddress,
	ForcedInclusionStoreAddress,
	L1ProposerPrivKey,
	L2SuggestedFeeRecipient,
	ProposeInterval,
	TxPoolLocals,
	TxPoolLocalsOnly,
	MinGasUsed,
	MinTxListBytes,
	MinTip,
	MinProposingInternal,
	AllowZeroInterval,
	MaxProposedTxListsPerEpoch,
	BlobAllowed,
	FallbackToCalldata,
	RevertProtectionEnabled,
}, TxmgrFlags)
