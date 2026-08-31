package processor

import (
	"crypto/ecdsa"
	"errors"
	"fmt"
	"net"
	"net/url"
	"strings"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/urfave/cli/v2"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"

	"github.com/taikoxyz/taiko-mono/packages/relayer/cmd/flags"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/db"
	pkgFlags "github.com/taikoxyz/taiko-mono/packages/relayer/pkg/flags"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue/rabbitmq"
)

// Config is a struct used to initialize a processor.
type Config struct {
	// address configs
	SrcSignalServiceAddress common.Address
	DestBridgeAddress       common.Address
	DestERC721VaultAddress  common.Address
	DestERC20VaultAddress   common.Address
	DestERC1155VaultAddress common.Address
	DestTaikoAddress        common.Address
	DestQuotaManagerAddress common.Address

	// private key
	ProcessorPrivateKey *ecdsa.PrivateKey

	TargetTxHash *common.Hash

	// processing configs
	HeaderSyncInterval   uint64
	Confirmations        uint64
	ConfirmationsTimeout uint64
	ProfitableOnly       bool
	EnableTaikoL2        bool

	// backoff configs
	BackoffRetryInterval uint64
	BackOffMaxRetries    uint64

	// db configs
	DatabaseUsername        string
	DatabasePassword        string
	DatabaseName            string
	DatabaseHost            string
	DatabaseMaxIdleConns    uint64
	DatabaseMaxOpenConns    uint64
	DatabaseMaxConnLifetime uint64
	// queue configs
	QueueUsername string
	QueuePassword string
	QueueHost     string
	QueuePort     uint64
	QueuePrefetch uint64
	// rpc configs
	SrcRPCUrl        string
	DestRPCUrl       string
	ETHClientTimeout uint64
	OpenQueueFunc    func() (queue.Queue, error)
	OpenDBFunc       func() (db.DB, error)

	UnprofitableMessageQueueExpiration *string
	TransientErrorQueueExpiration      *string

	TxmgrConfigs *txmgr.CLIConfig

	// DestPrivateRPCUrls are destination chain endpoints that hand transactions to block builders
	// without broadcasting them to the public mempool, in priority order. Empty when none are
	// configured, in which case every processMessage call goes out through DestRPCUrl.
	DestPrivateRPCUrls []string
	// PrivateRPCRetryInterval is how long a private endpoint is taken out of rotation after a
	// send through it fails.
	PrivateRPCRetryInterval time.Duration

	MaxMessageRetries uint64
	MinFeeToProcess   uint64
}

