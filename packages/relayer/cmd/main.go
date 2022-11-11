package main

import (
	"flag"
	"log"

	"github.com/taikochain/taiko-mono/packages/relayer"
	"github.com/taikochain/taiko-mono/packages/relayer/cli"
)

func main() {
	modePtr := flag.String("mode", string(cli.SyncMode), `mode to run in. 
	options:
	  sync: continue syncing from previous block
	  resync: restart syncing from block 0
	  fromBlock: restart syncing from specified block number
	`)

	layersPtr := flag.String("layers", string(cli.Both), `layers to watch and process. 
	options:
	  l1: only watch l1 => l2 bridge messages
	  l2: only watch l2 => l1 bridge messages
	  both: watch l1 => l2 and l2 => l1 bridge messages
	`)

	flag.Parse()

	if !relayer.IsInSlice(cli.Mode(*modePtr), cli.Modes) {
		log.Fatal("mode not valid")
	}

	if !relayer.IsInSlice(cli.Layer(*layersPtr), cli.Layers) {
		log.Fatal("mode not valid")
	}

	cli.Run(cli.Mode(*modePtr), cli.Layer(*layersPtr))
}
