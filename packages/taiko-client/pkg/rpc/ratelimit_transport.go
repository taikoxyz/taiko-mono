package rpc

import (
	"fmt"
	"io"
	"net/http"
	"strconv"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum/go-ethereum/log"
)

const (
	RateLimitResetHeader    = "x-ratelimit-reset"
	DefaultRateLimitBackoff = 1 * time.Second
	MaxRateLimitBackoff     = 30 * time.Second
	RateLimitMaxRetries     = 5

	unixTimestampThreshold int64 = 1_000_000_000
)

// RateLimitedTransport wraps an http.RoundTripper to handle HTTP 429 responses
// with exponential backoff and respect for x-ratelimit-reset headers.
type RateLimitedTransport struct {
	Base       http.RoundTripper
	MaxRetries int
}

// NewRateLimitedTransport creates a new RateLimitedTransport that wraps the given base transport.
func NewRateLimitedTransport(base http.RoundTripper, maxRetries uint64) *RateLimitedTransport {
	return &RateLimitedTransport{
		Base:       base,
		MaxRetries: int(maxRetries),
	}
}

func (t *RateLimitedTransport) base() http.RoundTripper {
	if t.Base != nil {
		return t.Base
	}
	return http.DefaultTransport
}

func (t *RateLimitedTransport) maxRetries() int {
	if t.MaxRetries > 0 {
		return t.MaxRetries
	}
	return RateLimitMaxRetries
}

// RoundTrip implements http.RoundTripper with rate limit handling.
func (t *RateLimitedTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	// If request has body but no way to reset it, don't retry
	canRetry := req.Body == nil || req.GetBody != nil

	bo := backoff.NewExponentialBackOff()
	bo.InitialInterval = DefaultRateLimitBackoff
	bo.MaxInterval = MaxRateLimitBackoff
	bo.Reset()

	for attempt := 0; attempt < t.maxRetries(); attempt++ {
		// Reset body for retries
		if attempt > 0 && req.GetBody != nil {
			body, err := req.GetBody()
			if err != nil {
				return nil, err
			}
			req.Body = body
		}

		resp, err := t.base().RoundTrip(req)
		if err != nil {
			return nil, err
		}

		if resp.StatusCode != http.StatusTooManyRequests {
			return resp, nil
		}

		// Can't retry without GetBody
		if !canRetry {
			log.Warn("Rate limited (HTTP 429) but can't retry", "url", req.URL)
			return resp, nil
		}

		wait := t.getWaitDuration(resp, bo)
		log.Warn("Rate limited (HTTP 429)", "url", req.URL, "attempt", attempt+1, "wait", wait)

		_, _ = io.Copy(io.Discard, resp.Body)
		resp.Body.Close()

		select {
		case <-req.Context().Done():
			return nil, req.Context().Err()
		case <-time.After(wait):
		}
	}

	log.Error("Rate limit retries exhausted", "url", req.URL, "attempts", t.maxRetries())
	return nil, &RateLimitError{URL: req.URL.String(), Attempts: t.maxRetries()}
}

func (t *RateLimitedTransport) getWaitDuration(resp *http.Response, bo *backoff.ExponentialBackOff) time.Duration {
	// Prefer server-provided reset time, capped at MaxRateLimitBackoff
	if wait := parseRateLimitReset(resp); wait > 0 {
		return min(wait, MaxRateLimitBackoff)
	}
	// Fall back to exponential backoff (includes jitter)
	if wait := bo.NextBackOff(); wait != backoff.Stop {
		return wait
	}
	return MaxRateLimitBackoff
}

func parseRateLimitReset(resp *http.Response) time.Duration {
	header := resp.Header.Get(RateLimitResetHeader)
	if header == "" {
		return 0
	}

	val, err := strconv.ParseInt(header, 10, 64)
	if err != nil {
		log.Debug("Failed to parse rate limit header", "value", header, "err", err)
		return 0
	}

	// Two possible response values: seconds-until-reset or unix timestamp (> year 2001)
	if val > unixTimestampThreshold {
		wait := time.Until(time.Unix(val, 0))
		if wait > 0 {
			return wait
		}
		return 0
	}
	return time.Duration(val) * time.Second
}

// RateLimitError indicates retry exhaustion due to rate limiting.
type RateLimitError struct {
	URL      string
	Attempts int
}

// Error implements the error interface.
func (e *RateLimitError) Error() string {
	return fmt.Sprintf("rate limit retries exhausted after %d attempts: %s", e.Attempts, e.URL)
}
