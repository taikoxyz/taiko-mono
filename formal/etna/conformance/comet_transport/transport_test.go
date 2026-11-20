package privval

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/cometbft/cometbft/crypto/secp256k1eth"
	"github.com/cometbft/cometbft/libs/log"
	"github.com/cometbft/cometbft/libs/protoio"
	privvalproto "github.com/cometbft/cometbft/proto/tendermint/privval"
	pb "github.com/cometbft/cometbft/proto/tendermint/types"
	"github.com/cometbft/cometbft/types"
	cmterrors "github.com/cometbft/cometbft/types/errors"
)

const (
	transportReadTimeout = 200 * time.Millisecond
	transportAccept      = 200 * time.Millisecond
	transportServerRead  = 3 * time.Second
	transportRetryWait   = 20 * time.Millisecond
	transportCancelWait  = 2 * time.Second
	transportJoin        = time.Second
	transportPing        = time.Hour
	transportMaxAttempts = 3
)

type transportCall struct {
	row        string
	wrongChain bool
	later      bool
}

type transportCase struct {
	name    string
	seed    string
	pipes   int
	retries int
	replies []string // Wire changes by episode-wide attempt number.
	cancel  bool
	calls   []transportCall
}

func transportCases() []transportCase {
	nilVote := transportCall{row: nilSeed}
	prevote := transportCall{row: prevoteSeed}
	return []transportCase{
		{name: "nil-exact", seed: nilSeed, pipes: 1, retries: 1, calls: []transportCall{nilVote}},
		{name: "nil-time", seed: nilSeed, pipes: 1, retries: 1, calls: []transportCall{{row: nilSeed, later: true}}},
		{name: "prevote-exact", seed: prevoteSeed, pipes: 1, retries: 1, calls: []transportCall{prevote}},
		{name: "wrong-chain-retry", seed: nilSeed, pipes: 1, retries: 2, calls: []transportCall{{row: nilSeed, wrongChain: true}, nilVote}},
		{name: "prevote-conflict-retry", seed: prevoteSeed, pipes: 1, retries: 2, calls: []transportCall{{row: "prevote_b_r1"}, prevote}},
		{name: "wrong-union", seed: nilSeed, pipes: 1, retries: 1, replies: []string{"wrong-union"}, calls: []transportCall{nilVote}},
		{name: "wrong-union-retry", seed: nilSeed, pipes: 1, retries: 2, replies: []string{"wrong-union"}, calls: []transportCall{nilVote}},
		{name: "truncated-retry", seed: nilSeed, pipes: 2, retries: 2, replies: []string{"truncate"}, calls: []transportCall{nilVote}},
		{name: "transport-exhausted", seed: nilSeed, pipes: 3, retries: 3, replies: []string{"silent", "silent", "silent"}, calls: []transportCall{nilVote}},
		{name: "cancel", seed: nilSeed, pipes: 1, retries: 3, replies: []string{"silent"}, cancel: true, calls: []transportCall{nilVote}},
	}
}

type transportAttempt struct {
	call            int
	pipe            int
	requestWrite    []byte
	requestRead     []byte
	request         record
	stockResponse   record
	handlerError    string
	serverFrame     []byte
	wireSent        []byte
	wireRead        []byte
	clientReadError string
	peerOpenAtError bool
	clientDeadline  bool
	clientDrop      bool
}

type transportEpisode struct {
	mu       sync.Mutex
	plan     transportCase
	key      secp256k1eth.PubKey
	pv       *FilePV
	chain    string
	safe     map[string]bool
	attempts []*transportAttempt
	call     int
	closing  bool
	problems []string
	accepts  []int
	dials    []int
	pairs    [][2]*transportConn
	listener *transportListener
	endpoint *SignerListenerEndpoint
	servers  []*SignerServer
	retry    *RetrySignerClient
}

type transportConn struct {
	net.Conn
	episode *transportEpisode
	pipe    int
	client  bool
	current *transportAttempt // Set on each actual client write, under episode.mu.
	closed  bool
}

func (episode *transportEpisode) problem(message string) error {
	episode.problems = append(episode.problems, message)
	return errors.New(message)
}

