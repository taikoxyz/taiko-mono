package proof

import (
	"testing"

	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/encoding"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
	"gopkg.in/go-playground/assert.v1"
)

func newTestProver() *Prover {
	return &Prover{
		blocker:     &mock.Blocker{},
		cacheOption: encoding.CACHE_BOTH,
	}
}

func Test_New(t *testing.T) {
	tests := []struct {
		name    string
		blocker blocker
		wantErr error
	}{
		{
			"success",
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
			_, err := New(tt.blocker, encoding.CACHE_BOTH)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}
