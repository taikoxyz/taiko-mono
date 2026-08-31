package rpcclient

import (
	"context"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/rpc"
)

// Dial creates an RPC client. HTTP requests are bounded so a stale upstream
// connection cannot block a relayer worker indefinitely.
func Dial(ctx context.Context, rawURL string, requestTimeout time.Duration) (*rpc.Client, error) {
	parsedURL, err := url.Parse(rawURL)
	if err != nil {
		return nil, fmt.Errorf("parse RPC URL: %w", err)
	}

	var options []rpc.ClientOption
	switch strings.ToLower(parsedURL.Scheme) {
	case "http", "https":
		if requestTimeout <= 0 {
			return nil, fmt.Errorf("HTTP RPC request timeout must be positive: %s", requestTimeout)
		}
		options = append(options, rpc.WithHTTPClient(newHTTPClient(requestTimeout)))
	}

	client, err := rpc.DialOptions(ctx, rawURL, options...)
	if err != nil {
		return nil, fmt.Errorf("dial RPC client: %w", err)
	}

	return client, nil
}

func newHTTPClient(requestTimeout time.Duration) *http.Client {
	return &http.Client{Timeout: requestTimeout}
}

// DialEthClient creates an Ethereum client backed by Dial.
func DialEthClient(
	ctx context.Context,
	rawURL string,
	requestTimeout time.Duration,
) (*ethclient.Client, error) {
	client, err := Dial(ctx, rawURL, requestTimeout)
	if err != nil {
		return nil, err
	}

	return ethclient.NewClient(client), nil
}
