package metrics

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestRisc0BacklogMetricNames(t *testing.T) {
	metricFamilies, err := registry.Gather()
	require.NoError(t, err)

	names := make(map[string]struct{}, len(metricFamilies))
	for _, family := range metricFamilies {
		names[family.GetName()] = struct{}{}
	}

	require.Contains(t, names, "prover_risc0_backlog_sp1_mode")
	require.Contains(t, names, "prover_risc0_backlog_clear")
	require.NotContains(t, names, "prover_zk_backlog_sgx_mode")
	require.NotContains(t, names, "prover_zk_backlog_clear")
}
