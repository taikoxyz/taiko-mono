package flags

import (
	"github.com/urfave/cli/v2"
)

// Required flags used by proposer.
var (
	L1ProposerPrivKey = &cli.StringFlag{
		Name:     "l1.proposerPrivKey",
		Usage:    "Private key of the L1 proposer, who will send transactions to the inbox",
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
)

// ProposerFlags All proposer flags.
var ProposerFlags = MergeFlags(CommonFlags, []cli.Flag{
	L2AuthEndpoint,
	L2WSEndpoint,
	JWTSecret,
	L1ProposerPrivKey,
	L2SuggestedFeeRecipient,
	ProposeInterval,
	MinTip,
	MinProposingInternal,
	AllowZeroTipInterval,
	MaxTxListsPerEpoch,
}, TxmgrFlags)
