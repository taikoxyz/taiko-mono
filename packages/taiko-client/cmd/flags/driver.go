package flags

import (
	"time"

	"github.com/urfave/cli/v2"
)

// Optional flags used by driver.
var (
	P2PSyncTimeout = &cli.DurationFlag{
		Name: "p2p.syncTimeout",
		Usage: "P2P syncing timeout, if no sync progress is made within this time span, " +
			"driver will stop the P2P sync and insert all remaining L2 blocks one by one",
		Value:    1 * time.Hour,
		Category: driverCategory,
		EnvVars:  []string{"P2P_SYNC_TIMEOUT"},
	}
	CheckPointSyncURL = &cli.StringFlag{
		Name:     "p2p.checkPointSyncUrl",
		Usage:    "HTTP RPC endpoint of another synced L2 execution engine node",
		Required: true,
		Category: driverCategory,
		EnvVars:  []string{"P2P_CHECK_POINT_SYNC_URL"},
	}
	// syncer specific flag
	MaxExponent = &cli.Uint64Flag{
		Name: "syncer.maxExponent",
		Usage: "Maximum exponent of retrieving L1 blocks when there is a mismatch between protocol and L2 EE," +
			"0 means that it is reset to the genesis height",
		Value:    0,
		Category: driverCategory,
		EnvVars:  []string{"SYNCER_MAX_EXPONENT"},
	}
	// blob server endpoint
	BlobServerEndpoint = &cli.StringFlag{
		Name:     "blob.server",
		Usage:    "Blob sidecar storage server",
		Category: driverCategory,
		EnvVars:  []string{"BLOB_SERVER"},
	}
	SocialScanEndpoint = &cli.StringFlag{
		Name:     "blob.socialScanEndpoint",
		Usage:    "Social Scan's blob storage server",
		Category: driverCategory,
		EnvVars:  []string{"BLOB_SOCIAL_SCAN_ENDPOINT"},
	}
)

// DriverFlags All driver flags.
var DriverFlags = MergeFlags(CommonFlags, []cli.Flag{
	L1BeaconEndpoint,
	L2WSEndpoint,
	L2AuthEndpoint,
	JWTSecret,
	P2PSyncTimeout,
	CheckPointSyncURL,
	MaxExponent,
	BlobServerEndpoint,
	SocialScanEndpoint,
})
