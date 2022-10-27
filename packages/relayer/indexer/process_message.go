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
	"github.com/umbracle/ethgo/abi"
)

var (
	signalProofType  = abi.MustNewType("tuple(tuple(bytes32 parenthash, bytes32 ommershash, address beneficiary, bytes32 stateroot, bytes32 transactionsroot, bytes32 receiptsroot, bytes32[8] logsbloom, uint256 difficulty, uint128 height, uint64 gaslimit, uint64 gasused, uint64 timestamp, bytes extradata, bytes32 mixhash, uint64 nonce) header, bytes proof)")
	storageProofType = abi.MustNewType("bytes")
)

// processMessage prepares and calls `processMessage` on the bridge.
// the proof must be generated from the gethclient's eth_getProof,
// then rlp-encoded and combined as a singular byte slice,
// as the contract expects
func (s *Service) processMessage(
	ctx context.Context,
	event *contracts.BridgeMessageSent,
	crossLayerBridgeAddress string,
) error {
	signal := event.Signal
	message := event.Message
	bridgeAddress := event.Raw.Address

	blockNumber := event.Raw.BlockNumber

	hashed := solsha3.SoliditySHA3(
		solsha3.Address(bridgeAddress),
		solsha3.Bytes32(signal),
	)

	key := hex.EncodeToString(hashed)

	log.Infof("processing message for signal: %v", common.Hash(signal).Hex())

	auth, err := bind.NewKeyedTransactorWithChainID(s.ecdsaKey, message.DestChainId)
	if err != nil {
		return errors.Wrap(err, "bind.NewKeyedTransactorWithChainID")
	}

	log.Infof("calling eth_getProof")

	// TODO: block should not be nil, but event.Raw.BlockNumber.
	// however, this is throwing a missing trie error with our L1 geth client.
	proof, err := s.gethClient.GetProof(ctx, bridgeAddress, []string{key}, big.NewInt(int64(blockNumber)))
	if err != nil {
		return errors.Wrap(err, "s.gethClient.GetProof")
	}

	log.Infof("proof value is %v", proof.StorageProof[0].Value.Int64())

	log.Info("rlp encoding account proof")

	rlpEncodedAccountProof, err := rlp.EncodeToBytes(proof.AccountProof)
	if err != nil {
		return errors.Wrap(err, "rlp.EncodeToBytes(proof.AccountProof")
	}

	log.Info("rlp encoding storage proof")
	rlpEncodedStorageProof, err := rlp.EncodeToBytes(proof.StorageProof[0].Proof)
	if err != nil {
		return errors.Wrap(err, "rlp.EncodeToBytes(proof.StorageProof[0].Proof")
	}

	block, err := s.ethClient.BlockByNumber(ctx, big.NewInt(int64(blockNumber)))
	if err != nil {
		return errors.Wrap(err, "s.ethClient.GetBlockByNumber")
	}
	log.Info("converting logsbloom")
	var logsBloom = [8][32]byte{}
	bloom := [256]byte(block.Bloom())
	index := 0
	for i := 0; i < 256; i += 32 {
		end := i + 31
		b := bloom[i:end]
		var r [32]byte
		copy(r[:], b)
		logsBloom[index] = r
		index++
	}

	blockHeader := relayer.BlockHeader{
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
		LogsBloom:        logsBloom,
	}

	p := bytes.Join([][]byte{rlpEncodedAccountProof, rlpEncodedStorageProof}, nil)
	log.Info("abi encoding storageProof")
	encodedProof, err := storageProofType.Encode(p)
	if err != nil {
		return errors.Wrap(err, "storageProofType.Encode(p)")
	}

	signalProof := relayer.SignalProof{
		Header: blockHeader,
		Proof:  encodedProof,
	}

	log.Info("abi encoding signal proof")
	encodedSignalProof, err := signalProofType.Encode(signalProof)
	if err != nil {
		return errors.Wrap(err, "signalProofType.Encode")
	}

	bridge, err := contracts.NewBridge(common.HexToAddress(crossLayerBridgeAddress), s.crossLayerEthClient)
	if err != nil {
		return errors.Wrap(err, "contracts.NewBridge")
	}

	log.Info("processing message")
	tx, err := bridge.ProcessMessage(auth, message, encodedSignalProof)
	if err != nil {
		return errors.Wrap(err, "bridge.ProcessMessage")
	}

	// TODO: needs to be cross-layer ethclient, not layer we sent the message on.
	ch := relayer.WaitForTx(ctx, s.crossLayerEthClient, tx.Hash())
	// wait for tx until mined
	<-ch

	log.Infof("Mined tx %s", tx.Hash())

	// TODO: update event in DB to be processed, or retriable if it failed
	return nil
}

// encodePacked replicates solidity's `abi.encodePacked`
func encodePacked(input ...[]byte) []byte {
	return bytes.Join(input, nil)
}

func encodeBytesString(v string) []byte {
	decoded, err := hex.DecodeString(v)
	if err != nil {
		panic(err)
	}
	return decoded
}
