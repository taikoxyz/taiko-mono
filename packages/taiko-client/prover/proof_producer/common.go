package producer

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"

	"github.com/ethereum/go-ethereum/log"
)

// requestHTTPProof sends a POST request to the given URL with the given JWT and request body,
// to get a proof of the given type.
func requestHTTPProof[T, U any](ctx context.Context, url string, jwt string, reqBody T) (*U, error) {
	res, err := requestHTTPProofResponse(ctx, url, jwt, reqBody)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()

	if res.StatusCode != http.StatusOK {
		return nil, fmt.Errorf(
			"failed to request proof,  statusCode: %d",
			res.StatusCode,
		)
	}

	resBytes, err := io.ReadAll(res.Body)
	if err != nil {
		return nil, err
	}

	log.Debug("Proof generation output", "output", string(resBytes))
	var output U
	if err := json.Unmarshal(resBytes, &output); err != nil {
		return nil, err
	}

	return &output, nil
}

// requestHTTPProofResponse sends a POST request to the given URL with the given JWT and request body,
// and returns the raw HTTP response.
func requestHTTPProofResponse[T any](ctx context.Context, url string, jwt string, reqBody T) (*http.Response, error) {
	client := &http.Client{}

	jsonValue, err := json.Marshal(reqBody)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(jsonValue))
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

	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return nil, fmt.Errorf(
			"failed to request proof,  statusCode: %d",
			res.StatusCode,
		)
	}

	return res, nil
}