func (conn *transportConn) Read(buffer []byte) (int, error) {
	count, err := conn.Conn.Read(buffer)
	episode := conn.episode
	episode.mu.Lock()
	defer episode.mu.Unlock()
	if attempt := conn.current; attempt != nil {
		if conn.client {
			attempt.wireRead = append(attempt.wireRead, buffer[:count]...)
			if err != nil && !episode.closing {
				attempt.clientReadError = err.Error()
				attempt.peerOpenAtError = !episode.pairs[conn.pipe-1][1].closed
			}
		} else {
			attempt.requestRead = append(attempt.requestRead, buffer[:count]...)
		}
	}
	return count, err
}

func (conn *transportConn) Write(buffer []byte) (int, error) {
	episode := conn.episode
	episode.mu.Lock()
	if conn.client {
		if len(episode.attempts) >= transportMaxAttempts || episode.closing {
			err := episode.problem("unexpected request outside the attempt budget")
			episode.mu.Unlock()
			return 0, err
		}
		attempt := &transportAttempt{call: episode.call, pipe: conn.pipe}
		conn.current = attempt
		episode.pairs[conn.pipe-1][1].current = attempt
		episode.attempts = append(episode.attempts, attempt)
		episode.mu.Unlock()
		count, err := conn.Conn.Write(buffer)
		episode.mu.Lock()
		attempt.requestWrite = bytes.Clone(buffer[:count])
		episode.mu.Unlock()
		return count, err
	}

	attempt := conn.current
	if attempt == nil || attempt.stockResponse == nil || attempt.serverFrame != nil {
		err := episode.problem("unexpected stock server write")
		episode.mu.Unlock()
		return 0, err
	}
	attempt.serverFrame = bytes.Clone(buffer)
	mode := ""
	if len(episode.attempts) <= len(episode.plan.replies) {
		mode = episode.plan.replies[len(episode.attempts)-1]
	}
	delivered := buffer
	switch mode {
	case "wrong-union":
		response := mustWrapMsg(&privvalproto.PingResponse{})
		var err error
		delivered, err = protoio.MarshalDelimited(&response)
		if err != nil {
			episode.mu.Unlock()
			return 0, err
		}
	case "truncate":
		delivered = buffer[:len(buffer)-1]
	case "silent":
		delivered = nil
	}
	episode.mu.Unlock()

	// A partial or silent reply leaves the Pipe open until the real
	// client-side read deadline makes the stock endpoint drop it.
	if mode == "silent" {
		return len(buffer), nil
	}
	count, err := conn.Conn.Write(delivered)
	episode.mu.Lock()
	attempt.wireSent = bytes.Clone(delivered[:count])
	episode.mu.Unlock()
	if err != nil || count != len(delivered) {
		return count, err
	}
	return len(buffer), nil
}

func (conn *transportConn) SetReadDeadline(deadline time.Time) error {
	err := conn.Conn.SetReadDeadline(deadline)
	if conn.client {
		episode := conn.episode
		episode.mu.Lock()
		defer episode.mu.Unlock()
		remaining := time.Until(deadline)
		if conn.current == nil || conn.current.clientDeadline || err != nil ||
			remaining <= 0 || remaining > transportReadTimeout {
			episode.problem("client did not set one bounded read deadline for the active attempt")
		} else {
			conn.current.clientDeadline = true
		}
	}
	return err
}

func (conn *transportConn) Close() error {
	episode := conn.episode
	episode.mu.Lock()
	defer episode.mu.Unlock()
	if !conn.closed && conn.client && conn.current != nil && !episode.closing {
		conn.current.clientDrop = true
	}
	conn.closed = true
	return conn.Conn.Close()
}

type transportListener struct {
	episode *transportEpisode
	queue   chan *transportConn
	closed  chan struct{}
	once    sync.Once
}

func (listener *transportListener) Accept() (net.Conn, error) {
	select {
	case <-listener.closed:
		return nil, net.ErrClosed
	case conn := <-listener.queue:
		listener.episode.mu.Lock()
		listener.episode.accepts = append(listener.episode.accepts, conn.pipe)
		listener.episode.mu.Unlock()
		return conn, nil
	}
}

