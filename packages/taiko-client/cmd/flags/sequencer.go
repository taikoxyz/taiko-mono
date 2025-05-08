package flags

import (
	"time"

	"github.com/urfave/cli/v2"
)

// Optional flags used by driver.
var (
	PreconfAPIURL = &cli.StringFlag{
		Name:     "sequencer.preconfApiUrl",
		Usage:    "URL of driver preconfAPI server",
		Value:    "http://localhost:9871",
		Category: sequencerCategory,
		Required: true,
		EnvVars:  []string{"PRECONF_API_URL"},
	}
	L2BlockTime = &cli.DurationFlag{
		Name:     "sequencer.blockTime",
		Usage:    "L2 block time",
		Value:    2 * time.Second,
		Category: sequencerCategory,
		Required: true,
		EnvVars:  []string{"L2_BLOCK_TIME"},
	}
	AnchorBlockOffset = &cli.IntFlag{
		Name:     "sequencer.anchorBlockOffset",
		Usage:    "Anchor block offset",
		Value:    5,
		Category: sequencerCategory,
		Required: true,
		EnvVars:  []string{"ANCHOR_BLOCK_OFFSET"},
	}
	HandoverBufferSeconds = &cli.DurationFlag{
		Name:     "sequencer.handoverBufferSeconds",
		Usage:    "Handover buffer seconds",
		Value:    8 * time.Second, // 5 seconds
		Category: sequencerCategory,
		Required: true,
		EnvVars:  []string{"HANDOVER_BUFFER_SECONDS"},
	}
)

// SequencerFlags All driver flags.
var SequencerFlags = MergeFlags(CommonFlags, []cli.Flag{
	L1BeaconEndpoint,
	L2WSEndpoint,
	L2AuthEndpoint,
	L2BlockTime,
	JWTSecret,
	PreconfBlockServerJWTSecret,
	PreconfWhitelistAddress,
	PreconfHandoverSkipSlots,
	AnchorBlockOffset,
	TaikoL1Address,
	TaikoL2Address,
	TaikoWrapperAddress,
	RPCTimeout,
}, TxmgrFlags)
