package producer

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
)

// requestHTTPProof sends a POST request to the given URL with the given JWT and request body,
// to get a proof of the given type.
func requestHTTPProof[T, U any](ctx context.Context, url string, jwt string, reqBody T) (*U, error) {
	res, err := requestHTTPProofResponse(ctx, url, jwt, reqBody)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()

	resBytes, err := io.ReadAll(res.Body)
	if err != nil {
		return nil, err
	}

	log.Debug("Proof generation output", "url", url, "output", string(resBytes))
	var output U
	if err := json.Unmarshal(resBytes, &output); err != nil {
		return nil, err
	}

	return &output, nil
}

// requestHTTPProofResponse sends a POST request to the given URL with the given JWT and request body,
// and returns the raw HTTP response, the caller is responsible for closing the response body.
func requestHTTPProofResponse[T any](ctx context.Context, url string, jwt string, reqBody T) (*http.Response, error) {
	client := &http.Client{}

	jsonValue, err := json.Marshal(reqBody)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewBuffer(jsonValue))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	if len(jwt) > 0 {
		req.Header.Set("Authorization", "Bearer "+base64.StdEncoding.EncodeToString([]byte(jwt)))
	}

	res, err := client.Do(req)
	if err != nil {
		return nil, err
	}

	if res.StatusCode != http.StatusOK {
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
	if isAggregation {
		// nolint:exhaustive
		// We deliberately handle only known proof types and catch others in default case
		switch proofType {
		case ProofTypePivot:
			metrics.ProverPivotAggregationGenerationTime.Set(float64(time.Since(requestAt).Seconds()))
			metrics.ProverPivotProofAggregationGeneratedCounter.Add(1)
		case ProofTypeSgx:
			metrics.ProverSGXAggregationGenerationTime.Set(float64(time.Since(requestAt).Seconds()))
			metrics.ProverSgxProofAggregationGeneratedCounter.Add(1)
		case ProofTypeZKR0:
			metrics.ProverR0AggregationGenerationTime.Set(float64(time.Since(requestAt).Seconds()))
			metrics.ProverR0ProofAggregationGeneratedCounter.Add(1)
		case ProofTypeZKSP1:
			metrics.ProverSP1AggregationGenerationTime.Set(float64(time.Since(requestAt).Seconds()))
			metrics.ProverSp1ProofAggregationGeneratedCounter.Add(1)
		default:
			log.Error("Unknown proof type", "proofType", proofType)
		}
	} else {
		// nolint:exhaustive
		// We deliberately handle only known proof types and catch others in default case
		switch proofType {
		case ProofTypePivot:
			metrics.ProverPivotProofGenerationTime.Set(float64(time.Since(requestAt).Seconds()))
			metrics.ProverPivotProofGeneratedCounter.Add(1)
		case ProofTypeSgx:
			metrics.ProverSgxProofGenerationTime.Set(float64(time.Since(requestAt).Seconds()))
			metrics.ProverSgxProofGeneratedCounter.Add(1)
		case ProofTypeZKR0:
			metrics.ProverR0ProofGenerationTime.Set(float64(time.Since(requestAt).Seconds()))
			metrics.ProverR0ProofGeneratedCounter.Add(1)
		case ProofTypeZKSP1:
			metrics.ProverSP1ProofGenerationTime.Set(float64(time.Since(requestAt).Seconds()))
			metrics.ProverSp1ProofGeneratedCounter.Add(1)
		default:
			log.Error("Unknown proof type", "proofType", proofType)
		}
	}
}
