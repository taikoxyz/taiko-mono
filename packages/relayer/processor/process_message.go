package processor

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log/slog"
	"math"
	"math/big"
	"strings"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/consensus/misc/eip1559"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/params"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/encoding"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/proof"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue"
)

var (
	zeroAddress          = common.HexToAddress("0x0000000000000000000000000000000000000000")
	errUnprocessable     = errors.New("message is unprocessable")
	errAlreadyProcessing = errors.New("already processing txHash")
)

// eventStatusFromMsgHash will check the event's msgHash/signal, and
// get it's on-chain current status.
func (p *Processor) eventStatusFromMsgHash(
	ctx context.Context,
	signal [32]byte,
) (relayer.EventStatus, error) {
	var eventStatus relayer.EventStatus

	ctx, cancel := context.WithTimeout(ctx, p.ethClientTimeout)

	defer cancel()

	messageStatus, err := p.destBridge.MessageStatus(&bind.CallOpts{
		Context: ctx,
	}, signal)
	if err != nil {
		return 0, errors.Wrap(err, "svc.destBridge.MessageStatus")
	}

	eventStatus = relayer.EventStatus(messageStatus)

	return eventStatus, nil
}

// processMessage prepares and calls `processMessage` on the bridge, given a
// message from the queue (from the indexer). It will
// generate a proof, or multiple proofs if hops are needed.
// it returns a boolean of whether we should requeue the message or not.
func (p *Processor) processMessage(
	ctx context.Context,
	msg queue.Message,
) (bool, uint64, error) {
	msgBody := &queue.QueueMessageSentBody{}
	if err := json.Unmarshal(msg.Body, msgBody); err != nil {
		return false, 0, errors.Wrap(err, "json.Unmarshal")
	}

	if msgBody.Event == nil {
		slog.Warn("empty msgBody", "id", msgBody.ID)

		return false, 0, errors.New("empty message body")
	}

	slog.Info("message received", "srcTxHash", msgBody.Event.Raw.TxHash.Hex())

	// check if we already processing this hash
	checkHash := func(hash common.Hash) error {
		p.processingTxHashMu.Lock()
		defer p.processingTxHashMu.Unlock()

		if _, ok := p.processingTxHashes[hash]; ok {
			slog.Warn("already processing txHash", "txhash", hash.Hex())
			return errAlreadyProcessing
		}

		p.processingTxHashes[hash] = true

		return nil
	}

	// if we are, we dont need to continue
	if err := checkHash(msgBody.Event.Raw.TxHash); err != nil {
		return false, 0, err
	}

	// otherwise, make sure when we exit, we remove this hash from being checked
	defer func(hash common.Hash) {
		p.processingTxHashMu.Lock()
		defer p.processingTxHashMu.Unlock()
		delete(p.processingTxHashes, hash)
	}(msgBody.Event.Raw.TxHash)

	if msgBody.TimesRetried >= p.maxMessageRetries {
		slog.Warn("max retries reached", "timesRetried", msgBody.TimesRetried)

		return false, msgBody.TimesRetried, nil
	}

	// we never want to process messages below a certain fee, if set.
	// return a nil error, and we will successfully acknowledge this.
	if p.minFeeToProcess != 0 && msgBody.Event.Message.Fee < p.minFeeToProcess {
		slog.Warn("minFeeToProcess not met",
			"minFeeToProcess", p.minFeeToProcess,
			"fee", msgBody.Event.Message.Fee,
			"srcTxHash", msgBody.Event.Raw.TxHash.Hex(),
		)

		return false, msgBody.TimesRetried, nil
	}

	// check message process eligibility before waiting for confirmations to process
	eventStatus, err := p.eventStatusFromMsgHash(ctx, msgBody.Event.MsgHash)
	if err != nil {
		return false, msgBody.TimesRetried, errors.Wrap(err, "p.eventStatusFromMsgHash")
	}

	if !canProcessMessage(
		ctx,
		eventStatus,
		msgBody.Event.Message.SrcOwner,
		p.relayerAddr,
		uint64(msgBody.Event.Message.GasLimit),
	) {
		return false, msgBody.TimesRetried, nil
	}

	if err := p.waitForConfirmations(ctx, msgBody.Event.Raw.TxHash, msgBody.Event.Raw.BlockNumber); err != nil {
		return false, msgBody.TimesRetried, err
	}

	// check paused status
	paused, err := p.destBridge.Paused(&bind.CallOpts{
		Context: ctx,
	})
	if err != nil {
		return false, msgBody.TimesRetried, err
	}

	// if paused, lets requeue
	if paused {
		return true, msgBody.TimesRetried, nil
	}

	// destQuotaManager is optional, it will not be set for L1-L2 bridging
	// but will be set for L2-L1 bridging.
	if p.destQuotaManager != nil {
		eventType, canonicalToken, amount, err := relayer.DecodeMessageData(
			msgBody.Event.Message.Data,
			msgBody.Event.Message.Value,
		)
		if err != nil {
			return false, msgBody.TimesRetried, err
		}

		// dont check quota for NFTs
		if eventType == relayer.EventTypeSendERC20 || eventType == relayer.EventTypeSendETH {
			// default to ETH (zero address) and msg value, overwrite if ERC20
			var tokenAddress common.Address = zeroAddress

			var value *big.Int = msgBody.Event.Message.Value

			if eventType == relayer.EventTypeSendERC20 {
				tokenAddress = canonicalToken.Address()
				value = amount
			}

			hasQuota, waitUntil, err := p.hasQuotaAvailable(ctx, tokenAddress, value)
			if err != nil {
				return false, msgBody.TimesRetried, err
			}

			if !hasQuota {
				// wait until quota available
				slog.Info("quota not available for token", "waitUntil", waitUntil)

				select {
				case <-ctx.Done():
					return false, msgBody.TimesRetried, ctx.Err()
				case <-time.After(time.Duration(int64(waitUntil)) * time.Second):
				}
			}
		}
	}

	encodedSignalProof, err := p.generateEncodedSignalProof(ctx, msgBody.Event)
	if err != nil {
		return false, msgBody.TimesRetried, err
	}

	_, err = p.sendProcessMessageCall(ctx, msgBody.ID, msgBody.Event, encodedSignalProof)
	if err != nil {
		return false, msgBody.TimesRetried, err
	}

	messageStatus, err := p.destBridge.MessageStatus(&bind.CallOpts{
		Context: ctx,
	}, msgBody.Event.MsgHash)
	if err != nil {
		return false, msgBody.TimesRetried, errors.Wrap(err, "p.destBridge.GetMessageStatus")
	}

	slog.Info(
		"updating message status",
		"status", relayer.EventStatus(messageStatus).String(),
		"occuredtxHash", msgBody.Event.Raw.TxHash.Hex(),
	)

	if messageStatus == uint8(relayer.EventStatusRetriable) {
		relayer.RetriableEvents.Inc()
	} else if messageStatus == uint8(relayer.EventStatusDone) {
		relayer.DoneEvents.Inc()
	}

	// internal will only be set if it's an actual queue message, not a targeted
	// transaction hash set via config flag.
	if msg.Internal != nil {
		// update message status
		if err := p.eventRepo.UpdateStatus(ctx, msgBody.ID, relayer.EventStatus(messageStatus)); err != nil {
			return false, msgBody.TimesRetried, err
		}
	}

	return false, msgBody.TimesRetried, nil
}

