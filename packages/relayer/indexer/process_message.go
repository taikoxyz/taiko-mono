package indexer

import (
	"context"
	"encoding/hex"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	solsha3 "github.com/miguelmota/go-solidity-sha3"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikochain/taiko-mono/packages/relayer"
	"github.com/taikochain/taiko-mono/packages/relayer/contracts"
)

// processMessage prepares and calls `processMessage` on the bridge.
// the proof must be generated from the gethclient's eth_getProof,
// then rlp-encoded and combined as a singular byte slice,
// then abi encoded into a relayer.SignalProof struct as the contract
// expects
func (svc *Service) processMessage(
	ctx context.Context,
	event *contracts.BridgeMessageSent,
	e *relayer.Event,
) error {
	blockNumber := event.Raw.BlockNumber

	hashed := solsha3.SoliditySHA3(
		solsha3.Address(event.Raw.Address),
		solsha3.Bytes32(event.Signal),
	)

	key := hex.EncodeToString(hashed)

	log.Infof("processing message for signal: %v", common.Hash(event.Signal).Hex())

	auth, err := bind.NewKeyedTransactorWithChainID(svc.ecdsaKey, event.Message.DestChainId)
	if err != nil {
		return errors.Wrap(err, "bind.NewKeyedTransactorWithChainID")
	}

	log.Infof("calling eth_getProof")

	encodedSignalProof, err := svc.getEncodedSignalProof(ctx, event.Raw.Address, key, int64(blockNumber))
	if err != nil {
		return errors.Wrap(err, "s.getEncodedSignalProof")
	}

	log.Info("processing message")
	tx, err := svc.crossLayerBridge.ProcessMessage(auth, event.Message, encodedSignalProof)
	if err != nil {
		return errors.Wrap(err, "bridge.ProcessMessage")
	}

	log.Infof("waiting for tx hash %v", hex.EncodeToString(tx.Hash().Bytes()))

	// TODO: needs to be cross-layer ethclient, not layer we sent the message on.
	ch := relayer.WaitForTx(ctx, svc.crossLayerEthClient, tx.Hash())
	// wait for tx until mined
	<-ch

	log.Infof("Mined tx %s", hex.EncodeToString(tx.Hash().Bytes()))

	messageStatus, err := svc.crossLayerBridge.GetMessageStatus(&bind.CallOpts{}, event.Signal)
	if err != nil {
		return errors.Wrap(err, "bridge.GetMessageStatus")
	}

	// update message status
	if err := svc.eventRepo.UpdateStatus(e.ID, relayer.EventStatus(messageStatus)); err != nil {
		return errors.Wrap(err, "s.eventRepo.UpdateStatus")
	}
	return nil
}
