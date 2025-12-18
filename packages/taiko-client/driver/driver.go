package driver

import (
	"context"
	"fmt"
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
	protocolStatusReportInterval            = 30 * time.Second
	exchangeTransitionConfigInterval        = 1 * time.Minute
	peerLoopReportInterval                  = 30 * time.Second
	defaultHandoverSkipSlots         uint64 = 4
)

// Driver keeps the L2 execution engine's local block chain in sync with the TaikoInbox
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

	// Handover config read from the preconf router
	handoverSkipSlots uint64
	// Last epoch when the handover config was reloaded
	lastConfigReloadEpoch uint64

	ctx    context.Context
	cancel context.CancelFunc
	wg     sync.WaitGroup
}

// InitFromCli initializes the given driver instance based on the command line flags.
func (d *Driver) InitFromCli(ctx context.Context, c *cli.Context) error {
	cfg, err := NewConfigFromCliContext(c)
	if err != nil {
		return fmt.Errorf("failed to create config from CLI context: %w", err)
	}

	return d.InitFromConfig(ctx, cfg)
}

// InitFromConfig initializes the driver instance based on the given configurations.
func (d *Driver) InitFromConfig(ctx context.Context, cfg *Config) (err error) {
	d.l1HeadCh = make(chan *types.Header, 1024)
	d.ctx, d.cancel = context.WithCancel(ctx)
	d.Config = cfg

	// Initialize handover config caching
	d.handoverSkipSlots = defaultHandoverSkipSlots
	d.lastConfigReloadEpoch = 0

	if d.rpc, err = rpc.NewClient(d.ctx, cfg.ClientConfig); err != nil {
		return fmt.Errorf("failed to create RPC client: %w", err)
	}

	if d.state, err = state.New(d.ctx, d.rpc); err != nil {
		return fmt.Errorf("failed to create driver state: %w", err)
	}

	peers, err := d.rpc.L2.PeerCount(d.ctx)
	if err != nil {
		return fmt.Errorf("failed to get L2 peer count: %w", err)
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
		return fmt.Errorf("failed to create L2 chain syncer: %w", err)
	}

	d.l1HeadSub = d.state.SubL1HeadsFeed(d.l1HeadCh)
	d.chainConfig = config.NewChainConfig(
		d.rpc.L2.ChainID,
		d.rpc.PacayaClients.ForkHeights.Ontake,
		d.rpc.PacayaClients.ForkHeights.Pacaya,
		d.rpc.ShastaClients.ForkTime,
	)

	if d.protocolConfig, err = d.rpc.GetProtocolConfigs(&bind.CallOpts{Context: d.ctx}); err != nil {
		return fmt.Errorf("failed to get protocol configs: %w", err)
	}

	config.ReportProtocolConfigs(d.protocolConfig)

	if d.PreconfBlockServerPort > 0 {
		// Initialize the preconfirmation block server.
		if d.preconfBlockServer, err = preconfBlocks.New(
			d.PreconfBlockServerCORSOrigins,
			d.PreconfBlockServerJWTSecret,
			d.PreconfOperatorAddress,
			d.TaikoAnchorAddress,
			d.l2ChainSyncer.EventSyncer().BlocksInserterPacaya(),
			d.l2ChainSyncer.EventSyncer().BlocksInserterShasta(),
			d.rpc,
			latestSeenProposalCh,
		); err != nil {
			return fmt.Errorf("failed to create preconf block server: %w", err)
		}
		log.Info("Preconf Operator Address", "PreconfOperatorAddress", d.PreconfOperatorAddress)

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
				return fmt.Errorf("failed to create P2P node: %w", err)
			}

			log.Info("P2P node information", "Addrs", d.p2pNode.Host().Addrs(), "PeerID", d.p2pNode.Host().ID())

			if !reflect2.IsNil(d.Config.P2PSignerConfigs) {
				if d.p2pSigner, err = d.P2PSignerConfigs.SetupSigner(d.ctx); err != nil {
					return fmt.Errorf("failed to setup P2P signer: %w", err)
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
		log.Info("Start P2P discovery process")

		go d.p2pNode.DiscoveryProcess(
			d.ctx,
			log.Root(),
			&rollup.Config{L1ChainID: d.rpc.L1.ChainID, L2ChainID: d.rpc.L2.ChainID, Taiko: true},
			d.p2pSetup.TargetPeers(),
		)

		go d.peerLoop(d.ctx)
	} else {
		log.Warn("Skip P2P discovery process")
	}

	go d.cacheLookaheadLoop()

	return nil
}

// Close closes the driver instance.
func (d *Driver) Close(_ context.Context) {
	if d.cancel != nil {
		d.cancel()
	}

	if d.l1HeadSub != nil {
		d.l1HeadSub.Unsubscribe()
	}
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
	// reqSync requests performing a synchronizing operation, won't block
	// if we are already synchronizing.
	reqSync := func() {
		select {
		case syncNotify <- struct{}{}:
		default:
		}
	}

	// doSyncWithBackoff performs a synchronizing operation with a backoff strategy.
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

// doSync fetches all `BatchProposed` events emitted from local
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
		return fmt.Errorf("failed to sync L2 chain: %w", err)
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
			d.reportStatus(maxNumProposals)
		}
	}
}

