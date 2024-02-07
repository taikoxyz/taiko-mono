package flags

import (
	"github.com/urfave/cli/v2"
)

var (
	WatchdogPrivateKey = &cli.StringFlag{
		Name:     "watchdogPrivateKey",
		Usage:    "Private key to suspend bridge transactions, should correspond with the address set on chain as watchdog",
		Required: true,
		Category: watchdogCategory,
		EnvVars:  []string{"WATCHDOG_PRIVATE_KEY"},
	}
)

var WatchdogFlags = MergeFlags(CommonFlags, QueueFlags, []cli.Flag{
	WatchdogPrivateKey,
	SrcSignalServiceAddress,
	DestERC721VaultAddress,
	DestERC1155VaultAddress,
	DestERC20VaultAddress,
	DestTaikoAddress,
	// optional
	HeaderSyncInterval,
	Confirmations,
	ConfirmationTimeout,
	ProfitableOnly,
	BackOffRetryInterval,
	BackOffMaxRetrys,
	QueuePrefetchCount,
	EnableTaikoL2,
	HopRPCUrls,
	HopSignalServiceAddresses,
	HopTaikoAddresses,
	DestBridgeAddress,
	TargetTxHash,
	ProofEncodingType,
	SrcBridgeAddress,
})
