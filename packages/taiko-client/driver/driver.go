package driver

import (
	"context"
	"log/slog"
	"math/big"
	"sync"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/event"
	"github.com/ethereum/go-ethereum/log"
	"github.com/urfave/cli/v2"

	chainSyncer "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer"
	softblocksapi "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/soft_blocks"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/state"
	txlistdecompressor "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/txlist_decompressor"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/p2p"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	softblocks "github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/softblocks"
)

const (
	protocolStatusReportInterval     = 30 * time.Second
	exchangeTransitionConfigInterval = 1 * time.Minute
)

// Driver keeps the L2 execution engine's local block chain in sync with the TaikoL1
// contract.
type Driver struct {
	*Config
	rpc             *rpc.Client
	l2ChainSyncer   *chainSyncer.L2ChainSyncer
	softblockServer *softblocksapi.SoftBlockAPIServer
	state           *state.State

	l1HeadCh  chan *types.Header
	l1HeadSub event.Subscription

	ctx context.Context
	wg  sync.WaitGroup

	p2pnetwork         *p2p.Network
	txListDecompressor *txlistdecompressor.TxListDecompressor
}

// InitFromCli initializes the given driver instance based on the command line flags.
func (d *Driver) InitFromCli(ctx context.Context, c *cli.Context) error {
	cfg, err := NewConfigFromCliContext(c)
	if err != nil {
		return err
	}

	return d.InitFromConfig(ctx, cfg)
}

// InitFromConfig initializes the driver instance based on the given configurations.
func (d *Driver) InitFromConfig(ctx context.Context, cfg *Config) (err error) {
	d.l1HeadCh = make(chan *types.Header, 1024)
	d.ctx = ctx
	d.Config = cfg
	if d.rpc, err = rpc.NewClient(d.ctx, cfg.ClientConfig); err != nil {
		return err
	}

	protocolConfigs, err := rpc.GetProtocolConfigs(d.rpc.TaikoL1, nil)
	if err != nil {
		return err
	}

	d.txListDecompressor = txlistdecompressor.NewTxListDecompressor(
		uint64(protocolConfigs.BlockMaxGasLimit),
		rpc.BlockMaxTxListBytes,
		d.rpc.L2.ChainID,
	)

	if d.state, err = state.New(d.ctx, d.rpc); err != nil {
		return err
	}

	peers, err := d.rpc.L2.PeerCount(d.ctx)
	if err != nil {
		return err
	}

	if cfg.P2PSync && peers == 0 {
		log.Warn("P2P syncing verified blocks enabled, but no connected peer found in L2 execution engine")
	}

	if d.l2ChainSyncer, err = chainSyncer.New(
		d.ctx,
		d.rpc,
		d.state,
		cfg.P2PSync,
		cfg.P2PSyncTimeout,
		cfg.MaxExponent,
		cfg.BlobServerEndpoint,
		cfg.SocialScanEndpoint,
	); err != nil {
		return err
	}

	d.l1HeadSub = d.state.SubL1HeadsFeed(d.l1HeadCh)

	d.p2pnetwork, err = p2p.NewNetwork(d.ctx, d.Config.P2PNetworkBootstrapNodeURL, d.Config.P2PNetworkPort)
	if err != nil {
		return err
	}

	if d.SoftBlockServerPort > 0 {
		if d.softblockServer, err = softblocksapi.New(
			d.SoftBlockServerCORSOrigins,
			d.SoftBlockServerJWTSecret,
			d.l2ChainSyncer.BlobSyncer(),
			d.rpc,
			d.Config.SoftBlockServerCheckSig,
			d.p2pnetwork,
		); err != nil {
			return err
		}
	}

	return nil
}

// Start starts the driver instance.
func (d *Driver) Start() error {
	go d.eventLoop()
	go d.reportProtocolStatus()
	go d.exchangeTransitionConfigLoop()

	// Start the soft block server if it is enabled.
	if d.softblockServer != nil {
		go func() {
			if err := d.softblockServer.Start(d.SoftBlockServerPort); err != nil {
				log.Crit("Failed to start soft block server", "error", err)
			}
		}()
	}

	if d.p2pnetwork != nil {
		go d.p2pnetwork.DiscoverPeers(d.ctx)
		go func() {
			if err := p2p.JoinTopic[softblocks.TransactionBatch](
				d.ctx,
				d.p2pnetwork,
				p2p.TopicNameSoftBlocks,
				func(ctx context.Context, txBatch softblocks.TransactionBatch) error {
					_, err := d.l2ChainSyncer.BlobSyncer().InsertSoftBlockFromTransactionsBatch(
						ctx,
						txBatch.BlockID,
						txBatch.ID,
						d.txListDecompressor.TryDecompress(
							d.rpc.L2.ChainID,
							new(big.Int).SetUint64(txBatch.BlockID),
							txBatch.TransactionsList,
							true,
						),
						txBatch.BatchMarker,
						txBatch.BlockParams,
					)

					if err != nil {
						slog.Error("error inserting soft block", "error", err)
					}

					return err
				}); err != nil {
				slog.Error("Failed to join soft block topic", "error", err)
			}

			if err := p2p.SubscribeToTopic[softblocks.TransactionBatch](
				d.ctx,
				d.p2pnetwork,
				p2p.TopicNameSoftBlocks,
			); err != nil {
				slog.Error("Failed to subscribe to soft block topic", "error", err)
			}
		}()
	}

	return nil
}

