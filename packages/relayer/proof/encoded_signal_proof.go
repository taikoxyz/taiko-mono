package proof

import (
	"context"
	"math/big"

	"log/slog"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/encoding"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/pkg/errors"
)

type HopParams struct {
	ChainID              *big.Int
	SignalServiceAddress common.Address
	Blocker              blocker
}

// EncodedSignalProof rlp and abi encodes the SignalProof struct expected by LibBridgeSignal
// in our contracts
func (p *Prover) EncodedSignalProof(
	ctx context.Context,
	caller relayer.Caller,
	signalServiceAddress common.Address,
	hopParams []HopParams,
	key string,
	blockHash common.Hash,
) ([]byte, error) {
	blockHeader, err := p.blockHeader(ctx, p.blocker, blockHash)
	if err != nil {
		return nil, errors.Wrap(err, "p.blockHeader")
	}

	encodedStorageProof, signalRoot, err := p.encodedStorageProof(
		ctx,
		caller,
		signalServiceAddress,
		key,
		blockHeader.Height.Int64(),
	)
	if err != nil {
		return nil, errors.Wrap(err, "p.getEncodedStorageProof")
	}

	hops := []encoding.Hop{}

	for _, hopParam := range hopParams {
		hopBlockHeader, err := p.blockHeader(ctx, hopParam.Blocker, common.Hash{})
		if err != nil {
			return nil, errors.Wrap(err, "hop p.blockHeader")
		}

		encodedHopStorageProof, signalRoot, err := p.encodedStorageProof(
			ctx,
			caller,
			hopParam.SignalServiceAddress,
			signalRoot.Hex(),
			hopBlockHeader.Height.Int64(),
		)

		if err != nil {
			return nil, errors.Wrap(err, "hop p.encodedStorageProof")
		}

		hop := encoding.Hop{
			ChainID:      hopParam.ChainID,
			SignalRoot:   signalRoot,
			StorageProof: encodedHopStorageProof,
		}

		hops = append(hops, hop)
	}

	signalProof := encoding.SignalProof{
		Height:       blockHeader.Height.Uint64(),
		StorageProof: encodedStorageProof,
		Hops:         hops,
	}

	encodedSignalProof, err := encoding.EncodeSignalProof(signalProof)
	if err != nil {
		return nil, errors.Wrap(err, "enoding.EncodeSignalProof")
	}

	return encodedSignalProof, nil
}

// getEncodedStorageProof rlp and abi encodes a proof for SignalService,
// where `proof` is an rlp and abi encoded (bytes, bytes) consisting of storageProof.Proofs[0]
// response from `eth_getProof`, and returns the storageHash to be used as the signalRoot.
func (p *Prover) encodedStorageProof(
	ctx context.Context,
	c relayer.Caller,
	signalServiceAddress common.Address,
	key string,
	blockNumber int64,
) ([]byte, common.Hash, error) {
	var ethProof StorageProof

	slog.Info("getting proof",
		"signalServiceAddress", signalServiceAddress.Hex(),
		"key", key,
		"blockNum", blockNumber,
	)

	err := c.CallContext(ctx,
		&ethProof,
		"eth_getProof",
		signalServiceAddress,
		[]string{key},
		hexutil.EncodeBig(new(big.Int).SetInt64(blockNumber)),
	)
	if err != nil {
		return nil, common.Hash{}, errors.Wrap(err, "c.CallContext")
	}

	slog.Info("proof generated", "value", new(big.Int).SetBytes(ethProof.StorageProof[0].Value).Int64())

	if new(big.Int).SetBytes(ethProof.StorageProof[0].Value).Int64() != int64(1) {
		return nil, common.Hash{}, errors.New("proof will not be valid, expected storageProof to be 1 but was not")
	}

	rlpEncodedStorageProof, err := rlp.EncodeToBytes(ethProof.StorageProof[0].Proof)
	if err != nil {
		return nil, common.Hash{}, errors.Wrap(err, "rlp.EncodeToBytes(proof.StorageProof[0].Proof")
	}

	return rlpEncodedStorageProof, ethProof.StorageHash, nil
}
