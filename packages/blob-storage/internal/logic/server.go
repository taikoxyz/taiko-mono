package logic

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"strings"

	"github.com/gorilla/mux"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
)

type Server struct {
	cfg *Config
}

func NewServer(cfg *Config) *Server {
	return &Server{
		cfg: cfg,
	}
}

func (s *Server) Start() error {
	log.Println("Server started!")
	r := mux.NewRouter()

	// Handler functions
	r.HandleFunc("/getBlob", s.getBlobHandler).Methods("GET")

	http.Handle("/", r)
	return http.ListenAndServe(s.cfg.Server.Port, nil)
}

func (s *Server) getBlobHandler(w http.ResponseWriter, r *http.Request) {
	blobHashes, ok := r.URL.Query()["blobHash"]
	if !ok || len(blobHashes) == 0 {
		http.Error(w, "Url Param 'blobHash' is missing", http.StatusBadRequest)
		return
	}

	data, err := GetBlobData(s.cfg, strings.Split(blobHashes[0], ","))
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	response := struct {
		Data []struct {
			Blob          string `json:"blob"`
			KzgCommitment string `json:"kzg_commitment"`
		} `json:"data"`
	}{}

	// Convert data to the correct type
	for _, d := range data {
		response.Data = append(response.Data, struct {
			Blob          string `json:"blob"`
			KzgCommitment string `json:"kzg_commitment"`
		}{Blob: d.Blob, KzgCommitment: d.KzgCommitment})
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// GetBlobData retrieves blob data from MongoDB based on blobHashes.
func GetBlobData(cfg *Config, blobHashes []string) ([]struct {
	Blob          string `bson:"blob_data"`
	KzgCommitment string `bson:"kzg_commitment"`
}, error) {
	mongoClient, err := NewMongoDBClient(cfg.MongoDB)
	if err != nil {
		return nil, err
	}
	defer mongoClient.Close()

	collection := mongoClient.Client.Database(cfg.MongoDB.Database).Collection("blobs")

	var results []struct {
		Blob          string `bson:"blob_data"`
		KzgCommitment string `bson:"kzg_commitment"`
	}

	for _, blobHash := range blobHashes {
		var result struct {
			Blob          string `bson:"blob_data"`
			KzgCommitment string `bson:"kzg_commitment"`
		}

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
