package proof

import (
	"testing"

	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
	"gopkg.in/go-playground/assert.v1"
)

func newTestProver() *Prover {
	return &Prover{
		blocker:           &mock.Blocker{},
		proofEncodingType: relayer.RLPEncodingType,
	}
}

func Test_New(t *testing.T) {
	tests := []struct {
		name      string
		blocker   blocker
		proofType relayer.ProofEncodingType
		wantErr   error
	}{
		{
			"success",
			&ethclient.Client{},
			relayer.RLPEncodingType,
			nil,
		},
		{
			"noEthClient",
			nil,
			relayer.RLPEncodingType,
			relayer.ErrNoEthClient,
		},
		{
			"wrongEncodingType",
			&ethclient.Client{},
			"fake",
			ErrInvalidProofType,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := New(tt.blocker, tt.proofType)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}
