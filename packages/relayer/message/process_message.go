package message

import (
	"context"
	"encoding/hex"
	"fmt"
	"math/big"
	"strings"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/contracts/bridge"
)

// Process prepares and calls `processMessage` on the bridge.
// the proof must be generated from the gethclient's eth_getProof via the Prover,
// then rlp-encoded and combined as a singular byte slice,
// then abi encoded into a SignalProof struct as the contract
// expects
func (p *Processor) ProcessMessage(
	ctx context.Context,
	event *bridge.BridgeMessageSent,
	e *relayer.Event,
) error {
	if event.Message.GasLimit == nil || event.Message.GasLimit.Cmp(common.Big0) == 0 {
		return errors.New("only user can process this, gasLimit set to 0")
	}

	if err := p.waitForConfirmations(ctx, event.Raw.TxHash, event.Raw.BlockNumber); err != nil {
		return errors.Wrap(err, "p.waitForConfirmations")
	}

	if err := p.waitHeaderSynced(ctx, event); err != nil {
		return errors.Wrap(err, "p.waitHeaderSynced")
	}

	// get latest synced header since not every header is synced from L1 => L2,
	// and later blocks still have the storage trie proof from previous blocks.
	latestSyncedHeader, err := p.destHeaderSyncer.GetCrossChainBlockHash(&bind.CallOpts{}, big.NewInt(0))
	if err != nil {
		return errors.Wrap(err, "taiko.GetSyncedHeader")
	}

	hashed := crypto.Keccak256(
		event.Raw.Address.Bytes(),
		event.MsgHash[:],
	)

	key := hex.EncodeToString(hashed)

	encodedSignalProof, err := p.prover.EncodedSignalProof(ctx, p.rpc, p.srcSignalServiceAddress, key, latestSyncedHeader)
	if err != nil {
		log.Errorf("srcChainID: %v, destChainID: %v, txHash: %v: msgHash: %v, from: %v encountered signalProofError %v",
			event.Message.SrcChainId,
			event.Message.DestChainId,
			event.Raw.TxHash.Hex(),
			common.Hash(event.MsgHash).Hex(),
			event.Message.Owner.Hex(),
			err,
		)

		return errors.Wrap(err, "p.prover.GetEncodedSignalProof")
	}

	// check if message is received first. if not, it will definitely fail,
	// so we can exit early on this one. there is most likely
	// an issue with the signal generation.
	received, err := p.destBridge.IsMessageReceived(&bind.CallOpts{
		Context: ctx,
	}, event.MsgHash, event.Message.SrcChainId, encodedSignalProof)
	if err != nil {
		return errors.Wrap(err, "p.destBridge.IsMessageReceived")
	}

	// message will fail when we try to process it
	if !received {
		log.Warnf(
			"msgHash: %v, srcChainId: %v, encodedSignalProof: %v not received on dest chain",
			common.Hash(event.MsgHash).Hex(),
			event.Message.SrcChainId,
			hex.EncodeToString(encodedSignalProof),
		)

		relayer.MessagesNotReceivedOnDestChain.Inc()

		return errors.New("message not received")
	}

	tx, err := p.sendProcessMessageCall(ctx, event, encodedSignalProof)
	if err != nil {
		return errors.Wrap(err, "p.sendProcessMessageCall")
	}

	relayer.EventsProcessed.Inc()

	ctx, cancel := context.WithTimeout(ctx, 4*time.Minute)

	defer cancel()

	receipt, err := relayer.WaitReceipt(ctx, p.destEthClient, tx.Hash())
	if err != nil {
		return errors.Wrap(err, "relayer.WaitReceipt")
	}

	if err := p.saveMessageStatusChangedEvent(ctx, receipt, e, event); err != nil {
		return errors.Wrap(err, "p.saveMEssageStatusChangedEvent")
	}

	log.Infof("Mined tx %s", hex.EncodeToString(tx.Hash().Bytes()))

	messageStatus, err := p.destBridge.GetMessageStatus(&bind.CallOpts{}, event.MsgHash)
	if err != nil {
		return errors.Wrap(err, "p.destBridge.GetMessageStatus")
	}

	log.Infof(
		"updating message status to: %v for txHash: %v, processed in txHash: %v",
		relayer.EventStatus(messageStatus).String(),
		event.Raw.TxHash.Hex(),
		hex.EncodeToString(tx.Hash().Bytes()),
	)

	if messageStatus == uint8(relayer.EventStatusRetriable) {
		relayer.RetriableEvents.Inc()
	} else if messageStatus == uint8(relayer.EventStatusDone) {
		relayer.DoneEvents.Inc()
	}

	// update message status
	if err := p.eventRepo.UpdateStatus(ctx, e.ID, relayer.EventStatus(messageStatus)); err != nil {
		return errors.Wrap(err, "s.eventRepo.UpdateStatus")
	}

	return nil
}

