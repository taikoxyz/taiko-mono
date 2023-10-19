package proof

import (
	"context"
	"math/big"

	"log/slog"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/icrosschainsync"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/signalservice"
	"github.com/taikoxyz/taiko-mono/packages/relayer/encoding"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/rlp"
	"github.com/pkg/errors"
)

type HopParams struct {
	ChainID              *big.Int
	SignalServiceAddress common.Address
	Blocker              blocker
	LatestSyncedSnippet  icrosschainsync.ICrossChainSyncSnippet
	Key                  string
	Caller               relayer.Caller
	BlockHash            common.Hash
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
	key string,
	blockHash common.Hash,
) ([]byte, error) {
	blockHeader, err := p.blockHeader(ctx, p.blocker, blockHash)
	if err != nil {
		return nil, errors.Wrap(err, "p.blockHeader")
	}

	encodedStorageProof, _, err := p.encodedStorageProof(
		ctx,
		caller,
		signalServiceAddress,
		key,
		blockHeader.Height.Int64(),
	)
	if err != nil {
		return nil, errors.Wrap(err, "p.getEncodedStorageProof")
	}

	signalProof := encoding.SignalProof{
		Height:       blockHeader.Height.Uint64(),
		StorageProof: encodedStorageProof,
		Hops:         []encoding.Hop{},
	}

	encodedSignalProof, err := encoding.EncodeSignalProof(signalProof)
	if err != nil {
		return nil, errors.Wrap(err, "enoding.EncodeSignalProof")
	}

	return encodedSignalProof, nil
}

func (p *Prover) EncodedSignalProofWithHops(
	ctx context.Context,
	caller relayer.Caller,
	signalServiceAddress common.Address,
	hopParams []HopParams,
	hopSignalService *signalservice.SignalService,
	hopTaikoAddress common.Address,
	hopChainID *big.Int,
) ([]byte, uint64, error) {
	hops := []encoding.Hop{}

	var signalRoot common.Hash

	// var hopBlockHeaderHeight uint64

	var blockHeader encoding.BlockHeader

	for _, hopParam := range hopParams {
		hopBlockHeader, err := p.blockHeader(ctx, hopParam.Blocker, hopParam.BlockHash)
		if err != nil {
			return nil, 0, errors.Wrap(err, "hop p.blockHeader")
		}

		encodedHopStorageProof, hopSignalRoot, err := p.encodedStorageProof(
			ctx,
			hopParam.Caller,
			hopParam.SignalServiceAddress,
			hopParam.Key,
			hopBlockHeader.Height.Int64(),
		)

		if err != nil {
			return nil, 0, errors.Wrap(err, "hop p.encodedStorageProof")
		}

		slog.Info("successfully generated hop proof")

		hop := encoding.Hop{
			ChainID:      hopParam.ChainID,
			SignalRoot:   hopSignalRoot,
			StorageProof: encodedHopStorageProof,
		}

		hops = append(hops, hop)

		signalRoot = hopSignalRoot

		blockHeader = hopBlockHeader
	}

	slog.Info("hop signal root", "root", signalRoot.Hex())

	// if err := waitHeaderSyncFunc(hopBlockHeaderHeight); err != nil {
	// 	return nil, errors.Wrap(err, "waitHeaderSyncFunc")
	// }

	key, err := hopSignalService.GetSignalSlot(&bind.CallOpts{},
		hopChainID,
		hopTaikoAddress,
		signalRoot,
	)
	if err != nil {
		return nil, 0, errors.Wrap(err, "hopSignalService.GetSignalSlot")
	}

	encodedStorageProof, _, err := p.encodedStorageProof(
		ctx,
		caller,
		signalServiceAddress,
		common.Bytes2Hex(key[:]),
		5064,
	)
	if err != nil {
		return nil, 0, errors.Wrap(err, "p.getEncodedStorageProof")
	}

	slog.Info("blockHeightSignalProof", "height", blockHeader.Height.Uint64())

	signalProof := encoding.SignalProof{
		Height:       blockHeader.Height.Uint64(),
		StorageProof: encodedStorageProof,
		Hops:         hops,
	}

	encodedSignalProof, err := encoding.EncodeSignalProof(signalProof)
	if err != nil {
		return nil, 0, errors.Wrap(err, "enoding.EncodeSignalProof")
	}

	return encodedSignalProof, blockHeader.Height.Uint64(), nil
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
