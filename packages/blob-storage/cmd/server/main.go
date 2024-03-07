package main

import (
	"log"

	"github.com/taikoxyz/taiko-mono/packages/blob-storage/internal/logic"
)

func main() {
	cfg, err := logic.GetConfig()
	if err != nil {
		log.Fatal("Error loading config:", err)
	}

	srv := logic.NewServer(cfg)
	if err := srv.Start(); err != nil {
		log.Fatal("Error starting server:", err)
	}
}
