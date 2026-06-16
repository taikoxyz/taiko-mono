package producer

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// ZKBacklogController is implemented by proof producers whose backend exposes the
// raiko2 control-plane endpoints for draining the ZK (`zk_any`) task backlog and
// reporting when the backend is idle. See raiko2 issue #93.
type ZKBacklogController interface {
	// ClearBacklog discards all non-terminal `zk_any` tasks on the ZK backend
	// (POST /v3/prover/clear).
	ClearBacklog(ctx context.Context) error
	// StatusClean reports whether the ZK backend is fully idle, i.e. the
	// `data.clean` field of GET /v3/prover/status is true.
	StatusClean(ctx context.Context) (bool, error)
}

// raikoControlPlaneResponse is the minimal body returned by POST /v3/prover/clear.
type raikoControlPlaneResponse struct {
	Status string `json:"status"`
}

// RaikoProverStatusResponse is the body returned by GET /v3/prover/status. Only
// `data.clean` is consumed; `tasks` and `network` are intentionally ignored.
type RaikoProverStatusResponse struct {
	Status string `json:"status"`
	Data   struct {
		Clean bool `json:"clean"`
	} `json:"data"`
}

// requestRaikoControlPlane sends a bodyless request (GET or POST) to a raiko2
// control-plane endpoint and unmarshals the JSON response into U. A non-200
// status code (including 404 when the endpoint is absent) returns an error.
func requestRaikoControlPlane[U any](
	ctx context.Context,
	method string,
	url string,
	apiKey string,
) (*U, error) {
	req, err := http.NewRequestWithContext(ctx, method, url, nil)
	if err != nil {
		return nil, err
	}
	if len(apiKey) > 0 {
		req.Header.Set("X-API-KEY", apiKey)
	}

	res, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()

	if res.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status code from %s: %d", url, res.StatusCode)
	}

	resBytes, err := io.ReadAll(res.Body)
	if err != nil {
		return nil, err
	}

	var output U
	if err := json.Unmarshal(resBytes, &output); err != nil {
		return nil, err
	}
	return &output, nil
}

// ClearBacklog implements the ZKBacklogController interface.
func (s *ComposeProofProducer) ClearBacklog(ctx context.Context) error {
	if s.Dummy {
		return nil
	}
	ctx, cancel := rpc.CtxWithTimeoutOrDefault(ctx, s.RaikoRequestTimeout)
	defer cancel()

	if _, err := requestRaikoControlPlane[raikoControlPlaneResponse](
		ctx,
		http.MethodPost,
		s.RaikoHostEndpoint+"/v3/prover/clear",
		s.ApiKey,
	); err != nil {
		return fmt.Errorf("failed to clear ZK backlog: %w", err)
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

	out, err := requestRaikoControlPlane[RaikoProverStatusResponse](
		ctx,
		http.MethodGet,
		s.RaikoHostEndpoint+"/v3/prover/status",
		s.ApiKey,
	)
	if err != nil {
		return false, fmt.Errorf("failed to get ZK prover status: %w", err)
	}
	return out.Data.Clean, nil
}
