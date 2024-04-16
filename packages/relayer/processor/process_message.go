package processor

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log/slog"
	"math/big"
	"strings"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
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
	errUnprocessable = errors.New("message is unprocessable")
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
) (bool, error) {
	msgBody := &queue.QueueMessageSentBody{}
	if err := json.Unmarshal(msg.Body, msgBody); err != nil {
		return false, errors.Wrap(err, "json.Unmarshal")
	}

	slog.Info("message received", "srcTxHash", msgBody.Event.Raw.TxHash.Hex())

	eventStatus, err := p.eventStatusFromMsgHash(ctx, msgBody.Event.MsgHash)
	if err != nil {
		return false, errors.Wrap(err, "p.eventStatusFromMsgHash")
	}

	if !canProcessMessage(
		ctx,
		eventStatus,
		msgBody.Event.Message.SrcOwner,
		p.relayerAddr,
		msgBody.Event.Message.GasLimit,
	) {
		return false, nil
	}

	slog.Info("waiting for confirmations",
		"msgHash", common.BytesToHash(msgBody.Event.MsgHash[:]).Hex(),
	)

	if err := p.waitForConfirmations(ctx, msgBody.Event.Raw.TxHash, msgBody.Event.Raw.BlockNumber); err != nil {
		return false, err
	}

	slog.Info("done waiting for confirmations",
		"msgHash", common.BytesToHash(msgBody.Event.MsgHash[:]).Hex(),
	)

	// we need to check the invocation delays and proof receipt to see if
	// this is currently processable, or we need to wait.
	invocationDelay, extraDelay, err := p.destBridge.GetInvocationDelays(&bind.CallOpts{
		Context: ctx,
	})
	if err != nil {
		return false, errors.Wrap(err, "p.destBridge.invocationDelays")
	}

	proofReceipt, err := p.destBridge.ProofReceipt(&bind.CallOpts{
		Context: ctx,
	}, msgBody.Event.MsgHash)
	if err != nil {
		return false, errors.Wrap(err, "p.destBridge.ProofReceipt")
	}

	var encodedSignalProof []byte

	// proof has not been submitted, we need to generate it
	if proofReceipt.ReceivedAt == 0 {
		encodedSignalProof, err = p.generateEncodedSignalProof(ctx, msgBody.Event)
		if err != nil {
			return false, err
		}
	} else {
		// proof has been submitted
		// we need to check the invocation delay and
		// preferred exeuctor, if it wasnt us
		// who proved it, there is an extra delay.
		if err := p.waitForInvocationDelay(ctx, invocationDelay, extraDelay, proofReceipt); err != nil {
			return false, err
		}
	}

	receipt, err := p.sendProcessMessageCall(ctx, msgBody.Event, encodedSignalProof)
	if err != nil {
		return false, err
	}

	bridgeAbi, err := abi.JSON(strings.NewReader(bridge.BridgeABI))
	if err != nil {
		return false, err
	}

	// we need to check the receipt logs to see if we received MessageReceived
	// or MessageExecuted, because we have a two-step bridge.
	for _, log := range receipt.Logs {
		topic := log.Topics[0]
		// if we have a MessageReceived event, this was not processed, only
		// the first step was. now we have to wait for the invocation delay.
		if topic == bridgeAbi.Events["MessageReceived"].ID {
			slog.Info("message processing resulted in MessageReceived event",
				"msgHash", common.BytesToHash(msgBody.Event.MsgHash[:]).Hex(),
				"txHash", receipt.TxHash.Hex(),
			)

			slog.Info("waiting for invocation delay",
				"msgHash", common.BytesToHash(msgBody.Event.MsgHash[:]).Hex())

			proofReceipt, err := p.destBridge.ProofReceipt(&bind.CallOpts{
				Context: ctx,
			}, msgBody.Event.MsgHash)
			if err != nil {
				return false, err
			}

			if err := p.waitForInvocationDelay(ctx, invocationDelay, extraDelay, proofReceipt); err != nil {
				return false, err
			}

			if _, err := p.sendProcessMessageCall(ctx, msgBody.Event, nil); err != nil {
				return false, err
			}
		} else if topic == bridgeAbi.Events["MessageExecuted"].ID {
			// if we got MessageExecuted, the message is finished processing. this occurs
			// either in one-step bridge processing (no invocation delay), or if this is the second process
			// message call after the first step was completed.
			slog.Info("message processing resulted in MessageExecuted event",
				"msgHash", common.BytesToHash(msgBody.Event.MsgHash[:]).Hex(),
				"txHash", receipt.TxHash.Hex())
		}
	}

	messageStatus, err := p.destBridge.MessageStatus(&bind.CallOpts{
		Context: ctx,
	}, msgBody.Event.MsgHash)
	if err != nil {
		return false, errors.Wrap(err, "p.destBridge.GetMessageStatus")
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
			return false, err
		}
	}

	return false, nil
}

