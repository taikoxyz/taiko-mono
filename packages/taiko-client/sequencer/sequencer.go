package sequencer

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"net/http"
	"sync"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	preconfblocks "github.com/taikoxyz/taiko-mono/packages/taiko-client/driver/preconf_blocks"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/config"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/lookahead"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/utils"
	builder "github.com/taikoxyz/taiko-mono/packages/taiko-client/proposer/transaction_builder"
)

var (
	batchesToProposeChSize = 6
)

type Batch struct {
	headers       []*types.Header
	txLists       []types.Transactions
	anchorBlockId uint64
}

type SequencerStatus int

// status enum
const (
	// SequencerStatusUnknown is the unknown status of the sequencer - we haven't gotten lookahead yet.
	SequencerStatusUnknown SequencerStatus = iota
	// SequencerStatusInactive means we are not in the sequencing window
	SequencerStatusInactive SequencerStatus = iota
	// SequencerStatusSequencing means we can sequence blocks but not propose them yet
	SequencerStatusSequencing SequencerStatus = iota
	// SequencerStatusProposing means we can  propose blocks but are past sequencing them
	SequencerStatusProposing SequencerStatus = iota
	// SequencerStatusSequencingAndProposing means we can sequence and propose
	SequencerStatusSequencingAndProposing SequencerStatus = iota
)

func (s SequencerStatus) String() string {
	switch s {
	case SequencerStatusUnknown:
		return "Unknown"
	case SequencerStatusInactive:
		return "Inactive"
	case SequencerStatusSequencing:
		return "Sequencing"
	case SequencerStatusProposing:
		return "Proposing"
	case SequencerStatusSequencingAndProposing:
		return "SequencingAndProposing"
	default:
		return "Unknown"
	}
}

// Sequencer sequences L2 preconf blocks and proposes them onchain
type Sequencer struct {
	*Config
	rpc *rpc.Client

	ctx context.Context
	wg  sync.WaitGroup

	lookahead          *lookahead.Lookahead
	lookaheadMutex     sync.Mutex
	batchesToProposeCh chan *Batch

	protocolConfigs config.ProtocolConfigs
	chainConfig     *config.ChainConfig

	txmgrSelector *utils.TxMgrSelector
	txBuilder     builder.ProposeBlocksTransactionBuilder

	status      SequencerStatus
	statusCh    chan SequencerStatus
	statusMutex sync.Mutex

	batches      []*Batch
	batchesMutex sync.Mutex

	anchorBlockId uint64
}

// InitFromCli initializes the given sequencer instance based on the command line flags.
func (s *Sequencer) InitFromCli(ctx context.Context, c *cli.Context) error {
	cfg, err := NewConfigFromCliContext(c)
	if err != nil {
		return err
	}

	return s.InitFromConfig(ctx, cfg)
}

// InitFromConfig initializes the sequencer instance based on the given configurations.
func (s *Sequencer) InitFromConfig(ctx context.Context, cfg *Config) (err error) {
	s.ctx = ctx
	s.Config = cfg

	s.lookahead = &lookahead.Lookahead{}
	s.lookaheadMutex = sync.Mutex{}

	s.status = SequencerStatusUnknown
	s.statusCh = make(chan SequencerStatus, 1)
	s.statusMutex = sync.Mutex{}

	s.batchesToProposeCh = make(chan *Batch, batchesToProposeChSize)

	if s.rpc, err = rpc.NewClient(s.ctx, cfg.ClientConfig); err != nil {
		return err
	}

	// Protocol configs
	if s.protocolConfigs, err = s.rpc.GetProtocolConfigs(&bind.CallOpts{Context: s.ctx}); err != nil {
		return fmt.Errorf("failed to get protocol configs: %w", err)
	}

	txMgr, err := txmgr.NewSimpleTxManager(
		"sequencer",
		log.Root(),
		&metrics.TxMgrMetrics,
		*cfg.TxmgrConfigs,
	)

	if err != nil {
		return err
	}

	s.chainConfig = config.NewChainConfig(
		s.rpc.L2.ChainID,
		s.rpc.OntakeClients.ForkHeight,
		s.rpc.PacayaClients.ForkHeight,
	)

	s.txmgrSelector = utils.NewTxMgrSelector(txMgr, nil, nil)

	s.txBuilder = builder.NewBuilderWithFallback(
		s.rpc,
		s.L1ProposerPrivKey,
		cfg.L2SuggestedFeeRecipient,
		cfg.TaikoL1Address,
		cfg.TaikoWrapperAddress,
		cfg.ProverSetAddress,
		cfg.ProposeBlockTxGasLimit,
		s.chainConfig,
		s.txmgrSelector,
		false, // TODO
		true,  // TODO
		false, // TODO
	)

	config.ReportProtocolConfigs(s.protocolConfigs)

	return nil
}

