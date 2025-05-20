package params

import (
	"github.com/ethereum/go-ethereum/common"
)

// SubProof should be same with ComposeVerifier.SubProof.
type SubProof struct {
	Verifier common.Address
	Proof    []byte
}
