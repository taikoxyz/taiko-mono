package producer

import (
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
)

// ProofType represents the type of the given proof.
type ProofType string

// ProofType constants.
const (
	ProofTypeSgxGeth ProofType = "sgxgeth"
	ProofTypeOp      ProofType = "op"
	ProofTypeSgx     ProofType = "sgx"
	ProofTypeSgxCPU  ProofType = "native"
	ProofTypeZKR0    ProofType = "risc0"
	ProofTypeZKSP1   ProofType = "sp1"
)

// ProofRequestOptions is an interface that contains all options that need to be passed to a backend proof producer
// service.
type ProofRequestOptions interface {
	ProposalOptions() *ProposalProofRequestOptions
	GetProverAddress() common.Address
	GetRawBlockHash() common.Hash
	IsCompanionProofGenerated() bool
	IsCompanionProofAggregationGenerated() bool
	IsRethProofGenerated() bool
	IsRethProofAggregationGenerated() bool
}

// Checkpoint represents a checkpoint for the proposal in protocol.
type Checkpoint struct {
	BlockNumber *big.Int
	BlockHash   common.Hash
	StateRoot   common.Hash
}

// ProposalProofRequestOptions contains all options that need to be passed to a backend proof producer service.
type ProposalProofRequestOptions struct {
	ProposalID    *big.Int
	Headers       []*types.Header
	ProverAddress common.Address
	EventL1Hash   common.Hash
	// CompanionProofGenerated and CompanionProofAggregationGenerated record whether the
	// mode-specific companion proof has been generated: SGX_GETH in the default mode or
	// RISC0 in ZK-only mode.
	CompanionProofGenerated            bool
	CompanionProofAggregationGenerated bool
	RethProofGenerated                 bool
	RethProofAggregationGenerated      bool
	ProofType                          ProofType
	L2BlockNums                        []*big.Int
	DesignatedProver                   common.Address
	Checkpoint                         *Checkpoint
	LastAnchorBlockNumber              *big.Int
}

// ProposalOptions implements the ProofRequestOptions interface.
func (s *ProposalProofRequestOptions) ProposalOptions() *ProposalProofRequestOptions {
	return s
}

// GetProverAddress implements the ProofRequestOptions interface.
func (s *ProposalProofRequestOptions) GetProverAddress() common.Address {
	return s.ProverAddress
}

// GetRawBlockHash implements the ProofRequestOptions interface.
func (s *ProposalProofRequestOptions) GetRawBlockHash() common.Hash {
	return s.EventL1Hash
}

// IsCompanionProofGenerated implements the ProofRequestOptions interface.
func (s *ProposalProofRequestOptions) IsCompanionProofGenerated() bool {
	return s.CompanionProofGenerated
}

// IsCompanionProofAggregationGenerated implements the ProofRequestOptions interface.
func (s *ProposalProofRequestOptions) IsCompanionProofAggregationGenerated() bool {
	return s.CompanionProofAggregationGenerated
}

// IsRethProofGenerated implements the ProofRequestOptions interface.
func (s *ProposalProofRequestOptions) IsRethProofGenerated() bool {
	return s.RethProofGenerated
}

// IsRethProofAggregationGenerated implements the ProofRequestOptions interface.
func (s *ProposalProofRequestOptions) IsRethProofAggregationGenerated() bool {
	return s.RethProofAggregationGenerated
}
