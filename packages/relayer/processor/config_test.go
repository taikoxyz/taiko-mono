package processor

import (
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/relayer/cmd/flags"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/db"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue"
)

var (
	srcSignalServiceAddr    = "0x63FaC9201494f0bd17B9892B9fae4d52fe3BD399"
	destBridgeAddr          = "0x63FaC9201494f0bd17B9892B9fae4d52fe3BD377"
	destQuotaManagerAddr    = "0x63FaC9201494f0bd17B9892B9fae4d52fe3BD357"
	headerSyncInterval      = "30"
	confirmations           = "10"
	confirmationTimeout     = "30"
	backoffRetryInterval    = "20"
	backOffMaxRetries       = "10"
	databaseMaxIdleConns    = "10"
	databaseMaxOpenConns    = "10"
	databaseMaxConnLifetime = "30"
	ethClientTimeout        = "10"
)

func setupApp() *cli.App {
	app := cli.NewApp()
	app.Flags = flags.ProcessorFlags
	app.Action = func(ctx *cli.Context) error {
		_, err := NewConfigFromCliContext(ctx)
		return err
	}

	return app
}

func TestNewConfigFromCliContext(t *testing.T) {
	app := setupApp()

	app.Action = func(ctx *cli.Context) error {
		c, err := NewConfigFromCliContext(ctx)
		assert.Nil(t, err)
		assert.Equal(t, "dbuser", c.DatabaseUsername)
		assert.Equal(t, "dbpass", c.DatabasePassword)
		assert.Equal(t, "dbname", c.DatabaseName)
		assert.Equal(t, "dbhost", c.DatabaseHost)
		assert.Equal(t, "queuename", c.QueueUsername)
		assert.Equal(t, "queuepassword", c.QueuePassword)
		assert.Equal(t, "queuehost", c.QueueHost)
		assert.Equal(t, uint64(5555), c.QueuePort)
		assert.Equal(t, "srcRpcUrl", c.SrcRPCUrl)
		assert.Equal(t, "destRpcUrl", c.DestRPCUrl)
		assert.Equal(t, common.HexToAddress(srcSignalServiceAddr), c.SrcSignalServiceAddress)
		assert.Equal(t, common.HexToAddress(destBridgeAddr), c.DestBridgeAddress)
		assert.Equal(t, common.HexToAddress(destBridgeAddr), c.DestERC20VaultAddress)
		assert.Equal(t, common.HexToAddress(destBridgeAddr), c.DestERC721VaultAddress)
		assert.Equal(t, common.HexToAddress(destBridgeAddr), c.DestERC1155VaultAddress)
		assert.Equal(t, common.HexToAddress(destBridgeAddr), c.DestTaikoAddress)
		assert.Equal(t, uint64(30), c.HeaderSyncInterval)
		assert.Equal(t, uint64(10), c.Confirmations)
		assert.Equal(t, uint64(30), c.ConfirmationsTimeout)
		assert.Equal(t, uint64(20), c.BackoffRetryInterval)
		assert.Equal(t, uint64(10), c.BackOffMaxRetries)
		assert.Equal(t, uint64(10), c.DatabaseMaxIdleConns)
		assert.Equal(t, uint64(10), c.DatabaseMaxOpenConns)
		assert.Equal(t, uint64(30), c.DatabaseMaxConnLifetime)
		assert.Equal(t, uint64(10), c.ETHClientTimeout)
		assert.Equal(t, 5*time.Minute, c.ETHClientRequestTimeout)
		assert.Equal(t, true, c.ProfitableOnly)
		assert.Equal(t, uint64(100), c.QueuePrefetch)
		assert.Equal(t, true, c.EnableTaikoL2)

		c.OpenDBFunc = func() (db.DB, error) {
			return &mock.DB{}, nil
		}

		c.OpenQueueFunc = func() (queue.Queue, error) {
			return &mock.Queue{}, nil
		}

		// assert.Nil(t, InitFromConfig(context.Background(), new(Processor), c))

		return err
	}

	assert.Nil(t, app.Run([]string{
		"TestNewConfigFromCliContext",
		"--" + flags.DatabaseUsername.Name, "dbuser",
		"--" + flags.DatabasePassword.Name, "dbpass",
		"--" + flags.DatabaseHost.Name, "dbhost",
		"--" + flags.DatabaseName.Name, "dbname",
		"--" + flags.QueueUsername.Name, "queuename",
		"--" + flags.QueuePassword.Name, "queuepassword",
		"--" + flags.QueueHost.Name, "queuehost",
		"--" + flags.QueuePort.Name, "5555",
		"--" + flags.SrcRPCUrl.Name, "srcRpcUrl",
		"--" + flags.DestRPCUrl.Name, "destRpcUrl",
		"--" + flags.SrcSignalServiceAddress.Name, srcSignalServiceAddr,
		"--" + flags.DestBridgeAddress.Name, destBridgeAddr,

		"--" + flags.DestERC721VaultAddress.Name, destBridgeAddr,
		"--" + flags.DestERC20VaultAddress.Name, destBridgeAddr,
		"--" + flags.DestERC1155VaultAddress.Name, destBridgeAddr,
		"--" + flags.DestTaikoAddress.Name, destBridgeAddr,
		"--" + flags.ProcessorPrivateKey.Name, dummyEcdsaKey,
		"--" + flags.HeaderSyncInterval.Name, headerSyncInterval,
		"--" + flags.Confirmations.Name, confirmations,
		"--" + flags.ConfirmationTimeout.Name, confirmationTimeout,
		"--" + flags.BackOffRetryInterval.Name, backoffRetryInterval,
		"--" + flags.BackOffMaxRetries.Name, backOffMaxRetries,
		"--" + flags.DatabaseMaxIdleConns.Name, databaseMaxIdleConns,
		"--" + flags.DatabaseMaxOpenConns.Name, databaseMaxOpenConns,
		"--" + flags.DatabaseConnMaxLifetime.Name, databaseMaxConnLifetime,
		"--" + flags.ETHClientTimeout.Name, ethClientTimeout,
		"--" + flags.QueuePrefetchCount.Name, "100",
		"--" + flags.ProfitableOnly.Name,
		"--" + flags.EnableTaikoL2.Name,
		"--" + flags.DestQuotaManagerAddress.Name, destQuotaManagerAddr,
	}))
}

