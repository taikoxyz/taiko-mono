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
	IsPacaya() bool
	IsShasta() bool
	PacayaOptions() *ProofRequestOptionsPacaya
	ShastaOptions() *ProofRequestOptionsShasta
	GetProverAddress() common.Address
	GetRawBlockHash() common.Hash
	IsGethProofGenerated() bool
	IsGethProofAggregationGenerated() bool
	IsRethProofGenerated() bool
	IsRethProofAggregationGenerated() bool
}

// ProofRequestOptionsPacaya contains all options that need to be passed to a backend proof producer service.
type ProofRequestOptionsPacaya struct {
	BatchID                       *big.Int
	Headers                       []*types.Header
	ProverAddress                 common.Address
	EventL1Hash                   common.Hash
	GethProofGenerated            bool
	GethProofAggregationGenerated bool
	RethProofGenerated            bool
	RethProofAggregationGenerated bool
}

// Checkpoint represents a checkpoint for the proposal in protocol.
type Checkpoint struct {
	BlockNumber *big.Int
	BlockHash   common.Hash
	StateRoot   common.Hash
}

// IsPacaya implemenwts the ProofRequestOptions interface.
func (p *ProofRequestOptionsPacaya) IsPacaya() bool {
	return true
}

// IsShasta implements the ProofRequestOptions interface.
func (p *ProofRequestOptionsPacaya) IsShasta() bool {
	return false
}

// PacayaOptions implements the ProofRequestOptions interface.
func (p *ProofRequestOptionsPacaya) PacayaOptions() *ProofRequestOptionsPacaya {
	return p
}

// ShastaOptions implements the ProofRequestOptions interface.
func (p *ProofRequestOptionsPacaya) ShastaOptions() *ProofRequestOptionsShasta {
	return nil
}

// GetProverAddress implements the ProofRequestOptions interface.
func (p *ProofRequestOptionsPacaya) GetProverAddress() common.Address {
	return p.ProverAddress
}

// GetRawBlockHash implements the ProofRequestOptions interface.
func (p *ProofRequestOptionsPacaya) GetRawBlockHash() common.Hash {
	return p.EventL1Hash
}

// IsGethProofGenerated implements the ProofRequestOptions interface.
func (p *ProofRequestOptionsPacaya) IsGethProofGenerated() bool {
	return p.GethProofGenerated
}

// IsGethProofAggregationGenerated implements the ProofRequestOptions interface.
func (p *ProofRequestOptionsPacaya) IsGethProofAggregationGenerated() bool {
	return p.GethProofAggregationGenerated
}

// IsRethProofGenerated implements the ProofRequestOptions interface.
func (p *ProofRequestOptionsPacaya) IsRethProofGenerated() bool {
	return p.RethProofGenerated
}

// IsRethProofAggregationGenerated implements the ProofRequestOptions interface.
func (p *ProofRequestOptionsPacaya) IsRethProofAggregationGenerated() bool {
	return p.RethProofAggregationGenerated
}

// ProofRequestOptionsShasta contains all options that need to be passed to a backend proof producer service.
type ProofRequestOptionsShasta struct {
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

// IsPacaya implemenwts the ProofRequestOptions interface.
func (s *ProofRequestOptionsShasta) IsPacaya() bool {
	return false
}

// IsShasta implements the ProofRequestOptions interface.
func (s *ProofRequestOptionsShasta) IsShasta() bool {
	return true
}

// PacayaOptions implements the ProofRequestOptions interface.
func (s *ProofRequestOptionsShasta) PacayaOptions() *ProofRequestOptionsPacaya {
	return nil
}

// ShastaOptions implements the ProofRequestOptions interface.
func (s *ProofRequestOptionsShasta) ShastaOptions() *ProofRequestOptionsShasta {
	return s
}

// GetProverAddress implements the ProofRequestOptions interface.
func (s *ProofRequestOptionsShasta) GetProverAddress() common.Address {
	return s.ProverAddress
}

// GetRawBlockHash implements the ProofRequestOptions interface.
func (s *ProofRequestOptionsShasta) GetRawBlockHash() common.Hash {
	return s.EventL1Hash
}

// IsGethProofGenerated implements the ProofRequestOptions interface.
func (s *ProofRequestOptionsShasta) IsGethProofGenerated() bool {
	return s.GethProofGenerated
}

// IsGethProofAggregationGenerated implements the ProofRequestOptions interface.
func (s *ProofRequestOptionsShasta) IsGethProofAggregationGenerated() bool {
	return s.GethProofAggregationGenerated
}

// IsRethProofGenerated implements the ProofRequestOptions interface.
func (s *ProofRequestOptionsShasta) IsRethProofGenerated() bool {
	return s.RethProofGenerated
}

// IsRethProofAggregationGenerated implements the ProofRequestOptions interface.
func (s *ProofRequestOptionsShasta) IsRethProofAggregationGenerated() bool {
	return s.RethProofAggregationGenerated
}
