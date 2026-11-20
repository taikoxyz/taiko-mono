package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync/atomic"
	"syscall"
	"testing"
	"time"

	"github.com/cometbft/cometbft/crypto/ed25519"
	"github.com/cometbft/cometbft/crypto/secp256k1eth"
	cmtjson "github.com/cometbft/cometbft/libs/json"
	"github.com/cometbft/cometbft/libs/protoio"
	"github.com/cometbft/cometbft/privval"
	pv "github.com/cometbft/cometbft/proto/tendermint/privval"
	tm "github.com/cometbft/cometbft/proto/tendermint/types"
	"github.com/libp2p/go-libp2p/core/peer"
	"github.com/libp2p/go-libp2p/core/sec"
)

func signerExchange(t *testing.T, conn net.Conn, request pv.Message) pv.Message {
	t.Helper()
	// Beyond the signer's 3.5 s hold, so a refusal on closed trust is read, not timed out.
	if err := conn.SetDeadline(time.Now().Add(6 * time.Second)); err != nil {
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
	binary := signerBinary(t)
	for _, transport := range []string{"unix", "noise"} {
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
			var extra []string
			if transport == "unix" {
				socket := filepath.Join(shortTemp(t), "comet.sock")
				raw, err := net.ListenUnix("unix", &net.UnixAddr{Name: socket, Net: "unix"})
				if err != nil {
					t.Fatal(err)
				}
				listener = privval.NewUnixListener(raw)
				addr = "unix://" + socket
			} else {
				// The operator's bootstrap: transport-keygen prints the peer ID Comet's listener pins.
				transportKey := filepath.Join(t.TempDir(), "transport.json")
				signerPeer, err := peer.Decode(commandJSON(t, binary, "transport-keygen", "--transport-key", transportKey)["peerId"])
				if err != nil {
					t.Fatal(err)
				}
				cometKey := ed25519.GenPrivKey()
				cometPeer, err := transportPeerID(cometKey)
				if err != nil {
					t.Fatal(err)
				}
				raw, err := net.Listen("tcp", "127.0.0.1:0")
				if err != nil {
					t.Fatal(err)
				}
				if listener, err = privval.NewNoiseListener(raw, cometKey, []peer.ID{signerPeer}); err != nil {
					t.Fatal(err)
				}
				addr = "noise://" + cometPeer.String() + "@" + raw.Addr().String()
				extra = []string{"--transport-key", transportKey}
			}
			defer listener.Close()
			var logs bytes.Buffer
			helper := exec.Command(binary, append([]string{"--comet-signer-addr", addr, "--trust-socket", path, "--chain-id", chain, "--priv-key", key, "--priv-state", state, "--domains-log", domainsLogOf(state)}, extra...)...)
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

// The signer accepts only the two transports START-10-6 allows: unix:// and stock
// noise://<comet-peer-id>@<ip>:<port> with its own transport key. Bare tcp://, whose stock
// listener generates a fresh identity at every start, every other scheme, Noise without a key,
// a key without Noise and malformed Noise addresses are refused before any dial.
func TestCometDialerAcceptsOnlyUnixAndPinnedNoise(t *testing.T) {
	key := filepath.Join(t.TempDir(), "transport.json")
	if err := transportKeygen([]string{"--transport-key", key}, io.Discard); err != nil {
		t.Fatal(err)
	}
	comet, err := transportPeerID(ed25519.GenPrivKey())
	if err != nil {
		t.Fatal(err)
	}
	noise := "noise://" + comet.String() + "@127.0.0.1:26659"
	for _, valid := range []struct{ addr, key string }{{"unix:///run/signer.sock", ""}, {noise, key}, {"noise://" + comet.String() + "@[::1]:26659", key}} {
		if _, err := cometDialer(valid.addr, valid.key); err != nil {
			t.Errorf("%s refused: %v", valid.addr, err)
		}
	}
	for _, invalid := range []struct{ addr, key, want string }{
		{"tcp://127.0.0.1:26659", "", "bare tcp:// is refused"},
		{"tcp://127.0.0.1:26659", key, "bare tcp:// is refused"},
		{"bad://transport", "", "unsupported Comet signer transport"},
		{"127.0.0.1:26659", "", "unsupported Comet signer transport"},
		{"unix://", "", "names no socket"},
		{"unix:///run/signer.sock", key, "only for a noise://"},
		{noise, "", "needs --transport-key"},
		{noise, filepath.Join(t.TempDir(), "absent.json"), "signer transport key"},
		{"noise://127.0.0.1:26659", key, "missing peer id"},
		{"noise://" + comet.String() + "@comet.example:26659", key, "IP literal"},
		{"noise://not-a-peer-id@127.0.0.1:26659", key, "invalid peer id"},
	} {
		if _, err := cometDialer(invalid.addr, invalid.key); err == nil || !strings.Contains(err.Error(), invalid.want) {
			t.Errorf("%s with key %q: %v, want %q", invalid.addr, invalid.key, err, invalid.want)
		}
	}
}

// Both Noise peer IDs are pinned: the signer's handshake fails unless the listener proves the
// pinned Comet node key, and stock Comet's listener refuses a signer whose transport key is not
// the one its noise://<signer-peer-id>@ address names (START-10-6 vector 6.p).
func TestNoisePinsBothPeerIDs(t *testing.T) {
	cometKey, signerKey := ed25519.GenPrivKey(), ed25519.GenPrivKey()
	// The signer pins another Comet node key.
	listener, _ := noisePair(t, cometKey, signerKey)
	defer listener.Close()
	accepted := make(chan error, 1)
	go func() {
		conn, err := listener.Accept()
		if err == nil {
			conn.Close()
		}
		accepted <- err
	}()
	impostor, err := noiseDialer("noise://"+mustPeer(t, ed25519.GenPrivKey()).String()+"@"+listener.Addr().String(), signerKey)
	if err != nil {
		t.Fatal(err)
	}
	var mismatch sec.ErrPeerIDMismatch
	if _, err = impostor(); !errors.As(err, &mismatch) {
		t.Fatalf("signer accepted an unpinned Comet: %v", err)
	}
	<-accepted
	// Comet pins another signer transport key.
	pinned, _ := noisePair(t, cometKey, ed25519.GenPrivKey())
	defer pinned.Close()
	refused := make(chan error, 1)
	go func() {
		conn, err := pinned.Accept()
		if err == nil {
			conn.Close()
		}
		refused <- err
	}()
	stranger, err := noiseDialer("noise://"+mustPeer(t, cometKey).String()+"@"+pinned.Addr().String(), signerKey)
	if err != nil {
		t.Fatal(err)
	}
	if conn, err := stranger(); err == nil {
		conn.Close()
	}
	select {
	case err := <-refused:
		if err == nil || !strings.Contains(err.Error(), "not allowlisted") {
			t.Fatalf("Comet accepted an unpinned signer: %v", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("Comet's listener did not decide")
	}
}

func mustPeer(t *testing.T, key ed25519.PrivKey) peer.ID {
	t.Helper()
	id, err := transportPeerID(key)
	if err != nil {
		t.Fatal(err)
	}
	return id
}

// transport-keygen writes one exclusive mode-0600 Ed25519 key in the stock node-key layout and
// prints its peer ID; loading accepts exactly that layout and nothing else.
func TestTransportKeygenAndLoad(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "transport.json")
	var out bytes.Buffer
	if err := transportKeygen([]string{"--transport-key", path}, &out); err != nil {
		t.Fatal(err)
	}
	var printed map[string]string
	if err := json.Unmarshal(out.Bytes(), &printed); err != nil || len(printed) != 1 {
		t.Fatalf("output %q: %v", out.String(), err)
	}
	key, err := loadTransportKey(path)
	if err != nil {
		t.Fatal(err)
	}
	if id := mustPeer(t, key); id.String() != printed["peerId"] {
		t.Fatalf("printed %s, key is %s", printed["peerId"], id)
	}
	if info, _ := os.Stat(path); info.Mode().Perm() != 0600 {
		t.Fatalf("mode %v", info.Mode())
	}
	before, _ := os.ReadFile(path)
	if err := transportKeygen([]string{"--transport-key", path}, io.Discard); err == nil {
		t.Fatal("keygen replaced an existing transport key")
	}
	if after, _ := os.ReadFile(path); !bytes.Equal(before, after) {
		t.Fatal("refused keygen changed the key")
	}
	link := filepath.Join(dir, "link.json")
	if err := os.Symlink(path, link); err != nil {
		t.Fatal(err)
	}
	if _, err := loadTransportKey(link); err == nil {
		t.Fatal("a symlinked transport key loaded")
	}
	secp, _ := cmtjson.Marshal(map[string]any{"priv_key": secp256k1eth.GenPrivKey()})
	for name, content := range map[string]string{
		"secp256k1eth": string(secp),
		"extra-field":  strings.Replace(string(before), "{", `{"id":"x",`, 1),
		"empty":        "",
		"not-json":     "x",
	} {
		bad := filepath.Join(dir, name+".json")
		if err := os.WriteFile(bad, []byte(content), 0600); err != nil {
			t.Fatal(err)
		}
		if _, err := loadTransportKey(bad); err == nil {
			t.Errorf("%s transport key loaded", name)
		}
	}
}

// The supervisor derives Noise peer IDs in Python from stock node-key files; this pins the
// vector both sides check (tests/supervisor_test.py PEER_ID_VECTOR).
func TestTransportPeerIDVector(t *testing.T) {
	key := ed25519.GenPrivKeyFromSecret([]byte("etna-transport-vector"))
	raw, err := cmtjson.Marshal(transportKeyFile{PrivKey: key})
	if err != nil {
		t.Fatal(err)
	}
	const layout = `{"priv_key":{"type":"tendermint/PrivKeyEd25519","value":"nZGcTgiuNXtFuZUZGISAcSje3hVT+bGhna2LmuPCFRKyPL6KLy400isFcvbvDSQ5ljD7QR05nMHahbB+NhZltA=="}}`
	if string(raw) != layout {
		t.Fatalf("transport key layout %s", raw)
	}
	if id := mustPeer(t, key); id.String() != "12D3KooWMp8TizWt75VicSKSACXjXQ8pByDngq47VN51SMPF5mfh" {
		t.Fatalf("peer ID %s", id)
	}
}