func (p *Processor) sendProcessMessageCall(
	ctx context.Context,
	event *bridge.BridgeMessageSent,
	proof []byte,
) (*types.Transaction, error) {
	auth, err := bind.NewKeyedTransactorWithChainID(p.ecdsaKey, event.Message.DestChainId)
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

	eventType, canonicalToken, _, err := relayer.DecodeMessageSentData(event)
	if err != nil {
		return nil, errors.Wrap(err, "relayer.DecodeMessageSentData")
	}

	var gas uint64

	var cost *big.Int

	var needsContractDeployment bool = false
	// node is unable to estimate gas correctly for contract deployments, we need to check if the token
	// is deployed, and always hardcode in this case. we need to check this before calling
	// estimategas, as the node will soemtimes return a gas estimate for a contract deployment, however,
	// it is incorrect and the tx will revert.
	if eventType == relayer.EventTypeSendERC20 && event.Message.DestChainId.Cmp(canonicalToken.ChainId) != 0 {
		// determine whether the canonical token is bridged or not on this chain
		bridgedAddress, err := p.destTokenVault.CanonicalToBridged(nil, canonicalToken.ChainId, canonicalToken.Addr)
		if err != nil {
			return nil, errors.Wrap(err, "p.destTokenVault.IsBridgedToken")
		}

		if bridgedAddress == relayer.ZeroAddress {
			// needs large gas limit because it has to deploy an ERC20 contract on destination
			// chain. deploying ERC20 can be 2 mil by itself. we want to skip estimating gas entirely
			// in this scenario.
			needsContractDeployment = true
		}
	}

	if needsContractDeployment {
		auth.GasLimit = 3000000
	} else {
		// otherwise we can estimate gas
		gas, cost, err = p.estimateGas(ctx, event.Message, proof)
		// and if gas estimation failed, we just try to hardcore a value no matter what type of event,
		// or whether the contract is deployed.
		if err != nil || gas == 0 {
			cost, err = p.hardcodeGasLimit(ctx, auth, event, eventType, canonicalToken)
			if err != nil {
				return nil, errors.Wrap(err, "p.hardcodeGasLimit")
			}
		}
	}

	gasTipCap, err := p.destEthClient.SuggestGasTipCap(ctx)
	if err != nil {
		if IsMaxPriorityFeePerGasNotFoundError(err) {
			auth.GasTipCap = FallbackGasTipCap
		} else {
			gasPrice, err := p.destEthClient.SuggestGasPrice(context.Background())
			if err != nil {
				return nil, errors.Wrap(err, "p.destBridge.SuggestGasPrice")
			}

			auth.GasPrice = gasPrice
		}
	} else {
		auth.GasTipCap = gasTipCap
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
	canonicalToken *relayer.CanonicalToken,
) (*big.Int, error) {
	if eventType == relayer.EventTypeSendETH {
		// eth bridges take much less gas, from 250k to 450k.
		auth.GasLimit = 500000
	} else {
		// determine whether the canonical token is bridged or not on this chain
		bridgedAddress, err := p.destTokenVault.CanonicalToBridged(nil, canonicalToken.ChainId, canonicalToken.Addr)
		if err != nil {
			return nil, errors.Wrap(err, "p.destTokenVault.IsBridgedToken")
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
	}

	gasPrice, err := p.destEthClient.SuggestGasPrice(ctx)
	if err != nil {
		return nil, errors.Wrap(err, "p.destEthClient.SuggestGasPrice")
	}

	return new(big.Int).Mul(gasPrice, new(big.Int).SetUint64(auth.GasLimit)), nil
}

func (p *Processor) setLatestNonce(nonce uint64) {
	p.destNonce = nonce
}

func (p *Processor) saveMessageStatusChangedEvent(
	ctx context.Context,
	receipt *types.Receipt,
	e *relayer.Event,
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
			ChainID:      event.Message.DestChainId,
			Status:       relayer.EventStatus(m["status"].(uint8)),
			MsgHash:      e.MsgHash,
			MessageOwner: e.MessageOwner,
			Event:        relayer.EventNameMessageStatusChanged,
		})
		if err != nil {
			return errors.Wrap(err, "svc.eventRepo.Save")
		}
	}

	return nil
}