// generateEncodedSignalproof takes a MessageSent event and calls a
// proof generation service to generate a proof for the source call
// as well as any additional hops required.
func (p *Processor) generateEncodedSignalProof(ctx context.Context,
	event *bridge.BridgeMessageSent) ([]byte, error) {
	var encodedSignalProof []byte

	var err error

	var blockNum uint64 = event.Raw.BlockNumber

	// wait for srcChain => destChain header to sync if no hops,
	// or srcChain => hopChain => hopChain => hopChain => destChain if hops exist.
	if len(p.hops) > 0 {
		var hopEthClient ethClient = p.srcEthClient

		var hopChainID *big.Int

		for _, hop := range p.hops {
			event, err := p.waitHeaderSynced(ctx, hopEthClient, hop.chainID.Uint64(), blockNum)

			if err != nil {
				return nil, errors.Wrap(err, "p.waitHeaderSynced")
			}

			if err != nil {
				return nil, errors.Wrap(err, "hop.headerSyncer.GetSyncedSnippet")
			}

			blockNum = event.SyncedInBlockID

			hopEthClient = hop.ethClient

			hopChainID = hop.chainID
		}

		event, err := p.waitHeaderSynced(ctx, hopEthClient, hopChainID.Uint64(), blockNum)
		if err != nil {
			return nil, err
		}

		blockNum = event.SyncedInBlockID
	} else {
		if _, err := p.waitHeaderSynced(ctx, p.srcEthClient, p.destChainId.Uint64(), event.Raw.BlockNumber); err != nil {
			return nil, err
		}
	}

	hops := []proof.HopParams{}

	key, err := p.srcSignalService.GetSignalSlot(&bind.CallOpts{},
		event.Message.SrcChainId,
		event.Raw.Address,
		event.MsgHash,
	)

	if err != nil {
		return nil, err
	}

	// if we have no hops, this is strictly a srcChain => destChain message.
	// we can grab the latestBlockID, create a singular "hop" of srcChain => destChain,
	// and generate a proof.
	if len(p.hops) == 0 {
		latestBlockID, err := p.eventRepo.LatestChainDataSyncedEvent(
			ctx,
			p.destChainId.Uint64(),
			p.srcChainId.Uint64(),
		)
		if err != nil {
			return nil, err
		}

		hops = append(hops, proof.HopParams{
			ChainID:              p.destChainId,
			SignalServiceAddress: p.srcSignalServiceAddress,
			Blocker:              p.srcEthClient,
			Caller:               p.srcCaller,
			SignalService:        p.srcSignalService,
			Key:                  key,
			BlockNumber:          latestBlockID,
		})
	} else {
		// otherwise, we should just create the first hop in the array, we will append
		// the rest of the hops after.
		hops = append(hops, proof.HopParams{
			ChainID:              p.destChainId,
			SignalServiceAddress: p.srcSignalServiceAddress,
			Blocker:              p.srcEthClient,
			Caller:               p.srcCaller,
			SignalService:        p.srcSignalService,
			Key:                  key,
			BlockNumber:          blockNum,
		})
	}

	// if a hop is set, the proof service needs to generate an additional proof
	// for the signal service intermediary chain in between the source chain
	// and the destination chain.
	for _, hop := range p.hops {
		slog.Info(
			"adding hop",
			"hopChainId", hop.chainID.Uint64(),
			"hopSignalServiceAddress", hop.signalServiceAddress.Hex(),
		)

		block, err := hop.ethClient.BlockByNumber(
			ctx,
			new(big.Int).SetUint64(blockNum),
		)
		if err != nil {
			return nil, err
		}

		hopStorageSlotKey, err := hop.signalService.GetSignalSlot(&bind.CallOpts{
			Context: ctx,
		},
			hop.chainID.Uint64(),
			hop.taikoAddress,
			block.Root(),
		)
		if err != nil {
			return nil, errors.Wrap(err, "hopSignalService.GetSignalSlot")
		}

		hops = append(hops, proof.HopParams{
			ChainID:              hop.chainID,
			SignalServiceAddress: hop.signalServiceAddress,
			Blocker:              hop.ethClient,
			Caller:               hop.caller,
			SignalService:        hop.signalService,
			Key:                  hopStorageSlotKey,
			BlockNumber:          blockNum,
		})
	}

	encodedSignalProof, err = p.prover.EncodedSignalProofWithHops(
		ctx,
		hops,
	)

	if err != nil {
		slog.Error("error encoding hop proof",
			"srcChainID", event.Message.SrcChainId,
			"destChainID", event.Message.DestChainId,
			"txHash", event.Raw.TxHash.Hex(),
			"msgHash", common.Hash(event.MsgHash).Hex(),
			"from", event.Message.From.Hex(),
			"srcOwner", event.Message.SrcOwner.Hex(),
			"destOwner", event.Message.DestOwner.Hex(),
			"error", err,
			"hopsLength", len(hops),
		)

		return nil, err
	}

	return encodedSignalProof, nil
}

