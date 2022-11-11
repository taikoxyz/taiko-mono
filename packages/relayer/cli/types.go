package cli

type Mode string

var (
	SyncMode   Mode = "sync"
	ResyncMode Mode = "resync"
	Modes           = []Mode{SyncMode, ResyncMode}
)

type Layer string

var (
	L1     Layer = "l1"
	L2     Layer = "l2"
	Both   Layer = "both"
	Layers       = []Layer{L1, L2, Both}
)
