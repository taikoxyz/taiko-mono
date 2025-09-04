package rpc

// This file contains method instrumentation helpers for various RPC clients

// Common RPC method mappings for different clients
var (
	// EthClient method mappings: Go method name -> RPC method name
	ethMethodMappings = map[string]string{
		"BlockByHash":             "eth_getBlockByHash",
		"BlockByNumber":           "eth_getBlockByNumber",
		"HeaderByHash":            "eth_getBlockByHash",
		"HeaderByNumber":          "eth_getBlockByNumber",
		"TransactionByHash":       "eth_getTransactionByHash",
		"TransactionSender":       "eth_getTransactionSender",
		"TransactionCount":        "eth_getBlockTransactionCount",
		"TransactionInBlock":      "eth_getTransactionByBlockHashAndIndex",
		"SyncProgress":            "eth_syncing",
		"NetworkID":               "net_version",
		"BalanceAt":               "eth_getBalance",
		"StorageAt":               "eth_getStorageAt",
		"CodeAt":                  "eth_getCode",
		"NonceAt":                 "eth_getTransactionCount",
		"PendingBalanceAt":        "eth_getBalance",
		"PendingStorageAt":        "eth_getStorageAt",
		"PendingCodeAt":           "eth_getCode",
		"PendingNonceAt":          "eth_getTransactionCount",
		"PendingTransactionCount": "eth_getTransactionCount",
		"CallContract":            "eth_call",
		"CallContractAtHash":      "eth_call",
		"PendingCallContract":     "eth_call",
		"SuggestGasPrice":         "eth_gasPrice",
		"SuggestGasTipCap":        "eth_maxPriorityFeePerGas",
		"FeeHistory":              "eth_feeHistory",
		"EstimateGas":             "eth_estimateGas",
		"SendTransaction":         "eth_sendTransaction",
		"FillTransaction":         "eth_fillTransaction",
		"BlockNumber":             "eth_blockNumber",
		"PeerCount":               "net_peerCount",
		"BatchCallContext":        "batch_call",
		"BatchBlocksByHashes":     "batch_getBlockByHash",
		"BatchHeadersByNumbers":   "batch_getBlockByNumber",
	}

	// EngineClient method mappings
	engineMethodMappings = map[string]string{
		"ForkchoiceUpdate":                "engine_forkchoiceUpdatedV2",
		"NewPayload":                      "engine_newPayloadV2",
		"GetPayload":                      "engine_getPayloadV2",
		"ExchangeTransitionConfiguration": "engine_exchangeTransitionConfigurationV1",
		"TxPoolContentWithMinTip":         "taikoAuth_txPoolContentWithMinTip",
		"UpdateL1Origin":                  "taikoAuth_updateL1Origin",
		"SetL1OriginSignature":            "taikoAuth_setL1OriginSignature",
		"SetHeadL1Origin":                 "taikoAuth_setHeadL1Origin",
	}

	// BeaconClient method mappings
	beaconMethodMappings = map[string]string{
		"GetBlobs":        "beacon_getBlobSidecars",
		"Get":             "beacon_get",
		"timeToSlot":      "beacon_timeToSlot",
		"CurrentSlot":     "beacon_currentSlot",
		"CurrentEpoch":    "beacon_currentEpoch",
		"SlotInEpoch":     "beacon_slotInEpoch",
		"TimestampOfSlot": "beacon_timestampOfSlot",
	}

	// TaikoClient method mappings (for methods.go)
	taikoMethodMappings = map[string]string{
		"GetProtocolConfigs":                 "taiko_getProtocolConfigs",
		"ensureGenesisMatched":               "taiko_ensureGenesisMatched",
		"filterGenesisBlockVerifiedV2":       "taiko_filterGenesisBlockVerifiedV2",
		"filterGenesisBlockVerified":         "taiko_filterGenesisBlockVerified",
		"WaitTillL2ExecutionEngineSynced":    "taiko_waitTillL2ExecutionEngineSynced",
		"LatestL2KnownL1Header":              "taiko_latestL2KnownL1Header",
		"GetGenesisL1Header":                 "taiko_getGenesisL1Header",
		"GetBatchByID":                       "taiko_getBatchByID",
		"L2ParentByCurrentBlockID":           "taiko_l2ParentByCurrentBlockID",
		"WaitL2Header":                       "taiko_waitL2Header",
		"CalculateBaseFee":                   "taiko_calculateBaseFee",
		"GetPoolContent":                     "taiko_getPoolContent",
		"L2AccountNonce":                     "taiko_l2AccountNonce",
		"L2ExecutionEngineSyncProgress":      "taiko_l2ExecutionEngineSyncProgress",
		"GetProtocolStateVariablesPacaya":    "taiko_getProtocolStateVariablesPacaya",
		"GetLastVerifiedTransitionPacaya":    "taiko_getLastVerifiedTransitionPacaya",
		"CheckL1Reorg":                       "taiko_checkL1Reorg",
		"checkSyncedL1SnippetFromAnchor":     "taiko_checkSyncedL1SnippetFromAnchor",
		"calculateBaseFeePacaya":             "taiko_calculateBaseFeePacaya",
		"getGenesisHeight":                   "taiko_getGenesisHeight",
		"GetProofVerifierPacaya":             "taiko_getProofVerifierPacaya",
		"GetPreconfWhiteListOperator":        "taiko_getPreconfWhiteListOperator",
		"GetNextPreconfWhiteListOperator":    "taiko_getNextPreconfWhiteListOperator",
		"GetAllPreconfOperators":             "taiko_getAllPreconfOperators",
		"GetForcedInclusionPacaya":           "taiko_getForcedInclusionPacaya",
		"GetPreconfRouterConfig":             "taiko_getPreconfRouterConfig",
		"GetOPVerifierPacaya":                "taiko_getOPVerifierPacaya",
		"GetSGXVerifierPacaya":               "taiko_getSGXVerifierPacaya",
		"GetRISC0VerifierPacaya":             "taiko_getRISC0VerifierPacaya",
		"GetSP1VerifierPacaya":               "taiko_getSP1VerifierPacaya",
		"GetSgxGethVerifierPacaya":           "taiko_getSgxGethVerifierPacaya",
		"GetPreconfRouterPacaya":             "taiko_getPreconfRouterPacaya",
		"getImmutableAddressPacaya":          "taiko_getImmutableAddress",
	}
)

// GetRPCMethodName returns the RPC method name for a given Go method name and client type
func GetRPCMethodName(clientType, methodName string) string {
	switch clientType {
	case "eth", "l1", "l2", "l2checkpoint":
		if rpcMethod, exists := ethMethodMappings[methodName]; exists {
			return rpcMethod
		}
	case "engine":
		if rpcMethod, exists := engineMethodMappings[methodName]; exists {
			return rpcMethod
		}
	case "beacon":
		if rpcMethod, exists := beaconMethodMappings[methodName]; exists {
			return rpcMethod
		}
	case "taiko":
		if rpcMethod, exists := taikoMethodMappings[methodName]; exists {
			return rpcMethod
		}
	}
	// Fallback to method name if not found in mappings
	return methodName
}
