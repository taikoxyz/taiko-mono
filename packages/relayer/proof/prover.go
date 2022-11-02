package proof

import (
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/taikochain/taiko-mono/packages/relayer"
)

type Prover struct {
	ethClient *ethclient.Client
}

func New(ethClient *ethclient.Client) (*Prover, error) {
	if ethClient == nil {
		return nil, relayer.ErrNoEthClient
	}

	return &Prover{
		ethClient: ethClient,
	}, nil
}
