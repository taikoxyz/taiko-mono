package rpc

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestGetRPCMethodName(t *testing.T) {
	tests := []struct {
		clientType string
		methodName string
		expected   string
	}{
		// EthClient mappings
		{"eth", "BlockByHash", "eth_getBlockByHash"},
		{"l1", "BlockByNumber", "eth_getBlockByNumber"},
		{"l2", "HeaderByHash", "eth_getBlockByHash"},
		{"l2checkpoint", "HeaderByNumber", "eth_getBlockByNumber"},
		{"eth", "TransactionByHash", "eth_getTransactionByHash"},
		{"eth", "TransactionSender", "eth_getTransactionSender"},
		{"eth", "TransactionCount", "eth_getBlockTransactionCount"},
		{"eth", "TransactionInBlock", "eth_getTransactionByBlockHashAndIndex"},
		{"eth", "SyncProgress", "eth_syncing"},
		{"eth", "NetworkID", "net_version"},
		{"eth", "BalanceAt", "eth_getBalance"},
		{"eth", "StorageAt", "eth_getStorageAt"},
		{"eth", "CodeAt", "eth_getCode"},
		{"eth", "NonceAt", "eth_getTransactionCount"},
		{"eth", "PendingBalanceAt", "eth_getBalance"},
		{"eth", "PendingStorageAt", "eth_getStorageAt"},
		{"eth", "PendingCodeAt", "eth_getCode"},
		{"eth", "PendingNonceAt", "eth_getTransactionCount"},
		{"eth", "PendingTransactionCount", "eth_getTransactionCount"},
		{"eth", "CallContract", "eth_call"},
		{"eth", "CallContractAtHash", "eth_call"},
		{"eth", "PendingCallContract", "eth_call"},
		{"eth", "SuggestGasPrice", "eth_gasPrice"},
		{"eth", "SuggestGasTipCap", "eth_maxPriorityFeePerGas"},
		{"eth", "FeeHistory", "eth_feeHistory"},
		{"eth", "EstimateGas", "eth_estimateGas"},
		{"eth", "SendTransaction", "eth_sendTransaction"},
		{"eth", "FillTransaction", "eth_fillTransaction"},
		{"eth", "BlockNumber", "eth_blockNumber"},
		{"eth", "PeerCount", "net_peerCount"},
		{"eth", "BatchCallContext", "batch_call"},
		{"eth", "BatchBlocksByHashes", "batch_getBlockByHash"},
		{"eth", "BatchHeadersByNumbers", "batch_getBlockByNumber"},

		// EngineClient mappings
		{"engine", "ForkchoiceUpdate", "engine_forkchoiceUpdatedV2"},
		{"engine", "NewPayload", "engine_newPayloadV2"},
		{"engine", "GetPayload", "engine_getPayloadV2"},
		{"engine", "ExchangeTransitionConfiguration", "engine_exchangeTransitionConfigurationV1"},
		{"engine", "TxPoolContentWithMinTip", "taikoAuth_txPoolContentWithMinTip"},
		{"engine", "UpdateL1Origin", "taikoAuth_updateL1Origin"},
		{"engine", "SetL1OriginSignature", "taikoAuth_setL1OriginSignature"},
		{"engine", "SetHeadL1Origin", "taikoAuth_setHeadL1Origin"},

		// BeaconClient mappings
		{"beacon", "GetBlobs", "beacon_getBlobSidecars"},
		{"beacon", "Get", "beacon_get"},
		{"beacon", "timeToSlot", "beacon_timeToSlot"},
		{"beacon", "CurrentSlot", "beacon_currentSlot"},
		{"beacon", "CurrentEpoch", "beacon_currentEpoch"},
		{"beacon", "SlotInEpoch", "beacon_slotInEpoch"},
		{"beacon", "TimestampOfSlot", "beacon_timestampOfSlot"},

		// TaikoClient mappings
		{"taiko", "GetProtocolConfigs", "taiko_getProtocolConfigs"},
		{"taiko", "ensureGenesisMatched", "taiko_ensureGenesisMatched"},
		{"taiko", "filterGenesisBlockVerifiedV2", "taiko_filterGenesisBlockVerifiedV2"},
		{"taiko", "filterGenesisBlockVerified", "taiko_filterGenesisBlockVerified"},
		{"taiko", "WaitTillL2ExecutionEngineSynced", "taiko_waitTillL2ExecutionEngineSynced"},
		{"taiko", "LatestL2KnownL1Header", "taiko_latestL2KnownL1Header"},
		{"taiko", "GetGenesisL1Header", "taiko_getGenesisL1Header"},
		{"taiko", "GetBatchByID", "taiko_getBatchByID"},
		{"taiko", "L2ParentByCurrentBlockID", "taiko_l2ParentByCurrentBlockID"},
		{"taiko", "WaitL2Header", "taiko_waitL2Header"},
		{"taiko", "CalculateBaseFee", "taiko_calculateBaseFee"},
		{"taiko", "GetPoolContent", "taiko_getPoolContent"},
		{"taiko", "L2AccountNonce", "taiko_l2AccountNonce"},
		{"taiko", "L2ExecutionEngineSyncProgress", "taiko_l2ExecutionEngineSyncProgress"},
		{"taiko", "GetProtocolStateVariablesPacaya", "taiko_getProtocolStateVariablesPacaya"},
		{"taiko", "GetLastVerifiedTransitionPacaya", "taiko_getLastVerifiedTransitionPacaya"},
		{"taiko", "CheckL1Reorg", "taiko_checkL1Reorg"},
		{"taiko", "checkSyncedL1SnippetFromAnchor", "taiko_checkSyncedL1SnippetFromAnchor"},
		{"taiko", "calculateBaseFeePacaya", "taiko_calculateBaseFeePacaya"},
		{"taiko", "getGenesisHeight", "taiko_getGenesisHeight"},
		{"taiko", "GetProofVerifierPacaya", "taiko_getProofVerifierPacaya"},
		{"taiko", "GetPreconfWhiteListOperator", "taiko_getPreconfWhiteListOperator"},
		{"taiko", "GetNextPreconfWhiteListOperator", "taiko_getNextPreconfWhiteListOperator"},
		{"taiko", "GetAllPreconfOperators", "taiko_getAllPreconfOperators"},
		{"taiko", "GetForcedInclusionPacaya", "taiko_getForcedInclusionPacaya"},
		{"taiko", "GetPreconfRouterConfig", "taiko_getPreconfRouterConfig"},
		{"taiko", "GetOPVerifierPacaya", "taiko_getOPVerifierPacaya"},
		{"taiko", "GetSGXVerifierPacaya", "taiko_getSGXVerifierPacaya"},
		{"taiko", "GetRISC0VerifierPacaya", "taiko_getRISC0VerifierPacaya"},
		{"taiko", "GetSP1VerifierPacaya", "taiko_getSP1VerifierPacaya"},
		{"taiko", "GetSgxGethVerifierPacaya", "taiko_getSgxGethVerifierPacaya"},
		{"taiko", "GetPreconfRouterPacaya", "taiko_getPreconfRouterPacaya"},

		// Fallback cases
		{"unknown", "UnknownMethod", "UnknownMethod"},
		{"eth", "UnmappedMethod", "UnmappedMethod"},
		{"engine", "UnmappedEngineMethod", "UnmappedEngineMethod"},
		{"beacon", "UnmappedBeaconMethod", "UnmappedBeaconMethod"},
		{"", "EmptyClientType", "EmptyClientType"},

		// Case sensitivity
		{"ETH", "BlockByHash", "BlockByHash"}, // uppercase client type should fallback
		{"eth", "blockbyhash", "blockbyhash"}, // lowercase method name should fallback
	}

	for _, tt := range tests {
		t.Run(tt.clientType+"_"+tt.methodName, func(t *testing.T) {
			result := GetRPCMethodName(tt.clientType, tt.methodName)
			assert.Equal(t, tt.expected, result, "clientType=%s, methodName=%s", tt.clientType, tt.methodName)
		})
	}
}

