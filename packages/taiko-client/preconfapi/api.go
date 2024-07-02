package preconfapi

import (
	"context"
	"errors"
	"fmt"
	"net/http"

	"github.com/ethereum/go-ethereum/log"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/preconfapi/builder"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/preconfapi/server"
	"github.com/urfave/cli/v2"
)

type PreconfAPI struct {
	*Config
	server *server.PreconfAPIServer
}

// InitFromCli New initializes the given proposer instance based on the command line flags.
func (p *PreconfAPI) InitFromCli(ctx context.Context, c *cli.Context) error {
	cfg, err := NewConfigFromCliContext(c)
	if err != nil {
		return err
	}

	return p.InitFromConfig(ctx, cfg)
}

func (p *PreconfAPI) InitFromConfig(ctx context.Context, cfg *Config) (err error) {
	var txBuilder builder.TxBuilder
	if cfg.BlobAllowed {
		txBuilder = builder.NewBlobTransactionBuilder(
			cfg.TaikoL1Address,
			cfg.ProposeBlockTxGasLimit,
		)
	} else {
		// TODO: calldata builder
	}

	// Prover server
	if p.server, err = server.New(&server.NewPreconfAPIServerOpts{
		TxBuilder: txBuilder,
	}); err != nil {
		return err
	}

	return nil
}

func (p *PreconfAPI) Start() error {
	go func() {
		if err := p.server.Start(fmt.Sprintf(":%v", p.HTTPPort)); !errors.Is(err, http.ErrServerClosed) {
			log.Crit("Failed to start http server", "error", err)
		}
	}()
	return nil
}

// Close closes the proposer instance.
func (p *PreconfAPI) Close(ctx context.Context) {
	if err := p.server.Shutdown(ctx); err != nil {
		log.Error("Failed to shut down prover server", "error", err)
	}
}

func (p *PreconfAPI) Name() string {
	return "preconfapi"
}
