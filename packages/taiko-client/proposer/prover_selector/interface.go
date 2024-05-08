package selector

import (
	"context"
	"math/big"
	"net/url"

	"github.com/ethereum/go-ethereum/common"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
)

type ProverSelector interface {
	AssignProver(
		ctx context.Context,
		tierFees []encoding.TierFee,
		txListHash common.Hash,
	) (assignment *encoding.ProverAssignment, assignedProver common.Address, fee *big.Int, err error)
	ProverEndpoints() []*url.URL
}
