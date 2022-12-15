package mock

import (
	"context"
	"errors"
	"math/big"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

var (
	MockChainID              = big.NewInt(167001)
	LatestBlockNumber        = big.NewInt(10)
	NotFoundTxHash           = common.HexToHash("0x123")
	SucceedTxHash            = common.HexToHash("0x456")
	FailTxHash               = common.HexToHash("0x789")
	BlockNum                 = 10
	PendingNonce      uint64 = 10
)

type EthClient struct {
}

func (c *EthClient) ChainID(ctx context.Context) (*big.Int, error) {
	return MockChainID, nil
}

func (c *EthClient) HeaderByNumber(ctx context.Context, number *big.Int) (*types.Header, error) {
	if number == nil {
		number = LatestBlockNumber
	}

	return &types.Header{
		Number: number,
	}, nil
}

func (c *EthClient) PendingNonceAt(ctx context.Context, account common.Address) (uint64, error) {
	return PendingNonce, nil
}

func (c *EthClient) TransactionReceipt(ctx context.Context, txHash common.Hash) (*types.Receipt, error) {
	if txHash == NotFoundTxHash {
		return nil, ethereum.NotFound
	}

	if txHash == FailTxHash {
		return &types.Receipt{
			Status:      types.ReceiptStatusFailed,
			BlockNumber: big.NewInt(1),
		}, nil
	}

	return &types.Receipt{
		Status:      types.ReceiptStatusSuccessful,
		BlockNumber: new(big.Int).Sub(big.NewInt(int64(BlockNum)), big.NewInt(1)),
	}, nil
}

func (c *EthClient) BlockNumber(ctx context.Context) (uint64, error) {
	return uint64(BlockNum), nil
}

func (c *EthClient) HeaderByHash(ctx context.Context, hash common.Hash) (*types.Header, error) {
	if hash == relayer.ZeroHash {
		return nil, errors.New("cant find block")
	}

	return Header, nil
}
