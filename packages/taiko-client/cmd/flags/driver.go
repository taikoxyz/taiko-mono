package flags

import (
	"time"

	"github.com/urfave/cli/v2"
)

// Flags used by driver.
var (
	L2AuthEndpoint = &cli.StringFlag{
		Name:     "l2.auth",
		Usage:    "Authenticated HTTP RPC endpoint of a L2 taiko-geth execution engine",
		Required: true,
		Category: driverCategory,
	}
	JWTSecret = &cli.StringFlag{
		Name:     "jwtSecret",
		Usage:    "Path to a JWT secret to use for authenticated RPC endpoints",
		Required: true,
		Category: driverCategory,
	}
)

// Optional flags used by driver.
var (
	P2PSyncVerifiedBlocks = &cli.BoolFlag{
		Name: "p2p.syncVerifiedBlocks",
		Usage: "Try P2P syncing verified blocks between L2 execution engines, " +
			"will be helpful to bring a new node online quickly",
		Value:    false,
		Category: driverCategory,
	}
	P2PSyncTimeout = &cli.DurationFlag{
		Name: "p2p.syncTimeout",
		Usage: "P2P syncing timeout, if no sync progress is made within this time span, " +
			"driver will stop the P2P sync and insert all remaining L2 blocks one by one",
		Value:    1 * time.Hour,
		Category: driverCategory,
	}
	CheckPointSyncURL = &cli.StringFlag{
		Name:     "p2p.checkPointSyncUrl",
		Usage:    "HTTP RPC endpoint of another synced L2 execution engine node",
		Category: driverCategory,
	}
)

// DriverFlags All driver flags.
var DriverFlags = MergeFlags(CommonFlags, []cli.Flag{
	L1BeaconEndpoint,
	L2WSEndpoint,
	L2AuthEndpoint,
	JWTSecret,
	P2PSyncVerifiedBlocks,
	P2PSyncTimeout,
	CheckPointSyncURL,
})