func TestNewConfigFromCliContext_PrivKeyError(t *testing.T) {
	app := setupApp()
	assert.ErrorContains(t, app.Run([]string{
		"TestingNewConfigFromCliContext",
		"--" + flags.DatabaseUsername.Name, "dbuser",
		"--" + flags.DatabasePassword.Name, "dbpass",
		"--" + flags.DatabaseHost.Name, "dbhost",
		"--" + flags.DatabaseName.Name, "dbname",
		"--" + flags.QueueUsername.Name, "queuename",
		"--" + flags.QueuePassword.Name, "queuepassword",
		"--" + flags.QueueHost.Name, "queuehost",
		"--" + flags.QueuePort.Name, "5555",
		"--" + flags.SrcRPCUrl.Name, "srcRpcUrl",
		"--" + flags.DestRPCUrl.Name, "destRpcUrl",
		"--" + flags.DestBridgeAddress.Name, destBridgeAddr,

		"--" + flags.DestERC721VaultAddress.Name, destBridgeAddr,
		"--" + flags.DestERC20VaultAddress.Name, destBridgeAddr,
		"--" + flags.DestERC1155VaultAddress.Name, destBridgeAddr,
		"--" + flags.DestTaikoAddress.Name, destBridgeAddr,
		"--" + flags.ProcessorPrivateKey.Name, "invalid-priv-key",
		"--" + flags.DestQuotaManagerAddress.Name, destQuotaManagerAddr,
	}), "invalid processorPrivateKey")
}

// baseProcessorArgs returns the arguments every processor config needs, so a test can append the
// flags it actually cares about.
func baseProcessorArgs(name string) []string {
	return []string{
		name,
		"--" + flags.DatabaseUsername.Name, "dbuser",
		"--" + flags.DatabasePassword.Name, "dbpass",
		"--" + flags.DatabaseHost.Name, "dbhost",
		"--" + flags.DatabaseName.Name, "dbname",
		"--" + flags.QueueUsername.Name, "queuename",
		"--" + flags.QueuePassword.Name, "queuepassword",
		"--" + flags.QueueHost.Name, "queuehost",
		"--" + flags.QueuePort.Name, "5555",
		"--" + flags.SrcRPCUrl.Name, "srcRpcUrl",
		"--" + flags.DestRPCUrl.Name, "destRpcUrl",
		"--" + flags.SrcSignalServiceAddress.Name, srcSignalServiceAddr,
		"--" + flags.DestBridgeAddress.Name, destBridgeAddr,
		"--" + flags.DestERC721VaultAddress.Name, destBridgeAddr,
		"--" + flags.DestERC20VaultAddress.Name, destBridgeAddr,
		"--" + flags.DestERC1155VaultAddress.Name, destBridgeAddr,
		"--" + flags.DestTaikoAddress.Name, destBridgeAddr,
		"--" + flags.ProcessorPrivateKey.Name, dummyEcdsaKey,
	}
}

