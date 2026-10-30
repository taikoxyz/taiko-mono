package proof

import (
	"context"
	"math/big"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/encoding"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/pkg/errors"
)

// ErrStateRootMismatch means the source block at the proof's block number no longer has the state
// root the caller expected, as after a source-chain reorg. A later attempt can succeed.
var ErrStateRootMismatch = errors.New("source block state root does not match the expected root")

type SignalProofParams struct {
	ChainID              *big.Int
	SignalServiceAddress common.Address
	Key                  [32]byte
	Blocker              blocker
	Caller               relayer.Caller
	BlockNumber          uint64
	// BlockID, when non-zero, is the proof's blockId instead of BlockNumber. After the Etna fork,
	// L2 verifies L1 signals by the timestamp of the L2 block that recorded the L1 state root.
	BlockID uint64
	// StateRoot, when non-zero, is the state root the block at BlockNumber must have.
	StateRoot common.Hash
}

func (p *Prover) EncodedSignalProof(ctx context.Context,
	params SignalProofParams,
) ([]byte, error) {
	block, err := params.Blocker.BlockByNumber(
		ctx,
		new(big.Int).SetUint64(params.BlockNumber),
	)
	if err != nil {
		return nil, errors.Wrap(err, "p.blockHeader")
	}

	if params.StateRoot != (common.Hash{}) && block.Root() != params.StateRoot {
		return nil, errors.Wrapf(ErrStateRootMismatch, "block %d has root %s, want %s",
			params.BlockNumber, block.Root().Hex(), params.StateRoot.Hex())
	}

	blockID := block.NumberU64()
	if params.BlockID != 0 {
		blockID = params.BlockID
	}

	ethProof, err := p.getProof(
		ctx,
		params.Caller,
		params.SignalServiceAddress,
		common.Bytes2Hex(params.Key[:]),
		int64(params.BlockNumber),
	)
	if err != nil {
		return nil, errors.Wrap(err, "p.getProof")
	}

	encodedSignalProof, err := encoding.EncodeHopProofs([]encoding.HopProof{{
		BlockID:      blockID,
		ChainID:      params.ChainID.Uint64(),
		RootHash:     block.Root(),
		CacheOption:  0,
		AccountProof: ethProof.AccountProof,
		StorageProof: ethProof.StorageProof[0].Proof,
	}})
	if err != nil {
		return nil, errors.Wrap(err, "encoding.EncodeHopProofs")
	}

	return encodedSignalProof, nil
}

// getProof rlp and abi encodes a proof for SignalService,
// where `proof` is an rlp and abi encoded (bytes, bytes) consisting of storageProof.Proofs[0]
// response from `eth_getProof`, and returns the storageHash to be used as the signalRoot.
func (p *Prover) getProof(
	ctx context.Context,
	c relayer.Caller,
	signalServiceAddress common.Address,
	key string,
	blockNumber int64,
) (*StorageProof, error) {
	var ethProof StorageProof

	err := c.CallContext(ctx,
		&ethProof,
		"eth_getProof",
		signalServiceAddress,
		[]string{key},
		hexutil.EncodeBig(new(big.Int).SetInt64(blockNumber)),
	)
	if err != nil {
		return nil, errors.Wrap(err, "c.CallContext")
	}

	if new(big.Int).SetBytes(ethProof.StorageProof[0].Value).Int64() == int64(0) {
		return nil, errors.New("proof will not be valid, expected storageProof to not be 0 but was not")
	}

	return &ethProof, nil
}
