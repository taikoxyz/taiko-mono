package producer

import (
	"context"
	"fmt"
	"net/http"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// ZKBacklogController is implemented by proof producers whose backend exposes the
// raiko2 control-plane endpoints for draining the ZK (`zk_any`) task backlog and
// reporting risc0 progress. See raiko2 issue #93.
type ZKBacklogController interface {
	// ClearBacklog discards all non-terminal `zk_any` tasks on the ZK backend
	// (POST /v3/prover/clear).
	ClearBacklog(ctx context.Context) error
	// Risc0Idle reports whether the ZK backend has no in-flight risc0 orders, i.e.
	// `data.network.risc0.inflight_orders` of GET /v3/prover/status is 0.
	Risc0Idle(ctx context.Context) (bool, error)
}

// raikoProverStatusResponse is the body returned by GET /v3/prover/status. Only
// `data.network.risc0.inflight_orders` is consumed; the remaining fields
// (`status`, `tasks`, `network.sp1`, `data.clean`, ...) are intentionally ignored.
// The risc0 section and its inflight_orders are pointers so a response that omits
// them (e.g. an older status schema) is treated as "unavailable" rather than
// silently decoding to a zero (idle) value.
type raikoProverStatusResponse struct {
	Data struct {
		Network struct {
			Risc0 *struct {
				InflightOrders *uint64 `json:"inflight_orders"`
			} `json:"risc0"`
		} `json:"network"`
	} `json:"data"`
}

// ClearBacklog implements the ZKBacklogController interface.
func (s *ComposeProofProducer) ClearBacklog(ctx context.Context) error {
	if s.Dummy {
		return nil
	}
	ctx, cancel := rpc.CtxWithTimeoutOrDefault(ctx, s.RaikoRequestTimeout)
	defer cancel()

	// The clear endpoint only needs to return HTTP 200; its response body is unused.
	if _, err := requestRaiko[struct{}](
		ctx,
		http.MethodPost,
		s.RaikoHostEndpoint+"/v3/prover/clear",
		s.ApiKey,
		nil,
	); err != nil {
		return fmt.Errorf("failed to clear ZK backlog: %w", err)
	}
	return nil
}

// Risc0Idle implements the ZKBacklogController interface.
func (s *ComposeProofProducer) Risc0Idle(ctx context.Context) (bool, error) {
	if s.Dummy {
		return true, nil
	}
	ctx, cancel := rpc.CtxWithTimeoutOrDefault(ctx, s.RaikoRequestTimeout)
	defer cancel()

	out, err := requestRaiko[raikoProverStatusResponse](
		ctx,
		http.MethodGet,
		s.RaikoHostEndpoint+"/v3/prover/status",
		s.ApiKey,
		nil,
	)
	if err != nil {
		return false, fmt.Errorf("failed to get ZK prover status: %w", err)
	}
	// Treat a missing risc0 section as unavailable (not idle) so canResumeZK takes
	// the status-unavailable path instead of silently trusting a zero value.
	if out.Data.Network.Risc0 == nil || out.Data.Network.Risc0.InflightOrders == nil {
		return false, fmt.Errorf("risc0 inflight_orders missing from /v3/prover/status response")
	}
	return *out.Data.Network.Risc0.InflightOrders == 0, nil
}
