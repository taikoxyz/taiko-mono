package indexer

import (
	"testing"

	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/taikochain/taiko-mono/packages/relayer"
	"github.com/taikochain/taiko-mono/packages/relayer/repo"
	"gopkg.in/go-playground/assert.v1"
)

func Test_NewService(t *testing.T) {
	tests := []struct {
		name    string
		opts    NewServiceOpts
		wantErr error
	}{
		{
			"success",
			NewServiceOpts{
				EventRepo: &repo.EventRepository{},
				BlockRepo: &repo.BlockRepository{},
				EthClient: &ethclient.Client{},
			},
			nil,
		},
		{
			"noEventRepo",
			NewServiceOpts{
				BlockRepo: &repo.BlockRepository{},
				EthClient: &ethclient.Client{},
			},
			relayer.ErrNoEventRepository,
		},
		{
			"noBlockRepo",
			NewServiceOpts{
				EventRepo: &repo.EventRepository{},
				EthClient: &ethclient.Client{},
			},
			relayer.ErrNoBlockRepository,
		},
		{
			"noEthClient",
			NewServiceOpts{
				EventRepo: &repo.EventRepository{},
				BlockRepo: &repo.BlockRepository{},
			},
			ErrNoEthClient,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := NewService(tt.opts)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}
