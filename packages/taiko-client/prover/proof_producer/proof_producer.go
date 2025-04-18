package producer

import (
	"context"
	"errors"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/common"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
)

var (
	errProofGenerating = errors.New("proof is generating")
	errEmptyProof      = errors.New("proof is empty")
	ErrInvalidLength   = errors.New("invalid items length")
)

// ProofRequestBody represents a request body to generate a proof.
type ProofRequestBody struct {
	Meta metadata.TaikoProposalMetaData
}

// ContestRequestBody represents a request body to generate a proof for contesting.
type ContestRequestBody struct {
	BlockID    *big.Int
	ProposedIn *big.Int
	ParentHash common.Hash
	Meta       metadata.TaikoProposalMetaData
}

// ProofResponse represents a response of a proof request.
type ProofResponse struct {
	BlockID   *big.Int
	Meta      metadata.TaikoProposalMetaData
	Proof     []byte
	Opts      ProofRequestOptions
	ProofType ProofType
}

// BatchProofs represents a response of a batch proof request.
type BatchProofs struct {
	ProofResponses       []*ProofResponse
	BatchProof           []byte
	BlockIDs             []*big.Int
	ProofType            ProofType
	Verifier             common.Address
	SgxGethBatchProof    []byte
	SgxGethProofVerifier common.Address
	IsPacaya             bool
}

// ProofProducer is an interface that contains all methods to generate a proof.
type ProofProducer interface {
	RequestProof(
		ctx context.Context,
		opts ProofRequestOptions,
		blockID *big.Int,
		meta metadata.TaikoProposalMetaData,
		requestAt time.Time,
	) (*ProofResponse, error)
	Aggregate(
		ctx context.Context,
		items []*ProofResponse,
		requestAt time.Time,
	) (*BatchProofs, error)
}
