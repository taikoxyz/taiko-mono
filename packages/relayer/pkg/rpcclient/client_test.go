package rpcclient

import (
	"context"
	"net/http"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

type roundTripperFunc func(*http.Request) (*http.Response, error)

func (f roundTripperFunc) RoundTrip(request *http.Request) (*http.Response, error) {
	return f(request)
}

func TestHTTPClientBoundsRequestDuration(t *testing.T) {
	requestStarted := make(chan struct{})
	client := newHTTPClient(25 * time.Millisecond)
	client.Transport = roundTripperFunc(func(request *http.Request) (*http.Response, error) {
		close(requestStarted)
		<-request.Context().Done()

		return nil, request.Context().Err()
	})

	request, err := http.NewRequestWithContext(context.Background(), http.MethodPost, "http://rpc.example", nil)
	require.NoError(t, err)
	_, err = client.Do(request)
	require.ErrorIs(t, err, context.DeadlineExceeded)

	select {
	case <-requestStarted:
	case <-time.After(time.Second):
		t.Fatal("JSON-RPC request was not sent")
	}
}

func TestDialRejectsUnboundedHTTPClient(t *testing.T) {
	_, err := Dial(context.Background(), "http://rpc.example", 0)
	require.ErrorContains(t, err, "must be positive")
}
