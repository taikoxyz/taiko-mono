package generator

import (
	"context"

	"github.com/urfave/cli/v2"
)

type Generator struct {
}

func (g *Generator) InitFromCli(ctx context.Context, cli *cli.Context) error {
	return nil
}

func (g *Generator) Name() string {
	return "generator"
}

func (g *Generator) Start() error {
	return nil
}

func (g *Generator) Close(ctx context.Context) {

}
