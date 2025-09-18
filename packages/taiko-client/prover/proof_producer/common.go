package producer

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/ethereum/go-ethereum/log"

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

const maxResponseBytes = 8 << 20 // 8 MiB hard limit for HTTP response body

// requestHTTPProof sends a POST request to the given URL with the given ApiKey and request body,
// to get a proof of the given type.
func requestHTTPProof[T, U any](ctx context.Context, url string, apiKey string, reqBody T) (*U, error) {
	res, err := requestHTTPProofResponse(ctx, url, apiKey, reqBody)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()

	// Limit the amount of data read to prevent OOM on huge responses.
	// If the server sends more than maxResponseBytes, we fail early.
	limited := io.LimitReader(res.Body, maxResponseBytes+1)
	resBytes, err := io.ReadAll(limited)
	if err != nil {
		return nil, err
	}
	if len(resBytes) > maxResponseBytes {
		return nil, fmt.Errorf("response too large")
	}
	
	// Avoid logging entire response which may be large or sensitive.
	preview := resBytes
	if len(preview) > 1024 {
		preview = preview[:1024]
	}
	log.Debug("Proof generation output", "url", url, "bytes", len(resBytes), "preview", string(preview))
	var output U
	if err := json.Unmarshal(resBytes, &output); err != nil {
		return nil, err
	}

	return &output, nil
}

// requestHTTPProofResponse sends a POST request to the given URL with the given ApiKey and request body,
// and returns the raw HTTP response, the caller is responsible for closing the response body.
func requestHTTPProofResponse[T any](
	ctx context.Context,
	url string,
	apiKey string,
	reqBody T,
) (*http.Response, error) {
	// Use an HTTP client with timeouts to avoid hanging connections.
	client := &http.Client{
		Timeout: 30 * time.Second,
		Transport: &http.Transport{
			ResponseHeaderTimeout: 15 * time.Second,
			IdleConnTimeout:       60 * time.Second,
			ExpectContinueTimeout: 2 * time.Second,
		},
	}

	jsonValue, err := json.Marshal(reqBody)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewBuffer(jsonValue))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	if len(apiKey) > 0 {
		req.Header.Set("X-API-KEY", apiKey)
	}

	res, err := client.Do(req)
	if err != nil {
		return nil, err
	}

	if res.StatusCode != http.StatusOK {
		// Ensure the body is closed on non-OK responses to avoid leaks.
		// We intentionally read and discard up to a small limit to allow connection reuse.
		// Note: We do not propagate the body content to logs to avoid leaking sensitive data.
		io.CopyN(io.Discard, res.Body, 1024)
		res.Body.Close()
		// Check for rate limiting (429 Too Many Requests)
		if res.StatusCode == http.StatusTooManyRequests {
			log.Error("Rate limit on L2 RPC has been reached. Using your own Taiko L2 node as RPC for Raiko is recommended")
		}

		return nil, fmt.Errorf(
			"failed to request proof, url: %s, statusCode: %d",
			url,
			res.StatusCode,
		)
	}

	return res, nil
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
