package testutils

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path"

	"github.com/ethereum-optimism/optimism/op-service/txmgr"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/log"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

// MemoryBlobTxMgr is a mock tx manager that stores blobs in memory.
type MemoryBlobTxMgr struct {
	rpc    *rpc.Client
	mgr    *txmgr.SimpleTxManager
	server *MemoryBlobServer
}

// NewMemoryBlobTxMgr creates a new MemoryBlobTxMgr.
func NewMemoryBlobTxMgr(rpc *rpc.Client, mgr *txmgr.SimpleTxManager, server *MemoryBlobServer) *MemoryBlobTxMgr {
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

	m.server.AddBlob(tx.BlobHashes(), tx.BlobTxSidecar())
	return receipt, nil
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
}

// NewMemoryBlobServer creates a new MemoryBlobServer.
func NewMemoryBlobServer() *MemoryBlobServer {
	blobsMap := make(map[common.Hash]*BlobInfo)
	return &MemoryBlobServer{
		blobs: blobsMap,
		server: httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			blobHash := path.Base(r.URL.Path)

			blobInfo, ok := blobsMap[common.HexToHash(blobHash)]
			if !ok {
				log.Error("Blob not found", "hash", blobHash)
				w.WriteHeader(http.StatusNotFound)
				return
			}

			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusOK)
			json.NewEncoder(w).Encode(&rpc.BlobServerResponse{
				Commitment:    blobInfo.Commitment,
				Data:          blobInfo.Data,
				VersionedHash: "",
			})
		})),
	}
}

// Close closes the server.
func (s *MemoryBlobServer) Close() {
	s.server.Close()
}

// URL returns the URL of the server.
func (s *MemoryBlobServer) URL() string {
	return s.server.URL
}

// AddBlob adds a blob to the server.
func (s *MemoryBlobServer) AddBlob(blobHashes []common.Hash, sidecar *types.BlobTxSidecar) {
	for i, hash := range blobHashes {
		s.blobs[hash].Data = common.Bytes2Hex(sidecar.Blobs[i][:])
		s.blobs[hash].Commitment = common.Bytes2Hex(sidecar.Commitments[i][:])
	}
}
