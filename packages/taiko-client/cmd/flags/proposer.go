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
		Usage:    "Private key of the L1 proposer, who will send TaikoInbox.proposeBatch transactions",
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
	BridgeAddress = &cli.StringFlag{
		Name:     "bridge",
		Usage:    "Bridge contract `address`",
		Required: true,
		Category: proposerCategory,
		EnvVars:  []string{"BRIDGE"},
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
	MinTip = &cli.Float64Flag{
		Name:     "epoch.minTip",
		Usage:    "Minimum tip (in GWei) for a transaction to propose",
		Category: proposerCategory,
		Value:    0,
		EnvVars:  []string{"EPOCH_MIN_TIP"},
	}
	MinProposingInterval = &cli.DurationFlag{
		Name: "epoch.minProposingInterval",
		Usage: "Minimum time interval to force proposing a block, even if there are no transactions in mempool " +
			"(set to 0 to disable empty block creation entirely)",
		Category: proposerCategory,
		Value:    0,
		EnvVars:  []string{"EPOCH_MIN_PROPOSING_INTERVAL"},
	}
	AllowZeroTipInterval = &cli.Uint64Flag{
		Name:     "epoch.allowZeroTipInterval",
		Usage:    "If set, after this many epochs, proposer will be allowed to propose zero tip transactions once",
		Category: proposerCategory,
		Value:    0,
		EnvVars:  []string{"EPOCH_ALLOW_ZERO_TIP_INTERVAL"},
	}
	MaxTxListsPerEpoch = &cli.Uint64Flag{
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
	CheckProfitability = &cli.BoolFlag{
		Name:     "checkProfitability",
		Usage:    "Check profitability of transactions before proposing",
		Value:    false,
		Category: proposerCategory,
		EnvVars:  []string{"CHECK_PROFITABILITY"},
	}
	ForceProposingDelay = &cli.DurationFlag{
		Name: "signal.forceProposingDelay",
		Usage: "Time delay after SignalSent event to force propose a block even if mempool is empty " +
			"(set to 0 to disable this feature)",
		Category: proposerCategory,
		Value:    0,
		EnvVars:  []string{"SIGNAL_FORCE_PROPOSING_DELAY"},
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
	BridgeAddress,
	ProposeInterval,
	MinTip,
	MinProposingInterval,
	AllowZeroTipInterval,
	MaxTxListsPerEpoch,
	BlobAllowed,
	FallbackToCalldata,
	RevertProtectionEnabled,
	CheckProfitability,
	ForceProposingDelay,
}, TxmgrFlags)
