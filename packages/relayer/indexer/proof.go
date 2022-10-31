package indexer

import (
	"context"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikochain/taiko-mono/packages/relayer"
)

// blockHeader converts an ethereum block to the BlockHeader type that LibBridgeData
// uses in our contracts
func (s *Service) blockHeader(ctx context.Context, blockNumber int64) (relayer.BlockHeader, error) {
	block, err := s.ethClient.BlockByNumber(ctx, big.NewInt(int64(blockNumber)))
	if err != nil {
		return relayer.BlockHeader{}, errors.Wrap(err, "s.ethClient.GetBlockByNumber")
	}

	return relayer.BlockHeader{
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

	signalProof := relayer.SignalProof{
		Header: blockHeader,
		Proof:  encodedStorageProof,
	}

	inAbi, err := relayer.StringToABI(relayer.SignalProofAbiString)
	if err != nil {
		return nil, errors.Wrap(err, fmt.Sprintf("invalid ABI definition %s, %v", relayer.SignalProofAbiString, err))
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

	rlpEncodedAccountProof, err := rlp.EncodeToBytes(proof.AccountProof)
	if err != nil {
		return nil, errors.Wrap(err, "rlp.EncodeToBytes(proof.AccountProof")
	}

	log.Info("rlp encoding storage proof")
	rlpEncodedStorageProof, err := rlp.EncodeToBytes(proof.StorageProof[0].Proof)
	if err != nil {
		return nil, errors.Wrap(err, "rlp.EncodeToBytes(proof.StorageProof[0].Proof")
	}

	inAbi, err := relayer.StringToABI(relayer.StorageProofAbiString)
	if err != nil {
		return nil, errors.Wrap(err, fmt.Sprintf("invalid ABI definition %s, %v", relayer.StorageProofAbiString, err))
	}
	p := relayer.Proof{
		AccountProof: rlpEncodedAccountProof,
		StorageProof: rlpEncodedStorageProof,
	}
	encodedStorageProof, err := inAbi.Pack("method", p)
	if err != nil {
		return nil, errors.Wrap(err, "inAbiPack")
	}
	return encodedStorageProof[4:], nil
}
