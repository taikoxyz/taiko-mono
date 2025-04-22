package preconfblocks

import (
	"sort"
	"time"

	"github.com/ethereum/go-ethereum/common"
)

// SlotRange represents a half‑open [Start,End) range of L1 slots.
type SlotRange struct {
	Start uint64
	End   uint64
}

// mergeRanges coalesces overlapping or adjacent SlotRanges.
func mergeRanges(r []SlotRange) []SlotRange {
	if len(r) == 0 {
		return r
	}

	sort.Slice(r, func(i, j int) bool {
		return r[i].Start < r[j].Start
	})

	out := []SlotRange{r[0]}

	for _, rng := range r[1:] {
		last := &out[len(out)-1]

		if rng.Start <= last.End {
			if rng.End > last.End {
				last.End = rng.End
			}
		} else {
			out = append(out, rng)
		}
	}
	return out
}

// opWindow holds the last three epochs’ operator addresses.
type opWindow struct {
	epochs  [3]uint64
	currOps [3]common.Address
	nextOps [3]common.Address
	valid   [3]bool
}

func NewOpWindow() *opWindow {
	return &opWindow{}
}

// Push records the operator pair for one epoch into the ring.
func (w *opWindow) Push(epoch uint64, curr, next common.Address) {
	idx := int(epoch % 3)

	w.epochs[idx] = epoch

	w.currOps[idx] = curr

	w.nextOps[idx] = next

	w.valid[idx] = true
}

// SequencingWindowSplit creates a slot range for either the current or the next operator
func (w *opWindow) SequencingWindowSplit(
	operator common.Address,
	curr bool,
	handoverSlots,
	slotsPerEpoch uint64,
) []SlotRange {
	var ranges []SlotRange
	threshold := slotsPerEpoch - handoverSlots

	for i := 0; i < 3; i++ {
		if !w.valid[i] {
			continue
		}

		epoch := w.epochs[i]
		startEpoch := epoch * slotsPerEpoch

		if curr {
			if w.currOps[i] == operator {
				ranges = append(ranges, SlotRange{
					Start: startEpoch,
					End:   startEpoch + threshold,
				})
			}
		} else {
			if w.nextOps[i] == operator {
				ranges = append(ranges, SlotRange{
					Start: startEpoch + threshold,
					End:   (epoch + 1) * slotsPerEpoch,
				})
			}
		}
	}

	return mergeRanges(ranges)
}

// Lookahead holds the up‑to‑date sequencing window and operator addrs.
type Lookahead struct {
	CurrOperator common.Address
	NextOperator common.Address
	CurrRanges   []SlotRange // slots allowed for CurrOperator (0..threshold-1)
	NextRanges   []SlotRange // slots allowed for NextOperator (threshold..slotsPerEpoch-1)
	UpdatedAt    time.Time
}