// NewConfigFromCliContext creates a new config instance from command line flags.
func NewConfigFromCliContext(c *cli.Context) (*Config, error) {
	processorPrivateKey, err := crypto.ToECDSA(
		common.Hex2Bytes(c.String(flags.ProcessorPrivateKey.Name)),
	)
	if err != nil {
		return nil, fmt.Errorf("invalid processorPrivateKey: %w", err)
	}

	var targetTxHash *common.Hash

	if c.IsSet(flags.TargetTxHash.Name) {
		hash := common.HexToHash(c.String(flags.TargetTxHash.Name))
		targetTxHash = &hash
	}

	var unprofitableMessageQueueExpiration *string

	if c.IsSet(flags.UnprofitableMessageQueueExpiration.Name) {
		u := c.String(flags.UnprofitableMessageQueueExpiration.Name)
		unprofitableMessageQueueExpiration = &u
	}

	// Always set, unlike the unprofitable expiration: a message with no expiration would wait in
	// the transient queue forever, and nothing would bring it back.
	transientErrorQueueExpiration := c.String(flags.TransientErrorQueueExpiration.Name)

	var destQuotaManagerAddress common.Address
	if c.IsSet(flags.DestQuotaManagerAddress.Name) {
		destQuotaManagerAddress = common.HexToAddress(c.String(flags.DestQuotaManagerAddress.Name))
	}

	// Order is preserved: sends are offered to these in the order they were given.
	privateRPCUrls, err := parsePrivateRPCUrls(c.StringSlice(flags.DestPrivateRPCUrls.Name))
	if err != nil {
		return nil, err
	}

	return &Config{
		ProcessorPrivateKey:                processorPrivateKey,
		SrcSignalServiceAddress:            common.HexToAddress(c.String(flags.SrcSignalServiceAddress.Name)),
		DestTaikoAddress:                   common.HexToAddress(c.String(flags.DestTaikoAddress.Name)),
		DestBridgeAddress:                  common.HexToAddress(c.String(flags.DestBridgeAddress.Name)),
		DestERC721VaultAddress:             common.HexToAddress(c.String(flags.DestERC721VaultAddress.Name)),
		DestERC20VaultAddress:              common.HexToAddress(c.String(flags.DestERC20VaultAddress.Name)),
		DestERC1155VaultAddress:            common.HexToAddress(c.String(flags.DestERC1155VaultAddress.Name)),
		DestQuotaManagerAddress:            destQuotaManagerAddress,
		DatabaseUsername:                   c.String(flags.DatabaseUsername.Name),
		DatabasePassword:                   c.String(flags.DatabasePassword.Name),
		DatabaseName:                       c.String(flags.DatabaseName.Name),
		DatabaseHost:                       c.String(flags.DatabaseHost.Name),
		DatabaseMaxIdleConns:               c.Uint64(flags.DatabaseMaxIdleConns.Name),
		DatabaseMaxOpenConns:               c.Uint64(flags.DatabaseMaxOpenConns.Name),
		DatabaseMaxConnLifetime:            c.Uint64(flags.DatabaseConnMaxLifetime.Name),
		QueueUsername:                      c.String(flags.QueueUsername.Name),
		QueuePassword:                      c.String(flags.QueuePassword.Name),
		QueuePort:                          c.Uint64(flags.QueuePort.Name),
		QueueHost:                          c.String(flags.QueueHost.Name),
		QueuePrefetch:                      c.Uint64(flags.QueuePrefetchCount.Name),
		SrcRPCUrl:                          c.String(flags.SrcRPCUrl.Name),
		DestRPCUrl:                         c.String(flags.DestRPCUrl.Name),
		HeaderSyncInterval:                 c.Uint64(flags.HeaderSyncInterval.Name),
		Confirmations:                      c.Uint64(flags.Confirmations.Name),
		ConfirmationsTimeout:               c.Uint64(flags.ConfirmationTimeout.Name),
		EnableTaikoL2:                      c.Bool(flags.EnableTaikoL2.Name),
		ProfitableOnly:                     c.Bool(flags.ProfitableOnly.Name),
		BackoffRetryInterval:               c.Uint64(flags.BackOffRetryInterval.Name),
		BackOffMaxRetries:                  c.Uint64(flags.BackOffMaxRetries.Name),
		ETHClientTimeout:                   c.Uint64(flags.ETHClientTimeout.Name),
		TargetTxHash:                       targetTxHash,
		UnprofitableMessageQueueExpiration: unprofitableMessageQueueExpiration,
		TransientErrorQueueExpiration:      &transientErrorQueueExpiration,
		TxmgrConfigs: pkgFlags.InitTxmgrConfigsFromCli(
			c.String(flags.DestRPCUrl.Name),
			processorPrivateKey,
			c,
		),
		DestPrivateRPCUrls:      privateRPCUrls,
		PrivateRPCRetryInterval: c.Duration(flags.PrivateRPCRetryInterval.Name),
		MaxMessageRetries:       c.Uint64(flags.MaxMessageRetries.Name),
		MinFeeToProcess:         c.Uint64(flags.MinFeeToProcess.Name),
		OpenDBFunc: func() (db.DB, error) {
			return db.OpenDBConnection(db.DBConnectionOpts{
				Name:            c.String(flags.DatabaseUsername.Name),
				Password:        c.String(flags.DatabasePassword.Name),
				Database:        c.String(flags.DatabaseName.Name),
				Host:            c.String(flags.DatabaseHost.Name),
				MaxIdleConns:    c.Uint64(flags.DatabaseMaxIdleConns.Name),
				MaxOpenConns:    c.Uint64(flags.DatabaseMaxOpenConns.Name),
				MaxConnLifetime: c.Uint64(flags.DatabaseConnMaxLifetime.Name),
				OpenFunc: func(dsn string) (db.DB, error) {
					gormDB, err := gorm.Open(mysql.Open(dsn), &gorm.Config{
						Logger: logger.Default.LogMode(logger.Silent),
					})
					if err != nil {
						return nil, err
					}

					return db.New(gormDB), nil
				},
			})
		},
		OpenQueueFunc: func() (queue.Queue, error) {
			opts := queue.NewQueueOpts{
				Username:      c.String(flags.QueueUsername.Name),
				Password:      c.String(flags.QueuePassword.Name),
				Host:          c.String(flags.QueueHost.Name),
				Port:          c.String(flags.QueuePort.Name),
				PrefetchCount: c.Uint64(flags.QueuePrefetchCount.Name),
			}

			q, err := rabbitmq.NewQueue(opts)
			if err != nil {
				return nil, err
			}

			return q, nil
		},
	}, nil
}

