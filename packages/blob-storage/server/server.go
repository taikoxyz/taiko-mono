package server

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"strings"

	"github.com/gorilla/mux"
	mongodb "github.com/taikoxyz/taiko-mono/packages/blob-storage/pkg/db"
	"github.com/urfave/cli/v2"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
)

type resp struct {
	Data []blobData `bson:"data" json:"data"`
}

type blobData struct {
	Blob          string `bson:"blob_hash" json:"blob_hash"`
	KzgCommitment string `bson:"kzg_commitment" json:"kzg_commitment"`
}

type Server struct {
	db     *mongodb.MongoDBClient
	dbName string
	port   int
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
	db, err := mongodb.NewMongoDBClient(mongodb.MongoDBConfig{
		Host:     cfg.DBHost,
		Port:     cfg.DBPort,
		Username: cfg.DBUsername,
		Password: cfg.DBPassword,
		Database: cfg.DBDatabase,
	})
	if err != nil {
		return err
	}

	s.db = db
	s.dbName = cfg.DBDatabase
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
	if err := s.db.Close(ctx); err != nil {
		slog.Error("error closing db connection", "error", err)
	}
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
	collection := s.db.Client.Database(s.dbName).Collection("blobs")

	var results []blobData

	for _, blobHash := range blobHashes {
		var result blobData

		if err := collection.FindOne(context.Background(), bson.M{"blob_hash": blobHash}).Decode(&result); err != nil {
			if err == mongo.ErrNoDocuments {
				// Handle case where blob hash is not found
				result.Blob = "NOT_FOUND"
				result.KzgCommitment = "NOT_FOUND"
			} else {
				// Return error for other types of errors
				return nil, err
			}
		}

		results = append(results, result)
	}

	return results, nil
}
