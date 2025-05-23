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
	PacayaOptions() *ProofRequestOptionsPacaya
	GetProverAddress() common.Address
	GetRawBlockHash() common.Hash
}

// ProofRequestOptionsPacaya contains all options that need to be passed to a backend proof producer service.
type ProofRequestOptionsPacaya struct {
	BatchID                         *big.Int
	Headers                         []*types.Header
	ProverAddress                   common.Address
	EventL1Hash                     common.Hash
	IsGethProofGenerated            bool
	IsGethProofAggregationGenerated bool
	IsRethProofGenerated            bool
	IsRethProofAggregationGenerated bool
}

// IsPacaya implemenwts the ProofRequestOptions interface.
func (o *ProofRequestOptionsPacaya) IsPacaya() bool {
	return true
}

// PacayaOptions implements the ProofRequestOptions interface.
func (o *ProofRequestOptionsPacaya) PacayaOptions() *ProofRequestOptionsPacaya {
	return o
}

// GetProverAddress implements the ProofRequestOptions interface.
func (o *ProofRequestOptionsPacaya) GetProverAddress() common.Address {
	return o.ProverAddress
}

// GetRawBlockHash implements the ProofRequestOptions interface.
func (o *ProofRequestOptionsPacaya) GetRawBlockHash() common.Hash {
	return o.EventL1Hash
}
