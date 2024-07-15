package processor

import (
	"context"
	"log/slog"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
)

// hasQuotaAvailable checks quota to see if message can be processed,
// and if not, returns a timestamp of when quota will be
// available
func (p *Processor) hasQuotaAvailable(
	ctx context.Context,
	tokenAddress common.Address,
	msgValue *big.Int,
) (bool, uint64, error) {
	available, err := p.destQuotaManager.AvailableQuota(&bind.CallOpts{
		Context: ctx,
	}, tokenAddress, common.Big0)
	if err != nil {
		return false, 0, err
	}

	slog.Info("available quota", "tokenAddress", tokenAddress.Hex(), "available", available, "required", msgValue.String())

	// if the quota is unavailable, return the time which
	// it will be
	if available.Cmp(msgValue) == -1 {
		period, err := p.destQuotaManager.QuotaPeriod(&bind.CallOpts{
			Context: ctx,
		})
		if err != nil {
			return false, 0, err
		}

		return false, period.Uint64(), nil
	}

	return true, 0, err
}
