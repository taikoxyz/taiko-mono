package rpc

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strconv"
	"sync/atomic"
	"testing"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/stretchr/testify/require"
)

func TestRateLimitedTransport_Success(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("success"))
	}))
	defer server.Close()

	client := &http.Client{Transport: &RateLimitedTransport{}}

	resp, err := client.Get(server.URL)
	require.NoError(t, err)
	defer resp.Body.Close()

	require.Equal(t, http.StatusOK, resp.StatusCode)
	body, _ := io.ReadAll(resp.Body)
	require.Equal(t, "success", string(body))
}

func TestRateLimitedTransport_RetryOn429(t *testing.T) {
	var attempts atomic.Int32

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		if attempts.Add(1) < 3 {
			w.Header().Set(RateLimitResetHeader, "1")
			w.WriteHeader(http.StatusTooManyRequests)
			return
		}
		w.WriteHeader(http.StatusOK)
	}))
	defer server.Close()

	client := &http.Client{Transport: &RateLimitedTransport{MaxRetries: 5}}

	resp, err := client.Get(server.URL)
	require.NoError(t, err)
	defer resp.Body.Close()

	require.Equal(t, http.StatusOK, resp.StatusCode)
	require.Equal(t, int32(3), attempts.Load())
}

func TestRateLimitedTransport_MaxRetriesExceeded(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set(RateLimitResetHeader, "1")
		w.WriteHeader(http.StatusTooManyRequests)
	}))
	defer server.Close()

	client := &http.Client{Transport: &RateLimitedTransport{MaxRetries: 2}}

	resp, err := client.Get(server.URL)
	if resp != nil {
		resp.Body.Close()
	}

	require.Error(t, err)
	var rateLimitErr *RateLimitError
	require.ErrorAs(t, err, &rateLimitErr)
}

func TestRateLimitedTransport_ContextCancellation(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set(RateLimitResetHeader, "60")
		w.WriteHeader(http.StatusTooManyRequests)
	}))
	defer server.Close()

	client := &http.Client{Transport: &RateLimitedTransport{MaxRetries: 10}}

	ctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer cancel()

	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, server.URL, nil)
	resp, err := client.Do(req)
	if resp != nil {
		resp.Body.Close()
	}

	require.ErrorIs(t, err, context.DeadlineExceeded)
}

func TestRateLimitedTransport_NonRetryableBody(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusTooManyRequests)
	}))
	defer server.Close()

	transport := &RateLimitedTransport{MaxRetries: 3}

	// Request with body but no GetBody - can't retry, returns 429
	req, _ := http.NewRequest(http.MethodPost, server.URL, bytes.NewReader([]byte("data")))
	req.GetBody = nil

	resp, err := transport.RoundTrip(req)
	require.NoError(t, err)
	defer resp.Body.Close()

	require.Equal(t, http.StatusTooManyRequests, resp.StatusCode)
}

func TestRateLimitedTransport_GetBodyError(t *testing.T) {
	var attempts atomic.Int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		attempts.Add(1)
		w.Header().Set(RateLimitResetHeader, "1")
		w.WriteHeader(http.StatusTooManyRequests)
	}))
	defer server.Close()

	transport := &RateLimitedTransport{MaxRetries: 3}
	req, _ := http.NewRequest(http.MethodPost, server.URL, bytes.NewReader([]byte("data")))
	req.GetBody = func() (io.ReadCloser, error) {
		return nil, fmt.Errorf("simulated GetBody error")
	}

	resp, err := transport.RoundTrip(req)
	if resp != nil {
		resp.Body.Close()
	}

	require.Error(t, err)
	require.Contains(t, err.Error(), "simulated GetBody error")
	require.Equal(t, int32(1), attempts.Load()) // First attempt succeeds, retry fails at GetBody before HTTP request
}

func TestRateLimitedTransport_ParseRateLimitReset(t *testing.T) {
	t.Run("empty", func(t *testing.T) {
		resp := &http.Response{Header: make(http.Header)}
		require.Equal(t, time.Duration(0), parseRateLimitReset(resp))
	})

	t.Run("invalid", func(t *testing.T) {
		resp := &http.Response{Header: make(http.Header)}
		resp.Header.Set(RateLimitResetHeader, "invalid")
		require.Equal(t, time.Duration(0), parseRateLimitReset(resp))
	})

	t.Run("seconds_until_reset", func(t *testing.T) {
		resp := &http.Response{Header: make(http.Header)}
		resp.Header.Set(RateLimitResetHeader, "5")
		require.Equal(t, 5*time.Second, parseRateLimitReset(resp))
	})

	t.Run("unix_timestamp", func(t *testing.T) {
		futureTime := time.Now().Add(10 * time.Second).Unix()
		resp := &http.Response{Header: make(http.Header)}
		resp.Header.Set(RateLimitResetHeader, strconv.FormatInt(futureTime, 10))

		wait := parseRateLimitReset(resp)
		require.Greater(t, wait, 8*time.Second)
		require.LessOrEqual(t, wait, 11*time.Second)
	})

	t.Run("past_timestamp", func(t *testing.T) {
		pastTime := time.Now().Add(-10 * time.Second).Unix()
		resp := &http.Response{Header: make(http.Header)}
		resp.Header.Set(RateLimitResetHeader, strconv.FormatInt(pastTime, 10))

		wait := parseRateLimitReset(resp)
		require.LessOrEqual(t, wait, time.Duration(0)) // Negative or zero
	})
}

func TestRateLimitedTransport_MaxBackoffCap(t *testing.T) {
	transport := &RateLimitedTransport{}

	// Server says wait 120 seconds, but we cap at MaxRateLimitBackoff
	resp := &http.Response{Header: make(http.Header)}
	resp.Header.Set(RateLimitResetHeader, "120")

	bo := backoff.NewExponentialBackOff()
	bo.InitialInterval = DefaultRateLimitBackoff
	bo.MaxInterval = MaxRateLimitBackoff

	wait := transport.getWaitDuration(resp, bo)
	require.Equal(t, MaxRateLimitBackoff, wait)
}

func TestRateLimitedTransport_Defaults(t *testing.T) {
	transport := &RateLimitedTransport{}
	require.Equal(t, http.DefaultTransport, transport.base())
	require.Equal(t, RateLimitMaxRetries, transport.maxRetries())

	transport2 := NewRateLimitedTransport(nil, 3)
	require.Equal(t, 3, transport2.MaxRetries)
}
