package main

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"sync/atomic"
	"syscall"
	"testing"
	"time"

	"github.com/cometbft/cometbft/crypto/ed25519"
	"github.com/cometbft/cometbft/libs/protoio"
	"github.com/cometbft/cometbft/privval"
	pv "github.com/cometbft/cometbft/proto/tendermint/privval"
	tm "github.com/cometbft/cometbft/proto/tendermint/types"
)

func buildSigner(t *testing.T) string {
	t.Helper()
	binary := filepath.Join(t.TempDir(), "etna-signer")
	if output, err := exec.Command("go", "build", "-mod=readonly", "-o", binary, ".").CombinedOutput(); err != nil {
		t.Fatalf("build helper: %v %s", err, output)
	}
	return binary
}
func signerExchange(t *testing.T, conn net.Conn, request pv.Message) pv.Message {
	t.Helper()
	if err := conn.SetDeadline(time.Now().Add(3 * time.Second)); err != nil {
		t.Fatal(err)
	}
	if _, err := protoio.NewDelimitedWriter(conn).WriteMsg(&request); err != nil {
		t.Fatal(err)
	}
	var response pv.Message
	if _, err := protoio.NewDelimitedReader(conn, 16*1024).ReadMsg(&response); err != nil {
		t.Fatal(err)
	}
	return response
}
func acceptSigner(t *testing.T, listener net.Listener) net.Conn {
	t.Helper()
	conn, err := listener.Accept()
	if err != nil {
		t.Fatalf("helper did not reconnect its transport: %v", err)
	}
	t.Cleanup(func() { conn.Close() })
	return conn
}

// Restart neither the helper nor its FilePV. Only the Comet-owned transport is
// closed; each replacement must BeginSession and deny even an already signed HRS.
func TestTransportOnlyDisconnectRearmsSameHelper(t *testing.T) {
	binary := buildSigner(t)
	for _, transport := range []string{"unix", "tcp"} {
		t.Run(transport, func(t *testing.T) {
			var begins atomic.Int64
			var ready atomic.Bool
			path := control(t, func(req map[string]any) any {
				if req["op"] == "begin_session" {
					begins.Add(1)
					ready.Store(false)
				}
				response := snapshot(ready.Load())
				response["session_id"] = fmt.Sprintf("transport:%d", begins.Load())
				return response
			})
			_, key, state := filePV(t)
			var listener net.Listener
			var addr string
			if transport == "unix" {
				socket := filepath.Join(shortTemp(t), "comet.sock")
				raw, err := net.ListenUnix("unix", &net.UnixAddr{Name: socket, Net: "unix"})
				if err != nil {
					t.Fatal(err)
				}
				listener = privval.NewUnixListener(raw)
				addr = "unix://" + socket
			} else {
				raw, err := net.Listen("tcp", "127.0.0.1:0")
				if err != nil {
					t.Fatal(err)
				}
				listener = privval.NewTCPListener(raw, ed25519.GenPrivKey())
				addr = "tcp://" + raw.Addr().String()
			}
			defer listener.Close()
			var logs bytes.Buffer
			helper := exec.Command(binary, "--comet-signer-addr", addr, "--trust-socket", path, "--chain-id", chain, "--priv-key", key, "--priv-state", state)
			helper.Stdout = &logs
			helper.Stderr = &logs
			if err := helper.Start(); err != nil {
				t.Fatal(err)
			}
			t.Cleanup(func() {
				helper.Process.Signal(syscall.SIGTERM)
				done := make(chan error, 1)
				go func() { done <- helper.Wait() }()
				select {
				case <-done:
				case <-time.After(3 * time.Second):
					helper.Process.Kill()
					<-done
				}
			})
			pid := helper.Process.Pid
			first := acceptSigner(t, listener)
			pubkey := pv.Message{Sum: &pv.Message_PubKeyRequest{PubKeyRequest: &pv.PubKeyRequest{ChainId: chain}}}
			if response := signerExchange(t, first, pubkey); response.GetPubKeyResponse() == nil || response.GetPubKeyResponse().Error != nil {
				t.Fatal("initial pubkey failed")
			}
			if begins.Load() != 1 {
				t.Fatalf("initial sessions=%d", begins.Load())
			}
			ready.Store(true)
			vote := voteRequest(tm.PrecommitType, 0, false)
			signedMessage := signerExchange(t, first, vote)
			signed := signedMessage.GetSignedVoteResponse()
			if signed == nil || signed.Error != nil || len(signed.Vote.Signature) != 65 {
				t.Fatal("initial Ready signature failed")
			}
			before, err := os.ReadFile(state)
			if err != nil {
				t.Fatal(err)
			}
			first.Close()
			second := acceptSigner(t, listener)
			if response := signerExchange(t, second, pubkey); response.GetPubKeyResponse() == nil || response.GetPubKeyResponse().Error != nil {
				t.Fatal("replacement pubkey failed while closed")
			}
			if begins.Load() != 2 {
				t.Fatalf("replacement did not begin a fresh session: %d", begins.Load())
			}
			if helper.Process.Pid != pid || helper.Process.Signal(syscall.Signal(0)) != nil {
				t.Fatal("helper process did not survive transport close")
			}
			deniedMessage := signerExchange(t, second, vote)
			denied := deniedMessage.GetSignedVoteResponse()
			if denied == nil || denied.Error == nil {
				t.Fatal("old Ready authorized a cached signature on replacement transport")
			}
			after, _ := os.ReadFile(state)
			if !bytes.Equal(before, after) {
				t.Fatal("closed replacement transport changed FilePV")
			}
			ready.Store(true)
			retryMessage := signerExchange(t, second, vote)
			retry := retryMessage.GetSignedVoteResponse()
			if retry == nil || retry.Error != nil || !bytes.Equal(retry.Vote.Signature, signed.Vote.Signature) {
				t.Fatal("replacement did not retain FilePV HRS/signature")
			}
		})
	}
}

type failingTransport struct {
	net.Conn
	failure error
}

func (c failingTransport) Read([]byte) (int, error)  { return 0, c.failure }
func (c failingTransport) Write([]byte) (int, error) { return 0, c.failure }

func TestTerminalIOPreservesCauseAndTimeoutClassification(t *testing.T) {
	timeout := &net.DNSError{Err: "test timeout", IsTimeout: true}
	for _, original := range []error{io.EOF, io.ErrUnexpectedEOF, fmt.Errorf("framed EOF: %w", io.EOF), timeout, fmt.Errorf("wrapped timeout: %w", timeout)} {
		t.Run(original.Error(), func(t *testing.T) {
			conn := &reconnectingConn{Conn: failingTransport{failure: original}}
			for _, operation := range []func([]byte) (int, error){conn.Read, conn.Write} {
				_, err := operation(nil)
				if !errors.Is(err, original) {
					t.Fatalf("cause lost: %v", err)
				}
				network, ok := err.(net.Error)
				if !ok {
					t.Fatalf("terminal error will not drop official endpoint: %T", err)
				}
				var originalNetwork net.Error
				wantTimeout := errors.As(original, &originalNetwork) && originalNetwork.Timeout()
				if network.Timeout() != wantTimeout {
					t.Fatalf("incorrect Timeout classification: %v", err)
				}
			}
		})
	}
}