// waitForInvocationDelay will return when the invocation delay has been met,
// if one exists, or return immediately if not.
func (p *Processor) waitForInvocationDelay(
	ctx context.Context,
	invocationDelay *big.Int,
	extraDelay *big.Int,
	proofReceipt struct {
		ReceivedAt        uint64
		PreferredExecutor common.Address
	},
) error {
	preferredExecutor := proofReceipt.PreferredExecutor

	delay := invocationDelay

	if invocationDelay.Cmp(common.Big0) == 1 && preferredExecutor.Cmp(p.relayerAddr) != 0 {
		delay = new(big.Int).Add(invocationDelay, extraDelay)
	}

	processableAt := new(big.Int).Add(new(big.Int).SetUint64(proofReceipt.ReceivedAt), delay)
	// check invocation delays and make sure we can submit it
	if time.Now().UTC().Unix() >= processableAt.Int64() {
		// if its passed already, we can submit
		return nil
	}

	slog.Info("waiting for invocation delay",
		"delay", delay.String(),
		"processableAt", processableAt.String(),
		"now", time.Now().UTC().Unix(),
		"difference", new(big.Int).Sub(processableAt, new(big.Int).SetInt64(time.Now().UTC().Unix())),
	)

	w := time.After(time.Duration(delay.Int64()) * time.Second)

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-w:
			slog.Info("done waiting for invocation delay")
			return nil
		}
	}
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
			hop.blockNum = blockNum

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
	event *bridge.BridgeMessageSent,
	proof []byte,
) (*types.Receipt, error) {
	eventType, canonicalToken, _, err := relayer.DecodeMessageData(event.Message.Data, event.Message.Value)
	if err != nil {
		return nil, err
	}

	var gas uint64

	var cost *big.Int

	needsContractDeployment, err := p.needsContractDeployment(ctx, event, eventType, canonicalToken)
	if err != nil {
		return nil, err
	}

	if needsContractDeployment {
		gas = 3000000
	} else {
		// otherwise we can estimate gas
		gas, err = p.estimateGas(ctx, event.Message, proof)
		// and if gas estimation failed, we just try to hardcore a value no matter what type of event,
		// or whether the contract is deployed.
		if err != nil || gas == 0 {
			slog.Info("gas estimation failed, hardcoding gas limit", "p.estimateGas:", err)

			gas, err = p.hardcodeGasLimit(ctx, event, eventType, canonicalToken)
			if err != nil {
				return nil, err
			}
		}
	}

	gasTipCap, err := p.destEthClient.SuggestGasTipCap(ctx)
	if err != nil {
		return nil, err
	}

	cost, err = p.getCost(ctx, gas, gasTipCap, nil)
	if err != nil {
		return nil, err
	}

	if bool(p.profitableOnly) {
		profitable, err := p.isProfitable(ctx, event.Message, cost)
		if err != nil || !profitable {
			return nil, relayer.ErrUnprofitable
		}
	}

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

	data, err := encoding.BridgeABI.Pack("processMessage", event.Message, proof)
	if err != nil {
		return nil, err
	}

	candidate := txmgr.TxCandidate{
		TxData:   data,
		Blobs:    nil,
		To:       &p.cfg.DestBridgeAddress,
		GasLimit: gas,
	}

	receipt, err := p.txmgr.Send(ctx, candidate)
	if err != nil {
		slog.Warn("Failed to send ProcessMessage transaction", "error", err.Error())
		return nil, err
	}

	slog.Info("Mined tx", "txHash", hex.EncodeToString(receipt.TxHash.Bytes()))

	if receipt.Status != types.ReceiptStatusSuccessful {
		relayer.MessageSentEventsProcessedReverted.Inc()

		return nil, errTxReverted
	}

	relayer.MessageSentEventsProcessed.Inc()

	if err := p.saveMessageStatusChangedEvent(ctx, receipt, event); err != nil {
		return nil, err
	}

	return receipt, nil
}

