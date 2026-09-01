// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title Slot Chain consensus constants
/// @custom:security-contact security@taiko.xyz
library LibSlotChainConstants {
    uint8 internal constant NORMAL_TIER = 1;
    uint8 internal constant SIGNED_RECOVERY_TIER = 2;
    uint8 internal constant UNSIGNED_ESCAPE_TIER = 3;

    uint8 internal constant NORMAL_REWARD_CLASS = 1;
    uint8 internal constant SIGNED_RECOVERY_REWARD_CLASS = 2;
    uint8 internal constant UNSIGNED_ESCAPE_REWARD_CLASS = 3;

    uint8 internal constant KIND_USER_TRANSACTION = 0;
    uint8 internal constant KIND_BRIDGE_CREDIT = 1;
    uint8 internal constant REFUND_MODE_DIRECT = 1;

    uint256 internal constant REGISTRY_TREE_DEPTH = 6;
    uint256 internal constant ADMISSION_TREE_DEPTH = 11;
    uint256 internal constant TRANCHE_TREE_DEPTH = 9;
    uint256 internal constant FORCED_TREE_DEPTH = 64;
    uint256 internal constant TERMINAL_TREE_DEPTH = 64;
    uint256 internal constant DATA_MMR_DEPTH = 12;

    uint256 internal constant REGISTRY_CELL_COUNT = 64;
    uint256 internal constant ADMISSION_USED_LEAF_COUNT = 1136;
    uint256 internal constant TRANCHE_LEAF_COUNT = 512;

    uint256 internal constant KIND0_FORCED_DESCRIPTOR_LENGTH = 220;
    uint256 internal constant KIND1_FORCED_DESCRIPTOR_LENGTH = 541;

    uint256 internal constant MAX_CANDIDATE_BLOCKS = 4096;
    uint256 internal constant MAX_SCHEDULE_WINDOWS = 12;
    uint256 internal constant MAX_SESSION_REFS = 16;
    uint256 internal constant MAX_DATA_RECORDS = 2100;
    uint256 internal constant MAX_MANIFEST_ENTRIES = MAX_DATA_RECORDS;
    uint256 internal constant MAX_CONSUMED_FORCED_ROWS = 256;
    uint256 internal constant MAX_FORCED_DESCRIPTOR_ROWS = MAX_CONSUMED_FORCED_ROWS + 1;
    uint256 internal constant MAX_DISPOSITION_ROWS = 64;
    uint256 internal constant MAX_INBOX_ROWS = 64;

    bytes4 internal constant COMPONENT_CONFIG_SELECTOR = 0xf6c0f7d2;
    uint256 internal constant COMPONENT_CONFIG_CALLDATA_LENGTH = 4;
    uint256 internal constant COMPONENT_CONFIG_RETURN_LENGTH = 32;
    uint256 internal constant COMPONENT_CONFIG_GETTER_GAS = 50_000;

    bytes4 internal constant VERIFY_INBOX_CREDIT_SELECTOR = 0x720f747b;
    bytes4 internal constant VERIFY_INBOX_CREDIT_MAGIC = 0x49435632;
    uint256 internal constant VERIFY_INBOX_CREDIT_CALLDATA_LENGTH = 36;
    uint256 internal constant VERIFY_INBOX_CREDIT_RETURN_LENGTH = 256;
    uint256 internal constant VERIFY_INBOX_CREDIT_GAS = 100_000;

    bytes32 internal constant SLOT_CHAIN_BLOCK_TYPEHASH =
        0xee6a8c8e31e8245cd527869508f6e464d6084893991203876f734d1855aed87c;
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    bytes32 internal constant SLOT_CHAIN_NAME_HASH = keccak256("SlotChain");
    bytes32 internal constant SLOT_CHAIN_VERSION_HASH = keccak256("2");
    bytes32 internal constant SOURCE_CONTEXT_TYPEHASH = keccak256(
        "SourceContextV2(uint64 protocolVersion,uint8 kind,bytes32 creditId,bytes32 msgHash,"
        "bytes32 sourceDomainId,uint64 sourceRegistrationEpoch,address sourceBridge,"
        "bytes32 sourceBridgeExecutionHash,uint64 emittedAtBlock,uint64 queueIndex)"
    );
    bytes32 internal constant DESTINATION_CONTEXT_TYPEHASH = keccak256(
        "DestinationContextV2(uint256 destinationChainId,bytes32 destinationDomainId,"
        "address destinationBridge,bytes32 releaseManifestHash,bytes32 executionProfileHash)"
    );

    string internal constant REGISTRY_LEAF_DOMAIN = "slot-chain-registry-leaf-v1";
    string internal constant REGISTRY_NODE_DOMAIN = "slot-chain-registry-node-v1";
    string internal constant ADMISSION_LEAF_DOMAIN = "slot-chain-admission-leaf-v1";
    string internal constant ADMISSION_NODE_DOMAIN = "slot-chain-admission-node-v1";
    string internal constant ENTRY_LEAF_DOMAIN = "slot-chain-entry-leaf-v1";
    string internal constant ENTRY_NODE_DOMAIN = "slot-chain-entry-node-v1";
    string internal constant TRANCHE_LEAF_DOMAIN = "slot-chain-tranche-leaf-v1";
    string internal constant TRANCHE_NODE_DOMAIN = "slot-chain-tranche-node-v1";
    string internal constant FORCE_USER_DOMAIN = "slot-chain-force-user-v2";
    string internal constant FORCE_BRIDGE_DOMAIN = "slot-chain-force-bridge-v11";
    string internal constant FORCE_DESCRIPTOR_LIST_DOMAIN = "slot-chain-force-descriptor-list-v2";
    string internal constant FORCE_EMPTY_DOMAIN = "slot-chain-force-empty-v2";
    string internal constant FORCE_NODE_DOMAIN = "slot-chain-force-node-v2";
    string internal constant FORCE_ROOT_DOMAIN = "slot-chain-force-root-v2";
    string internal constant DATA_LEAF_DOMAIN = "slot-chain-data-leaf-v1";
    string internal constant DATA_NODE_DOMAIN = "slot-chain-data-node-v1";
    string internal constant DATA_BAG_DOMAIN = "slot-chain-data-bag-v1";
    string internal constant MANIFEST_EMPTY_DOMAIN = "slot-chain-manifest-empty-v1";
    string internal constant MANIFEST_LEAF_DOMAIN = "slot-chain-manifest-leaf-v1";
    string internal constant MANIFEST_NODE_DOMAIN = "slot-chain-manifest-node-v1";
    string internal constant MANIFEST_ROOT_DOMAIN = "slot-chain-manifest-root-v1";
    string internal constant DISPOSITIONS_DOMAIN = "slot-chain-dispositions-v1";
    string internal constant BRIDGE_RESULT_DOMAIN = "slot-chain-bridge-credit-result-v11";
    string internal constant BRIDGE_CREDIT_ID_DOMAIN = "slot-chain-bridge-credit-id-v6";
    string internal constant BRIDGE_ESCROW_DOMAIN = "slot-chain-bridge-escrow-v2";
    string internal constant INBOX_CREDIT_SLOT_DOMAIN = "slot-chain-inbox-credit-slot-v5";
    string internal constant SOURCE_DOMAIN_DOMAIN = "slot-chain-source-domain-v4";
    string internal constant DESTINATION_DOMAIN_DOMAIN = "slot-chain-destination-domain-v7";
    string internal constant TERMINAL_EMPTY_DOMAIN = "slot-chain-terminal-empty-v2";
    string internal constant TERMINAL_LEAF_DOMAIN = "slot-chain-terminal-leaf-v2";
    string internal constant TERMINAL_NODE_DOMAIN = "slot-chain-terminal-node-v2";
    string internal constant TERMINAL_ROOT_DOMAIN = "slot-chain-terminal-root-v2";
    string internal constant LIQUIDITY_SETTLEMENT_DOMAIN = "slot-chain-liquidity-settlement-v1";
    string internal constant BODY_DOMAIN = "slot-chain-body-v1";
    string internal constant BODY_CHUNK_DOMAIN = "slot-chain-body-chunk-v1";
    string internal constant SESSION_DOMAIN = "slot-chain-session-v1";
    string internal constant CORE_DOMAIN = "slot-chain-core-v3";
    string internal constant CANONICAL_DOMAIN = "slot-chain-canonical-v2";
    string internal constant CANDIDATE_DOMAIN = "slot-chain-candidate-v2";
    string internal constant WINNING_DATA_DOMAIN = "slot-chain-winning-data-v1";
    string internal constant SCHEDULE_LIST_DOMAIN = "slot-chain-schedule-list-v1";
    string internal constant SESSION_LIST_DOMAIN = "slot-chain-session-list-v1";
    string internal constant OUTPUTS_DOMAIN = "slot-chain-outputs-v2";
    string internal constant STATEMENT_DOMAIN = "slot-chain-statement-v2";
    string internal constant REWARD_RECEIPT_DOMAIN = "slot-chain-reward-receipt-v1";
    string internal constant NORMAL_CONTEXT_DOMAIN = "slot-chain-normal-context-v1";
    string internal constant MIGRATION_DATA_DOMAIN = "slot-chain-migration-data-v2";
    string internal constant RECOVERY_DOMAIN = "slot-chain-recovery-v2";
}
