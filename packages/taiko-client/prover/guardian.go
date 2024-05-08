package prover

import (
	"context"
	"time"

	"github.com/ethereum/go-ethereum/log"
	"golang.org/x/sync/errgroup"
)

var (
	heartbeatInterval = 12 * time.Second
)

// guardianProverHeartbeatLoop keeps sending heartbeats to the guardian prover health check server
// on an interval.
func (p *Prover) guardianProverHeartbeatLoop(ctx context.Context) {
	p.wg.Add(1)
	defer p.wg.Done()

	ticker := time.NewTicker(heartbeatInterval)
	defer ticker.Stop()

	for {
		select {
		case <-p.ctx.Done():
			return
		case <-ticker.C:
			var (
				latestL1Block uint64
				latestL2Block uint64
				err           error
				g             = new(errgroup.Group)
			)

			g.Go(func() error {
				latestL1Block, err = p.rpc.L1.BlockNumber(ctx)
				return err
			})
			g.Go(func() error {
				latestL2Block, err = p.rpc.L2.BlockNumber(ctx)
				return err
			})
			if err := g.Wait(); err != nil {
				log.Error("Failed to get latest L1/L2 block number", "error", err)
				continue
			}

			if err := p.guardianProverHeartbeater.SendHeartbeat(
				ctx,
				latestL1Block,
				latestL2Block,
			); err != nil {
				log.Error("Failed to send guardian prover heartbeat", "error", err)
			}
		}
	}
}
