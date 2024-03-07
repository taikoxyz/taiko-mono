package logic

import (
	"context"
	"log"
	"strconv"

	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// MongoDBClient holds the MongoDB client instance.
type MongoDBClient struct {
	Client *mongo.Client
}

// NewMongoDBClient creates a new MongoDB client.
func NewMongoDBClient(cfg MongoDBConfig) (*MongoDBClient, error) {
	// Set MongoDB connection options
	clientOptions := options.Client().ApplyURI("mongodb://" + cfg.Host + ":" + strconv.Itoa(cfg.Port))
	if cfg.Username != "" && cfg.Password != "" {
		clientOptions.Auth = &options.Credential{
			Username: cfg.Username,
			Password: cfg.Password,
		}
	}

	// Connect to MongoDB
	client, err := mongo.Connect(context.Background(), clientOptions)
	if err != nil {
		return nil, err
	}

	// Check the connection
	err = client.Ping(context.Background(), nil)
	if err != nil {
		return nil, err
	}

	log.Println("Connected to MongoDB")

	return &MongoDBClient{Client: client}, nil
}

// Close closes the MongoDB client connection.
func (mc *MongoDBClient) Close() {
	if mc.Client != nil {
		mc.Client.Disconnect(context.Background())
		log.Println("Disconnected from MongoDB")
	}
}