// sendProcessMessageCall calls `bridge.processMessage` with latest nonce
// after estimating gas, and checking profitability.
func (p *Processor) sendProcessMessageCall(
	ctx context.Context,
	id int,
	event *bridge.BridgeMessageSent,
	proof []byte,
) (*types.Receipt, error) {
	defer p.logRelayerBalance(ctx)

	received, err := p.destBridge.IsMessageReceived(nil, event.Message, proof)
	if err != nil {
		return nil, err
	}

	// message will fail when we try to process it
	if !received {
		slog.Warn("Message not received on dest chain",
			"msgHash", common.Hash(event.MsgHash).Hex(),
			"srcChainId", event.Message.SrcChainId,
		)

		relayer.MessagesNotReceivedOnDestChain.Inc()

		return nil, errors.New("message not received")
	}

	baseFee, err := p.getBaseFee(ctx)
	if err != nil {
		return nil, err
	}

	gasTipCap, err := p.destEthClient.SuggestGasTipCap(ctx)
	if err != nil {
		return nil, err
	}

	data, err := encoding.BridgeABI.Pack("processMessage", event.Message, proof)
	if err != nil {
		return nil, err
	}

	// mul by 1.05 for padding
	gasLimit := uint64(float64(event.Message.GasLimit))

	var estimatedCost uint64 = 0

	if bool(p.profitableOnly) {
		profitable, err := p.isProfitable(
			ctx,
			id,
			event.Message.Fee,
			gasLimit,
			baseFee.Uint64(),
			gasTipCap.Uint64(),
		)
		if err != nil || !profitable {
			if err == errImpossible {
				return nil, errImpossible
			}

			return nil, relayer.ErrUnprofitable
		}

		// now simulate the transaction and lets confirm it is profitable
		auth, err := bind.NewKeyedTransactorWithChainID(p.ecdsaKey, p.destChainId)
		if err != nil {
			return nil, err
		}

		msg := ethereum.CallMsg{
			From: auth.From,
			To:   &p.cfg.DestBridgeAddress,
			Data: data,
		}

		gasUsed, err := p.destEthClient.EstimateGas(context.Background(), msg)
		if err != nil {
			return nil, err
		}

		slog.Info("estimatedGasUsed",
			"gasUsed", gasUsed,
			"messageGasLimit", event.Message.GasLimit,
			"paddedGasLimit", gasLimit,
			"srcTxHash", event.Raw.TxHash.Hex(),
		)

		if gasUsed > gasLimit {
			return nil, relayer.ErrUnprofitable
		}

		estimatedCost = gasUsed * (baseFee.Uint64() + gasTipCap.Uint64())
	}

	// we should check event status one more time, after we have waiting for
	// confirmations, and after we have generated proof. its possible another relayer
	// or the user themself has claimed this in the time it took
	// for us to do this work, which would cause us to revert.
	eventStatus, err := p.eventStatusFromMsgHash(ctx, event.MsgHash)
	if err != nil {
		return nil, errors.Wrap(err, "p.eventStatusFromMsgHash")
	}

	if !canProcessMessage(
		ctx,
		eventStatus,
		event.Message.SrcOwner,
		p.relayerAddr,
		uint64(event.Message.GasLimit),
	) {
		slog.Error("can not process message after waiting for confirmations", "err", errUnprocessable)
		return nil, errUnprocessable
	}

	candidate := txmgr.TxCandidate{
		TxData:   data,
		Blobs:    nil,
		To:       &p.cfg.DestBridgeAddress,
		GasLimit: gasLimit,
	}

	receipt, err := p.txmgr.Send(ctx, candidate)
	if err != nil {
		slog.Warn("Failed to send ProcessMessage transaction", "error", err.Error())
		return nil, err
	}

	slog.Info("Mined tx",
		"txHash", hex.EncodeToString(receipt.TxHash.Bytes()),
		"srcTxHash", event.Raw.TxHash.Hex(),
	)

	if receipt.Status != types.ReceiptStatusSuccessful {
		relayer.MessageSentEventsProcessedReverted.Inc()
		slog.Warn("Transaction reverted", "txHash", hex.EncodeToString(receipt.TxHash.Bytes()),
			"srcTxHash", event.Raw.TxHash.Hex(),
			"status", receipt.Status)

		return nil, errTxReverted
	}

	relayer.MessageSentEventsProcessed.Inc()

	if p.profitableOnly {
		cost := receipt.GasUsed * receipt.EffectiveGasPrice.Uint64()

		slog.Info("tx cost", "txHash", hex.EncodeToString(receipt.TxHash.Bytes()),
			"srcTxHash", event.Raw.TxHash.Hex(),
			"actualCost", cost,
			"estimatedCost", estimatedCost,
		)

		if cost > estimatedCost {
			relayer.UnprofitableMessageAfterTransacting.Inc()
		} else {
			relayer.ProfitableMessageAfterTransacting.Inc()
		}
	}

	if err := p.saveMessageStatusChangedEvent(ctx, receipt, event); err != nil {
		return nil, err
	}

	return receipt, nil
}

