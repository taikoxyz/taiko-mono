package processor

import (
	"sync"

	"github.com/ethereum/go-ethereum/crypto"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/mock"
	"github.com/taikoxyz/taiko-mono/packages/relayer/proof"
)

var dummyEcdsaKey = "8da4ef21b864d2cc526dbdb2a120bd2874c36c9d0a1fb7f8c63d7f7a8b41de8f"

func newTestProcessor(profitableOnly relayer.ProfitableOnly) *Processor {
	privateKey, _ := crypto.HexToECDSA(dummyEcdsaKey)

	prover, _ := proof.New(
		&mock.Blocker{},
	)

	return &Processor{
		eventRepo:                 &mock.EventRepository{},
		destBridge:                &mock.Bridge{},
		srcEthClient:              &mock.EthClient{},
		destEthClient:             &mock.EthClient{},
		destERC20Vault:            &mock.TokenVault{},
		mu:                        &sync.Mutex{},
		ecdsaKey:                  privateKey,
		destHeaderSyncer:          &mock.HeaderSyncer{},
		prover:                    prover,
		rpc:                       &mock.Caller{},
		profitableOnly:            false,
		headerSyncIntervalSeconds: 1,
		confTimeoutInSeconds:      900,
		confirmations:             1,
		queue:                     &mock.Queue{},
	}
}