// needsContractDeployment is needed because
// node is unable to estimate gas correctly for contract deployments,
// so we need to check if the token
// is deployed, and always hardcode in this case. we need to check this before calling
// estimategas, as the node will soemtimes return a gas estimate for a contract deployment, however,
// it is incorrect and the tx will revert.
func (p *Processor) needsContractDeployment(
	ctx context.Context,
	event *bridge.BridgeMessageSent,
	eventType relayer.EventType,
	canonicalToken relayer.CanonicalToken,
) (bool, error) {
	if eventType == relayer.EventTypeSendETH {
		return false, nil
	}

	var bridgedAddress common.Address

	var err error

	chainID := new(big.Int).SetUint64(canonicalToken.ChainID())
	addr := canonicalToken.Address()

	ctx, cancel := context.WithTimeout(ctx, p.ethClientTimeout)
	defer cancel()

	opts := &bind.CallOpts{
		Context: ctx,
	}

	destChainID := new(big.Int).SetUint64(event.Message.DestChainId)
	if eventType == relayer.EventTypeSendERC20 && destChainID.Cmp(chainID) != 0 {
		// determine whether the canonical token is bridged or not on this chain
		bridgedAddress, err = p.destERC20Vault.CanonicalToBridged(opts, chainID, addr)
	}

	if eventType == relayer.EventTypeSendERC721 && destChainID.Cmp(chainID) != 0 {
		// determine whether the canonical token is bridged or not on this chain
		bridgedAddress, err = p.destERC721Vault.CanonicalToBridged(opts, chainID, addr)
	}

	if eventType == relayer.EventTypeSendERC1155 && destChainID.Cmp(chainID) != 0 {
		// determine whether the canonical token is bridged or not on this chain
		bridgedAddress, err = p.destERC1155Vault.CanonicalToBridged(opts, chainID, addr)
	}

	if err != nil {
		return false, err
	}

	return bridgedAddress == relayer.ZeroAddress, nil
}

// hardcodeGasLimit determines a viable gas limit when we can get
// unable to estimate gas for contract deployments within the contract code.
// if we get an error or the gas is 0, lets manual set high gas limit and ignore error,
// and try to actually send.
// if contract has not been deployed, we need much higher gas limit, otherwise, we can
// send lower.
func (p *Processor) hardcodeGasLimit(
	ctx context.Context,
	event *bridge.BridgeMessageSent,
	eventType relayer.EventType,
	canonicalToken relayer.CanonicalToken,
) (uint64, error) {
	var bridgedAddress common.Address

	var err error

	var gas uint64

	switch eventType {
	case relayer.EventTypeSendETH:
		// eth bridges take much less gas, from 250k to 450k.
		return 500000, nil
	case relayer.EventTypeSendERC20:
		// determine whether the canonical token is bridged or not on this chain
		bridgedAddress, err = p.destERC20Vault.CanonicalToBridged(
			&bind.CallOpts{
				Context: ctx,
			},
			new(big.Int).SetUint64(canonicalToken.ChainID()),
			canonicalToken.Address(),
		)
		if err != nil {
			return 0, err
		}
	case relayer.EventTypeSendERC721:
		// determine whether the canonical token is bridged or not on this chain
		bridgedAddress, err = p.destERC721Vault.CanonicalToBridged(
			&bind.CallOpts{
				Context: ctx,
			},
			new(big.Int).SetUint64(canonicalToken.ChainID()),
			canonicalToken.Address(),
		)
		if err != nil {
			return 0, err
		}
	case relayer.EventTypeSendERC1155:
		// determine whether the canonical token is bridged or not on this chain
		bridgedAddress, err = p.destERC1155Vault.CanonicalToBridged(
			&bind.CallOpts{
				Context: ctx,
			},
			new(big.Int).SetUint64(canonicalToken.ChainID()),
			canonicalToken.Address(),
		)
		if err != nil {
			return 0, err
		}
	default:
		return 0, errors.New("unexpected event type")
	}

	if bridgedAddress == relayer.ZeroAddress {
		// needs large gas limit because it has to deploy an ERC20 contract on destination
		// chain. deploying ERC20 can be 2 mil by itself.
		gas = 3000000
	} else {
		// needs larger than ETH gas limit but not as much as deploying ERC20.
		// takes 450-550k gas after signalRoot refactors.
		gas = 600000
	}

	return gas, nil
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

		_, err = p.eventRepo.Save(ctx, relayer.SaveEventOpts{
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

// getCost determines the fee of a processMessage call
func (p *Processor) getCost(ctx context.Context, gas uint64, gasTipCap *big.Int, gasPrice *big.Int) (*big.Int, error) {
	if gasTipCap != nil {
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

		slog.Info("cost estimation",
			"gas", gas,
			"gasTipCap", gasTipCap.String(),
			"baseFee", baseFee.String(),
		)

		return new(big.Int).Mul(
			new(big.Int).SetUint64(gas),
			new(big.Int).Add(gasTipCap, baseFee)), nil
	} else {
		slog.Info("cost estimation",
			"gas", gas,
			"gasPrice", gasPrice.String(),
		)

		return new(big.Int).Mul(gasPrice, new(big.Int).SetUint64(gas)), nil
	}
}
