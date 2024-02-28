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

	"github.com/cenkalti/backoff"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/consensus/misc/eip1559"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/params"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/proof"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/utils"
)

var (
	errUnprocessable = errors.New("message is unprocessable")
)

func (p *Processor) eventStatusFromMsgHash(
	ctx context.Context,
	gasLimit *big.Int,
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
	if eventStatus == relayer.EventStatusNew {
		if gasLimit == nil || gasLimit.Cmp(common.Big0) == 0 {
			// if gasLimit is 0, relayer can not process this.
			eventStatus = relayer.EventStatusNewOnlyOwner
		}
	}

	return eventStatus, nil
}

// processMessage prepares and calls `processMessage` on the bridge.
// the proof must be generated from the gethclient's eth_getProof via the Prover,
// then rlp-encoded and combined as a singular byte slice,
// then abi encoded into a SignalProof struct as the contract
// expects
func (p *Processor) processMessage(
	ctx context.Context,
	msg queue.Message,
) error {
	msgBody := &queue.QueueMessageSentBody{}
	if err := json.Unmarshal(msg.Body, msgBody); err != nil {
		return errors.Wrap(err, "json.Unmarshal")
	}

	if msgBody.Event.Message.GasLimit == nil || msgBody.Event.Message.GasLimit.Cmp(common.Big0) == 0 {
		return errors.New("only user can process this, gasLimit set to 0")
	}

	eventStatus, err := p.eventStatusFromMsgHash(ctx, msgBody.Event.Message.GasLimit, msgBody.Event.MsgHash)
	if err != nil {
		return errors.Wrap(err, "p.eventStatusFromMsgHash")
	}

	if !canProcessMessage(ctx, eventStatus, msgBody.Event.Message.SrcOwner, p.relayerAddr) {
		return errUnprocessable
	}

	if err := p.waitForConfirmations(ctx, msgBody.Event.Raw.TxHash, msgBody.Event.Raw.BlockNumber); err != nil {
		return errors.Wrap(err, "p.waitForConfirmations")
	}

	invocationDelays, err := p.destBridge.GetInvocationDelays(nil)
	if err != nil {
		return errors.Wrap(err, "p.destBridge.invocationDelays")
	}

	proofReceipt, err := p.destBridge.ProofReceipt(nil, msgBody.Event.MsgHash)
	if err != nil {
		return errors.Wrap(err, "p.destBridge.ProofReceipt")
	}

	slog.Info("proofReceipt",
		"receivedAt", proofReceipt.ReceivedAt,
		"preferredExecutor", proofReceipt.PreferredExecutor.Hex(),
		"msgHash", common.BytesToHash(msgBody.Event.MsgHash[:]).Hex(),
	)

	var encodedSignalProof []byte

	// proof has not been submitted, we need to generate it
	if proofReceipt.ReceivedAt == 0 {
		encodedSignalProof, err = p.generateEncodedSignalProof(ctx, msgBody.Event)
		if err != nil {
			return errors.Wrap(err, "p.generateEncodedSignalProof")
		}
	} else {
		// proof has been submitted
		// we need to check the invocation delay and
		// preferred exeuctor, if it wasnt us
		// who proved it, there is an extra delay.
		if err := p.waitForInvocationDelay(ctx, invocationDelays, proofReceipt); err != nil {
			return errors.Wrap(err, "p.waitForInvocationDelay")
		}
	}

	receipt, err := p.sendProcessMessageAndWaitForReceipt(ctx, encodedSignalProof, msgBody)

	if err != nil {
		return errors.Wrap(err, "p.sendProcessMessageAndWaitForReceipt")
	}

	bridgeAbi, err := abi.JSON(strings.NewReader(bridge.BridgeABI))
	if err != nil {
		return err
	}

	for _, log := range receipt.Logs {
		topic := log.Topics[0]
		// if we have a MessageReceived event, this was not processed,
		// and we have to wait for the invocation delay.
		if topic == bridgeAbi.Events["MessageReceived"].ID {
			slog.Info("message processing resulted in MessageReceived event",
				"msgHash", common.BytesToHash(msgBody.Event.MsgHash[:]).Hex(),
			)

			slog.Info("waiting for invocation delay",
				"msgHash", common.BytesToHash(msgBody.Event.MsgHash[:]).Hex())

			proofReceipt, err := p.destBridge.ProofReceipt(nil, msgBody.Event.MsgHash)
			if err != nil {
				return errors.Wrap(err, "p.destBridge.ProofReceipt")
			}

			if err := p.waitForInvocationDelay(ctx, invocationDelays, proofReceipt); err != nil {
				return errors.Wrap(err, "p.waitForInvocationDelay")
			}

			if _, err := p.sendProcessMessageAndWaitForReceipt(ctx, nil, msgBody); err != nil {
				return errors.Wrap(err, "p.sendProcessMessageAndWaitForReceipt")
			}

		} else if topic == bridgeAbi.Events["MessageExecuted"].ID {
			slog.Info("message processing resulted in MessageExecuted event. processing finished")
		}
	}

	messageStatus, err := p.destBridge.MessageStatus(&bind.CallOpts{}, msgBody.Event.MsgHash)
	if err != nil {
		return errors.Wrap(err, "p.destBridge.GetMessageStatus")
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
	// transaction hash.
	if msg.Internal != nil {
		// update message status
		if err := p.eventRepo.UpdateStatus(ctx, msgBody.ID, relayer.EventStatus(messageStatus)); err != nil {
			return errors.Wrap(err, fmt.Sprintf("p.eventRepo.UpdateStatus, id: %v", msgBody.ID))
		}
	}

	return nil
}

func (p *Processor) sendProcessMessageAndWaitForReceipt(
	ctx context.Context,
	encodedSignalProof []byte,
	msgBody *queue.QueueMessageSentBody,
) (*types.Receipt, error) {
	var tx *types.Transaction

	var err error

	sendTx := func() error {
		if ctx.Err() != nil {
			return nil
		}

		tx, err = p.sendProcessMessageCall(ctx, msgBody.Event, encodedSignalProof)
		if err != nil {
			return err
		}

		return nil
	}

	if err := backoff.Retry(sendTx, backoff.WithMaxRetries(
		backoff.NewConstantBackOff(p.backOffRetryInterval),
		p.backOffMaxRetries),
	); err != nil {
		return nil, err
	}

	relayer.EventsProcessed.Inc()

	ctx, cancel := context.WithTimeout(ctx, 4*time.Minute)

	defer cancel()

	receipt, err := relayer.WaitReceipt(ctx, p.destEthClient, tx.Hash())
	if err != nil {
		return nil, errors.Wrap(err, "relayer.WaitReceipt")
	}

	slog.Info("Mined tx", "txHash", hex.EncodeToString(tx.Hash().Bytes()))

	if err := p.saveMessageStatusChangedEvent(ctx, receipt, msgBody.Event); err != nil {
		return nil, errors.Wrap(err, "p.saveMEssageStatusChangedEvent")
	}

	return receipt, nil
}

func (p *Processor) waitForInvocationDelay(
	ctx context.Context,
	invocationDelays struct {
		InvocationDelay      *big.Int
		InvocationExtraDelay *big.Int
	},
	proofReceipt struct {
		ReceivedAt        uint64
		PreferredExecutor common.Address
	},
) error {
	invocationDelay := invocationDelays.InvocationDelay
	preferredExecutor := proofReceipt.PreferredExecutor

	if invocationDelay.Cmp(common.Big0) == 1 && preferredExecutor.Cmp(p.relayerAddr) != 0 {
		invocationDelay = new(big.Int).Add(invocationDelay, invocationDelays.InvocationExtraDelay)
	}

	processableAt := new(big.Int).Add(new(big.Int).SetUint64(proofReceipt.ReceivedAt), invocationDelay)
	// check invocation delays and make sure we can submit it
	if time.Now().UTC().Unix() >= processableAt.Int64() {
		// if its passed already, we can submit
		return nil
	}
	// its unprocessable, we shouldnt send the transaction.
	// wait until it's processable.
	t := time.NewTicker(60 * time.Second)

	defer t.Stop()

	w := time.After(time.Duration(invocationDelay.Int64()) * time.Second)

	for {
		select {
		case <-ctx.Done():
			return nil
		case <-t.C:
			slog.Info("waiting for invocation delay",
				"processableAt", processableAt.String(),
				"now", time.Now().UTC().Unix(),
			)
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
			return nil, errors.Wrap(err, "p.waitHeaderSynced")
		}

		blockNum = event.SyncedInBlockID
	} else {
		if _, err := p.waitHeaderSynced(ctx, p.srcEthClient, p.destChainId.Uint64(), event.Raw.BlockNumber); err != nil {
			return nil, errors.Wrap(err, "p.waitHeaderSynced")
		}
	}

	hops := []proof.HopParams{}

	key, err := p.srcSignalService.GetSignalSlot(&bind.CallOpts{},
		event.Message.SrcChainId,
		event.Raw.Address,
		event.MsgHash,
	)

	if err != nil {
		return nil, errors.Wrap(err, "p.srcSignalService.GetSignalSlot")
	}

	if len(p.hops) == 0 {
		latestBlockID, err := p.eventRepo.LatestChainDataSyncedEvent(
			ctx,
			p.destChainId.Uint64(),
			p.srcChainId.Uint64(),
		)
		if err != nil {
			return nil, errors.Wrap(err, "p.eventRepo.ChainDataSyncedEventByBlockNumberOrGreater")
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
			return nil, errors.Wrap(err, "p.blockHeader")
		}

		hopStorageSlotKey, err := hop.signalService.GetSignalSlot(&bind.CallOpts{},
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

		return nil, errors.Wrap(err, "p.prover.GetEncodedSignalProof")
	}

	// check if message is received first. if not, it will definitely fail,
	// so we can exit early on this one. there is most likely
	// an issue with the signal generation.
	received, err := p.destBridge.ProveMessageReceived(&bind.CallOpts{
		Context: ctx,
	}, event.Message, encodedSignalProof)
	if err != nil {
		return nil, errors.Wrap(err, "p.destBridge.ProveMessageReceived")
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

	return encodedSignalProof, nil
}

func (p *Processor) sendProcessMessageCall(
	ctx context.Context,
	event *bridge.BridgeMessageSent,
	proof []byte,
) (*types.Transaction, error) {
	auth, err := bind.NewKeyedTransactorWithChainID(p.ecdsaKey, new(big.Int).SetUint64(event.Message.DestChainId))
	if err != nil {
		return nil, errors.Wrap(err, "bind.NewKeyedTransactorWithChainID")
	}

	auth.Context = ctx

	p.mu.Lock()
	defer p.mu.Unlock()

	err = p.getLatestNonce(ctx, auth)
	if err != nil {
		return nil, errors.New("p.getLatestNonce")
	}

	eventType, canonicalToken, _, err := relayer.DecodeMessageData(event.Message.Data, event.Message.Value)
	if err != nil {
		return nil, errors.Wrap(err, "relayer.DecodeMessageData")
	}

	var gas uint64

	var cost *big.Int

	needsContractDeployment, err := p.needsContractDeployment(ctx, event, eventType, canonicalToken)
	if err != nil {
		return nil, errors.Wrap(err, "p.needsContractDeployment")
	}

	if needsContractDeployment {
		auth.GasLimit = 3000000
	} else {
		// otherwise we can estimate gas
		gas, err = p.estimateGas(ctx, event.Message, proof)
		// and if gas estimation failed, we just try to hardcore a value no matter what type of event,
		// or whether the contract is deployed.
		if err != nil || gas == 0 {
			slog.Info("gas estimation failed, hardcoding gas limit", "p.estimateGas:", err)

			err = p.hardcodeGasLimit(ctx, auth, event, eventType, canonicalToken)
			if err != nil {
				return nil, errors.Wrap(err, "p.hardcodeGasLimit")
			}
		} else {
			auth.GasLimit = gas
		}
	}

	if err = utils.SetGasTipOrPrice(ctx, auth, p.destEthClient); err != nil {
		return nil, errors.Wrap(err, "p.setGasTipOrPrice")
	}

	cost, err = p.getCost(ctx, auth)
	if err != nil {
		return nil, errors.Wrap(err, "p.getCost")
	}

	if bool(p.profitableOnly) {
		profitable, err := p.isProfitable(ctx, event.Message, cost)
		if err != nil || !profitable {
			return nil, relayer.ErrUnprofitable
		}
	}

	// process the message on the destination bridge.
	tx, err := p.destBridge.ProcessMessage(auth, event.Message, proof)
	if err != nil {
		return nil, errors.Wrap(err, "p.destBridge.ProcessMessage")
	}

	p.setLatestNonce(tx.Nonce())

	return tx, nil
}

// node is unable to estimate gas correctly for contract deployments, we need to check if the token
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
	auth *bind.TransactOpts,
	event *bridge.BridgeMessageSent,
	eventType relayer.EventType,
	canonicalToken relayer.CanonicalToken,
) error {
	var bridgedAddress common.Address

	var err error

	switch eventType {
	case relayer.EventTypeSendETH:
		// eth bridges take much less gas, from 250k to 450k.
		auth.GasLimit = 500000
	case relayer.EventTypeSendERC20:
		// determine whether the canonical token is bridged or not on this chain
		bridgedAddress, err = p.destERC20Vault.CanonicalToBridged(
			nil,
			new(big.Int).SetUint64(canonicalToken.ChainID()),
			canonicalToken.Address(),
		)
		if err != nil {
			return errors.Wrap(err, "p.destERC20Vault.CanonicalToBridged")
		}
	case relayer.EventTypeSendERC721:
		// determine whether the canonical token is bridged or not on this chain
		bridgedAddress, err = p.destERC721Vault.CanonicalToBridged(
			nil,
			new(big.Int).SetUint64(canonicalToken.ChainID()),
			canonicalToken.Address(),
		)
		if err != nil {
			return errors.Wrap(err, "p.destERC721Vault.CanonicalToBridged")
		}
	case relayer.EventTypeSendERC1155:
		// determine whether the canonical token is bridged or not on this chain
		bridgedAddress, err = p.destERC1155Vault.CanonicalToBridged(
			nil,
			new(big.Int).SetUint64(canonicalToken.ChainID()),
			canonicalToken.Address(),
		)
		if err != nil {
			return errors.Wrap(err, "p.destERC1155Vault.CanonicalToBridged")
		}
	default:
		return errors.New("unexpected event type")
	}

	if bridgedAddress == relayer.ZeroAddress {
		// needs large gas limit because it has to deploy an ERC20 contract on destination
		// chain. deploying ERC20 can be 2 mil by itself.
		auth.GasLimit = 3000000
	} else {
		// needs larger than ETH gas limit but not as much as deploying ERC20.
		// takes 450-550k gas after signalRoot refactors.
		auth.GasLimit = 600000
	}

	return nil
}

func (p *Processor) setLatestNonce(nonce uint64) {
	p.destNonce = nonce
}

func (p *Processor) saveMessageStatusChangedEvent(
	ctx context.Context,
	receipt *types.Receipt,
	event *bridge.BridgeMessageSent,
) error {
	bridgeAbi, err := abi.JSON(strings.NewReader(bridge.BridgeABI))
	if err != nil {
		return errors.Wrap(err, "abi.JSON")
	}

	m := make(map[string]interface{})

	for _, log := range receipt.Logs {
		topic := log.Topics[0]
		if topic == bridgeAbi.Events["MessageStatusChanged"].ID {
			err = bridgeAbi.UnpackIntoMap(m, "MessageStatusChanged", log.Data)
			if err != nil {
				return errors.Wrap(err, "abi.UnpackIntoInterface")
			}

			break
		}
	}

	if m["status"] != nil {
		// keep same format as other raw events
		data := fmt.Sprintf(`{"Raw":{"transactionHash": "%v"}}`, receipt.TxHash.Hex())

		_, err = p.eventRepo.Save(ctx, relayer.SaveEventOpts{
			Name:         relayer.EventNameMessageStatusChanged,
			Data:         data,
			ChainID:      new(big.Int).SetUint64(event.Message.DestChainId),
			Status:       relayer.EventStatus(m["status"].(uint8)),
			MsgHash:      common.Hash(event.MsgHash).Hex(),
			MessageOwner: event.Message.SrcOwner.Hex(),
			Event:        relayer.EventNameMessageStatusChanged,
		})
		if err != nil {
			return errors.Wrap(err, "svc.eventRepo.Save")
		}
	}

	return nil
}

func (p *Processor) getCost(ctx context.Context, auth *bind.TransactOpts) (*big.Int, error) {
	if auth.GasTipCap != nil {
		blk, err := p.destEthClient.BlockByNumber(ctx, nil)
		if err != nil {
			return nil, err
		}

		var baseFee *big.Int

		if p.taikoL2 != nil {
			gasUsed := uint32(blk.GasUsed())
			timeSince := uint64(time.Since(time.Unix(int64(blk.Time()), 0)))
			baseFee, err = p.taikoL2.GetBasefee(&bind.CallOpts{Context: ctx}, timeSince, gasUsed)

			if err != nil {
				return nil, errors.Wrap(err, "p.taikoL2.GetBasefee")
			}
		} else {
			cfg := params.NetworkIDToChainConfigOrDefault(p.destChainId)
			baseFee = eip1559.CalcBaseFee(cfg, blk.Header())
		}

		return new(big.Int).Mul(
			new(big.Int).SetUint64(auth.GasLimit),
			new(big.Int).Add(auth.GasTipCap, baseFee)), nil
	} else {
		return new(big.Int).Mul(auth.GasPrice, new(big.Int).SetUint64(auth.GasLimit)), nil
	}
}
