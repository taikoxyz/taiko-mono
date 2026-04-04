package handler

import (
	"context"
	"errors"
	"fmt"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

var errL1Reorged = errors.New("L1 reorged")

const proofExpirationDelay = 72 * time.Second

// checkL1Reorg verifies that the event's L1 block is still canonical.
func (h *BatchProposedEventHandler) checkL1Reorg(
	ctx context.Context,
	proposalID *big.Int,
	meta metadata.TaikoProposalMetaData,
) error {
	header, err := h.rpc.L1.HeaderByNumber(ctx, meta.GetRawBlockHeight())
	if err != nil {
		return fmt.Errorf("failed to get L1 header for proposal %s: %w", proposalID, err)
	}

	if header.Hash() != meta.GetRawBlockHash() {
		log.Warn(
			"Detected L1 reorg for proposed proposal",
			"proposalID", proposalID,
			"l1Height", meta.GetRawBlockHeight(),
			"l1HashOld", meta.GetRawBlockHash(),
			"l1HashNew", header.Hash(),
		)
		return errL1Reorged
	}

	return nil
}

// IsProvingWindowExpiredShasta returns true as the first return parameter if the assigned prover
// proving window of the given proposed block is expired, the second return parameter is the expired time,
// and the third return parameter is the time remaining till proving window is expired.
func IsProvingWindowExpiredShasta(
	rpc *rpc.Client,
	metadata metadata.TaikoProposalMetaData,
) (bool, time.Time, time.Duration, error) {
	configs, err := rpc.GetProtocolConfigsShasta(nil)
	if err != nil {
		return false, time.Time{}, 0, fmt.Errorf("failed to get Shasta protocol configs: %w", err)
	}

	var (
		now       = uint64(time.Now().Unix())
		expiredAt = metadata.Shasta().GetTimestamp() + configs.ProvingWindow.Uint64()
	)
	remainingSeconds := int64(expiredAt) - int64(now)
	if remainingSeconds < 0 {
		remainingSeconds = 0
	}
	return now > expiredAt, time.Unix(int64(expiredAt), 0), time.Duration(remainingSeconds) * time.Second, nil
}
