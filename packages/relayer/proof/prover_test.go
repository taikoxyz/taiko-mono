package proof

import (
	"testing"

	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/taikochain/taiko-mono/packages/relayer"
	"github.com/taikochain/taiko-mono/packages/relayer/mock"
	"gopkg.in/go-playground/assert.v1"
)

func newTestProver() *Prover {
	return &Prover{
		blocker: &mock.Blocker{},
	}
}

func Test_New(t *testing.T) {
	tests := []struct {
		name      string
		ethClient *ethclient.Client
		wantErr   error
	}{
		{
			"succcess",
			&ethclient.Client{},
			nil,
		},
		{
			"noEthClient",
			nil,
			relayer.ErrNoEthClient,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := New(tt.ethClient)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}