// parsePrivateRPCUrls trims and validates the configured private endpoints, preserving order and
// skipping blank entries, which a trailing separator in an env var leaves behind.
//
// Only http and https are accepted. Those transports are built without contacting the endpoint, so
// a relay that is down cannot stop the processor from starting; ws and ipc connect while dialling,
// which would make startup depend on a relay being up. A rejected URL fails startup on purpose:
// quietly dropping one would leave the relayer broadcasting publicly while its operator believed
// otherwise.
//
// No rejection quotes the entry itself. A private relay URL carries its credential in the path or
// query, and a startup error is logged like any other, so an error naming the bad entry would put
// that credential in the logs — the same exposure the redaction on send errors closes, reached
// through configuration instead. Entries are identified by position, which is what identifies a
// relay in the logs everywhere else in this feature.
func parsePrivateRPCUrls(configured []string) ([]string, error) {
	urls := make([]string, 0, len(configured))

	for i, raw := range configured {
		raw = strings.TrimSpace(raw)
		if raw == "" {
			continue
		}

		parsed, err := url.Parse(raw)
		if err != nil {
			return nil, fmt.Errorf(
				"invalid %s entry %d: %w",
				flags.DestPrivateRPCUrls.Name,
				i,
				parseFailureReason(err),
			)
		}

		if parsed.Scheme != "http" && parsed.Scheme != "https" {
			return nil, fmt.Errorf(
				"invalid %s entry %d: scheme %q is not supported, use http or https",
				flags.DestPrivateRPCUrls.Name,
				i,
				parsed.Scheme,
			)
		}

		// Hostname() rather than Host: "https://:8545/KEY" parses with a Host of ":8545" and an
		// empty hostname, which passes a Host check and then fails at dial time — in an error that
		// quotes the whole entry, key included.
		if parsed.Hostname() == "" {
			return nil, fmt.Errorf("invalid %s entry %d: no host", flags.DestPrivateRPCUrls.Name, i)
		}

		if parsed.Scheme == "http" && !isLocalHost(parsed.Hostname()) {
			return nil, fmt.Errorf(
				"invalid %s entry %d: %q sends signed transactions in cleartext, use https",
				flags.DestPrivateRPCUrls.Name,
				i,
				parsed.Hostname(),
			)
		}

		urls = append(urls, raw)
	}

	return urls, nil
}

