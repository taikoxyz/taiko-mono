package flags

import (
	"time"

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
	// Chain syncer specific flag
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
	// preconf block server
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
	PreconfBlockServerCheckSig = &cli.BoolFlag{
		Name:     "preconfirmation.signatureCheck",
		Usage:    "If the preconfirmation block server will check the signature of the incoming preconf blocks",
		Category: driverCategory,
		Value:    false,
		EnvVars:  []string{"PRECONFIRMATION_SERVER_SIGNATURE_CHECK"},
	}
	PreconfP2PNetworkPort = &cli.Uint64Flag{
		Name:     "preconfirmation.p2pPort",
		Usage:    "Port to run p2p network on for preconfirmation block propagation",
		Category: driverCategory,
		EnvVars:  []string{"PRECONFIRMATION_P2P_NETWORK_PORT"},
	}
	PreconfP2PNetworkBootstrapNodeURLs = &cli.StringSliceFlag{
		Name:     "preconfirmation.p2pBootstrapNodeUrls",
		Usage:    "Bootstrap node URLs for p2p network for preconfirmation block propagation",
		Category: driverCategory,
		EnvVars:  []string{"PRECONFIRMATION_P2P_NETWORK_BOOTSTRAP_NODE_URLS"},
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
	MaxExponent,
	BlobServerEndpoint,
	SocialScanEndpoint,
	PreconfBlockServerPort,
	PreconfBlockServerJWTSecret,
	PreconfBlockServerCORSOrigins,
	PreconfBlockServerCheckSig,
	PreconfP2PNetworkPort,
	PreconfP2PNetworkBootstrapNodeURLs,
})
