package eventindexer

type Mode string

var (
	SyncMode   Mode = "sync"
	ResyncMode Mode = "resync"
	Modes           = []Mode{SyncMode, ResyncMode}
)

type WatchMode string

var (
	FilterWatchMode             WatchMode = "filter"
	SubscribeWatchMode          WatchMode = "subscribe"
	FilterAndSubscribeWatchMode WatchMode = "filter-and-subscribe"
	WatchModes                            = []WatchMode{FilterWatchMode, SubscribeWatchMode}
)

type HTTPOnly bool
