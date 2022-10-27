package indexer

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikochain/taiko-mono/packages/relayer"
)

// blockHeader converts an ethereum block to the BlockHeader type that LibBridgeData
// uses in our contracts
func (s *Service) blockHeader(ctx context.Context, blockNumber int64) (*BlockHeader, error) {
	block, err := s.ethClient.BlockByNumber(ctx, big.NewInt(int64(blockNumber)))
	if err != nil {
		return nil, errors.Wrap(err, "s.ethClient.GetBlockByNumber")
	}

	return &BlockHeader{
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

// getEncodedSignalProof rlp and abi encodes the SignalProof struct expected by LibBridgeSignal
// in our contracts, which looks like:
// SignalProof struct {
//  BlockHeader header
//  byte[] proof
// }
func (s *Service) getEncodedSignalProof(ctx context.Context, bridgeAddress common.Address, key string, blockNumber int64) ([]byte, error) {
	encodedStorageProof, err := s.getEncodedStorageProof(ctx, bridgeAddress, key, int64(blockNumber))
	if err != nil {
		return nil, errors.Wrap(err, "s.getEncodedStorageProof")
	}

	blockHeader, err := s.blockHeader(ctx, int64(blockNumber))
	if err != nil {
		return nil, errors.Wrap(err, "s.blockHeader")
	}

	signalProof := &SignalProof{
		Header: *blockHeader,
		Proof:  encodedStorageProof,
	}

	log.Info("abi encoding signal proof")
	return signalProofType.Encode(signalProof)
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

	p := Proof{
		AccountProof: rlpEncodedAccountProof,
		StorageProof: rlpEncodedStorageProof,
	}

	log.Info("abi encoding accountProof")
	encodedStorageProof, err := storageProofType.Encode(&p)
	if err != nil {
		return nil, errors.Wrap(err, "storageProofType.Encode(p)")
	}
	return encodedStorageProof, nil
}
