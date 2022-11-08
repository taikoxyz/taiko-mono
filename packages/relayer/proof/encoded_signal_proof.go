package proof

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/rpc"
	"github.com/taikochain/taiko-mono/packages/relayer/encoding"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
)

// EncodedSignalProof rlp and abi encodes the SignalProof struct expected by LibBridgeSignal
// in our contracts
func (p *Prover) EncodedSignalProof(ctx context.Context, c *rpc.Client, bridgeAddress common.Address, key string, blockHash common.Hash) ([]byte, error) {
	blockHeader, err := p.blockHeader(ctx, blockHash)
	if err != nil {
		return nil, errors.Wrap(err, "p.blockHeader")
	}

	encodedStorageProof, err := p.encodedStorageProof(ctx, c, bridgeAddress, key, blockHeader.Height.Int64())
	if err != nil {
		return nil, errors.Wrap(err, "p.getEncodedStorageProof")
	}

	signalProof := encoding.SignalProof{
		Header: blockHeader,
		Proof:  encodedStorageProof,
	}

	encodedSignalProof, err := encoding.EncodeSignalProof(signalProof)
	if err != nil {
		return nil, errors.Wrap(err, "enoding.EncodeSignalProof")
	}

	log.Infof("signalProof: %s", hexutil.Encode(encodedSignalProof))
	return encodedSignalProof, nil
}

// getEncodedStorageProof rlp and abi encodes a proof for LibBridgeSignal,
// where `proof` is an rlp and abi encoded (bytes, bytes) consisting of the accountProof and storageProof.Proofs[0]
// response from `eth_getProof`
func (p *Prover) encodedStorageProof(ctx context.Context, c *rpc.Client, bridgeAddress common.Address, key string, blockNumber int64) ([]byte, error) {
	var ethProof StorageProof
	err := c.CallContext(ctx, &ethProof, "eth_getProof", bridgeAddress, []string{key}, hexutil.EncodeBig(new(big.Int).SetInt64(blockNumber)))
	if new(big.Int).SetBytes(ethProof.StorageProof[0].Value).Int64() != int64(1) {
		return nil, errors.New("proof will not be valid, expected storageProof to be 1 but was not")
	}

	rlpEncodedAccountProof, err := rlp.EncodeToBytes(ethProof.AccountProof)
	if err != nil {
		return nil, errors.Wrap(err, "rlp.EncodeToBytes(proof.AccountProof")
	}

	rlpEncodedStorageProof, err := rlp.EncodeToBytes(ethProof.StorageProof[0].Proof)
	if err != nil {
		return nil, errors.Wrap(err, "rlp.EncodeToBytes(proof.StorageProof[0].Proof")
	}

	encodedStorageProof, err := encoding.EncodeStorageProof(rlpEncodedAccountProof, rlpEncodedStorageProof)
	if err != nil {
		return nil, errors.Wrap(err, "encoding.EncodeStorageProof")
	}

	return encodedStorageProof, nil
}