func (listener *transportListener) Close() error {
	listener.once.Do(func() { close(listener.closed) })
	return nil
}

type pipeAddress struct{}

func (pipeAddress) Network() string { return "pipe" }
func (pipeAddress) String() string  { return "owned-pipe" }

func (*transportListener) Addr() net.Addr { return pipeAddress{} }

func transportVote(chain string, vote *pb.Vote) (record, error) {
	wire, err := vote.Marshal()
	if err != nil {
		return nil, err
	}
	return record{
		"wire": hex.EncodeToString(wire), "signBytes": hex.EncodeToString(types.VoteSignBytes(chain, vote)),
		"seconds": vote.Timestamp.Unix(), "nanos": vote.Timestamp.Nanosecond(),
		"signature": hex.EncodeToString(vote.Signature), "extensionSignature": hex.EncodeToString(vote.ExtensionSignature),
	}, nil
}

func transportResponse(message *privvalproto.Message, chain string, key secp256k1eth.PubKey) (record, error) {
	wire, err := message.Marshal()
	if err != nil {
		return nil, err
	}
	result := record{"wire": hex.EncodeToString(wire)}
	if response := message.GetSignedVoteResponse(); response != nil {
		vote, err := transportVote(chain, &response.Vote)
		if err != nil {
			return nil, err
		}
		result["union"] = "SignedVoteResponse"
		result["vote"] = vote
		result["error"] = transportRemote(response.Error)
		result["verified"] = key.VerifySignature(types.VoteSignBytes(chain, &response.Vote), response.Vote.Signature)
		return result, nil
	}
	if message.GetPingResponse() != nil {
		result["union"] = "PingResponse"
		return result, nil
	}
	return nil, fmt.Errorf("unexpected received response union %T", message.Sum)
}

func transportRemote(remote *privvalproto.RemoteSignerError) any {
	if remote == nil {
		return nil
	}
	return record{"code": remote.Code, "description": remote.Description}
}

func (episode *transportEpisode) handle(conn *transportConn, validator types.PrivValidator, message privvalproto.Message, chain string) (privvalproto.Message, error) {
	episode.mu.Lock()
	defer episode.mu.Unlock()
	attempt := conn.current
	request := message.GetSignVoteRequest()
	if attempt == nil || attempt.request != nil || request == nil || request.Vote == nil ||
		validator != episode.pv || episode.pv.Key.PrivKey != nil || chain != episode.chain {
		return privvalproto.Message{}, episode.problem("unexpected request or validator")
	}
	frame, err := protoio.MarshalDelimited(&message)
	if err != nil || !bytes.Equal(frame, attempt.requestRead) || !episode.safe[string(frame)] {
		return privvalproto.Message{}, episode.problem("request outside exact public cache allowlist")
	}
	vote := request.Vote
	if (vote.Type != pb.PrevoteType && (vote.Type != pb.PrecommitType || !types.ProtoBlockIDIsNil(&vote.BlockID))) ||
		len(vote.Signature) != 0 || len(vote.Extension) != 0 || len(vote.ExtensionSignature) != 0 {
		return privvalproto.Message{}, episode.problem("request could leave the public cached vote branches")
	}
	state := episode.pv.LastSignState
	if vote.Height != state.Height || vote.Round != state.Round || voteToStep(vote) != state.Step ||
		len(state.SignBytes) == 0 || len(state.Signature) != 65 {
		return privvalproto.Message{}, episode.problem("request could leave the persisted exact HRS")
	}
	observed, err := transportVote(request.ChainId, vote)
	if err != nil {
		return privvalproto.Message{}, err
	}
	body, err := message.Marshal()
	if err != nil {
		return privvalproto.Message{}, err
	}
	attempt.request = record{"chain": request.ChainId, "configuredChain": chain,
		"wire": hex.EncodeToString(body), "vote": observed}
	response, handlerErr := DefaultValidationRequestHandler(validator, message, chain)
	attempt.stockResponse, err = transportResponse(&response, chain, episode.key)
	if err != nil {
		return privvalproto.Message{}, episode.problem(err.Error())
	}
	attempt.handlerError = errorText(handlerErr)
	return response, handlerErr
}

