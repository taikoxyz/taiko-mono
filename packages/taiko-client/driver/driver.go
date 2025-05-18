package driver

import (
	"context"
	"math/big"
	"sync"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum-optimism/optimism/op-node/p2p"
	"github.com/ethereum-optimism/optimism/op-node/rollup"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/beacon/engine"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/event"
	"github.com/ethereum/go-ethereum/log"
	"github.com/modern-go/reflect2"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	chainSyncer "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/chain_syncer"
	preconfBlocks "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/preconf_blocks"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/state"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/config"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

const (
	protocolStatusReportInterval     = 30 * time.Second
	exchangeTransitionConfigInterval = 1 * time.Minute
)

// Driver keeps the L2 execution engine's local block chain in sync with the TaikoL1
// contract.
type Driver struct {
	*Config
	rpc                *rpc.Client
	l2ChainSyncer      *chainSyncer.L2ChainSyncer
	preconfBlockServer *preconfBlocks.PreconfBlockAPIServer
	state              *state.State
	chainConfig        *config.ChainConfig
	protocolConfig     config.ProtocolConfigs

	l1HeadCh  chan *types.Header
	l1HeadSub event.Subscription

	// P2P network for preconfirmation block propagation
	p2pNode   *p2p.NodeP2P
	p2pSigner p2p.Signer
	p2pSetup  p2p.SetupP2P

	ctx context.Context
	wg  sync.WaitGroup
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

	if d.state, err = state.New(d.ctx, d.rpc); err != nil {
		return err
	}

	peers, err := d.rpc.L2.PeerCount(d.ctx)
	if err != nil {
		return err
	}

	if cfg.P2PSync && peers == 0 {
		log.Warn("P2P syncing enabled, but no connected peer found in L2 execution engine")
	}

	latestSeenProposalCh := make(chan *encoding.LastSeenProposal, 1024)
	if d.l2ChainSyncer, err = chainSyncer.New(
		d.ctx,
		d.rpc,
		d.state,
		cfg.P2PSync,
		cfg.P2PSyncTimeout,
		cfg.BlobServerEndpoint,
		latestSeenProposalCh,
	); err != nil {
		return err
	}

	d.l1HeadSub = d.state.SubL1HeadsFeed(d.l1HeadCh)
	d.chainConfig = config.NewChainConfig(
		d.rpc.L2.ChainID,
		d.rpc.OntakeClients.ForkHeight,
		d.rpc.PacayaClients.ForkHeight,
	)

	if d.protocolConfig, err = d.rpc.GetProtocolConfigs(&bind.CallOpts{Context: d.ctx}); err != nil {
		return err
	}

	config.ReportProtocolConfigs(d.protocolConfig)

	if d.PreconfBlockServerPort > 0 {
		// Initialize the preconfirmation block server.
		if d.preconfBlockServer, err = preconfBlocks.New(
			d.PreconfBlockServerCORSOrigins,
			d.PreconfBlockServerJWTSecret,
			d.PreconfOperatorAddress,
			d.TaikoL2Address,
			d.l2ChainSyncer.EventSyncer().BlocksInserterPacaya(),
			d.rpc,
			latestSeenProposalCh,
		); err != nil {
			return err
		}

		// Enable P2P network for preconfirmation block propagation.
		if cfg.P2PConfigs != nil && !cfg.P2PConfigs.DisableP2P {
			log.Info("Enabling P2P network", "configs", cfg.P2PConfigs)
			d.p2pSetup = cfg.P2PConfigs

			if d.p2pNode, err = p2p.NewNodeP2P(
				d.ctx,
				&rollup.Config{L1ChainID: d.rpc.L1.ChainID, L2ChainID: d.rpc.L2.ChainID, Taiko: true},
				log.Root(),
				d.p2pSetup,
				d.preconfBlockServer,
				nil,
				d.preconfBlockServer,
				metrics.P2PNodeMetrics,
				false,
			); err != nil {
				return err
			}

			log.Info("P2P node information", "Addrs", d.p2pNode.Host().Addrs(), "PeerID", d.p2pNode.Host().ID())

			if !reflect2.IsNil(d.Config.P2PSignerConfigs) {
				if d.p2pSigner, err = d.P2PSignerConfigs.SetupSigner(d.ctx); err != nil {
					return err
				}
			}

			d.preconfBlockServer.SetP2PNode(d.p2pNode)
			d.preconfBlockServer.SetP2PSigner(d.p2pSigner)
		}

		// Set the preconfirmation block server to the chain syncer.
		d.l2ChainSyncer.SetPreconfBlockServer(d.preconfBlockServer)
	}

	return nil
}

// Start starts the driver instance.
func (d *Driver) Start() error {
	go d.eventLoop()
	go d.reportProtocolStatus()
	go d.exchangeTransitionConfigLoop()

	// Start the preconfirmation block server if it is enabled.
	if d.preconfBlockServer != nil {
		go func() {
			if err := d.preconfBlockServer.Start(d.PreconfBlockServerPort); err != nil {
				log.Crit("Failed to start preconfirmation block server", "error", err)
			}
		}()

		go d.preconfBlockServer.LatestSeenProposalEventLoop(d.ctx)
	}

	if d.p2pNode != nil && d.p2pNode.Dv5Udp() != nil {
		log.Info("P2P starting discovery process")

		go d.p2pNode.DiscoveryProcess(
			d.ctx,
			log.Root(),
			&rollup.Config{L1ChainID: d.rpc.L1.ChainID, L2ChainID: d.rpc.L2.ChainID, Taiko: true},
			d.p2pSetup.TargetPeers(),
		)
	} else {
		log.Warn("P2P skipping discovery process")
	}

	go d.cacheLookaheadLoop()

	return nil
}

// Close closes the driver instance.
func (d *Driver) Close(_ context.Context) {
	d.l1HeadSub.Unsubscribe()
	d.state.Close()
	// Close the preconfirmation block server if it is enabled.
	if d.preconfBlockServer != nil {
		if err := d.preconfBlockServer.Shutdown(d.ctx); err != nil {
			log.Error("Failed to shutdown preconfirmation block server", "error", err)
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
	var (
		ticker          = time.NewTicker(protocolStatusReportInterval)
		maxNumProposals = d.protocolConfig.MaxProposals()
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
			l2Head, err := d.rpc.L2.BlockNumber(d.ctx)
			if err != nil {
				log.Error("Failed to fetch L2 head", "error", err)
				continue
			}

			if d.chainConfig.IsPacaya(new(big.Int).SetUint64(l2Head)) {
				d.reportProtocolStatusPacaya(maxNumProposals)
			} else {
				d.reportProtocolStatusOntake(maxNumProposals)
			}
		}
	}
}

// reportProtocolStatusPacaya reports some status for Pacaya protocol.
func (d *Driver) reportProtocolStatusPacaya(maxNumProposals uint64) {
	vars, err := d.rpc.GetProtocolStateVariablesPacaya(&bind.CallOpts{Context: d.ctx})
	if err != nil {
		log.Error("Failed to get protocol state variables", "error", err)
		return
	}

	log.Info(
		"📖 Protocol status",
		"lastVerifiedBacthID", vars.Stats2.LastVerifiedBatchId,
		"pendingBatchs", vars.Stats2.NumBatches-vars.Stats2.LastVerifiedBatchId-1,
		"availableSlots", vars.Stats2.LastVerifiedBatchId+maxNumProposals-vars.Stats2.NumBatches,
	)
}

// reportProtocolStatusOntake reports some status for Ontake protocol.
func (d *Driver) reportProtocolStatusOntake(maxNumProposals uint64) {
	_, slotB, err := d.rpc.OntakeClients.TaikoL1.GetStateVariables(&bind.CallOpts{Context: d.ctx})
	if err != nil {
		log.Error("Failed to get protocol state variables", "error", err)
		return
	}

	log.Info(
		"📖 Protocol status",
		"lastVerifiedBlockId", slotB.LastVerifiedBlockId,
		"pendingBlocks", slotB.NumBlocks-slotB.LastVerifiedBlockId-1,
		"availableSlots", slotB.LastVerifiedBlockId+maxNumProposals-slotB.NumBlocks,
	)
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

// cacheLookaheadLoop keeps updating the lookahead information for the preconfirmation block server, and
// checks if the operator is transitioning to being the sequencer. If it is, it makes sure
// it has seen an EndOfSequencing block. If it hasn't, it requests it via the p2p network
// which the currentOperator will return.
func (d *Driver) cacheLookaheadLoop() {
	if d.rpc.L1Beacon == nil || d.p2pNode == nil {
		log.Warn("`--l1.beacon` flag value is empty, skipping lookahead cache")
		return
	}

	ticker := time.NewTicker(time.Second * time.Duration(d.rpc.L1Beacon.SecondsPerSlot) / 3)
	d.wg.Add(1)

	defer func() {
		ticker.Stop()
		d.wg.Done()
	}()

	var (
		seenBlockNumber uint64 = 0
		lastSlot        uint64 = 0
		opWin                  = preconfBlocks.NewOpWindow(d.PreconfHandoverSkipSlots, d.rpc.L1Beacon.SlotsPerEpoch)
		wasSequencer    bool   = false
	)

	checkHandover := func(epoch, slot uint64) {
		if d.p2pNode == nil {
			return
		}

		err := d.preconfBlockServer.CheckLookaheadHandover(d.PreconfOperatorAddress, slot)
		isSequencer := err == nil

		if isSequencer && !wasSequencer {
			log.Info("Lookahead transitioning to sequencing for operator", "epoch", epoch, "slot", slot)

			hash, seen := d.preconfBlockServer.GetSequencingEndedForEpoch(epoch)
			if !seen {
				log.Info("Lookahead requesting end of sequencing for epoch", "epoch", epoch, "slot", slot)
				if err := d.p2pNode.GossipOut().PublishL2EndOfSequencingRequest(
					context.Background(),
					epoch,
				); err != nil {
					log.Warn(
						"Failed to publish end of sequencing request",
						"currentEpoch", epoch,
						"slot", slot,
						"error", err,
					)
				}
			} else {
				log.Info(
					"End of sequencing already seen",
					"epoch", epoch,
					"slot", slot,
					"hash", hash.Hex(),
				)
			}
		}

		wasSequencer = isSequencer
	}

	cacheLookahead := func(currentEpoch, currentSlot uint64) error {
		var (
			slotInEpoch      = d.rpc.L1Beacon.SlotInEpoch()
			slotsLeftInEpoch = d.rpc.L1Beacon.SlotsPerEpoch - d.rpc.L1Beacon.SlotInEpoch()
		)

		latestSeenBlockNumber, err := d.rpc.L1.BlockNumber(d.ctx)
		if err != nil {
			log.Error("Failed to fetch the latest L1 head for lookahead", "error", err)

			return err
		}

		if latestSeenBlockNumber == seenBlockNumber {
			// Leave some grace period for the block to arrive.
			if lastSlot != currentSlot &&
				uint64(time.Now().UTC().Unix())-d.rpc.L1Beacon.TimestampOfSlot(currentSlot) > 6 {
				log.Warn(
					"Lookahead possible missed slot detected",
					"currentSlot", currentSlot,
					"latestSeenBlockNumber", latestSeenBlockNumber,
				)

				lastSlot = currentSlot
			}

			return nil
		}

		lastSlot = currentSlot
		seenBlockNumber = latestSeenBlockNumber

		currOp, err := d.rpc.GetPreconfWhiteListOperator(nil)
		if err != nil {
			log.Warn("Could not fetch current operator", "err", err)

			return err
		}

		nextOp, err := d.rpc.GetNextPreconfWhiteListOperator(nil)
		if err != nil {
			log.Warn("Could not fetch next operator", "err", err)

			return err
		}

		l := d.preconfBlockServer.GetLookahead()
		// we dont need to update the lookahead on every slot, we just need to make sure we do it
		// once per epoch, since we push the next operator as the current range when we check.
		// so, this means we should use a reliable slot past 0 where the operator has no possible
		// way to change. mid-epooch works, so we use slot 16.
		if l == nil || l.LastEpochUpdated < currentEpoch && slotInEpoch >= 15 {
			// push into our 3‑epoch ring
			log.Debug("Pushing into window", "epoch", currentEpoch, "currOp", currOp.Hex(), "nextOp", nextOp.Hex())
			opWin.Push(currentEpoch, currOp, nextOp)

			// Push next epoch (nextOp becomes currOp at next epoch)
			log.Debug("Pushing into window", "epoch", currentEpoch+1, "currOp", nextOp.Hex(), "nextOp", common.Address{})
			opWin.Push(currentEpoch+1, nextOp, common.Address{}) // we don't know next-next-op, safe to leave zero

			var (
				currRanges = opWin.SequencingWindowSplit(d.PreconfOperatorAddress, true)
				nextRanges = opWin.SequencingWindowSplit(d.PreconfOperatorAddress, false)
			)

			d.preconfBlockServer.UpdateLookahead(&preconfBlocks.Lookahead{
				CurrOperator:     currOp,
				NextOperator:     nextOp,
				CurrRanges:       currRanges,
				NextRanges:       nextRanges,
				UpdatedAt:        time.Now().UTC(),
				LastEpochUpdated: currentEpoch,
			})

			log.Info(
				"Lookahead updated",
				"currentSlot", currentSlot,
				"currentEpoch", currentEpoch,
				"slotsLeftInEpoch", slotsLeftInEpoch,
				"slotInEpoch", slotInEpoch,
				"currOp", currOp.Hex(),
				"nextOp", nextOp.Hex(),
				"currRanges", currRanges,
				"nextRanges", nextRanges,
			)

			return nil
		}

		// otherwise, just log out information
		var (
			currRanges = opWin.SequencingWindowSplit(d.PreconfOperatorAddress, true)
			nextRanges = opWin.SequencingWindowSplit(d.PreconfOperatorAddress, false)
		)

		log.Info("Lookahead tick",
			"currentSlot", currentSlot,
			"currentEpoch", currentEpoch,
			"slotsLeftInEpoch", slotsLeftInEpoch,
			"slotInEpoch", slotInEpoch,
			"currOp", currOp.Hex(),
			"nextOp", nextOp.Hex(),
			"currRanges", currRanges,
			"nextRanges", nextRanges,
		)

		return nil
	}

	// run once initially, so we dont have to wait for ticker
	if err := cacheLookahead(
		d.rpc.L1Beacon.CurrentEpoch(),
		d.rpc.L1Beacon.CurrentSlot(),
	); err != nil {
		log.Warn("Failed to cache initial lookahead", "error", err)
	}

	checkHandover(d.rpc.L1Beacon.CurrentEpoch(), d.rpc.L1Beacon.CurrentSlot())

	for {
		select {
		case <-d.ctx.Done():
			return
		case <-ticker.C:
			var (
				currentEpoch = d.rpc.L1Beacon.CurrentEpoch()
				currentSlot  = d.rpc.L1Beacon.CurrentSlot()
			)

			if err := cacheLookahead(currentEpoch, currentSlot); err != nil {
				log.Warn("Failed to cache lookahead", "error", err)
			}

			checkHandover(currentEpoch, currentSlot)
		}
	}
}

// Name returns the application name.
func (d *Driver) Name() string {
	return "driver"
}