func TestNewConfigFromCliContext_NoPrivateRPCUrls(t *testing.T) {
	app := setupApp()

	app.Action = func(ctx *cli.Context) error {
		c, err := NewConfigFromCliContext(ctx)
		assert.Nil(t, err)
		assert.Empty(t, c.DestPrivateRPCUrls, "every send should go through destRpcUrl by default")
		assert.Equal(t, 5*time.Minute, c.PrivateRPCRetryInterval)

		return nil
	}

	assert.Nil(t, app.Run(baseProcessorArgs("TestNewConfigFromCliContext_NoPrivateRPCUrls")))
}

func TestNewConfigFromCliContext_PrivateRPCUrls(t *testing.T) {
	flashbots := "https://rpc.flashbots.net?hint=hash"
	mevBlocker := "https://rpc.mevblocker.io/fullprivacy"

	app := setupApp()

	app.Action = func(ctx *cli.Context) error {
		c, err := NewConfigFromCliContext(ctx)
		assert.Nil(t, err)

		// Order is the failover order, so it has to survive parsing.
		assert.Equal(t, []string{flashbots, mevBlocker}, c.DestPrivateRPCUrls)
		assert.Equal(t, 30*time.Second, c.PrivateRPCRetryInterval)

		return nil
	}

	assert.Nil(t, app.Run(append(
		baseProcessorArgs("TestNewConfigFromCliContext_PrivateRPCUrls"),
		"--"+flags.DestPrivateRPCUrls.Name, flashbots,
		"--"+flags.DestPrivateRPCUrls.Name, mevBlocker,
		"--"+flags.PrivateRPCRetryInterval.Name, "30s",
	)))
}

func TestNewConfigFromCliContext_PrivateRPCUrlsSkipsBlankEntries(t *testing.T) {
	app := setupApp()

	app.Action = func(ctx *cli.Context) error {
		c, err := NewConfigFromCliContext(ctx)
		assert.Nil(t, err)

		// A trailing separator or padded entry is easy to leave in a deployment env var, and would
		// otherwise become an endpoint pointed at nothing.
		assert.Equal(t, []string{"https://rpc.flashbots.net?hint=hash"}, c.DestPrivateRPCUrls)

		return nil
	}

	assert.Nil(t, app.Run(append(
		baseProcessorArgs("TestNewConfigFromCliContext_PrivateRPCUrlsSkipsBlankEntries"),
		"--"+flags.DestPrivateRPCUrls.Name, "  https://rpc.flashbots.net?hint=hash  ",
		"--"+flags.DestPrivateRPCUrls.Name, "   ",
		"--"+flags.DestPrivateRPCUrls.Name, "",
	)))
}

func TestNewConfigFromCliContext_PrivateRPCUrlsAsOneCommaSeparatedValue(t *testing.T) {
	app := setupApp()

	app.Action = func(ctx *cli.Context) error {
		c, err := NewConfigFromCliContext(ctx)
		assert.Nil(t, err)

		// Deployments set this through the DEST_PRIVATE_RPC_URLS env var, which arrives as one
		// comma-separated string rather than a repeated flag.
		assert.Equal(t, []string{
			"https://rpc.flashbots.net?hint=hash",
			"https://rpc.mevblocker.io/fullprivacy",
		}, c.DestPrivateRPCUrls)

		return nil
	}

	assert.Nil(t, app.Run(append(
		baseProcessorArgs("TestNewConfigFromCliContext_PrivateRPCUrlsAsOneCommaSeparatedValue"),
		"--"+flags.DestPrivateRPCUrls.Name,
		"https://rpc.flashbots.net?hint=hash, https://rpc.mevblocker.io/fullprivacy",
	)))
}

func TestParsePrivateRPCUrls(t *testing.T) {
	tests := []struct {
		name       string
		configured []string
		want       []string
		wantErr    string
	}{
		{
			name:       "none configured",
			configured: nil,
			want:       []string{},
		},
		{
			name:       "order is the failover order and has to survive parsing",
			configured: []string{"https://rpc.flashbots.net?hint=hash", "https://rpc.mevblocker.io/fullprivacy"},
			want:       []string{"https://rpc.flashbots.net?hint=hash", "https://rpc.mevblocker.io/fullprivacy"},
		},
		{
			// A trailing separator or padded entry is easy to leave in a deployment env var.
			name:       "blank and padded entries are skipped",
			configured: []string{" https://rpc.flashbots.net ", "", "   "},
			want:       []string{"https://rpc.flashbots.net"},
		},
		{
			name:       "plain http is allowed",
			configured: []string{"http://localhost:8545"},
			want:       []string{"http://localhost:8545"},
		},
		{
			// http and https transports are built without contacting the endpoint, so a relay
			// that is down cannot stop the processor starting. ws dials while connecting, which
			// would make startup depend on a relay being up.
			name:       "websocket is rejected",
			configured: []string{"wss://rpc.example.com"},
			wantErr:    "scheme \"wss\" is not supported",
		},
		{
			name:       "a bare host with no scheme is rejected",
			configured: []string{"rpc.flashbots.net"},
			wantErr:    "is not supported",
		},
		{
			// Quietly dropping this would leave the relayer broadcasting publicly while its
			// operator believed otherwise, which is the whole exposure this feature removes.
			name:       "an unparsable entry is rejected rather than skipped",
			configured: []string{"https://rpc.flashbots.net", "https://  bad host"},
			wantErr:    "invalid",
		},
		{
			name:       "a scheme with no host is rejected",
			configured: []string{"https://"},
			wantErr:    "no host",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := parsePrivateRPCUrls(tt.configured)

			if tt.wantErr != "" {
				require.ErrorContains(t, err, tt.wantErr)
				assert.Nil(t, got, "a rejected configuration must not yield a partial endpoint list")

				return
			}

			require.NoError(t, err)
			assert.Equal(t, tt.want, got)
		})
	}
}