func (episode *transportEpisode) start(t *testing.T, wait time.Duration) {
	t.Helper()
	logger := log.NewNopLogger()
	listener := &transportListener{
		episode: episode, queue: make(chan *transportConn, episode.plan.pipes),
		closed: make(chan struct{}),
	}
	episode.listener = listener
	for pipe := 1; pipe <= episode.plan.pipes; pipe++ {
		clientSide, serverSide := net.Pipe()
		client := &transportConn{Conn: clientSide, episode: episode, pipe: pipe, client: true}
		server := &transportConn{Conn: serverSide, episode: episode, pipe: pipe}
		episode.pairs = append(episode.pairs, [2]*transportConn{client, server})
		listener.queue <- client

		var available net.Conn = server
		dialer := NewSignerDialerEndpoint(logger, func() (net.Conn, error) {
			current := available
			if current == nil {
				return nil, net.ErrClosed
			}
			available = nil
			episode.mu.Lock()
			episode.dials = append(episode.dials, server.pipe)
			episode.mu.Unlock()
			return current, nil
		}, SignerDialerEndpointTimeoutReadWrite(transportServerRead),
			SignerDialerEndpointConnRetries(1), SignerDialerEndpointRetryWaitInterval(transportRetryWait))
		service := NewSignerServer(dialer, episode.chain, episode.pv)
		service.SetRequestHandler(func(validator types.PrivValidator, message privvalproto.Message, chain string) (privvalproto.Message, error) {
			return episode.handle(server, validator, message, chain)
		})
		check(t, service.Start() == nil, "start owned stock signer server")
		episode.servers = append(episode.servers, service)
	}

	episode.endpoint = NewSignerListenerEndpoint(logger, listener,
		SignerListenerEndpointTimeoutReadWrite(transportPing*3/2))
	episode.endpoint.timeoutAccept = transportAccept
	client, err := NewSignerClient(episode.endpoint, episode.chain)
	check(t, err == nil, "start stock listener endpoint: %v", err)
	// Retain the real ping loop, but schedule housekeeping beyond the case.
	episode.endpoint.instanceMtx.Lock()
	episode.endpoint.timeoutReadWrite = transportReadTimeout
	episode.endpoint.instanceMtx.Unlock()
	episode.retry = NewRetrySignerClient(client, episode.plan.retries, wait)
}

func stackContains(names ...string) bool {
	buffer := make([]byte, 128<<10)
	count := runtime.Stack(buffer, true)
	if count == len(buffer) {
		panic("truncated owned-goroutine observation")
	}
	for _, name := range names {
		if bytes.Contains(buffer[:count], []byte(name)) {
			return true
		}
	}
	return false
}

func waitForTransportStack(present bool, names ...string) bool {
	deadline := time.Now().Add(transportJoin)
	for time.Now().Before(deadline) {
		if stackContains(names...) == present {
			return true
		}
		time.Sleep(time.Millisecond)
	}
	return false
}

func (episode *transportEpisode) close() {
	episode.mu.Lock()
	if episode.closing {
		episode.mu.Unlock()
		return
	}
	episode.closing = true
	episode.mu.Unlock()

	for _, pair := range episode.pairs {
		for _, conn := range pair {
			_ = conn.Close()
		}
	}
	if episode.retry != nil {
		_ = episode.retry.Close()
	}
	if episode.endpoint != nil && episode.endpoint.IsRunning() {
		_ = episode.endpoint.Stop()
	} else if episode.listener != nil {
		_ = episode.listener.Close()
	}
	for _, server := range episode.servers {
		_ = server.Stop()
	}
}

func transportResult(err error) record {
	result := record{"class": "ok", "message": errorText(err), "remote": nil}
	if err == nil {
		return result
	}
	var remote *RemoteSignerError
	var required cmterrors.ErrRequiredField
	if errors.As(err, &remote) {
		result["class"] = "remote"
		if err != remote {
			result["class"] = "exhausted-remote"
		}
		result["remote"] = record{"code": remote.Code, "description": remote.Description}
	} else if errors.As(err, &required) && required.Field == "response" {
		result["class"] = "exhausted-required-response"
	} else if errors.Is(err, ErrReadTimeout) {
		result["class"] = "exhausted-timeout"
		if strings.HasPrefix(err.Error(), "aborted signing vote: ") {
			result["class"] = "aborted-timeout"
		}
	} else {
		result["class"] = "unexpected"
	}
	return result
}

