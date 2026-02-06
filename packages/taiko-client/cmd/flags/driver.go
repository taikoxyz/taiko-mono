package flags

import (
	"time"

	p2pFlags "github.com/ethereum-optimism/optimism/op-node/flags"
	"github.com/urfave/cli/v2"
)

// Optional flags used by driver.
var (
	P2PSync = &cli.BoolFlag{
		Name: "p2p.sync",
		Usage: "Try P2P syncing blocks between L2 execution engines, " +
			"will be helpful to bring a new node online quickly",
		Value:    false,
		Category: driverCategory,
		EnvVars:  []string{"P2P_SYNC"},
	}
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
		Category: driverCategory,
		EnvVars:  []string{"P2P_CHECK_POINT_SYNC_URL"},
	}
	// blob server endpoint
	BlobServerEndpoint = &cli.StringFlag{
		Name:     "blob.server",
		Usage:    "Blob sidecar storage server",
		Category: driverCategory,
		EnvVars:  []string{"BLOB_SERVER"},
	}
	// preconfirmation block server
	PreconfBlockServerPort = &cli.Uint64Flag{
		Name:     "preconfirmation.serverPort",
		Usage:    "HTTP port of the preconfirmation block server, 0 means disabled",
		Category: driverCategory,
		EnvVars:  []string{"PRECONFIRMATION_SERVER_PORT"},
	}
	PreconfBlockServerJWTSecret = &cli.StringFlag{
		Name:     "preconfirmation.jwtSecret",
		Usage:    "Path to a JWT secret to use for the preconfirmation block server",
		Category: driverCategory,
		EnvVars:  []string{"PRECONFIRMATION_SERVER_JWT_SECRET"},
	}
	PreconfBlockServerCORSOrigins = &cli.StringFlag{
		Name:     "preconfirmation.corsOrigins",
		Usage:    "CORS Origins settings for the preconfirmation block server",
		Category: driverCategory,
		Value:    "*",
		EnvVars:  []string{"PRECONFIRMATION_SERVER_CORS_ORIGINS"},
	}
	DriverTaikoWrapperAddress = &cli.StringFlag{
		Name:     "taikoWrapper",
		Usage:    "TaikoWrapper contract `address`",
		Required: false,
		Category: driverCategory,
		EnvVars:  []string{"TAIKO_WRAPPER"},
	}
)

// DriverFlags All driver flags.
var DriverFlags = MergeFlags(CommonFlags, []cli.Flag{
	L1BeaconEndpoint,
	L2WSEndpoint,
	L2AuthEndpoint,
	JWTSecret,
	P2PSync,
	P2PSyncTimeout,
	CheckPointSyncURL,
	BlobServerEndpoint,
	PreconfBlockServerPort,
	PreconfBlockServerJWTSecret,
	PreconfBlockServerCORSOrigins,
	DriverTaikoWrapperAddress,
}, p2pFlags.P2PFlags("PRECONFIRMATION"))
