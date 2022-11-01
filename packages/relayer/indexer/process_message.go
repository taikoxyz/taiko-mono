package indexer

import (
	"context"
	"encoding/hex"
	"math/big"

	"github.com/davecgh/go-spew/spew"
	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
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
	spew.Dump(event.Message)
	blockNumber := event.Raw.BlockNumber

	hashed := solsha3.SoliditySHA3(
		solsha3.Address(event.Raw.Address),
		solsha3.Bytes32(event.Signal),
	)

	key := hex.EncodeToString(hashed)

	log.Infof("processing message for signal: %v, key: %v", common.Hash(event.Signal).Hex(), key)

	auth, err := bind.NewKeyedTransactorWithChainID(svc.ecdsaKey, event.Message.DestChainId)
	if err != nil {
		return errors.Wrap(err, "bind.NewKeyedTransactorWithChainID")
	}

	// uncomment to skip `eth_estimateGas`
	auth.GasLimit = 200000
	auth.GasPrice = new(big.Int).SetUint64(500000000)

	log.Infof("getting proof")
	encodedSignalProof, err := svc.getEncodedSignalProof(ctx, svc.rpc, event.Raw.Address, key, int64(blockNumber))
	if err != nil {
		return errors.Wrap(err, "s.getEncodedSignalProof")
	}
	decode, err := contracts.NewDecode(common.HexToAddress("0x6BdBb69660E6849b98e8C524d266a0005D3655F7"), svc.crossLayerEthClient)
	if err != nil {
		return errors.Wrap(err, "contracts.Decode")
	}

	err = decode.DecodeBoth(&bind.CallOpts{}, encodedSignalProof)
	if err != nil {
		return errors.Wrap(err, "decode.Decode")
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

	r, err := GetFailingMessage(*svc.crossLayerEthClient, tx.Hash())
	if err != nil {
		return errors.Wrap(err, "GetFailingMessage")
	}

	log.Infof("reason: %s", r)

	log.Infof("updating message status to %s", relayer.EventStatus(messageStatus).String())

	// update message status
	if err := svc.eventRepo.UpdateStatus(e.ID, relayer.EventStatus(messageStatus)); err != nil {
		return errors.Wrap(err, "s.eventRepo.UpdateStatus")
	}
	return nil
}

func GetFailingMessage(client ethclient.Client, hash common.Hash) (string, error) {
	tx, _, err := client.TransactionByHash(context.Background(), hash)
	if err != nil {
		return "", err
	}

	from, err := types.Sender(types.NewEIP155Signer(tx.ChainId()), tx)
	if err != nil {
		return "", err
	}

	msg := ethereum.CallMsg{
		From:     from,
		To:       tx.To(),
		Gas:      tx.Gas(),
		GasPrice: tx.GasPrice(),
		Value:    tx.Value(),
		Data:     tx.Data(),
	}

	res, err := client.CallContract(context.Background(), msg, nil)
	if err != nil {
		return "", err
	}

	return string(res), nil
}
