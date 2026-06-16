package producer

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"github.com/ethereum/go-ethereum/log"
	"github.com/go-resty/resty/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
)

// RaikoRequestProofBodyResponseV2 represents the JSON body of the response of the proof requests.
type RaikoRequestProofBodyResponseV2 struct {
	Data         *RaikoProofDataV2 `json:"data"`
	ErrorMessage string            `json:"message"`
	Error        string            `json:"error"`
	ProofType    ProofType         `json:"proof_type"`
}

// Validate validates the response of the proof requests.
func (res *RaikoRequestProofBodyResponseV2) Validate() error {
	if len(res.ErrorMessage) > 0 || len(res.Error) > 0 {
		return fmt.Errorf(
			"failed to get proof, err: %s, msg: %s, type: %s",
			res.Error,
			res.ErrorMessage,
			res.ProofType,
		)
	}

	if res.Data == nil {
		return fmt.Errorf("unexpected structure error, proofType: %s", res.ProofType)
	}
	if res.Data.Status == ErrProofInProgress.Error() {
		return ErrProofInProgress
	}
	if res.Data.Status == StatusRegistered {
		return ErrRetry
	}
	if res.Data.Status == ErrZkAnyNotDrawn.Error() {
		return ErrZkAnyNotDrawn
	}
	// Note: Since the single sp1 proof from raiko is null, we need to ignore the case.
	if ProofTypeZKSP1 != res.ProofType &&
		(res.Data.Proof == nil || len(res.Data.Proof.Proof) == 0) {
		return ErrEmptyProof
	}

	return nil
}

// RaikoProofDataV2 represents the JSON body of the response of the proof requests.
type RaikoProofDataV2 struct {
	Proof  *ProofDataV2 `json:"proof"`
	Status string       `json:"status"`
}

// ProofDataV2 represents the JSON body of the response of the proof requests.
type ProofDataV2 struct {
	KzgProof string `json:"kzg_proof"`
	Proof    string `json:"proof"`
	Quote    string `json:"quote"`
}

// raikoHTTPClient is the shared resty client used for all raiko HTTP requests.
// Each request carries its own deadline via the per-call context, matching the
// previous net/http behavior.
var raikoHTTPClient = resty.New()

// requestRaiko sends an HTTP request to a raiko endpoint with the shared resty
// client and unmarshals a successful (HTTP 200) JSON response into U. A nil body
// is sent without a request body; a non-nil body is JSON-encoded. The response is
// always parsed as JSON, regardless of the Content-Type the server returns.
func requestRaiko[U any](
	ctx context.Context,
	method string,
	url string,
	apiKey string,
	body any,
) (*U, error) {
	var output U
	req := raikoHTTPClient.R().
		SetContext(ctx).
		ForceContentType("application/json").
		SetResult(&output)
	if body != nil {
		req = req.SetHeader("Content-Type", "application/json").SetBody(body)
	}
	if len(apiKey) > 0 {
		req = req.SetHeader("X-API-KEY", apiKey)
	}

	log.Debug("Requesting raiko", "url", url, "method", method)
	resp, err := req.Execute(method, url)
	if err != nil {
		return nil, err
	}

	if resp.StatusCode() != http.StatusOK {
		// Check for rate limiting (429 Too Many Requests)
		if resp.StatusCode() == http.StatusTooManyRequests {
			log.Error("Rate limit on L2 RPC has been reached. Using your own Taiko L2 node as RPC for Raiko is recommended")
		}

		return nil, fmt.Errorf("failed to request raiko, url: %s, statusCode: %d", url, resp.StatusCode())
	}

	log.Debug("Raiko response", "url", url, "body", string(resp.Body()))
	return &output, nil
}

// requestHTTPProof sends a POST request with the given JSON body to a raiko proof
// endpoint and unmarshals the response into U.
func requestHTTPProof[T, U any](ctx context.Context, url string, apiKey string, reqBody T) (*U, error) {
	return requestRaiko[U](ctx, http.MethodPost, url, apiKey, reqBody)
}

// updateProvingMetrics updates the metrics for the given proof type, including
// the generation time and the number of proofs generated.
func updateProvingMetrics(proofType ProofType, requestAt time.Time, isAggregation bool) {
	generationTime := time.Since(requestAt).Seconds()
	if isAggregation {
		// nolint:exhaustive
		// We deliberately handle only known proof types and catch others in default case
		switch proofType {
		case ProofTypeSgxGeth:
			metrics.ProverSgxGethAggregationGenerationTime.Set(generationTime)
			metrics.ProverSgxGethAggregationGenerationTimeSum.Add(generationTime)
			metrics.ProverSgxGethProofAggregationGeneratedCounter.Add(1)
		case ProofTypeSgx:
			metrics.ProverSGXAggregationGenerationTime.Set(generationTime)
			metrics.ProverSGXAggregationGenerationTimeSum.Add(generationTime)
			metrics.ProverSgxProofAggregationGeneratedCounter.Add(1)
		case ProofTypeZKR0:
			metrics.ProverR0AggregationGenerationTime.Set(generationTime)
			metrics.ProverR0AggregationGenerationTimeSum.Add(generationTime)
			metrics.ProverR0ProofAggregationGeneratedCounter.Add(1)
		case ProofTypeZKSP1:
			metrics.ProverSP1AggregationGenerationTime.Set(generationTime)
			metrics.ProverSP1AggregationGenerationTimeSum.Add(generationTime)
			metrics.ProverSp1ProofAggregationGeneratedCounter.Add(1)
		default:
			log.Error("Unknown proof type", "proofType", proofType)
		}
	} else {
		// nolint:exhaustive
		// We deliberately handle only known proof types and catch others in default case
		switch proofType {
		case ProofTypeSgxGeth:
			metrics.ProverSgxGethProofGenerationTime.Set(generationTime)
			metrics.ProverSgxGethProofGenerationTimeSum.Add(generationTime)
			metrics.ProverSgxGethProofGeneratedCounter.Add(1)
		case ProofTypeSgx:
			metrics.ProverSgxProofGenerationTime.Set(generationTime)
			metrics.ProverSgxProofGenerationTimeSum.Add(generationTime)
			metrics.ProverSgxProofGeneratedCounter.Add(1)
		case ProofTypeZKR0:
			metrics.ProverR0ProofGenerationTime.Set(generationTime)
			metrics.ProverR0ProofGenerationTimeSum.Add(generationTime)
			metrics.ProverR0ProofGeneratedCounter.Add(1)
		case ProofTypeZKSP1:
			metrics.ProverSP1ProofGenerationTime.Set(generationTime)
			metrics.ProverSP1ProofGenerationTimeSum.Add(generationTime)
			metrics.ProverSp1ProofGeneratedCounter.Add(1)
		default:
			log.Error("Unknown proof type", "proofType", proofType)
		}
	}
}