func TestGetRPCMethodName_AllClientTypes(t *testing.T) {
	// Test that all supported client types work for the same method
	testCases := []struct {
		clientType string
		expected   string
	}{
		{"eth", "eth_getBlockByHash"},
		{"l1", "eth_getBlockByHash"},
		{"l2", "eth_getBlockByHash"},
		{"l2checkpoint", "eth_getBlockByHash"},
	}

	for _, tc := range testCases {
		result := GetRPCMethodName(tc.clientType, "BlockByHash")
		assert.Equal(t, tc.expected, result, "clientType=%s should map BlockByHash correctly", tc.clientType)
	}
}

func TestGetRPCMethodName_ExhaustiveMappings(t *testing.T) {
	// Test that all mappings in the maps are accessible
	for methodName, expectedRPC := range ethMethodMappings {
		result := GetRPCMethodName("eth", methodName)
		assert.Equal(t, expectedRPC, result, "eth method %s should map to %s", methodName, expectedRPC)
	}

	for methodName, expectedRPC := range engineMethodMappings {
		result := GetRPCMethodName("engine", methodName)
		assert.Equal(t, expectedRPC, result, "engine method %s should map to %s", methodName, expectedRPC)
	}

	for methodName, expectedRPC := range beaconMethodMappings {
		result := GetRPCMethodName("beacon", methodName)
		assert.Equal(t, expectedRPC, result, "beacon method %s should map to %s", methodName, expectedRPC)
	}

	for methodName, expectedRPC := range taikoMethodMappings {
		result := GetRPCMethodName("taiko", methodName)
		assert.Equal(t, expectedRPC, result, "taiko method %s should map to %s", methodName, expectedRPC)
	}
}