package preconf

import (
	"testing"

	gethcore "github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/params"
	"github.com/stretchr/testify/require"
)

func TestCheckNotEtna(t *testing.T) {
	originalUnzen, originalEtna := gethcore.DevnetUnzenTime, gethcore.DevnetEtnaTime
	t.Cleanup(func() { gethcore.DevnetUnzenTime, gethcore.DevnetEtnaTime = originalUnzen, originalEtna })
	gethcore.DevnetUnzenTime, gethcore.DevnetEtnaTime = 0, 100

	require.NoError(t, CheckNotEtna(params.TaikoInternalNetworkID, 99))
	require.ErrorIs(t, CheckNotEtna(params.TaikoInternalNetworkID, 100), ErrNotSupportedAfterEtna)
	require.NoError(t, CheckNotEtna(params.TaikoMainnetNetworkID, 100))
}