// Start starts the sequencer instance.
func (s *Sequencer) Start() error {
	// compare l1 origin and l2 head, get difference, and propose those sequenced but unproposed blocks
	if err := s.resync(); err != nil {
		return err
	}

	go s.anchorLoop()
	go s.statusLoop()
	go s.cacheLookaheadLoop()
	go s.sequenceEventLoop()
	go s.proposeEventLoop()

	return nil
}

func (s *Sequencer) anchorLoop() {
	s.wg.Add(1)
	defer s.wg.Done()

	// subscribe to new blocks from L1 WS endpoint
	newHeads := make(chan (*types.Header), 1024)

	sub, err := s.rpc.L1.SubscribeNewHead(s.ctx, newHeads)
	if err != nil {
		log.Error("Failed to subscribe to new head", "error", err)
		return
	}

	// reanchor immediately

	latestHead, err := s.rpc.L1.HeaderByNumber(s.ctx, nil)
	if err != nil {
		return
	}

	if err := s.reanchorIfNecessary(latestHead); err != nil {
		log.Error("Failed to reanchor", "error", err)
	}

	// TODO: resubscribe
	for {
		select {
		case <-s.ctx.Done():
			return
		case <-sub.Err():
			return
		case head := <-newHeads:
			log.Info("New L1 block", "blockID", head.Number.String())

			if err := s.reanchorIfNecessary(head); err != nil {
				log.Error("Failed to anchor", "error", err)
			}
		}
	}
}

func (s *Sequencer) reanchorIfNecessary(head *types.Header) error {
	// first‑time initialization
	if s.anchorBlockId == 0 {
		newAnchor := head.Number.Uint64() - s.AnchorBlockOffset
		log.Info("Initial reanchor to", "blockID", newAnchor)
		s.anchorBlockId = newAnchor
		return nil
	}

	maxOffset := s.protocolConfigs.MaxAnchorHeightOffset()
	headNum := head.Number.Uint64()

	// compute the block at which the anchor truly expires:
	expireAt := s.anchorBlockId + maxOffset

	// compute the threshold where we want to *pre‑emptively* propose:
	threshold := expireAt - s.AnchorBlockOffset

	// if we've reached (or passed) that threshold, trigger a proposal
	if headNum >= threshold {
		newAnchor := headNum - s.AnchorBlockOffset
		log.Info(
			"Anchor nearing expiry, reanchoring and flushing latest batch",
			"oldAnchor", s.anchorBlockId,
			"newAnchor", newAnchor,
			"expireAt", expireAt,
			"threshold", threshold,
			"head", headNum,
		)
		s.anchorBlockId = newAnchor

		// enqueue the latest in‑flight batch for proposal
		s.batchesMutex.Lock()
		for _, batch := range s.batches {
			log.Info("Sending all batches to be proposed")
			s.batchesToProposeCh <- batch
		}

		s.batches = nil

		s.batchesMutex.Unlock()
	} else {
		log.Info(
			"Anchor still healthy",
			"anchorBlockId", s.anchorBlockId,
			"expireAt", expireAt,
			"threshold(pre‑empt)", threshold,
			"head", headNum,
		)
	}

	return nil
}

