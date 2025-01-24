package producer

import (
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
)

type ProofRequestOptions interface {
	IsPacaya() bool
	OntakeOptions() *ProofRequestOptionsOntake
	PacayaOptions() *ProofRequestOptionsPacaya
	GetGraffiti() string
	GetProverAddress() common.Address
	GetRawBlockHash() common.Hash
}

// ProofRequestOptionsOntake contains all options that need to be passed to a backend proof producer service.
type ProofRequestOptionsOntake struct {
	BlockID            *big.Int
	ProverAddress      common.Address
	ProposeBlockTxHash common.Hash
	BlockHash          common.Hash
	ParentHash         common.Hash
	StateRoot          common.Hash
	EventL1Hash        common.Hash
	Graffiti           string
	GasUsed            uint64
	ParentGasUsed      uint64
	Compressed         bool
}

// IsPacaya implements the ProofRequestOptions interface.
func (o *ProofRequestOptionsOntake) IsPacaya() bool {
	return false
}

// OntakeOptions implements the ProofRequestOptions interface.
func (o *ProofRequestOptionsOntake) OntakeOptions() *ProofRequestOptionsOntake {
	return o
}

// PacayaOptions implements the ProofRequestOptions interface.
func (o *ProofRequestOptionsOntake) PacayaOptions() *ProofRequestOptionsPacaya {
	return nil
}

// GetGraffiti implements the ProofRequestOptions interface.
func (o *ProofRequestOptionsOntake) GetGraffiti() string {
	return o.Graffiti
}

// GetProverAddress implements the ProofRequestOptions interface.
func (o *ProofRequestOptionsOntake) GetProverAddress() common.Address {
	return o.ProverAddress
}

// GetRawBlockHash implements the ProofRequestOptions interface.
func (o *ProofRequestOptionsOntake) GetRawBlockHash() common.Hash {
	return o.EventL1Hash
}

// ProofRequestOptionsPacaya contains all options that need to be passed to a backend proof producer service.
type ProofRequestOptionsPacaya struct {
	BatchID            *big.Int
	Headers            []*types.Header
	ProverAddress      common.Address
	ProposeBlockTxHash common.Hash
	EventL1Hash        common.Hash
}

// IsPacaya implemenwts the ProofRequestOptions interface.
func (o *ProofRequestOptionsPacaya) IsPacaya() bool {
	return true
}

// OntakeOptions implements the ProofRequestOptions interface.
func (o *ProofRequestOptionsPacaya) OntakeOptions() *ProofRequestOptionsOntake {
	return nil
}

// PacayaOptions implements the ProofRequestOptions interface.
func (o *ProofRequestOptionsPacaya) PacayaOptions() *ProofRequestOptionsPacaya {
	return o
}

// GetGraffiti implements the ProofRequestOptions interface.
func (o *ProofRequestOptionsPacaya) GetGraffiti() string {
	return ""
}

// GetProverAddress implements the ProofRequestOptions interface.
func (o *ProofRequestOptionsPacaya) GetProverAddress() common.Address {
	return o.ProverAddress
}

// GetRawBlockHash implements the ProofRequestOptions interface.
func (o *ProofRequestOptionsPacaya) GetRawBlockHash() common.Hash {
	return o.EventL1Hash
}
