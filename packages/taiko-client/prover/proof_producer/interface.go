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

// IsShasta implements the ProofRequestOptions interface.
func (o *ProofRequestOptionsPacaya) IsShasta() bool {
	return false
}

// PacayaOptions implements the ProofRequestOptions interface.
func (o *ProofRequestOptionsPacaya) PacayaOptions() *ProofRequestOptionsPacaya {
	return o
}

// ShastaOptions implements the ProofRequestOptions interface.
func (o *ProofRequestOptionsPacaya) ShastaOptions() *ProofRequestOptionsShasta {
	return nil
}

// GetProverAddress implements the ProofRequestOptions interface.
func (o *ProofRequestOptionsPacaya) GetProverAddress() common.Address {
	return o.ProverAddress
}

// GetRawBlockHash implements the ProofRequestOptions interface.
func (o *ProofRequestOptionsPacaya) GetRawBlockHash() common.Hash {
	return o.EventL1Hash
}

// ProofRequestOptionsPacaya contains all options that need to be passed to a backend proof producer service.
type ProofRequestOptionsShasta struct {
	BatchID       *big.Int
	Headers       []*types.Header
	ProverAddress common.Address
	EventL1Hash   common.Hash
}

// IsPacaya implemenwts the ProofRequestOptions interface.
func (o *ProofRequestOptionsShasta) IsPacaya() bool {
	return false
}

// IsShasta implements the ProofRequestOptions interface.
func (o *ProofRequestOptionsShasta) IsShasta() bool {
	return true
}

// PacayaOptions implements the ProofRequestOptions interface.
func (o *ProofRequestOptionsShasta) PacayaOptions() *ProofRequestOptionsPacaya {
	return nil
}

// ShastaOptions implements the ProofRequestOptions interface.
func (o *ProofRequestOptionsShasta) ShastaOptions() *ProofRequestOptionsShasta {
	return o
}

// GetProverAddress implements the ProofRequestOptions interface.
func (o *ProofRequestOptionsShasta) GetProverAddress() common.Address {
	return o.ProverAddress
}

// GetRawBlockHash implements the ProofRequestOptions interface.
func (o *ProofRequestOptionsShasta) GetRawBlockHash() common.Hash {
	return o.EventL1Hash
}
