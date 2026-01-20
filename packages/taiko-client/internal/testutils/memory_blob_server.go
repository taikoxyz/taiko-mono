package testutils

import (
	"context"
	"encoding/json"
	"math/big"
	"net/http"
	"net/http/httptest"
	"net/url"
	"path"
	"sync"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	gethRPC "github.com/ethereum/go-ethereum/rpc"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// MemoryBlobTxMgr is a mock tx manager that stores blobs in memory.
type MemoryBlobTxMgr struct {
	rpc    *rpc.Client
	mgr    txmgr.TxManager
	server *MemoryBlobServer
}

// NewMemoryBlobTxMgr creates a new MemoryBlobTxMgr.
func NewMemoryBlobTxMgr(rpc *rpc.Client, mgr txmgr.TxManager, server *MemoryBlobServer) *MemoryBlobTxMgr {
	return &MemoryBlobTxMgr{
		rpc:    rpc,
		mgr:    mgr,
		server: server,
	}
}

// Send sends a transaction to the tx manager.
func (m *MemoryBlobTxMgr) Send(ctx context.Context, candidate txmgr.TxCandidate) (*types.Receipt, error) {
	receipt, err := m.mgr.Send(ctx, candidate)
	if err != nil {
		return nil, err
	}

	tx, _, err := m.rpc.L1.TransactionByHash(ctx, receipt.TxHash)
	if err != nil {
		return nil, err
	}

	if tx.Type() != types.BlobTxType {
		return receipt, nil
	}

	return receipt, m.server.AddBlob(tx.BlobHashes(), candidate.Blobs)
}

// SendAsync implements TxManager interface.
func (m *MemoryBlobTxMgr) SendAsync(ctx context.Context, candidate txmgr.TxCandidate, ch chan txmgr.SendResponse) {
	m.mgr.SendAsync(ctx, candidate, ch)
}

// From implements TxManager interface.
func (m *MemoryBlobTxMgr) From() common.Address {
	return m.mgr.From()
}

// BlockNumber implements TxManager interface.
func (m *MemoryBlobTxMgr) BlockNumber(ctx context.Context) (uint64, error) {
	return m.mgr.BlockNumber(ctx)
}

// API implements TxManager interface.
func (m *MemoryBlobTxMgr) API() gethRPC.API {
	return m.mgr.API()
}

// Close implements TxManager interface.
func (m *MemoryBlobTxMgr) Close() {
	m.mgr.Close()
}

// IsClosed implements TxManager interface.
func (m *MemoryBlobTxMgr) IsClosed() bool {
	return m.mgr.IsClosed()
}

// SuggestGasPriceCaps implements TxManager interface.
func (m *MemoryBlobTxMgr) SuggestGasPriceCaps(
	ctx context.Context,
) (tipCap *big.Int, baseFee *big.Int, blobBaseFee *big.Int, err error) {
	return m.mgr.SuggestGasPriceCaps(ctx)
}

// BlobInfo contains the data and commitment of a blob.
type BlobInfo struct {
	Data       string
	Commitment string
}

// MemoryBlobServer is a mock blob server that stores blobs in memory.
type MemoryBlobServer struct {
	blobs  map[common.Hash]*BlobInfo
	server *httptest.Server
	mu     sync.RWMutex
	waitCh <-chan struct{}
	hitCh  chan<- struct{}
}

// NewMemoryBlobServer creates a new MemoryBlobServer.
func NewMemoryBlobServer() *MemoryBlobServer {
	blobsMap := make(map[common.Hash]*BlobInfo)
	s := &MemoryBlobServer{blobs: blobsMap}
	s.server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		blobHash := path.Base(r.URL.Path)

		s.mu.RLock()
		blobInfo, ok := s.blobs[common.HexToHash(blobHash)]
		waitCh := s.waitCh
		hitCh := s.hitCh
		s.mu.RUnlock()
		if !ok {
			log.Error("Blob not found", "hash", blobHash)
			w.WriteHeader(http.StatusNotFound)
			return
		}

		if hitCh != nil {
			select {
			case hitCh <- struct{}{}:
			default:
			}
		}
		if waitCh != nil {
			select {
			case <-waitCh:
			case <-r.Context().Done():
				return
			}
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		if err := json.NewEncoder(w).Encode(&rpc.BlobServerResponse{
			Commitment:    blobInfo.Commitment,
			Data:          blobInfo.Data,
			VersionedHash: blobHash,
		}); err != nil {
			log.Error("Failed to encode blob server response", "err", err)
			w.WriteHeader(http.StatusInternalServerError)
			return
		}
	}))
	return s
}

// Close closes the server.
func (s *MemoryBlobServer) Close() {
	s.server.Close()
}

// URL returns the URL of the server.
func (s *MemoryBlobServer) URL() *url.URL {
	url, err := url.Parse(s.server.URL)
	if err != nil {
		log.Crit("Failed to parse server URL", "err", err)
	}
	return url
}

// SetRequestWaiter blocks blob responses until the channel is closed or the request is canceled.
func (s *MemoryBlobServer) SetRequestWaiter(ch <-chan struct{}) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.waitCh = ch
}

// SetRequestNotifier emits on the provided channel when a blob request is received.
func (s *MemoryBlobServer) SetRequestNotifier(ch chan<- struct{}) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.hitCh = ch
}

// AddBlob adds a blob to the server.
func (s *MemoryBlobServer) AddBlob(blobHashes []common.Hash, blobs []*eth.Blob) error {
	for i, hash := range blobHashes {
		commitment, err := blobs[i].ComputeKZGCommitment()
		if err != nil {
			return err
		}

		s.mu.Lock()
		s.blobs[hash] = &BlobInfo{
			Data:       blobs[i].String(),
			Commitment: common.Bytes2Hex(commitment[:]),
		}
		s.mu.Unlock()

		log.Info(
			"New blob added to memory blob server",
			"hash", hash,
			"commitment", common.Bytes2Hex(commitment[:]),
			"url", s.server.URL,
		)
	}

	return nil
}
