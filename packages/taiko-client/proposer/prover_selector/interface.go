package selector

import (
	"context"
	"math/big"
	"net/url"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
)

type ProverSelector interface {
	AssignProver(
		ctx context.Context,
		tierFees []encoding.TierFee,
	) (fee *big.Int, err error)
	ProverEndpoints() []*url.URL
}