func (episode *transportEpisode) observeAttempts(t *testing.T, calls []record) {
	t.Helper()
	for _, attempt := range episode.attempts {
		var response record
		if len(attempt.wireRead) > 0 {
			var delivered privvalproto.Message
			reader := protoio.NewDelimitedReader(bytes.NewReader(attempt.wireRead), maxRemoteSignerMsgSize)
			count, err := reader.ReadMsg(&delivered)
			if err == nil {
				check(t, count == len(attempt.wireRead), "unexpected response frame trailing bytes")
				response, err = transportResponse(&delivered, episode.chain, episode.key)
				check(t, err == nil, "decode observed response frame: %v", err)
			} else {
				check(t, errors.Is(err, io.ErrUnexpectedEOF), "unexpected observed prefix decode: %v", err)
			}
		}
		row := record{
			"pipe": attempt.pipe, "requestWrite": hex.EncodeToString(attempt.requestWrite),
			"requestRead": hex.EncodeToString(attempt.requestRead), "request": attempt.request,
			"stockResponse": attempt.stockResponse, "handlerError": attempt.handlerError,
			"serverFrame": hex.EncodeToString(attempt.serverFrame),
			"wireSent":    hex.EncodeToString(attempt.wireSent), "wireRead": hex.EncodeToString(attempt.wireRead),
			"wireResponse": response, "clientReadError": attempt.clientReadError,
			"clientDeadline": attempt.clientDeadline, "clientDrop": attempt.clientDrop,
			"peerOpenAtError": attempt.peerOpenAtError,
		}
		call := calls[attempt.call]
		call["attempts"] = append(call["attempts"].([]record), row)
	}
}