// retrieve the balance of the relayer and set Prometheus
func (p *Processor) logRelayerBalance(ctx context.Context) {
	balance, err := p.destEthClient.BalanceAt(ctx, p.relayerAddr, nil)
	if err != nil {
		slog.Warn("Failed to retrieve relayer balance", "error", err)
		return
	}

	balanceFloat := new(big.Float).SetInt(balance)
	balanceEth := new(big.Float).Quo(
		balanceFloat,
		big.NewFloat(math.Pow10(18)),
	)

	slog.Info("Relayer balance",
		"relayerAddress", p.relayerAddr,
		"balance", balanceEth.Text('f', 18),
	)

	balanceEthFloat, _ := balanceEth.Float64()
	relayer.RelayerKeyBalanceGauge.Set(balanceEthFloat)
}

// saveMessageStatusChangedEvent writes the MessageStatusChanged event to the
// database after a message is processed
func (p *Processor) saveMessageStatusChangedEvent(
	ctx context.Context,
	receipt *types.Receipt,
	event *bridge.BridgeMessageSent,
) error {
	bridgeAbi, err := abi.JSON(strings.NewReader(bridge.BridgeABI))
	if err != nil {
		return err
	}

	m := make(map[string]interface{})

	for _, log := range receipt.Logs {
		topic := log.Topics[0]
		if topic == bridgeAbi.Events["MessageStatusChanged"].ID {
			err = bridgeAbi.UnpackIntoMap(m, "MessageStatusChanged", log.Data)
			if err != nil {
				return err
			}

			break
		}
	}

	if m["status"] != nil {
		// keep same format as other raw events
		data := fmt.Sprintf(`{"Raw":{"transactionHash": "%v"}}`, receipt.TxHash.Hex())

		_, err = p.eventRepo.Save(ctx, &relayer.SaveEventOpts{
			Name:           relayer.EventNameMessageStatusChanged,
			Data:           data,
			EmittedBlockID: event.Raw.BlockNumber,
			ChainID:        new(big.Int).SetUint64(event.Message.SrcChainId),
			DestChainID:    new(big.Int).SetUint64(event.Message.DestChainId),
			Status:         relayer.EventStatus(m["status"].(uint8)),
			MsgHash:        common.Hash(event.MsgHash).Hex(),
			MessageOwner:   event.Message.SrcOwner.Hex(),
			Event:          relayer.EventNameMessageStatusChanged,
		})
		if err != nil {
			return errors.Wrap(err, "svc.eventRepo.Save")
		}
	}

	return nil
}

// getBaseFee determines the baseFee on the dest chain
func (p *Processor) getBaseFee(ctx context.Context) (*big.Int, error) {
	blk, err := p.destEthClient.BlockByNumber(ctx, nil)
	if err != nil {
		return nil, err
	}

	var baseFee *big.Int

	if p.taikoL2 != nil {
		latestL2Block, err := p.destEthClient.BlockByNumber(ctx, nil)
		if err != nil {
			return nil, err
		}

		bf, err := p.taikoL2.GetBasefee(&bind.CallOpts{Context: ctx}, blk.NumberU64(), uint32(latestL2Block.GasUsed()))
		if err != nil {
			return nil, err
		}

		baseFee = bf.Basefee
	} else {
		cfg := params.NetworkIDToChainConfigOrDefault(p.destChainId)
		baseFee = eip1559.CalcBaseFee(cfg, blk.Header())
	}

	return baseFee, nil
}
