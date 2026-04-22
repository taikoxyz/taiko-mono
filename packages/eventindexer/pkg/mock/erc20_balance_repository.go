package mock

import (
	"context"
	"net/http"

	"github.com/morkid/paginate"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

type ERC20BalanceRepository struct {
	ERC20Balances []*eventindexer.ERC20Balance
}

func NewERC20BalanceRepository() *ERC20BalanceRepository {
	return &ERC20BalanceRepository{}
}

func (r *ERC20BalanceRepository) IncreaseAndDecreaseBalancesInTx(
	ctx context.Context,
	increaseOpts eventindexer.UpdateERC20BalanceOpts,
	decreaseOpts eventindexer.UpdateERC20BalanceOpts,
) (increasedBalance *eventindexer.ERC20Balance, decreasedBalance *eventindexer.ERC20Balance, err error) {
	return nil, nil, nil
}

func (r *ERC20BalanceRepository) FindByAddress(ctx context.Context,
	req *http.Request,
	address string,
	chainID string,
) (paginate.Page, error) {
	var balances []*eventindexer.ERC20Balance

	for _, b := range r.ERC20Balances {
		if b.Address == address {
			balances = append(balances, b)
		}
	}

	return paginate.Page{
		Items: balances,
	}, nil
}

func (r *ERC20BalanceRepository) FindMetadata(
	ctx context.Context,
	chainID int64,
	contractAddress string,
) (*eventindexer.ERC20Metadata, error) {
	return &eventindexer.ERC20Metadata{}, nil
}

func (r *ERC20BalanceRepository) CreateMetadata(
	ctx context.Context,
	chainID int64,
	contractAddress string,
	symbol string,
	decimals uint8,
) (int, error) {
	return 1, nil
}
