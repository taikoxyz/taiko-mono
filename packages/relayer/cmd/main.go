package main

import (
	"flag"
	"log"

	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/cli"
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

	watchModePtr := flag.String("watch-mode", string(relayer.FilterAndSubscribeWatchMode), `watch mode to run in. 
	options:
	  filter: only filter previous messages
	  subscribe: only subscribe to new messages
	  filter-and-subscribe: catch up on all previous messages, then subscribe to new messages
	`)

	httpOnlyPtr := flag.Bool("http-only", false, `only run an http server and don't index blocks. 
	options:
	  true: only run an http server, dont index blocks
	  false: run an http server and index blocks
	`)

	profitableOnlyPtr := flag.Bool("profitable-only", false, `only process profitable transactions. 
	options:
	  true:
	  false:
	`)

	flag.Parse()

	if !relayer.IsInSlice(relayer.Mode(*modePtr), relayer.Modes) {
		log.Fatal("mode not valid")
	}

	if !relayer.IsInSlice(relayer.Layer(*layersPtr), relayer.Layers) {
		log.Fatal("mode not valid")
	}

	cli.Run(
		relayer.Mode(*modePtr),
		relayer.WatchMode(*watchModePtr),
		relayer.Layer(*layersPtr),
		relayer.HTTPOnly(*httpOnlyPtr),
		relayer.ProfitableOnly(*profitableOnlyPtr),
	)
}
