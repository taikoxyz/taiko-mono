package proof

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

var (
	ErrInvalidProofType = errors.New("invalid proof encoding type")
)

type blocker interface {
	BlockByHash(ctx context.Context, hash common.Hash) (*types.Block, error)
	BlockByNumber(ctx context.Context, number *big.Int) (*types.Block, error)
}
type Prover struct {
	blocker           blocker
	proofEncodingType relayer.ProofEncodingType
}

func New(blocker blocker, proofEncodingType relayer.ProofEncodingType) (*Prover, error) {
	if blocker == nil {
		return nil, relayer.ErrNoEthClient
	}

	if !relayer.IsValidProofEncodingType(proofEncodingType) {
		return nil, ErrInvalidProofType
	}

	return &Prover{
		blocker:           blocker,
		proofEncodingType: proofEncodingType,
	}, nil
}
