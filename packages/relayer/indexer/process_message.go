package indexer

import (
	"bytes"
	"context"
	"encoding/hex"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/rlp"
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
func (s *Service) processMessage(
	ctx context.Context,
	event *contracts.BridgeMessageSent,
	e *relayer.Event,
	crossLayerBridgeAddress string,
) error {
	blockNumber := event.Raw.BlockNumber

	hashed := solsha3.SoliditySHA3(
		solsha3.Address(event.Raw.Address),
		solsha3.Bytes32(event.Signal),
	)

	key := hex.EncodeToString(hashed)

	log.Infof("processing message for signal: %v", common.Hash(event.Signal).Hex())

	auth, err := bind.NewKeyedTransactorWithChainID(s.ecdsaKey, event.Message.DestChainId)
	if err != nil {
		return errors.Wrap(err, "bind.NewKeyedTransactorWithChainID")
	}

	log.Infof("calling eth_getProof")

	encodedSignalProof, err := s.getEncodedSignalProof(ctx, event.Raw.Address, key, int64(blockNumber))
	if err != nil {
		return errors.Wrap(err, "s.getEncodedSignalProof")
	}

	bridge, err := contracts.NewBridge(common.HexToAddress(crossLayerBridgeAddress), s.crossLayerEthClient)
	if err != nil {
		return errors.Wrap(err, "contracts.NewBridge")
	}

	log.Info("processing message")
	tx, err := bridge.ProcessMessage(auth, event.Message, encodedSignalProof)
	if err != nil {
		return errors.Wrap(err, "bridge.ProcessMessage")
	}

	log.Info("waiting for tx hash %v", hex.EncodeToString(tx.Hash().Bytes()))

	// TODO: needs to be cross-layer ethclient, not layer we sent the message on.
	ch := relayer.WaitForTx(ctx, s.crossLayerEthClient, tx.Hash())
	// wait for tx until mined
	<-ch

	log.Infof("Mined tx %s", hex.EncodeToString(tx.Hash().Bytes()))

	messageStatus, err := bridge.GetMessageStatus(&bind.CallOpts{}, event.Signal)
	if err != nil {
		return errors.Wrap(err, "bridge.GetMessageStatus")
	}

	// update message status
	if err := s.eventRepo.UpdateStatus(e.ID, relayer.EventStatus(messageStatus)); err != nil {
		return errors.Wrap(err, "s.eventRepo.UpdateStatus")
	}
	return nil
}

func (s *Service) blockHeader(ctx context.Context, blockNumber int64) (*relayer.BlockHeader, error) {
	block, err := s.ethClient.BlockByNumber(ctx, big.NewInt(int64(blockNumber)))
	if err != nil {
		return nil, errors.Wrap(err, "s.ethClient.GetBlockByNumber")
	}
	return &relayer.BlockHeader{
		ParentHash:       block.ParentHash(),
		OmmersHash:       block.UncleHash(),
		Beneficiary:      block.Coinbase(),
		TransactionsRoot: block.TxHash(),
		ReceiptsRoot:     block.ReceiptHash(),
		Difficulty:       block.Difficulty(),
		Height:           block.Number(),
		GasLimit:         block.GasLimit(),
		GasUsed:          block.GasUsed(),
		Timestamp:        block.Time(),
		ExtraData:        block.Extra(),
		MixHash:          block.MixDigest(),
		Nonce:            block.Nonce(),
		StateRoot:        block.Root(),
		LogsBloom:        relayer.LogsBloomToBytes(block.Bloom()),
	}, nil
}

func (s *Service) getEncodedSignalProof(ctx context.Context, bridgeAddress common.Address, key string, blockNumber int64) ([]byte, error) {
	encodedStorageProof, err := s.getEncodedStorageProof(ctx, bridgeAddress, key, int64(blockNumber))
	if err != nil {
		return nil, errors.Wrap(err, "s.getEncodedStorageProof")
	}

	blockHeader, err := s.blockHeader(ctx, int64(blockNumber))
	if err != nil {
		return nil, errors.Wrap(err, "s.blockHeader")
	}

	signalProof := &relayer.SignalProof{
		Header: *blockHeader,
		Proof:  encodedStorageProof,
	}

	log.Info("abi encoding signal proof")
	return signalProofType.Encode(signalProof)
}

func (s *Service) getEncodedStorageProof(ctx context.Context, bridgeAddress common.Address, key string, blockNumber int64) ([]byte, error) {
	proof, err := s.gethClient.GetProof(ctx, bridgeAddress, []string{key}, big.NewInt(blockNumber))
	if err != nil {
		return nil, errors.Wrap(err, "s.gethClient.GetProof")
	}

	if proof.StorageProof[0].Value.Int64() != int64(1) {
		return nil, errors.New("proof will not be valid, expected storageProof to be 1 but was not")
	}

	log.Info("rlp encoding account proof")

	rlpEncodedAccountProof, err := rlp.EncodeToBytes(proof.AccountProof)
	if err != nil {
		return nil, errors.Wrap(err, "rlp.EncodeToBytes(proof.AccountProof")
	}

	log.Info("rlp encoding storage proof")
	rlpEncodedStorageProof, err := rlp.EncodeToBytes(proof.StorageProof[0].Proof)
	if err != nil {
		return nil, errors.Wrap(err, "rlp.EncodeToBytes(proof.StorageProof[0].Proof")
	}

	log.Info("abi encoding accountProof")
	encodedAccountProof, err := storageProofType.Encode(rlpEncodedAccountProof)
	if err != nil {
		return nil, errors.Wrap(err, "storageProofType.Encode(p)")
	}

	log.Info("abi encoding storageProof")
	encodedStorageProof, err := storageProofType.Encode(rlpEncodedStorageProof)
	if err != nil {
		return nil, errors.Wrap(err, "storageProofType.Encode(p)")
	}
	return bytes.Join([][]byte{encodedAccountProof, encodedStorageProof}, nil), nil
}
