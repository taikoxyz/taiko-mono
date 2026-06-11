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
	ErrEmptyProof      = errors.New("proof is empty")
	ErrInvalidLength   = errors.New("invalid items length")
	ErrProofInProgress = errors.New("work_in_progress")
	ErrRetry           = errors.New("retry")
	ErrZkAnyNotDrawn   = errors.New("zk_any_not_drawn")
	StatusRegistered   = "registered"
)

// ProofRequestBody represents a request body to generate a proof.
type ProofRequestBody struct {
	Meta metadata.TaikoProposalMetaData
}

// ProofResponse represents a response of a proof request.
type ProofResponse struct {
	BatchID   *big.Int
	Meta      metadata.TaikoProposalMetaData
	Proof     []byte
	Opts      ProofRequestOptions
	ProofType ProofType
}

// BatchProofs represents a response of a batch proof request.
//
// For compose proofs, the main proof (BatchProof / Verifier / VerifierID) is paired
// with a second sub-proof. Which set of fields holds the pair depends on the compose
// flavor:
//   - SGX+ZK compose: SgxGethBatchProof / SgxGethProofVerifier / SgxGethVerifierID
//     carry the SGX_GETH sub-proof.
//   - TDX+ZK compose: TdxBatchProof / TdxProofVerifier / TdxVerifierID carry the
//     TDX_RETH sub-proof.
//
// The submitter must encode both sub-proofs in strictly ascending VerifierType order.
type BatchProofs struct {
	ProofResponses       []*ProofResponse
	BatchProof           []byte
	BatchIDs             []*big.Int
	ProofType            ProofType
	Verifier             common.Address
	VerifierID           uint8
	SgxGethBatchProof    []byte
	SgxGethProofVerifier common.Address
	SgxGethVerifierID    uint8
	TdxBatchProof        []byte
	TdxProofVerifier     common.Address
	TdxVerifierID        uint8
}

// ProofProducer is an interface that contains all methods to generate a proof.
type ProofProducer interface {
	RequestProof(
		ctx context.Context,
		opts ProofRequestOptions,
		batchID *big.Int,
		meta metadata.TaikoProposalMetaData,
		requestAt time.Time,
	) (*ProofResponse, error)
	Aggregate(ctx context.Context, items []*ProofResponse, requestAt time.Time) (*BatchProofs, error)
}
