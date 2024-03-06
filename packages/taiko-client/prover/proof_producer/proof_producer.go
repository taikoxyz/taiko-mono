package producer

import (
	"context"
	"errors"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
)

var (
	proofPollingInterval = 10 * time.Second
	errProofGenerating   = errors.New("proof is generating")
)

// ProofRequestOptions contains all options that need to be passed to a backend proof producer service.
type ProofRequestOptions struct {
	BlockID            *big.Int
	ProverAddress      common.Address
	ProposeBlockTxHash common.Hash
	TaikoL2            common.Address
	MetaHash           common.Hash
	BlockHash          common.Hash
	ParentHash         common.Hash
	StateRoot          common.Hash
	EventL1Hash        common.Hash
	Graffiti           string
	GasUsed            uint64
	ParentGasUsed      uint64
}

type ProofWithHeader struct {
	BlockID *big.Int
	Meta    *bindings.TaikoDataBlockMetadata
	Header  *types.Header
	Proof   []byte
	Opts    *ProofRequestOptions
	Tier    uint16
}

type ProofProducer interface {
	RequestProof(
		ctx context.Context,
		opts *ProofRequestOptions,
		blockID *big.Int,
		meta *bindings.TaikoDataBlockMetadata,
		header *types.Header,
	) (*ProofWithHeader, error)
	Cancellable() bool
	Cancel(ctx context.Context, blockID *big.Int) error
	Tier() uint16
}
