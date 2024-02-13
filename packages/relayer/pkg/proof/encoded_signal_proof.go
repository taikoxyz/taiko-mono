package proof

import (
	"context"
	"math/big"

	"log/slog"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/encoding"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/pkg/errors"
)

type HopParams struct {
	ChainID              *big.Int
	SignalServiceAddress common.Address
	SignalService        relayer.SignalService
	TaikoAddress         common.Address
	Blocker              blocker
	Caller               relayer.Caller
	BlockNumber          uint64
}

// EncodedSignalProof rlp and abi encodes the SignalProof struct expected by SignalService
// in our contracts. If there is no intermediary chain, and no `hops` are in between,
// it needs just a proof of the source SignalService having sent the signal.
// If it needs hops (ie: L1 => L3, L2A => L2B), it needs to generate proof calls for the hops
// as well, and we call `EncodedSignalProofWithHops` instead
func (p *Prover) EncodedSignalProof(
	ctx context.Context,
	caller relayer.Caller,
	signalServiceAddress common.Address,
	crossChainSyncAddress common.Address,
	key string,
	blockHash common.Hash,
) ([]byte, error) {
	return p.abiEncodeSignalProof(ctx,
		caller,
		signalServiceAddress,
		crossChainSyncAddress,
		key,
		blockHash,
	)
}

func (p *Prover) abiEncodeSignalProof(ctx context.Context,
	caller relayer.Caller,
	signalServiceAddress common.Address,
	crossChainSyncAddress common.Address,
	key string,
	blockHash common.Hash,
) ([]byte, error) {
	blockHeader, err := p.blockHeader(ctx, p.blocker, blockHash)
	if err != nil {
		return nil, errors.Wrap(err, "p.blockHeader")
	}

	encodedMerkleProof, _, err := p.abiEncodedMerkleProof(
		ctx,
		caller,
		signalServiceAddress,
		key,
		blockHeader.Height.Int64(),
	)
	if err != nil {
		return nil, errors.Wrap(err, "p.abiEncodedMerkleProof")
	}

	signalProof := encoding.SignalProof{
		Height:      blockHeader.Height.Uint64(),
		MerkleProof: encodedMerkleProof,
		Hops:        []encoding.Hop{},
	}

	encodedSignalProof, err := encoding.EncodeSignalProof(signalProof)
	if err != nil {
		return nil, errors.Wrap(err, "enoding.EncodeABISignalProof")
	}

	return encodedSignalProof, nil
}

func (p *Prover) EncodedSignalProofWithHops(
	ctx context.Context,
	caller relayer.Caller,
	signalServiceAddress common.Address,
	crossChainSyncAddress common.Address,
	hopParams []HopParams,
	key string,
	blockHash common.Hash,
	blockNum uint64,
) ([]byte, uint64, error) {
	return p.abiEncodeSignalProofWithHops(ctx,
		caller,
		signalServiceAddress,
		crossChainSyncAddress,
		hopParams,
		key,
		blockHash,
		blockNum,
	)
}

func (p *Prover) abiEncodeSignalProofWithHops(ctx context.Context,
	caller relayer.Caller,
	signalServiceAddress common.Address,
	crossChainSyncAddress common.Address,
	hopParams []HopParams,
	key string,
	blockHash common.Hash,
	blockNum uint64) ([]byte, uint64, error) {
	blockHeader, err := p.blockHeader(ctx, p.blocker, blockHash)
	if err != nil {
		return nil, 0, errors.Wrap(err, "p.blockHeader")
	}

	encodedMerkleProof, stateRoot, err := p.abiEncodedMerkleProof(
		ctx,
		caller,
		signalServiceAddress,
		key,
		blockHeader.Height.Int64(),
	)

	if err != nil {
		return nil, 0, errors.Wrap(err, "p.abiEncodedMerkleProof")
	}

	slog.Info("successfully generated main storage proof")

	hops := []encoding.Hop{}

	for _, hop := range hopParams {
		hopStorageSlotKey, err := hop.SignalService.GetSignalSlot(&bind.CallOpts{},
			hop.ChainID.Uint64(),
			hop.TaikoAddress,
			stateRoot,
		)
		if err != nil {
			return nil, 0, errors.Wrap(err, "hopSignalService.GetSignalSlot")
		}

		encodedHopMerkleProof, nextStateRoot, err := p.abiEncodedMerkleProof(
			ctx,
			hop.Caller,
			hop.SignalServiceAddress,
			common.Bytes2Hex(hopStorageSlotKey[:]),
			int64(hop.BlockNumber),
		)
		if err != nil {
			return nil, 0, errors.Wrap(err, "hop p.getEncodedMerkleProof")
		}

		hops = append(hops, encoding.Hop{
			ChainID:     hop.ChainID.Uint64(),
			Relay:       hop.TaikoAddress,
			StateRoot:   stateRoot,
			MerkleProof: encodedHopMerkleProof,
		})

		stateRoot = nextStateRoot
	}

	signalProof := encoding.SignalProof{
		Height:      blockNum,
		MerkleProof: encodedMerkleProof,
		Hops:        hops,
	}

	encodedSignalProof, err := encoding.EncodeSignalProof(signalProof)
	if err != nil {
		return nil, 0, errors.Wrap(err, "enoding.EncodeSignalProof")
	}

	return encodedSignalProof, blockHeader.Height.Uint64(), nil
}

// abiEncodedMerkleProof rlp and abi encodes a proof for SignalService,
// where `proof` is an rlp and abi encoded (bytes, bytes) consisting of storageProof.Proofs[0]
// response from `eth_getProof`, and returns the storageHash to be used as the signalRoot.
func (p *Prover) abiEncodedMerkleProof(
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

	encodedStorageProof, err := encoding.EncodeStorageProof(ethProof.AccountProof, ethProof.StorageProof[0].Proof)
	if err != nil {
		return nil, common.Hash{}, errors.Wrap(err, "encoding.EncodeStorageProof")
	}

	return encodedStorageProof, ethProof.StorageHash, nil
}