func (s *Sequencer) resync() error {
	log.Info("Resync checking L1 origin and L2 head")
	l1Origin, err := s.rpc.L2.HeadL1Origin(s.ctx)
	if err != nil {
		return err
	}

	l2Head, err := s.rpc.L2.BlockByNumber(s.ctx, nil)
	if err != nil {
		return err
	}

	l2HeadBlockID := l2Head.NumberU64()

	l1OriginBlockID := l1Origin.BlockID.Uint64()
	if l1OriginBlockID == l2HeadBlockID {
		log.Info("L1 origin and L2 head are the same, no resync needed")
		return nil
	}

	// get all blocks between l1Origin and l2Head, propose them
	log.Info("Resyncing L1 origin and L2 head", "l1Origin", l1OriginBlockID, "l2Head", l2HeadBlockID)

	// get the blocks between l1Origin and l2Head

	blocks, err := s.fetchNBlocks(l1OriginBlockID+1, l2HeadBlockID)
	if err != nil {
		return fmt.Errorf("failed to fetch blocks: %w", err)
	}

	willReorg := false

	// check each blocks anchorBlockId by decoding first transaction in the transactions array
	// into the TaikoAnchor.anchorV3
	for _, block := range blocks {
		if len(block.Transactions()) == 0 {
			log.Warn("Block has no transactions, skipping")
			continue
		}
		tx := block.Transactions()[0]

		input := tx.Data()

		if method, err := encoding.TaikoAnchorABI.MethodById(input[:4]); err == nil && method.Name == "anchorV3" {
			var args struct {
				AnchorBlockId   uint64
				AnchorStateRoot [32]byte
				ParentGasUsed   uint32
				BaseFeeConfig   *pacayaBindings.LibSharedDataBaseFeeConfig
				SignalSlots     [][32]byte
			}
			if err := encoding.TaikoAnchorABI.UnpackIntoInterface(&args, "anchorV3", input[4:]); err != nil {
				return fmt.Errorf("unpack anchorV3 args: %w", err)
			}

			// check anchorBlockID expiry
			if args.AnchorBlockId+uint64(s.protocolConfigs.MaxAnchorHeightOffset()) >= l2HeadBlockID {
				// needs to be re-anchored, will be a reorg.
				// TODO
				log.Warn("Anchor block ID expired on resync batch, needs to be re-anchored",
					"anchorBlockId", args.AnchorBlockId,
					"l2HeadBlockID", l2HeadBlockID,
				)

				willReorg = true
				break
			}
		}
	}

	// TODO: re-anchor, resubmit.

	log.Info("Resync TODO", "willReorg", willReorg)

	return nil
}

func (s *Sequencer) fetchNBlocks(start, end uint64) ([]*types.Block, error) {
	blocks := make([]*types.Block, 0)

	for i := start; i <= end; i++ {
		block, err := s.rpc.L2.BlockByNumber(s.ctx, big.NewInt(int64(i)))
		if err != nil {
			return nil, fmt.Errorf("failed to fetch block %d: %w", i, err)
		}

		blocks = append(blocks, block)
	}

	return blocks, nil
}

// Close closes the sequencer instance.
func (s *Sequencer) Close(_ context.Context) {
	// close propose ch
	close(s.batchesToProposeCh)

	s.wg.Wait()
}

func (s *Sequencer) statusLoop() {
	s.wg.Add(1)
	defer s.wg.Done()

	for {
		select {
		case <-s.ctx.Done():
			return
		case newStatus := <-s.statusCh:
			s.statusMutex.Lock()
			oldStatus := s.status
			s.status = newStatus

			log.Info("Sequencer status updated",
				"oldStatus", oldStatus.String(),
				"newStatus", newStatus.String(),
			)

			s.statusMutex.Unlock()

			switch newStatus {
			case SequencerStatusProposing:
				s.flushPendingBatches()
			case SequencerStatusSequencing:
				if err := s.resync(); err != nil {
					log.Error("Failed to resync", "error", err)
				}
			}

		}
	}

}

// flushPendingBatches sends every batch we’ve accumulated to the propose channel
// and clears the in‑memory slice so we don’t re‑submit them.
func (s *Sequencer) flushPendingBatches() {
	s.batchesMutex.Lock()
	defer s.batchesMutex.Unlock()

	if len(s.batches) == 0 {
		log.Info("No pending batches to flush on proposing transition")
		return
	}

	log.Info("Flushing pending batches", "batchCount", len(s.batches))
	for _, batch := range s.batches {
		s.batchesToProposeCh <- batch
	}

	// drop them from memory
	s.batches = make([]*Batch, 0)
}

