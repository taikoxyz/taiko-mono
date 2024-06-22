package selector

import (
	"context"
	"errors"
	"fmt"
	"math/big"
	"net/url"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

var (
	httpScheme              = "http"
	httpsScheme             = "https"
	errEmptyProverEndpoints = errors.New("empty prover endpoints")
	errUnableToFindProver   = errors.New("unable to find prover")
)

// ETHFeeEOASelector is a prover selector implementation which use ETHs as prover fee and
// all provers selected must be EOA accounts.
type ETHFeeEOASelector struct {
	protocolConfigs               *bindings.TaikoDataConfig
	rpc                           *rpc.Client
	proposerAddress               common.Address
	taikoL1Address                common.Address
	proverSetAddress              common.Address
	tiersFee                      []encoding.TierFee
	tierFeePriceBump              *big.Int
	proverEndpoints               []*url.URL
	maxTierFeePriceBumpIterations uint64
}

// NewETHFeeEOASelector creates a new ETHFeeEOASelector instance.
func NewETHFeeEOASelector(
	protocolConfigs *bindings.TaikoDataConfig,
	rpc *rpc.Client,
	proposerAddress common.Address,
	taikoL1Address common.Address,
	proverSetAddress common.Address,
	tiersFee []encoding.TierFee,
	tierFeePriceBump *big.Int,
	proverEndpoints []*url.URL,
	maxTierFeePriceBumpIterations uint64,
) (*ETHFeeEOASelector, error) {
	if len(proverEndpoints) == 0 {
		return nil, errEmptyProverEndpoints
	}

	for _, endpoint := range proverEndpoints {
		if endpoint.Scheme != httpScheme && endpoint.Scheme != httpsScheme {
			return nil, fmt.Errorf("invalid prover endpoint %s", endpoint)
		}
	}

	return &ETHFeeEOASelector{
		protocolConfigs,
		rpc,
		proposerAddress,
		taikoL1Address,
		proverSetAddress,
		tiersFee,
		tierFeePriceBump,
		proverEndpoints,
		maxTierFeePriceBumpIterations,
	}, nil
}

// ProverEndpoints returns all registered prover endpoints.
func (s *ETHFeeEOASelector) ProverEndpoints() []*url.URL { return s.proverEndpoints }

// AssignProver tries to pick a prover through the registered prover endpoints.
func (s *ETHFeeEOASelector) AssignProver(
	ctx context.Context,
	tierFees []encoding.TierFee,
) (*big.Int, error) {
	var (
		fees         = make([]encoding.TierFee, len(tierFees))
		big100       = new(big.Int).SetUint64(uint64(100))
		maxProverFee = common.Big0
	)

	// Deep copy the tierFees slice.
	for i, fee := range tierFees {
		fees[i] = encoding.TierFee{Tier: fee.Tier, Fee: new(big.Int).Set(fee.Fee)}
	}

	// Iterate over each configured endpoint, and see if someone wants to accept this block.
	// If it is denied, we continue on to the next endpoint.
	// If we do not find a prover, we can increase the fee up to a point, or give up.
	for i := 0; i < int(s.maxTierFeePriceBumpIterations); i++ {
		// Bump tier fee on each failed loop.
		cumulativeBumpPercent := new(big.Int).Mul(s.tierFeePriceBump, new(big.Int).SetUint64(uint64(i)))
		for idx := range fees {
			if i > 0 {
				fee := new(big.Int).Mul(fees[idx].Fee, cumulativeBumpPercent)
				fees[idx].Fee = fees[idx].Fee.Add(fees[idx].Fee, fee.Div(fee, big100))
			}
			if fees[idx].Fee.Cmp(maxProverFee) > 0 {
				maxProverFee = fees[idx].Fee
			}
		}

		spender := s.taikoL1Address
		proverAddress := s.proposerAddress
		if s.proverSetAddress != rpc.ZeroAddress {
			proverAddress = s.proverSetAddress
		}

		ok, err := rpc.CheckProverBalance(
			ctx,
			s.rpc,
			proverAddress,
			spender,
			s.protocolConfigs.LivenessBond,
		)
		if err != nil {
			log.Warn("Failed to check prover balance", "error", err)
			continue
		}
		if !ok {
			continue
		}

		return maxProverFee, nil
	}

	return nil, errUnableToFindProver
}
