package proof

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/rpc"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
)

// EncodedSignalProof rlp and abi encodes the SignalProof struct expected by LibBridgeSignal
// in our contracts
func (p *Prover) EncodedSignalProof(ctx context.Context, c *rpc.Client, bridgeAddress common.Address, key string, blockNumber int64) ([]byte, error) {
	encodedStorageProof, err := p.encodedStorageProof(ctx, c, bridgeAddress, key, int64(blockNumber))
	if err != nil {
		return nil, errors.Wrap(err, "p.getEncodedStorageProof")
	}

	blockHeader, err := p.blockHeader(ctx, int64(blockNumber))
	if err != nil {
		return nil, errors.Wrap(err, "p.blockHeader")
	}

	signalProof := SignalProof{
		Header: blockHeader,
		Proof:  encodedStorageProof,
	}

	args := abi.Arguments{
		{
			Type: signalProofT,
		},
	}

	encodedSignalProof, err := args.Pack(signalProof)
	if err != nil {
		return nil, errors.Wrap(err, "args.Pack")
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

	log.Info("rlp encoding account proof")

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

	args := abi.Arguments{
		{
			Type: bytesT,
		},
		{
			Type: bytesT,
		},
	}

	encodedStorageProof, err := args.Pack(rlpEncodedAccountProof, rlpEncodedStorageProof)
	if err != nil {
		return nil, errors.Wrap(err, "args.Pack")
	}

	log.Infof("encodedStorageProof: %s", hexutil.Encode(encodedStorageProof))
	return encodedStorageProof, nil
}