// cacheLookaheadLoop keeps updating the lookahead info to detemine the eligiblity of the
// sequencer.
func (s *Sequencer) cacheLookaheadLoop() {
	s.lookaheadMutex.Lock()
	defer s.lookaheadMutex.Unlock()

	ticker := time.NewTicker(time.Second * time.Duration(s.rpc.L1Beacon.SecondsPerSlot) / 3)
	s.wg.Add(1)

	defer func() {
		ticker.Stop()
		s.wg.Done()
	}()

	var (
		seenBlockNumber uint64 = 0
		lastSlot        uint64 = 0
		opWin                  = lookahead.NewOpWindow(
			s.PreconfHandoverSkipSlots,
			s.rpc.L1Beacon.SlotsPerEpoch,
		)
	)

	cacheLookahead := func(currentEpoch, currentSlot uint64) error {
		var (
			slotInEpoch      = s.rpc.L1Beacon.SlotInEpoch()
			slotsLeftInEpoch = s.rpc.L1Beacon.SlotsPerEpoch - s.rpc.L1Beacon.SlotInEpoch()
		)

		latestSeenBlockNumber, err := s.rpc.L1.BlockNumber(s.ctx)
		if err != nil {
			log.Error("Failed to fetch the latest L1 head for lookahead", "error", err)

			return err
		}

		if latestSeenBlockNumber == seenBlockNumber {
			// Leave some grace period for the block to arrive.
			if lastSlot != currentSlot &&
				uint64(time.Now().UTC().Unix())-s.rpc.L1Beacon.TimestampOfSlot(currentSlot) > 6 {
				log.Warn(
					"Lookahead possible missed slot detected",
					"currentSlot", currentSlot,
					"latestSeenBlockNumber", latestSeenBlockNumber,
				)

				lastSlot = currentSlot
			}

			return errors.New("no new L1 head")
		}

		lastSlot = currentSlot
		seenBlockNumber = latestSeenBlockNumber

		currOp, err := s.rpc.GetPreconfWhiteListOperator(nil)
		if err != nil {
			log.Warn("Could not fetch current operator", "err", err)

			return err
		}

		nextOp, err := s.rpc.GetNextPreconfWhiteListOperator(nil)
		if err != nil {
			log.Warn("Could not fetch next operator", "err", err)

			return err
		}

		// push into our 3‑epoch ring
		opWin.Push(currentEpoch, currOp, nextOp)

		// Push next epoch (nextOp becomes currOp at next epoch)
		opWin.Push(currentEpoch+1, nextOp, common.Address{}) // we don't know next-next-op, safe to leave zero

		var (
			currRanges = opWin.SequencingWindowSplit(s.PreconfOperatorAddress, true)
			nextRanges = opWin.SequencingWindowSplit(s.PreconfOperatorAddress, false)
		)

		s.lookahead = &lookahead.Lookahead{
			CurrOperator: currOp,
			NextOperator: nextOp,
			CurrRanges:   currRanges,
			NextRanges:   nextRanges,
			UpdatedAt:    time.Now().UTC(),
		}

		log.Info(
			"Lookahead information refreshed",
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

	var (
		currentEpoch = s.rpc.L1Beacon.CurrentEpoch()
		currentSlot  = s.rpc.L1Beacon.CurrentSlot()
	)
	// run once initially, so we dont have to wait for ticker
	if err := cacheLookahead(
		currentEpoch,
		currentSlot,
	); err != nil {
		log.Warn("Failed to cache initial lookahead", "error", err)
	}

	s.statusCh <- s.updateStatus(s.PreconfOperatorAddress, currentSlot)

	for {
		select {
		case <-s.ctx.Done():
			return
		case <-ticker.C:
			var (
				currentEpoch = s.rpc.L1Beacon.CurrentEpoch()
				currentSlot  = s.rpc.L1Beacon.CurrentSlot()
			)

			if err := cacheLookahead(currentEpoch, currentSlot); err != nil {
				log.Warn("Failed to cache lookahead", "error", err)
			}

			s.statusCh <- s.updateStatus(s.PreconfOperatorAddress, currentSlot)

			log.Info("Status updated",
				"status", s.status.String(),
				"currentSlot", currentSlot,
				"currentEpoch", currentEpoch,
				"slotsLeftInEpoch", s.rpc.L1Beacon.SlotsPerEpoch-s.rpc.L1Beacon.SlotInEpoch(),
				"slotInEpoch", s.rpc.L1Beacon.SlotInEpoch(),
				"currOp", s.lookahead.CurrOperator.Hex(),
				"nextOp", s.lookahead.NextOperator.Hex(),
				"currRanges", s.lookahead.CurrRanges,
				"nextRanges", s.lookahead.NextRanges,
			)

		}
	}
}

func (s *Sequencer) updateStatus(feeRecipient common.Address, globalSlot uint64) SequencerStatus {
	s.lookaheadMutex.Lock()
	la := s.lookahead
	s.lookaheadMutex.Unlock()

	if la == nil || s.rpc.L1Beacon == nil {
		log.Warn("Lookahead information not initialized, disallowing by default")
		return SequencerStatusUnknown
	}

	if feeRecipient == la.CurrOperator {
		// early‐epoch: can both sequence & propose
		for _, r := range la.CurrRanges {
			if globalSlot >= r.Start && globalSlot < r.End {
				return SequencerStatusSequencingAndProposing
			}
		}
		// late‐epoch: only sequence
		for _, r := range la.NextRanges {
			if globalSlot >= r.Start && globalSlot < r.End {
				return SequencerStatusSequencing
			}
		}
	}

	// 2) next operator
	if feeRecipient == la.NextOperator {
		// late‐epoch: only propose (to start next epoch)
		for _, r := range la.NextRanges {
			if globalSlot >= r.Start && globalSlot < r.End {
				return SequencerStatusProposing
			}
		}
	}

	// If not in any range
	log.Debug(
		"Slot out of sequencing window",
		"slot", globalSlot,
		"currRanges", la.CurrRanges,
		"nextRanges", la.NextRanges,
	)

	return SequencerStatusInactive
}

func (s *Sequencer) sequenceEventLoop() {
	s.wg.Add(1)
	defer s.wg.Done()

	t := time.NewTicker(s.L2BlockTime)

	hasSlept := false
	for {
		select {
		case <-s.ctx.Done():
			return
		case <-t.C:
			switch s.status {
			case SequencerStatusUnknown:
				hasSlept = false
				log.Warn("Sequencer status unknown, skipping sequence")
				continue
			case SequencerStatusInactive:
				hasSlept = false
				log.Warn("Sequencer not in sequencing window, skipping sequence")
				continue
			case SequencerStatusProposing:
				hasSlept = false
				log.Warn("Sequencer able to propose but not sequence, skipping sequence")
				continue
			default:
				if !hasSlept {
					log.Info("Starting sequencing, sleeping for handover buffer",
						"buffer", s.HandoverBufferSeconds.String(),
					)
					time.Sleep(s.HandoverBufferSeconds)

					hasSlept = true
				}

				if err := s.sequence(false); err != nil {
					log.Error("Failed to sequence batch", "error", err)
				}
			}
		}
	}
}

func (s *Sequencer) sequence(endOfSequencing bool) error {
	s.batchesMutex.Lock()
	defer s.batchesMutex.Unlock()

	if s.status != SequencerStatusSequencing && s.status != SequencerStatusSequencingAndProposing {
		log.Warn("Sequencer not in sequencing window, skipping sequence")
		return nil
	}

	log.Info("Sequence loop initiating")

	// fetch transcations from mempool
	preBuiltTxList, err := s.rpc.GetPoolContent(
		s.ctx,
		s.PreconfOperatorAddress,
		s.protocolConfigs.BlockMaxGasLimit(),
		rpc.BlockMaxTxListBytes,
		[]common.Address{},
		1,
		0,
		s.chainConfig,
		s.protocolConfigs.BaseFeeConfig(),
	)
	if err != nil {
		return fmt.Errorf("failed to fetch transaction pool content: %w", err)
	}

	if len(preBuiltTxList) == 0 {
		log.Warn("No transactions in the pool, skipping sequence")
		return nil
	}

	log.Info("Pool content", "txCount", len(preBuiltTxList[0].TxList))

	// Extract the transaction lists from the pre-built transaction lists information.
	encodedCompressed, err := utils.EncodeAndCompressTxList(preBuiltTxList[0].TxList)
	if err != nil {
		return err
	}

	l2Head, err := s.rpc.L2.HeaderByNumber(s.ctx, nil)
	if err != nil {
		return fmt.Errorf("failed to get L2 head: %w", err)
	}

	timestamp := uint64(time.Now().UTC().Unix())
	// get base fee per gas
	baseFeePerGas, err := s.rpc.CalculateBaseFee(
		s.ctx,
		l2Head,
		true,
		s.protocolConfigs.BaseFeeConfig(),
		timestamp,
	)
	if err != nil {
		return fmt.Errorf("failed to get base fee per gas: %w", err)
	}

	extraData := common.Hex2Bytes("000000000000000000000000000000000000000000000000000000000000004b")

	executableData := &preconfblocks.ExecutableData{
		ParentHash:    l2Head.Hash(),
		FeeRecipient:  s.PreconfOperatorAddress,
		Number:        l2Head.Number.Uint64() + 1,
		GasLimit:      uint64(s.protocolConfigs.BlockMaxGasLimit()),
		Timestamp:     timestamp,
		Transactions:  encodedCompressed,
		ExtraData:     extraData,
		BaseFeePerGas: baseFeePerGas.Uint64(),
	}

	b := preconfblocks.BuildPreconfBlockRequestBody{
		ExecutableData:  executableData,
		EndOfSequencing: &endOfSequencing,
	}

	marshalled, err := json.Marshal(b)
	if err != nil {
		return err
	}

	body := bytes.NewReader(marshalled)

	req, err := http.NewRequest(http.MethodPost,
		fmt.Sprintf("%v/%v", s.PreconfBlockServerAPIURL, "/preconfBlocks"),
		body,
	)

	if err != nil {
		return err
	}

	log.Info("Sending request to soft block server",
		"parentHash", executableData.ParentHash.Hex(),
		"feeRecipient", executableData.FeeRecipient.Hex(),
		"number", executableData.Number,
		"gasLimit", executableData.GasLimit,
		"timestamp", executableData.Timestamp,
		"transactions", len(executableData.Transactions),
		"extraData", common.Bytes2Hex(executableData.ExtraData),
		"baseFeePerGas", executableData.BaseFeePerGas,
		"endOfSequencing", endOfSequencing,
	)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("failed to get preconf block, status code: %d", resp.StatusCode)
	}

	defer resp.Body.Close()

	var header *types.Header
	if err := json.NewDecoder(resp.Body).Decode(&header); err != nil {
		return fmt.Errorf("failed to decode preconf block header: %w", err)
	}

	log.Info("Response from soft block server",
		"blockID", header.Number.String(),
		"parentHash", header.ParentHash.Hex(),
		"feeRecipient", header.Coinbase.Hex(),
		"number", header.Number.String(),
		"gasLimit", header.GasLimit,
		"timestamp", header.Time,
		"extraData", common.Bytes2Hex(header.Extra),
		"baseFeePerGas", header.BaseFee.Uint64(),
		"endOfSequencing", endOfSequencing,
		"anchorBlockID", s.anchorBlockId,
	)

	if len(s.batches) == 0 {
		log.Info("Creating new batch for block")
		s.batches = append(s.batches, &Batch{
			headers:       []*types.Header{header},
			txLists:       []types.Transactions{preBuiltTxList[0].TxList},
			anchorBlockId: s.anchorBlockId,
		})
	} else {
		lastBatch := s.batches[len(s.batches)-1]
		if len(lastBatch.headers) < s.protocolConfigs.MaxBlocksPerBatch() {
			log.Info("Adding block to last batch", "blockID", header.Number.String(), "headers", len(lastBatch.headers))

			lastBatch.headers = append(lastBatch.headers, header)
			lastBatch.txLists = append(lastBatch.txLists, preBuiltTxList[0].TxList)
		} else {
			log.Info("Creating new batch for block", "blockID", header.Number.String(), "headersOfLastBatch", len(lastBatch.headers))
			s.batches = append(s.batches, &Batch{
				headers:       []*types.Header{header},
				txLists:       []types.Transactions{preBuiltTxList[0].TxList},
				anchorBlockId: s.anchorBlockId,
			})
		}
	}

	// if we have enough headers in the last batch, send it to propose
	if len(s.batches[len(s.batches)-1].headers) == s.protocolConfigs.MaxBlocksPerBatch() {
		log.Info("Sending batch to propose", "blockID", header.Number.String())

		s.batchesToProposeCh <- s.batches[len(s.batches)-1]
		s.batches = s.batches[:len(s.batches)-1]
	}

	return nil
}

func (s *Sequencer) proposeEventLoop() {
	s.wg.Add(1)
	defer s.wg.Done()

	for {
		select {
		case <-s.ctx.Done():
			return
		case batch := <-s.batchesToProposeCh:
			log.Info("Proposing batch")

			if err := s.proposeBatch(batch); err != nil {
				log.Error("Failed to propose batch", "error", err)
			}
		}
	}
}

func (s *Sequencer) proposeBatch(batch *Batch) error {
	// Wait until L2 execution engine is synced at first.
	if err := s.rpc.WaitTillL2ExecutionEngineSynced(s.ctx); err != nil {
		return fmt.Errorf("failed to wait until L2 execution engine synced: %w", err)
	}

	if len(batch.txLists) == 0 {
		return errors.New("empty batch")
	}

	// TODO: split batch
	if len(batch.txLists) > s.protocolConfigs.MaxBlocksPerBatch() {
		return fmt.Errorf(
			"batch size %d is greater than max batch size %d",
			len(batch.headers),
			s.protocolConfigs.MaxBlocksPerBatch(),
		)
	}

	var txs uint64

	for _, txList := range batch.txLists {
		txs += uint64(len(txList))
	}

	forcedInclusion, minTxsPerForcedInclusion, err := s.rpc.GetForcedInclusionPacaya(s.ctx)
	if err != nil {
		return fmt.Errorf("failed to fetch forced inclusion: %w", err)
	}

	if forcedInclusion == nil {
		log.Info("No forced inclusion", "proposer", s.PreconfOperatorAddress.Hex())
	} else {
		log.Info(
			"Forced inclusion",
			"proposer", s.PreconfOperatorAddress.Hex(),
			"blobHash", common.BytesToHash(forcedInclusion.BlobHash[:]),
			"feeInGwei", forcedInclusion.FeeInGwei,
			"createdAtBatchId", forcedInclusion.CreatedAtBatchId,
			"blobByteOffset", forcedInclusion.BlobByteOffset,
			"blobByteSize", forcedInclusion.BlobByteSize,
			"minTxsPerForcedInclusion", minTxsPerForcedInclusion,
		)
	}

	state, err := s.rpc.GetProtocolStateVariablesPacaya(&bind.CallOpts{Context: s.ctx})
	if err != nil {
		return fmt.Errorf("failed to fetch protocol state variables: %w", err)
	}

	latestBatch, err := s.rpc.GetBatchByID(
		s.ctx,
		new(big.Int).SetUint64(state.Stats2.NumBatches-1),
	)
	if err != nil {
		return fmt.Errorf("failed to fetch batch by ID: %w", err)
	}

	lastBlockTimestamp := batch.headers[len(batch.headers)-1].Time

	txCandidate, err := s.txBuilder.BuildPacaya(
		s.ctx,
		batch.txLists,
		forcedInclusion,
		minTxsPerForcedInclusion,
		latestBatch.MetaHash,
		batch.anchorBlockId,
		lastBlockTimestamp,
		batch.headers,
	)
	if err != nil {
		log.Error("Failed to build TaikoInbox.proposeBatch transaction", "error", encoding.TryParsingCustomError(err))
		return err
	}

	if err := s.sendTx(txCandidate); err != nil {
		log.Error("Failed to send TaikoInbox.proposeBatch transaction", "error", encoding.TryParsingCustomError(err))
		return err
	}

	log.Info("📝 Propose blocks batch succeeded", "blocksInBatch", len(batch.txLists), "txs", txs)

	metrics.ProposerProposedTxListsCounter.Add(float64(len(batch.txLists)))
	metrics.ProposerProposedTxsCounter.Add(float64(txs))

	return nil
}

// sendTx is the function to send a transaction with a selected tx manager.
func (s *Sequencer) sendTx(txCandidate *txmgr.TxCandidate) error {
	txMgr, isPrivate := s.txmgrSelector.Select()
	receipt, err := txMgr.Send(s.ctx, *txCandidate)
	if err != nil {
		log.Warn(
			"Failed to send TaikoL1.proposeBlockV2 / TaikoInbox.proposeBatch transaction by tx manager",
			"isPrivateMempool", isPrivate,
			"error", encoding.TryParsingCustomError(err),
		)
		if isPrivate {
			s.txmgrSelector.RecordPrivateTxMgrFailed()
		}
		return err
	}

	if receipt.Status != types.ReceiptStatusSuccessful {
		return fmt.Errorf("failed to propose block: %s", receipt.TxHash.Hex())
	}

	return nil
}

// Name returns the application name.
func (s *Sequencer) Name() string {
	return "sequencer"
}