// reportStatus reports some status for Pacaya or Shasta protocol.
func (d *Driver) reportStatus(maxNumProposals uint64) {
	proposal, err := d.rpc.GetShastaProposalHash(&bind.CallOpts{Context: d.ctx}, common.Big1)
	if err != nil {
		log.Debug("Failed to get Shasta proposal hash", "error", err)
	}
	// If chain has forked into Shasta fork, report Shasta status instead.
	if proposal != (common.Hash{}) {
		d.reportProtocolStatusShasta()
		return
	}
	vars, err := d.rpc.GetProtocolStateVariablesPacaya(&bind.CallOpts{Context: d.ctx})
	if err != nil {
		log.Error("Failed to get protocol state variables", "error", err)
		return
	}

	log.Info(
		"📖 Pacaya protocol status",
		"lastVerifiedBatchID", vars.Stats2.LastVerifiedBatchId,
		"pendingBatchs", vars.Stats2.NumBatches-vars.Stats2.LastVerifiedBatchId-1,
		"availableSlots", vars.Stats2.LastVerifiedBatchId+maxNumProposals-vars.Stats2.NumBatches,
	)
}

// reportProtocolStatusShasta reports some status for Shasta protocol.
func (d *Driver) reportProtocolStatusShasta() {
	coreState, err := d.rpc.GetCoreStateShasta(&bind.CallOpts{Context: d.ctx})
	if err != nil {
		log.Debug("Failed to get Shasta Inbox core state", "error", err)
		return
	}

	log.Info(
		"📖 Shasta protocol status",
		"lastFinalizedProposalId", coreState.LastFinalizedProposalId,
		"lastFinalizedTimestamp", coreState.LastFinalizedTimestamp,
		"nextProposalID", coreState.NextProposalId,
	)
}