func runTransportCase(t *testing.T, plan transportCase, rows map[string]publicVote, key secp256k1eth.PubKey, address []byte) {
	t.Helper()
	path := stateFile(plan.seed)
	pv, loadedDisk := rehydrate(t, path)
	chain := rows[plan.seed].Chain
	otherChain := rows["gen1_precommit_a"].Chain
	check(t, chain != otherChain, "wrong-chain control aliases configured chain")
	episode := &transportEpisode{plan: plan, key: key, pv: &pv, chain: chain, safe: make(map[string]bool)}
	t.Cleanup(episode.close)

	makeRequest := func(call transportCall) (string, *pb.Vote) {
		requestChain := chain
		if call.wrongChain {
			requestChain = otherChain
		}
		vote := unsignedVote(t, rows[call.row], address)
		if call.later {
			vote.Timestamp = vote.Timestamp.Add(time.Nanosecond)
		}
		return requestChain, vote
	}
	for _, call := range plan.calls {
		requestChain, vote := makeRequest(call)
		req := mustWrapMsg(&privvalproto.SignVoteRequest{Vote: vote, ChainId: requestChain})
		frame, err := protoio.MarshalDelimited(&req)
		check(t, err == nil, "freeze permitted public request: %v", err)
		episode.safe[string(frame)] = true
	}

	wait := transportRetryWait
	if plan.cancel {
		wait = transportCancelWait
	}
	episode.start(t, wait)

	calls := make([]record, 0, len(plan.calls))
	retryWaitObserved := false
	for index, call := range plan.calls {
		episode.mu.Lock()
		episode.call = index
		episode.mu.Unlock()
		requestChain, vote := makeRequest(call)
		stateBefore := observeState(pv.LastSignState)
		_, diskBefore := readStateBytes(t, path)
		before := observeVote(t, requestChain, vote)
		var err error
		if plan.cancel {
			result := make(chan error, 1)
			done := make(chan struct{})
			go func() {
				defer close(done)
				result <- episode.retry.SignVote(requestChain, vote)
			}()
			retryWaitObserved = waitForTransportStack(true, "(*RetrySignerClient).sleep")
			closeErr := episode.retry.Close()
			check(t, closeErr == nil, "cancel through stock Close: %v", closeErr)
			select {
			case err = <-result:
			case <-time.After(transportJoin):
				t.Fatal("cancelled SignVote did not join")
			}
			select {
			case <-done:
			case <-time.After(transportJoin):
				t.Fatal("owned cancellation worker did not exit")
			}
		} else {
			err = episode.retry.SignVote(requestChain, vote)
		}
		_, diskAfter := readStateBytes(t, path)
		calls = append(calls, record{
			"requestedChain": requestChain, "before": before,
			"after": observeVote(t, requestChain, vote), "result": transportResult(err),
			"verified":    key.VerifySignature(types.VoteSignBytes(requestChain, vote), vote.Signature),
			"stateBefore": stateBefore, "stateAfter": observeState(pv.LastSignState),
			"diskBefore": diskBefore, "diskAfter": diskAfter, "attempts": []record{},
		})
	}
	episode.close()
	joined := waitForTransportStack(false, "(*SignerServer).serviceLoop", "(*SignerListenerEndpoint).serviceLoop",
		"(*SignerListenerEndpoint).pingLoop", "(*RetrySignerClient).SignVote")
	episode.mu.Lock()
	defer episode.mu.Unlock()
	check(t, len(episode.problems) == 0, "transport observation failed: %v", episode.problems)
	episode.observeAttempts(t, calls)
	closedPipes := make([]int, 0, len(episode.pairs))
	for _, pair := range episode.pairs {
		if pair[0].closed && pair[1].closed {
			closedPipes = append(closedPipes, pair[0].pipe)
		}
	}
	listenerClosed := false
	select {
	case <-episode.listener.closed:
		listenerClosed = true
	default:
	}
	retryClosed := false
	select {
	case <-episode.retry.quit:
		retryClosed = true
	default:
	}
	servicesStopped := !episode.endpoint.IsRunning()
	for _, server := range episode.servers {
		servicesStopped = servicesStopped && !server.IsRunning()
	}
	// Dial order can vary. Listener order and each attempt still bind the
	// specific Pipe receiving the request.
	sort.Ints(episode.dials)
	writeTransportReceipt(t, plan.name, record{
		"schema": "etna-comet-transport-receipt-1", "episode": plan.name,
		"seed": plan.seed, "path": path, "configuredChain": chain,
		"loadedDisk": loadedDisk, "calls": calls,
		"profile": record{"readMillis": episode.endpoint.timeoutReadWrite.Milliseconds(),
			"serverMillis": episode.servers[0].endpoint.timeoutReadWrite.Milliseconds(),
			"acceptMillis": episode.endpoint.timeoutAccept.Milliseconds(),
			"retryMillis":  episode.retry.timeout.Milliseconds(), "pingMillis": episode.endpoint.pingInterval.Milliseconds(),
			"retries": episode.retry.retries},
		"cleanup": record{"accepted": episode.accepts, "dialed": episode.dials,
			"closedPipes": closedPipes, "retryWaitObserved": retryWaitObserved, "joined": joined,
			"retryClosed": retryClosed, "listenerClosed": listenerClosed, "servicesStopped": servicesStopped},
	})
}

func writeTransportReceipt(t *testing.T, name string, receipt record) {
	t.Helper()
	data, err := json.Marshal(receipt)
	check(t, err == nil, "encode transport receipt: %v", err)
	path := filepath.Join("/tmp/output/receipts", name+".json")
	file, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o600)
	check(t, err == nil, "create exclusive transport receipt: %v", err)
	n, writeErr := file.Write(data)
	closeErr := file.Close()
	check(t, writeErr == nil && closeErr == nil && n == len(data), "write full transport receipt: %v %v", writeErr, closeErr)
	digest := sha256.Sum256(data)
	t.Logf("receipt %s %d %x", name, len(data), digest)
}

func TestCometTransport(t *testing.T) {
	identity := processIdentity(t)
	t.Logf("transport process %d %s %s", identity["pid"], identity["namespace"], identity["startTicks"])
	projection, rows := readProjection(t)
	key, address := publicKey(t, projection)
	for _, plan := range transportCases() {
		t.Run(plan.name, func(t *testing.T) { runTransportCase(t, plan, rows, key, address) })
	}
}
