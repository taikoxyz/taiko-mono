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
	ProofTypeZKAny   ProofType = "zk_any"
)

// ProofRequestOptions is an interface that contains all options that need to be passed to a backend proof producer
// service.
type ProofRequestOptions interface {
	ProposalOptions() *ProposalProofRequestOptions
	GetProverAddress() common.Address
	GetRawBlockHash() common.Hash
	IsGethProofGenerated() bool
	IsGethProofAggregationGenerated() bool
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
	ProposalID                    *big.Int
	Headers                       []*types.Header
	ProverAddress                 common.Address
	EventL1Hash                   common.Hash
	GethProofGenerated            bool
	GethProofAggregationGenerated bool
	RethProofGenerated            bool
	RethProofAggregationGenerated bool
	L2BlockNums                   []*big.Int
	DesignatedProver              common.Address
	Checkpoint                    *Checkpoint
	LastAnchorBlockNumber         *big.Int
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

// IsGethProofGenerated implements the ProofRequestOptions interface.
func (s *ProposalProofRequestOptions) IsGethProofGenerated() bool {
	return s.GethProofGenerated
}

// IsGethProofAggregationGenerated implements the ProofRequestOptions interface.
func (s *ProposalProofRequestOptions) IsGethProofAggregationGenerated() bool {
	return s.GethProofAggregationGenerated
}

// IsRethProofGenerated implements the ProofRequestOptions interface.
func (s *ProposalProofRequestOptions) IsRethProofGenerated() bool {
	return s.RethProofGenerated
}

// IsRethProofAggregationGenerated implements the ProofRequestOptions interface.
func (s *ProposalProofRequestOptions) IsRethProofAggregationGenerated() bool {
	return s.RethProofAggregationGenerated
}
