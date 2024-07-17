package preconfapi

import (
	"context"
	"errors"
	"fmt"
	"net/http"

	"github.com/ethereum/go-ethereum/log"
	"github.com/urfave/cli/v2"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/preconfapi/builder"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/preconfapi/server"
)

type PreconfAPI struct {
	cfg    *Config
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

func (p *PreconfAPI) InitFromConfig(_ context.Context, cfg *Config) (err error) {
	txBuilders := make(map[string]builder.TxBuilder)
	txBuilders["blob"] = builder.NewBlobTransactionBuilder(
		cfg.TaikoL1Address,
		cfg.ProposeBlockTxGasLimit,
	)

	txBuilders["calldata"] = builder.NewCalldataTransactionBuilder(
		cfg.TaikoL1Address,
		cfg.ProposeBlockTxGasLimit,
	)

	if p.server, err = server.New(&server.NewPreconfAPIServerOpts{
		TxBuilders: txBuilders,
	}); err != nil {
		return err
	}

	p.cfg = cfg

	return nil
}

func (p *PreconfAPI) Start() error {
	go func() {
		if err := p.server.Start(fmt.Sprintf(":%v", p.cfg.HTTPPort)); !errors.Is(err, http.ErrServerClosed) {
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
