package indexer

import (
	"context"
	"fmt"
	"math/big"

	"github.com/davecgh/go-spew/spew"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/ethereum/go-ethereum/rpc"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikochain/taiko-mono/packages/relayer"
	"github.com/taikochain/taiko-mono/packages/relayer/proof"
)

// blockHeader converts an ethereum block to the BlockHeader type that LibBridgeData
// uses in our contracts
func (s *Service) blockHeader(ctx context.Context, blockNumber int64) (proof.BlockHeader, error) {
	block, err := s.ethClient.BlockByNumber(ctx, big.NewInt(int64(blockNumber)))
	if err != nil {
		return proof.BlockHeader{}, errors.Wrap(err, "s.ethClient.GetBlockByNumber")
	}

	log.Infof("state root", block.Root())

	return proof.BlockHeader{
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
		LogsBloom:        proof.LogsBloomToBytes(block.Bloom()),
	}, nil
}

// getEncodedSignalProof rlp and abi encodes the SignalProof struct expected by LibBridgeSignal
// in our contracts
func (s *Service) getEncodedSignalProof(ctx context.Context, c *rpc.Client, bridgeAddress common.Address, key string, blockNumber int64) ([]byte, error) {
	encodedStorageProof, err := s.getEncodedStorageProof(ctx, c, bridgeAddress, key, int64(blockNumber))
	if err != nil {
		return nil, errors.Wrap(err, "s.getEncodedStorageProof")
	}

	blockHeader, err := s.blockHeader(ctx, int64(blockNumber))
	if err != nil {
		return nil, errors.Wrap(err, "s.blockHeader")
	}

	signalProof := proof.SignalProof{
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
func (s *Service) getEncodedStorageProof(ctx context.Context, c *rpc.Client, bridgeAddress common.Address, key string, blockNumber int64) ([]byte, error) {
	var ethProof proof.StorageProof
	err := c.CallContext(ctx, &ethProof, "eth_getProof", bridgeAddress, []string{key}, hexutil.EncodeBig(new(big.Int).SetInt64(blockNumber)))
	if new(big.Int).SetBytes(ethProof.StorageProof[0].Value).Int64() != int64(1) {
		return nil, errors.New("proof will not be valid, expected storageProof to be 1 but was not")
	}

	log.Info("rlp encoding account proof")
	spew.Dump(ethProof)

	rlpEncodedAccountProof, err := rlp.EncodeToBytes(ethProof.AccountProof)
	if err != nil {
		return nil, errors.Wrap(err, "rlp.EncodeToBytes(proof.AccountProof")
	}

	log.Infof("rlpEncodedAccountProof: %s", common.Bytes2Hex(rlpEncodedAccountProof))

	log.Info("rlp encoding storage proof")
	rlpEncodedStorageProof, err := rlp.EncodeToBytes(ethProof.StorageProof[0].Proof)
	if err != nil {
		return nil, errors.Wrap(err, "rlp.EncodeToBytes(proof.StorageProof[0].Proof")
	}

	log.Infof("rlpEncodedStorageProof: %s", hexutil.Encode(rlpEncodedStorageProof))

	inAbi, err := relayer.StringToABI(relayer.StorageProofAbiString)
	if err != nil {
		return nil, errors.Wrap(err, fmt.Sprintf("invalid ABI definition %s, %v", relayer.StorageProofAbiString, err))
	}
	p := proof.Proof{
		AccountProof: rlpEncodedAccountProof,
		StorageProof: rlpEncodedStorageProof,
	}
	encodedStorageProof, err := inAbi.Pack("method", p)
	if err != nil {
		return nil, errors.Wrap(err, "inAbiPack")
	}

	log.Infof("encodedStorageProof: %s", hexutil.Encode(encodedStorageProof[4:]))
	return encodedStorageProof[4:], nil
}
