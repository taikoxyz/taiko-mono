package rpc

import (
	"context"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/log"
	"github.com/ethereum/go-ethereum/node"
	"github.com/ethereum/go-ethereum/rpc"
)

// DialClientWithBackoff connects a ethereum RPC client at the given URL with
// a backoff strategy. Added a retry limit so it doesn't retry endlessly
func DialClientWithBackoff(
	ctx context.Context,
	url string,
	retryInterval time.Duration,
	maxRetrys uint64) (*ethclient.Client, error) {
	var client *ethclient.Client
	if err := backoff.Retry(
		func() (err error) {
			ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, defaultTimeout)
			defer cancel()

			client, err = ethclient.DialContext(ctxWithTimeout, url)
			if err != nil {
				log.Error("Dial ethclient error", "url", url, "error", err)
				return err
			}

			return nil
		},
		backoff.WithMaxRetries(backoff.NewConstantBackOff(retryInterval), maxRetrys),
	); err != nil {
		return nil, err
	}

	return client, nil
}

// DialEngineClientWithBackoff connects an ethereum engine RPC client at the
// given URL with a backoff strategy. Added a retry limit so it doesn't retry endlessly
func DialEngineClientWithBackoff(
	ctx context.Context,
	url string,
	jwtSecret string,
	retryInterval time.Duration,
	maxRetry uint64,
) (*EngineClient, error) {
	var engineClient *EngineClient
	if err := backoff.Retry(
		func() (err error) {
			ctxWithTimeout, cancel := CtxWithTimeoutOrDefault(ctx, defaultTimeout)
			defer cancel()

			jwtAuth := node.NewJWTAuth(StringToBytes32(jwtSecret))
			client, err := rpc.DialOptions(ctxWithTimeout, url, rpc.WithHTTPAuth(jwtAuth))
			if err != nil {
				log.Error("Dial engine client error", "url", url, "error", err)
				return err
			}

			engineClient = &EngineClient{client}
			return nil
		},
		backoff.WithMaxRetries(backoff.NewConstantBackOff(retryInterval), maxRetry),
	); err != nil {
		return nil, err
	}

	return engineClient, nil
}