// exchangeTransitionConfigLoop keeps exchanging transition configs with the L2 execution engine.
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
		log.Warn("`--l1.beacon` flag value is empty, or `d.p2pNode` is nil, skipping lookahead cache")
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
		opWin                  = preconfBlocks.NewOpWindow(d.rpc.L1Beacon.SlotsPerEpoch)
		wasSequencer           = false
	)

	// Check if the operator is transitioning to being the sequencer, if so, will check
	// if it has seen the EndOfSequencing block of the current epoch. If it hasn't, will request it via the p2p network.
	checkHandover := func(epoch, slot uint64) {
		if d.p2pNode == nil {
			return
		}

		isSequencer := d.preconfBlockServer.CheckLookaheadHandover(d.PreconfOperatorAddress, slot) == nil

		if isSequencer && !wasSequencer {
			log.Info("Lookahead transitioning to sequencing for operator", "epoch", epoch, "slot", slot)

			hash, seen := d.preconfBlockServer.GetSequencingEndedForEpoch(epoch)
			if !seen {
				log.Info(
					"Lookahead requesting end of sequencing for epoch",
					"epoch", epoch,
					"slot", slot,
				)

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
				log.Info("End of sequencing already seen", "epoch", epoch, "slot", slot, "hash", hash.Hex())
			}
		}

		wasSequencer = isSequencer
	}

	// cacheLookahead caches the lookahead information for the preconfirmation block server.
	cacheLookahead := func(currentEpoch, currentSlot uint64) error {
		var (
			slotInEpoch      = d.rpc.L1Beacon.SlotInEpoch()
			slotsLeftInEpoch = d.rpc.L1Beacon.SlotsPerEpoch - d.rpc.L1Beacon.SlotInEpoch()
		)

		// Only read and update handover config at epoch transitions to avoid race conditions
		// where different nodes might read different configs during mid-epoch upgrades
		if currentEpoch > d.lastConfigReloadEpoch {
			log.Info(
				"Epoch transition detected, reloading handover config",
				"epoch", currentEpoch,
				"lastConfigReloadEpoch", d.lastConfigReloadEpoch,
			)

			routerConfig, err := d.rpc.GetPreconfRouterConfig(&bind.CallOpts{Context: d.ctx})
			if err != nil {
				log.Warn(
					"Failed to fetch preconf router config, keeping current handoverSkipSlots",
					"error", err,
					"currentHandoverSkipSlots", d.handoverSkipSlots,
				)
			} else {
				newHandoverSkipSlots := routerConfig.HandOverSlots.Uint64()
				if newHandoverSkipSlots != d.handoverSkipSlots {
					log.Info(
						"Updated handover config for new epoch",
						"epoch", currentEpoch,
						"oldHandoverSkipSlots", d.handoverSkipSlots,
						"newHandoverSkipSlots", newHandoverSkipSlots,
					)
					d.handoverSkipSlots = newHandoverSkipSlots
				}
			}

			d.lastConfigReloadEpoch = currentEpoch

			log.Info("Handover config reload complete", "lastConfigReloadEpoch", d.lastConfigReloadEpoch)
		}

		latestSeenBlockNumber, err := d.rpc.L1.BlockNumber(d.ctx)
		if err != nil {
			log.Error("Failed to fetch the latest L1 head for lookahead", "error", err)

			return fmt.Errorf("failed to fetch L1 head for lookahead: %w", err)
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

			return fmt.Errorf("failed to fetch current operator: %w", err)
		}

		nextOp, err := d.rpc.GetNextPreconfWhiteListOperator(nil)
		if err != nil {
			log.Warn("Could not fetch next operator", "err", err)

			return fmt.Errorf("failed to fetch next operator: %w", err)
		}

		lookahead := d.preconfBlockServer.GetLookahead()
		// We dont need to update the lookahead on every slot, we just need to make sure we do it
		// once per epoch, since we push the next operator as the current range when we check.
		// so, this means we should use a reliable slot past 0 where the operator has no possible
		// way to change. mid-epooch works, so we use slot 16.
		if lookahead == nil || slotInEpoch >= 2 {
			if currOp == d.PreconfOperatorAddress && nextOp == d.PreconfOperatorAddress {
				log.Info(
					"Pushing into window for current epoch as current and next operator",
					"epoch", currentEpoch,
					"currentSlot", currentSlot,
					"slotInEpoch", slotInEpoch,
					"currOp", currOp.Hex(),
					"nextOp", nextOp.Hex(),
				)
				opWin.Push(currentEpoch, currOp, nextOp) // push both ops in, we are current and next

				log.Info(
					"Pushing into window for next epoch as current operator",
					"epoch", currentEpoch+1,
					"currentSlot", currentSlot,
					"slotInEpoch", slotInEpoch,
					"currOp", nextOp.Hex(),
				)
				opWin.Push(currentEpoch+1, nextOp, common.Address{}) // next next op is safe to leave 0
			} else if currOp == d.PreconfOperatorAddress {
				log.Info(
					"Pushing into window for current epoch as current operator",
					"epoch", currentEpoch,
					"currentSlot", currentSlot,
					"slotInEpoch", slotInEpoch,
					"currOp", currOp.Hex(),
					"nextOp", nextOp.Hex(),
				)
				opWin.Push(currentEpoch, currOp, common.Address{})
			} else if nextOp == d.PreconfOperatorAddress {
				log.Info(
					"Pushing into window for current epoch as next operator",
					"epoch", currentEpoch,
					"currentSlot", currentSlot,
					"slotInEpoch", slotInEpoch,
					"currOp", currOp.Hex(),
					"nextOp", nextOp.Hex(),
				)
				opWin.Push(currentEpoch, common.Address{}, nextOp)

				log.Info(
					"Pushing into window for next epoch as current operator",
					"epoch", currentEpoch+1,
					"currentSlot", currentSlot,
					"slotInEpoch", slotInEpoch,
					"currOp", nextOp.Hex(),
				)
				opWin.Push(currentEpoch+1, nextOp, common.Address{}) // next next op is safe to leave 0
			}

			var (
				currRanges = opWin.SequencingWindowSplit(d.PreconfOperatorAddress, true, d.handoverSkipSlots)
				nextRanges = opWin.SequencingWindowSplit(d.PreconfOperatorAddress, false, d.handoverSkipSlots)
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

		// Otherwise, just log out lookahead information.
		var (
			currRanges = opWin.SequencingWindowSplit(d.PreconfOperatorAddress, true, d.handoverSkipSlots)
			nextRanges = opWin.SequencingWindowSplit(d.PreconfOperatorAddress, false, d.handoverSkipSlots)
		)

		log.Info(
			"Lookahead tick",
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

	// Run once initially, so we dont have to wait for ticker.
	if err := cacheLookahead(d.rpc.L1Beacon.CurrentEpoch(), d.rpc.L1Beacon.CurrentSlot()); err != nil {
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

// peerLoop runs a loop to log out peers information intervally.
func (d *Driver) peerLoop(ctx context.Context) {
	d.wg.Add(1)
	defer d.wg.Done()

	t := time.NewTicker(peerLoopReportInterval)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			log.Info("Peer loop context done, exiting")
			return
		case <-t.C:
			d.peerTick()
		}
	}
}

// peerTick logs out peers information.
func (d *Driver) peerTick() {
	if d.p2pNode == nil ||
		d.p2pNode.Dv5Local() == nil ||
		d.p2pNode.Dv5Local().Node() == nil {
		log.Warn("P2P node is nil, skipping peer loop report")
		return
	}

	peers := d.p2pNode.Host().Network().Peers()
	advertisedUDP := d.p2pNode.Dv5Local().Node().UDP()
	advertisedTCP := d.p2pNode.Dv5Local().Node().TCP()
	advertisedIP := d.p2pNode.Dv5Local().Node().IP()

	addrInfo := make([]string, 0, len(peers))
	for _, p := range peers {
		info := d.p2pNode.Host().Peerstore().PeerInfo(p)

		for _, addr := range info.Addrs {
			addrInfo = append(addrInfo, addr.String())
		}
	}

	log.Info(
		"Peer tick",
		"peersLen", len(peers),
		"peers", peers,
		"addrInfo", addrInfo,
		"id", d.p2pNode.Host().ID(),
		"advertisedUDP", advertisedUDP,
		"advertisedTCP", advertisedTCP,
		"advertisedIP", advertisedIP,
	)
}

// Name returns the application name.
func (d *Driver) Name() string {
	return "driver"
}
