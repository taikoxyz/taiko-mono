package logic

import (
	"github.com/ethereum/go-ethereum/core/types"
)

// CallbackFunc represents the type of the callback function for handling events.
type CallbackFunc func(string, string, string, types.Log)

// IndexedEvent struct represents the configuration for an indexed event.
type IndexedEvent struct {
	Contract  string
	EventName string
	EventHash string
	Callback  CallbackFunc
}

// NetworkConfig struct represents the configuration for a network.
type NetworkConfig struct {
	RPCURL        string
	BeaconURL     string // Add this field
	NetworkName   string
	IndexedEvents []IndexedEvent
}

// MongoDBConfig holds the configuration for MongoDB.
type MongoDBConfig struct {
	Host     string
	Port     int
	Username string
	Password string
	Database string
}

// ServerConfig struct represents the configuration for the api server.
type ServerConfig struct {
	Port string
}

// Config struct holds the overall configuration for the application.
type Config struct {
	Networks []NetworkConfig
	MongoDB  MongoDBConfig
	Server   ServerConfig
}

// GetConfig loads the configuration from environment variables or a config file.
func GetConfig() (*Config, error) {
	cfg := &Config{}
	cfg.Networks = []NetworkConfig{
		{
			RPCURL:      "wss://l1ws.internal.taiko.xyz",
			BeaconURL:   "https://l1beacon.internal.taiko.xyz/eth/v1/beacon/blob_sidecars/", // Set the beacon URL here
			NetworkName: "L2A",
			IndexedEvents: []IndexedEvent{
				{
					Contract:  "0xC069c3d2a9f2479F559AD34485698ad5199C555f",
					EventHash: "0xa62cea5af360b010ef0d23472a2a7493b54175fd9fd2f9c2aa2bb427d2f4d3ca",
					EventName: "BlockProposed",
					Callback:  BlockProposedCallback,
				},
			},
		},
		{
			RPCURL:      "wss://l1ws.internal.taiko.xyz",
			BeaconURL:   "https://l1beacon.internal.taiko.xyz/eth/v1/beacon/blob_sidecars/", // Set the beacon URL here
			NetworkName: "L2B",
			IndexedEvents: []IndexedEvent{
				{
					Contract:  "0xCF4303dFAA6b7aa9bB985a068035E2F8AEcEC7fE",
					EventHash: "0xa62cea5af360b010ef0d23472a2a7493b54175fd9fd2f9c2aa2bb427d2f4d3ca",
					EventName: "BlockProposed",
					Callback:  BlockProposedCallback,
				},
			},
		},
	}

	// Same DB for the blobs (L2A, L2B, etc.)
	cfg.MongoDB = MongoDBConfig{
		Host:     "localhost",
		Port:     27017,
		Username: "",             // Add your MongoDB username if needed
		Password: "",             // Add your MongoDB password if needed
		Database: "blob_storage", // Choose your MongoDB database name
	}

	// Server listen and serve
	cfg.Server = ServerConfig{
		Port: ":27001",
	}

	return cfg, nil
}
