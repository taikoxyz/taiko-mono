package main

import (
	"flag"
	"log"

	"github.com/taikochain/taiko-mono/packages/relayer"
	"github.com/taikochain/taiko-mono/packages/relayer/cli"
)

func main() {
	modePtr := flag.String("mode", string(relayer.SyncMode), `mode to run in. 
	options:
	  sync: continue syncing from previous block
	  resync: restart syncing from block 0
	  fromBlock: restart syncing from specified block number
	`)

	layersPtr := flag.String("layers", string(relayer.Both), `layers to watch and process. 
	options:
	  l1: only watch l1 => l2 bridge messages
	  l2: only watch l2 => l1 bridge messages
	  both: watch l1 => l2 and l2 => l1 bridge messages
	`)

	flag.Parse()

	if !relayer.IsInSlice(relayer.Mode(*modePtr), relayer.Modes) {
		log.Fatal("mode not valid")
	}

	if !relayer.IsInSlice(relayer.Layer(*layersPtr), relayer.Layers) {
		log.Fatal("mode not valid")
	}

	cli.Run(relayer.Mode(*modePtr), relayer.Layer(*layersPtr))
}
