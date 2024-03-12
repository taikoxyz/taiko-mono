package server

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"strings"

	"github.com/gorilla/mux"
	blobstorage "github.com/taikoxyz/taiko-mono/packages/blob-storage"
	"github.com/taikoxyz/taiko-mono/packages/blob-storage/pkg/repo"
	"github.com/urfave/cli/v2"
	"gorm.io/gorm"
)

type resp struct {
	Data []blobData `bson:"data" json:"data"`
}

type blobData struct {
	Blob          string `bson:"blob_hash" json:"blob_hash"`
	KzgCommitment string `bson:"kzg_commitment" json:"kzg_commitment"`
}

type Server struct {
	blobHashRepo blobstorage.BlobHashRepository
	port         int
}

func (s *Server) InitFromCli(ctx context.Context, c *cli.Context) error {
	cfg, err := NewConfigFromCliContext(c)
	if err != nil {
		return err
	}

	return InitFromConfig(ctx, s, cfg)
}

// InitFromConfig inits a new Server from a provided Config struct
func InitFromConfig(ctx context.Context, s *Server, cfg *Config) (err error) {
	db, err := cfg.OpenDBFunc()
	if err != nil {
		return err
	}

	blobHashRepo, err := repo.NewBlobHashRepository(db)
	if err != nil {
		return err
	}

	s.blobHashRepo = blobHashRepo

	s.port = int(cfg.Port)

	return nil
}

func (s *Server) Start() error {
	slog.Info("Server started!")

	r := mux.NewRouter()

	// Handler functions
	r.HandleFunc("/getBlob", s.getBlobHandler).Methods("GET")

	http.Handle("/", r)
	return http.ListenAndServe(fmt.Sprintf(":%v", s.port), nil)
}

func (s *Server) Close(ctx context.Context) {
}

func (s *Server) getBlobHandler(w http.ResponseWriter, r *http.Request) {
	blobHashes, ok := r.URL.Query()["blobHash"]
	if !ok || len(blobHashes) == 0 {
		http.Error(w, "Url Param 'blobHash' is missing", http.StatusBadRequest)
		return
	}

	data, err := s.getBlobData(strings.Split(blobHashes[0], ","))
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}

	response := resp{
		Data: make([]blobData, 0),
	}

	// Convert data to the correct type
	for _, d := range data {
		response.Data = append(response.Data, blobData{
			Blob:          d.Blob,
			KzgCommitment: d.KzgCommitment,
		},
		)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (s *Server) Name() string {
	return "server"
}

// getBlobData retrieves blob data from MongoDB based on blobHashes.
func (s *Server) getBlobData(blobHashes []string) ([]blobData, error) {
	var results []blobData

	for _, blobHash := range blobHashes {
		var result blobData

		bh, err := s.blobHashRepo.FirstByBlobHash(blobHash)

		if err != nil {
			if err == gorm.ErrRecordNotFound {
				// Handle case where blob hash is not found
				result.Blob = "NOT_FOUND"
				result.KzgCommitment = "NOT_FOUND"
			} else {
				// Return error for other types of errors
				return nil, err
			}
		} else {
			result.Blob = bh.BlobHash
			result.KzgCommitment = bh.KzgCommitment

			results = append(results, result)
		}
	}

	return results, nil
}