func Test_parsePrivateRPCUrlsRejectsCleartextToRemoteHosts(t *testing.T) {
	tests := []struct {
		name    string
		url     string
		wantErr string
	}{
		{
			// A signed claim on the wire in cleartext can be read and front-run, which is the
			// exposure private endpoints exist to remove, reached by another route.
			name:    "plain http to a public host",
			url:     "http://rpc.flashbots.net",
			wantErr: "cleartext",
		},
		{name: "plain http to a public IP", url: "http://8.8.8.8:8545", wantErr: "cleartext"},
		{name: "https to a public host", url: "https://rpc.flashbots.net"},
		{name: "http to localhost", url: "http://localhost:8545"},
		{name: "http to loopback", url: "http://127.0.0.1:8545"},
		{name: "http to IPv6 loopback", url: "http://[::1]:8545"},
		{name: "http to a private subnet", url: "http://10.0.0.7:8545"},
		{name: "http to another private subnet", url: "http://192.168.1.5:8545"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := parsePrivateRPCUrls([]string{tt.url})

			if tt.wantErr != "" {
				require.ErrorContains(t, err, tt.wantErr)
				assert.Nil(t, got)

				return
			}

			require.NoError(t, err)
			assert.Equal(t, []string{tt.url}, got)
		})
	}
}

func Test_privateRPCSendTimeout(t *testing.T) {
	// A relay can accept a transaction and never include it, and acceptance is the only signal
	// this relayer gets, so without a send timeout the claim waits for a receipt indefinitely.
	timeout, defaulted := privateRPCSendTimeout(2, 0)
	assert.Equal(t, DefaultPrivateRPCSendTimeout, timeout)
	assert.True(t, defaulted)

	// An operator who picked a bound keeps it.
	timeout, defaulted = privateRPCSendTimeout(2, time.Minute)
	assert.Equal(t, time.Minute, timeout)
	assert.False(t, defaulted)

	// Nothing is imposed on a deployment that configures no private endpoints, which is every
	// deployment that predates them — this timeout governs the public path too.
	timeout, defaulted = privateRPCSendTimeout(0, 0)
	assert.Zero(t, timeout)
	assert.False(t, defaulted)
}

func Test_parsePrivateRPCUrlsKeepsRejectedEntriesOutOfTheError(t *testing.T) {
	// url.Parse builds a *url.Error whose text quotes the raw input, so wrapping it verbatim puts
	// the endpoint — and any API key in its path or query — into whatever logs the startup error.
	// That is the same exposure the returned-error redaction closes, reached through config
	// parsing instead of through a send.
	tests := []struct {
		name   string
		url    string
		reason string
	}{
		{
			name:   "invalid escape",
			url:    "https://relay.example.com/v1/SUPERSECRETKEY%zz",
			reason: "invalid URL escape",
		},
		{
			name:   "control character",
			url:    "https://relay.example.com/v1/SUPERSECRETKEY\x7f",
			reason: "invalid control character",
		},
		{
			name:   "invalid port",
			url:    "https://relay.example.com:notaport/v1/SUPERSECRETKEY",
			reason: "invalid port",
		},
		{
			// No scheme, so a regex looking for one would not find a URL to remove here. The
			// endpoint has to be kept out by construction rather than by matching.
			name:   "no scheme",
			url:    "relay.example.com/v1/SUPERSECRETKEY%zz",
			reason: "invalid URL escape",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := parsePrivateRPCUrls([]string{tt.url})

			require.Error(t, err)
			assert.Nil(t, got)

			assert.NotContains(t, err.Error(), "SUPERSECRETKEY")
			assert.NotContains(t, err.Error(), "relay.example.com")

			// The operator still has to be able to act on it: which entry, and what was wrong.
			assert.Contains(t, err.Error(), tt.reason)
			assert.Contains(t, err.Error(), "entry 0")
		})
	}
}
