package indexer

import (
	"context"
	"fmt"
	"math/big"
	"strings"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
)

// blockHeader converts an ethereum block to the BlockHeader type that LibBridgeData
// uses in our contracts
func (s *Service) blockHeader(ctx context.Context, blockNumber int64) (BlockHeader, error) {
	block, err := s.ethClient.BlockByNumber(ctx, big.NewInt(int64(blockNumber)))
	if err != nil {
		return BlockHeader{}, errors.Wrap(err, "s.ethClient.GetBlockByNumber")
	}

	return BlockHeader{
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
		LogsBloom:        [8][32]byte{},
	}, nil
}

// getEncodedSignalProof rlp and abi encodes the SignalProof struct expected by LibBridgeSignal
// in our contracts
func (s *Service) getEncodedSignalProof(ctx context.Context, bridgeAddress common.Address, key string, blockNumber int64) ([]byte, error) {
	encodedStorageProof, err := s.getEncodedStorageProof(ctx, bridgeAddress, key, int64(blockNumber))
	if err != nil {
		return nil, errors.Wrap(err, "s.getEncodedStorageProof")
	}

	blockHeader, err := s.blockHeader(ctx, int64(blockNumber))
	if err != nil {
		return nil, errors.Wrap(err, "s.blockHeader")
	}

	signalProof := SignalProof{
		Header: blockHeader,
		Proof:  encodedStorageProof,
	}

	inDef := fmt.Sprintf(`[{ "name" : "method", "type": "function", "inputs": %s}]`, signalProofAbiString)
	inAbi, err := JSON(strings.NewReader(inDef))
	if err != nil {
		return nil, errors.Wrap(err, fmt.Sprintf("invalid ABI definition %s, %v", signalProofAbiString, err))
	}
	encodedSignalProof, err := inAbi.Pack("method", signalProof)
	if err != nil {
		return nil, errors.Wrap(err, "inAbiPack")
	}

	log.Infof("signalProof: %s", hexutil.Encode(encodedSignalProof))
	return encodedSignalProof[4:], nil
}

// getEncodedStorageProof rlp and abi encodes a proof for LibBridgeSignal,
// where `proof` is an rlp and abi encoded (bytes, bytes) consisting of the accountProof and storageProof.Proofs[0]
// response from `eth_getProof`
func (s *Service) getEncodedStorageProof(ctx context.Context, bridgeAddress common.Address, key string, blockNumber int64) ([]byte, error) {
	proof, err := s.gethClient.GetProof(ctx, bridgeAddress, []string{key}, big.NewInt(blockNumber))
	if err != nil {
		return nil, errors.Wrap(err, "s.gethClient.GetProof")
	}
	if proof.StorageProof[0].Value.Int64() != int64(1) {
		return nil, errors.New("proof will not be valid, expected storageProof to be 1 but was not")
	}

	log.Info("rlp encoding account proof")

	accountProofSliceData := make(SliceData, 0)
	for _, p := range proof.AccountProof {
		accountProofSliceData = append(accountProofSliceData, []byte(p))
	}

	rlpEncodedAccountProof, err := rlp.EncodeToBytes(accountProofSliceData)
	if err != nil {
		return nil, errors.Wrap(err, "rlp.EncodeToBytes(proof.AccountProof")
	}

	log.Info("rlp encoding storage proof")
	storageProofStorageResult := StorageResult{}
	storageProofStorageResult.Key = QuantityBytes(proof.StorageProof[0].Key)
	storageProofStorageResult.Value = QuantityBytes(proof.StorageProof[0].Value.Bytes())
	storageProofSliceData := make(SliceData, 0)
	for _, p := range proof.StorageProof[0].Proof {
		storageProofSliceData = append(storageProofSliceData, []byte(p))
	}

	storageProofStorageResult.Proof = storageProofSliceData
	rlpEncodedStorageProof, err := rlp.EncodeToBytes(storageProofStorageResult)
	if err != nil {
		return nil, errors.Wrap(err, "rlp.EncodeToBytes(proof.StorageProof[0].Proof")
	}

	inDef := fmt.Sprintf(`[{ "name" : "method", "type": "function", "inputs": %s}]`, storageProofAbiString)
	inAbi, err := JSON(strings.NewReader(inDef))
	if err != nil {
		return nil, errors.Wrap(err, fmt.Sprintf("invalid ABI definition %s, %v", storageProofAbiString, err))
	}
	p := Proof{
		AccountProof: rlpEncodedAccountProof,
		StorageProof: rlpEncodedStorageProof,
	}
	encodedStorageProof, err := inAbi.Pack("method", p)
	if err != nil {
		return nil, errors.Wrap(err, "inAbiPack")
	}
	return encodedStorageProof[4:], nil
}