// Close closes the driver instance.
func (d *Driver) Close(_ context.Context) {
	d.l1HeadSub.Unsubscribe()
	d.state.Close()
	// Close the soft block server if it is enabled.
	if d.softblockServer != nil {
		if err := d.softblockServer.Shutdown(d.ctx); err != nil {
			log.Error("Failed to shutdown soft block server", "error", err)
		}
	}
	d.wg.Wait()
}

// eventLoop starts the main loop of a L2 execution engine's driver.
func (d *Driver) eventLoop() {
	d.wg.Add(1)
	defer d.wg.Done()

	syncNotify := make(chan struct{}, 1)
	// reqSync requests performing a synchronising operation, won't block
	// if we are already synchronising.
	reqSync := func() {
		select {
		case syncNotify <- struct{}{}:
		default:
		}
	}

	// doSyncWithBackoff performs a synchronising operation with a backoff strategy.
	doSyncWithBackoff := func() {
		if err := backoff.Retry(
			d.doSync,
			backoff.WithContext(backoff.NewConstantBackOff(d.RetryInterval), d.ctx),
		); err != nil {
			log.Error("Sync L2 execution engine's block chain error", "error", err)
		}
	}

	// Call doSync() right away to catch up with the latest known L1 head.
	doSyncWithBackoff()

	for {
		select {
		case <-d.ctx.Done():
			return
		case <-syncNotify:
			doSyncWithBackoff()
		case <-d.l1HeadCh:
			reqSync()
		}
	}
}

// doSync fetches all `BlockProposed` events emitted from local
// L1 sync cursor to the L1 head, and then applies all corresponding
// L2 blocks into node's local blockchain.
func (d *Driver) doSync() error {
	// Check whether the application is closing.
	if d.ctx.Err() != nil {
		log.Warn("Driver context error", "error", d.ctx.Err())
		return nil
	}

	if err := d.l2ChainSyncer.Sync(); err != nil {
		log.Error("Process new L1 blocks error", "error", err)
		return err
	}

	return nil
}

// ChainSyncer returns the driver's chain syncer, this method
// should only be used for testing.
func (d *Driver) ChainSyncer() *chainSyncer.L2ChainSyncer {
	return d.l2ChainSyncer
}

// reportProtocolStatus reports some protocol status intervally.
func (d *Driver) reportProtocolStatus() {
	protocolConfigs, err := rpc.GetProtocolConfigs(d.rpc.TaikoL1, &bind.CallOpts{Context: d.ctx})
	if err != nil {
		log.Error("Failed to get protocol configs", "error", err)
		return
	}

	var (
		ticker       = time.NewTicker(protocolStatusReportInterval)
		maxNumBlocks = protocolConfigs.BlockMaxProposals
	)
	d.wg.Add(1)

	defer func() {
		ticker.Stop()
		d.wg.Done()
	}()

	for {
		select {
		case <-d.ctx.Done():
			return
		case <-ticker.C:
			vars, err := d.rpc.GetProtocolStateVariables(&bind.CallOpts{Context: d.ctx})
			if err != nil {
				log.Error("Failed to get protocol state variables", "error", err)
				continue
			}

			log.Info(
				"📖 Protocol status",
				"lastVerifiedBlockId", vars.B.LastVerifiedBlockId,
				"pendingBlocks", vars.B.NumBlocks-vars.B.LastVerifiedBlockId-1,
				"availableSlots", vars.B.LastVerifiedBlockId+maxNumBlocks-vars.B.NumBlocks,
			)
		}
	}
}

// exchangeTransitionConfigLoop keeps exchanging transition configs with the
// L2 execution engine.
func (d *Driver) exchangeTransitionConfigLoop() {
	ticker := time.NewTicker(exchangeTransitionConfigInterval)
	d.wg.Add(1)

	defer func() {
		ticker.Stop()
		d.wg.Done()
	}()

	for {
		select {
		case <-d.ctx.Done():
			return
		case <-ticker.C:
			tc, err := d.rpc.L2Engine.ExchangeTransitionConfiguration(d.ctx, &engine.TransitionConfigurationV1{
				TerminalTotalDifficulty: (*hexutil.Big)(common.Big0),
				TerminalBlockHash:       common.Hash{},
				TerminalBlockNumber:     0,
			})
			if err != nil {
				log.Error("Failed to exchange Transition Configuration", "error", err)
			} else {
				log.Debug("Exchanged transition config", "transitionConfig", tc)
			}
		}
	}
}

// Name returns the application name.
func (d *Driver) Name() string {
	return "driver"
}
