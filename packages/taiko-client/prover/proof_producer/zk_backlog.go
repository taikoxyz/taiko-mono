package producer

import (
	"context"
	"fmt"
	"net/http"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// ZKBacklogController is implemented by proof producers whose backend exposes the
// raiko2 control-plane endpoints for draining the RISC0 task backlog and
// reporting when the backend is idle. See raiko2 issue #93.
type ZKBacklogController interface {
	// ClearBacklog discards non-terminal proof tasks on the RISC0 backend.
	ClearBacklog(ctx context.Context) error
	// StatusClean reports whether the RISC0 backend is fully idle, i.e. the
	// `data.clean` field of GET /v3/prover/status is true.
	StatusClean(ctx context.Context) (bool, error)
}

// raikoProverStatusResponse is the body returned by GET /v3/prover/status. Only
// `data.clean` is consumed; the remaining fields (`status`, `tasks`, `network`)
// are intentionally ignored.
type raikoProverStatusResponse struct {
	Data struct {
		Clean bool `json:"clean"`
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
		return fmt.Errorf("failed to clear RISC0 backlog: %w", err)
	}
	return nil
}

// StatusClean implements the ZKBacklogController interface.
func (s *ComposeProofProducer) StatusClean(ctx context.Context) (bool, error) {
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
		return false, fmt.Errorf("failed to get RISC0 prover status: %w", err)
	}
	return out.Data.Clean, nil
}
