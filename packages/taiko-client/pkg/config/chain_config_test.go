package config

import (
	"bytes"
	"math/big"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/log"
	"github.com/stretchr/testify/require"
)

func TestChainConfigDescriptionIsShastaOnly(t *testing.T) {
	forkTime := uint64(123456)
	cfg := NewChainConfig(big.NewInt(167001), 0, 42, forkTime)

	desc := cfg.Description()
	require.Contains(t, desc, "Shasta")
}

func TestReportProtocolConfigsOmitsLegacyForkHeight(t *testing.T) {
	var buf bytes.Buffer
	oldRoot := log.Root()
	log.SetDefault(log.NewLogger(log.NewTerminalHandler(&buf, false)))
	t.Cleanup(func() {
		log.SetDefault(oldRoot)
	})

	ReportProtocolConfigs(testProtocolConfigs{})

	output := buf.String()
	require.Contains(t, output, "ProvingWindow")
	require.NotContains(t, output, "ForkHeights")
}

type testProtocolConfigs struct{}

func (testProtocolConfigs) LivenessBond() *big.Int {
	return big.NewInt(5)
}

func (testProtocolConfigs) LivenessBondPerBlock() *big.Int {
	return common.Big0
}

func (testProtocolConfigs) MaxProposals() uint64 {
	return 6
}

func (testProtocolConfigs) ProvingWindow() (time.Duration, error) {
	return 8 * time.Second, nil
}

func (testProtocolConfigs) MaxBlocksPerBatch() int {
	return 8
}

func (testProtocolConfigs) MaxAnchorHeightOffset() uint64 {
	return 0
}
