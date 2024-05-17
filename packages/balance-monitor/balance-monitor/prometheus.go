package balanceMonitor

import (
	"github.com/prometheus/client_golang/prometheus"
)

var (
	l1EthBalanceGauge = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "l1_eth_balance",
			Help: "ETH balance of addresses on L1",
		},
		[]string{"address"},
	)
	l1Erc20BalanceGauge = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "l1_erc20_balance",
			Help: "ERC-20 token balance of addresses on L1",
		},
		[]string{"token_address", "address"},
	)
	l2EthBalanceGauge = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "l2_eth_balance",
			Help: "ETH balance of addresses on L2",
		},
		[]string{"address"},
	)
	l2Erc20BalanceGauge = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "l2_erc20_balance",
			Help: "ERC-20 token balance of addresses on L2",
		},
		[]string{"token_address", "address"},
	)
)

func init() {
	prometheus.MustRegister(l1EthBalanceGauge)
	prometheus.MustRegister(l2EthBalanceGauge)
	prometheus.MustRegister(l1Erc20BalanceGauge)
	prometheus.MustRegister(l2Erc20BalanceGauge)
}
