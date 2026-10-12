package indexer

import (
	"context"
	"github.com/stretchr/testify/require"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/cmd/flags"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/db"
	"github.com/urfave/cli/v2"
	"testing"
)

func TestNFTOnlyStartupValidation(t *testing.T) {
	for _, tt := range []struct {
		name string
		cfg  Config
		want error
	}{
		{"NFT disabled", Config{SyncMode: Sync, BlockBatchSize: 10}, eventindexer.ErrNFTIndexingDisabled},
		{"zero batch", Config{SyncMode: Sync, IndexNFTs: true}, eventindexer.ErrInvalidBlockBatchSize},
		{"invalid mode", Config{SyncMode: "invalid", IndexNFTs: true, BlockBatchSize: 10}, eventindexer.ErrInvalidMode},
	} {
		t.Run(tt.name, func(t *testing.T) {
			opened := false
			tt.cfg.OpenDBFunc = func() (db.DB, error) { opened = true; return nil, nil }
			require.ErrorIs(t, InitFromConfig(context.Background(), new(Indexer), &tt.cfg), tt.want)
			require.False(t, opened)
		})
	}

	for _, mode := range []SyncMode{Sync, Resync} {
		require.NoError(t, (&Config{SyncMode: mode, IndexNFTs: true, BlockBatchSize: 10}).validate())
	}
}

func TestNFTOnlyCLIConfig(t *testing.T) {
	app := cli.NewApp()
	app.Flags = flags.IndexerFlags
	app.Action = func(ctx *cli.Context) error {
		cfg, err := NewConfigFromCliContext(ctx)
		require.NoError(t, err)
		require.NoError(t, cfg.validate())
		require.Equal(t, "http://localhost:8545", cfg.RPCUrl)
		require.EqualValues(t, 23, cfg.BlockBatchSize)
		require.Equal(t, Resync, cfg.SyncMode)
		require.True(t, cfg.IndexNFTs)
		require.NotNil(t, cfg.OpenDBFunc)

		return nil
	}
	require.NoError(t, app.Run([]string{
		"indexer", "--db.username", "user", "--db.password", "pass",
		"--db.host", "host", "--db.name", "nft", "--rpcUrl", "http://localhost:8545",
		"--indexNfts", "--blockBatchSize", "23", "--syncMode", "resync",
	}))

	for _, retired := range []string{"layer", "indexERC20s", "shastaInboxAddress", "bridgeAddress", "subscriptionBackoff", "ethClientTimeout"} {
		for _, f := range flags.IndexerFlags {
			require.NotContains(t, f.Names(), retired)
		}
	}
}
