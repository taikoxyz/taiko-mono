package mongodb

import (
	"context"
	"strconv"

	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
	"golang.org/x/exp/slog"
)

// MongoDBClient holds the MongoDB client instance.
type MongoDBClient struct {
	Client *mongo.Client
}

// MongoDBConfig holds the configuration for MongoDB.
type MongoDBConfig struct {
	Host     string
	Port     int
	Username string
	Password string
	Database string
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

	slog.Info("Connected to MongoDB")

	return &MongoDBClient{Client: client}, nil
}

// Close closes the MongoDB client connection.
func (mc *MongoDBClient) Close(ctx context.Context) error {
	if mc.Client != nil {
		if err := mc.Client.Disconnect(ctx); err != nil {
			slog.Error("error disconnecting from mongodb", "error", err)

			return err
		}

		slog.Info("Disconnected from MongoDB")
	}

	return nil
}
