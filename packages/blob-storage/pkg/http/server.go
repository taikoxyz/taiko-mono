package http

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"strings"

	"github.com/gorilla/mux"
	mongodb "github.com/taikoxyz/taiko-mono/packages/blob-storage/pkg/db"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
)

type resp struct {
	Data []blobData `json:"data"`
}

type blobData struct {
	Blob          string `json:"blob"`
	KzgCommitment string `json:"kzg_commitment"`
}

type Server struct {
	db     *mongodb.MongoDBClient
	dbName string
	port   int
}

func NewServer(db *mongodb.MongoDBClient, dbName string, port int) *Server {
	return &Server{
		db:     db,
		dbName: dbName,
		port:   port,
	}
}

func (s *Server) Start() error {
	slog.Info("Server started!")
	r := mux.NewRouter()

	// Handler functions
	r.HandleFunc("/getBlob", s.getBlobHandler).Methods("GET")

	http.Handle("/", r)
	return http.ListenAndServe(fmt.Sprintf(":%v", s.port), nil)
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