// parseFailureReason strips the URL that url.Parse quotes back at us, leaving only why it failed.
//
// url.Parse always returns a *url.Error, whose Error() is `parse "<the whole raw input>": <why>`.
// Redacting that text with a regex is not enough: an entry with no scheme — which is one of the
// ways to land here — has nothing for a URL pattern to match, so the input has to be dropped by
// taking the reason out of the error rather than by rewriting its text.
func parseFailureReason(err error) error {
	var parseErr *url.Error
	if errors.As(err, &parseErr) {
		return parseErr.Err
	}

	return err
}

// isLocalHost reports whether host is reachable without leaving the machine or a private network.
//
// Plain http to anything else would put a signed processMessage on the wire in cleartext, where it
// can be read and front-run — the exact exposure private endpoints exist to remove, arrived at by
// a different route.
//
// Only the name "localhost" and IP literals in the loopback, private and link-local ranges pass.
// A name is deliberately not resolved: resolution would make a cleartext-transport decision depend
// on what DNS answers at that moment, which an attacker may influence and which can differ by the
// time the endpoint is dialled. The cost is that a private name — mev-relay.default.svc.cluster
// .local, say — is rejected even when it resolves inside the cluster, and such a deployment has to
// give the address as a literal or serve the relay over https.
func isLocalHost(host string) bool {
	// Hosts are compared without regard to case: url.Parse lowercases the scheme but leaves the
	// host as written, so "LOCALHOST" arrives here exactly as the operator typed it.
	if strings.EqualFold(host, "localhost") {
		return true
	}

	ip := net.ParseIP(host)
	if ip == nil {
		return false
	}

	return ip.IsLoopback() || ip.IsPrivate() || ip.IsLinkLocalUnicast()
}

// DefaultPrivateRPCSendTimeout bounds one send when private endpoints are configured and the
// operator left TX_SEND_TIMEOUT disabled.
//
// A private relay can accept a transaction and never have it included — Flashbots Protect drops
// would-revert transactions by design — and acceptance is the only signal this relayer gets, since
// receipts are polled through DEST_RPC_URL. With no send timeout the transaction manager waits for
// that receipt for as long as it takes, so the claim stalls and its worker with it.
//
// Five minutes is a bound this relayer chooses, not the point at which the relays give up. Their
// roughly twenty-five block window runs per transaction submitted, and every fee bump submits a new
// one, so the newest variant of a claim is still being offered well past this — a bump at the 48s
// RESUBMISSION_TIMEOUT default pushes the tail out to around ten minutes. Abandoning the send at
// five can therefore overlap a variant a builder may yet include; what that costs is a nonce shared
// between the abandoned claim and the next one, which resolves as a retry rather than a loss.
//
// What the value is chosen for: six fee bumps at the 48s default, so a claim that was merely
// underpriced has had several chances to catch up, and a match with the PRIVATE_RPC_RETRY_INTERVAL
// default, so a stalled claim and a tripped endpoint come back on the same timescale.
//
// It is a ceiling rather than the usual exit. A send no endpoint will take ends earlier, at the
// transaction manager's TxNotInMempoolTimeout — two minutes by default — because no publish ever
// succeeded.
const DefaultPrivateRPCSendTimeout = 5 * time.Minute

// privateRPCSendTimeout returns the send timeout to run with, supplying a default rather than
// leaving a claim able to wait for a receipt indefinitely.
//
// The default only applies where the problem exists. Deployments that configure no private endpoint
// keep the transaction manager's own behaviour: this timeout governs the public path too, and every
// deployment that predates private endpoints has been running without it. An operator who wants a
// different bound sets TX_SEND_TIMEOUT; the one value that cannot be asked for alongside private
// endpoints is no bound at all, which is the configuration this exists to rule out.
//
// It reports whether it supplied the default, so the caller can say so in the log without this
// having to.
func privateRPCSendTimeout(privateEndpoints int, configured time.Duration) (
	timeout time.Duration,
	defaulted bool,
) {
	if privateEndpoints == 0 || configured != 0 {
		return configured, false
	}

	return DefaultPrivateRPCSendTimeout, true
}
