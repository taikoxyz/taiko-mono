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

    /// @dev The only forced-message kind. Wire value 1 is unassigned and reserved.
    uint8 internal constant KIND_USER_TRANSACTION = 0;

    uint256 internal constant REGISTRY_TREE_DEPTH = 6;
    uint256 internal constant ADMISSION_TREE_DEPTH = 11;
    uint256 internal constant RANKED_ENTRY_TREE_DEPTH = 6;
    uint256 internal constant TRANCHE_TREE_DEPTH = 9;
    uint256 internal constant FORCED_TREE_DEPTH = 64;
    uint256 internal constant DATA_MMR_DEPTH = 12;
    uint256 internal constant MANIFEST_TREE_DEPTH = 12;

    uint256 internal constant REGISTRY_CELL_COUNT = 64;
    uint256 internal constant ADMISSION_LEAF_COUNT = 2048;
    uint256 internal constant ADMISSION_USED_LEAF_COUNT = 1136;
    uint256 internal constant RANKED_ENTRY_LEAF_COUNT = 64;
    uint256 internal constant TRANCHE_LEAF_COUNT = 512;

    bytes32 internal constant EMPTY_REGISTRY_ROOT =
        0x2f40c290594200091bcd31881e40bf56ba1960016a24c9931cf3b1a9a8705ae8;
    bytes32 internal constant EMPTY_ADMISSION_ROOT =
        0x71a511ce5247c6c3b0411e182c8e4b4dcbd0adc97163c585cac94ca3b031ac54;
    bytes32 internal constant EMPTY_RANKED_ENTRY_ROOT =
        0x986d3e795bd9ddfabe213b93cea0211eea5a663e895bfc112d90c5bf2fff1564;
    bytes32 internal constant EMPTY_TRANCHE_ROOT =
        0xdee49bfb4494eee086cf6485f471866cd49591358b3490d4a156813702501768;

    uint256 internal constant KIND0_FORCED_DESCRIPTOR_LENGTH = 220;
    uint256 internal constant KIND0_FORCED_ADMISSION_LENGTH = 204;
    uint256 internal constant FORCED_QUEUE_CONFIG_PREIMAGE_LENGTH = 113;
    uint64 internal constant FORCED_QUEUE_CAPACITY = type(uint64).max;
    /// @dev Canonical wrapped empty depth-64 forced root: `hashForcedRoot(0, emptyTreeRoot)`.
    bytes32 internal constant EMPTY_FORCED_ROOT =
        0x4001bca0d3c5171a99a50118f1219024e1bef9302262ea3b075ecbed36be7592;

    uint256 internal constant MAX_CANDIDATE_BLOCKS = 4096;
    uint256 internal constant MAX_SCHEDULE_WINDOWS = 12;
    uint256 internal constant MAX_SESSION_REFS = 16;
    uint256 internal constant MAX_DATA_RECORDS = 2100;
    uint256 internal constant MAX_MANIFEST_ENTRIES = MAX_DATA_RECORDS;
    uint256 internal constant MAX_CONSUMED_FORCED_ROWS = 256;
    uint256 internal constant MAX_FORCED_DESCRIPTOR_ROWS = MAX_CONSUMED_FORCED_ROWS + 1;

    bytes4 internal constant COMPONENT_CONFIG_SELECTOR = 0xf6c0f7d2;
    uint256 internal constant COMPONENT_CONFIG_CALLDATA_LENGTH = 4;
    uint256 internal constant COMPONENT_CONFIG_RETURN_LENGTH = 32;
    uint256 internal constant COMPONENT_CONFIG_GETTER_GAS = 50_000;

    bytes32 internal constant SLOT_CHAIN_BLOCK_TYPEHASH =
        0xee6a8c8e31e8245cd527869508f6e464d6084893991203876f734d1855aed87c;
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    bytes32 internal constant SLOT_CHAIN_NAME_HASH = keccak256("SlotChain");
    bytes32 internal constant SLOT_CHAIN_VERSION_HASH = keccak256("2");

    string internal constant REGISTRY_LEAF_DOMAIN = "slot-chain-registry-leaf-v1";
    string internal constant REGISTRY_NODE_DOMAIN = "slot-chain-registry-node-v1";
    string internal constant ADMISSION_LEAF_DOMAIN = "slot-chain-admission-leaf-v1";
    string internal constant ADMISSION_NODE_DOMAIN = "slot-chain-admission-node-v1";
    string internal constant ENTRY_LEAF_DOMAIN = "slot-chain-entry-leaf-v1";
    string internal constant ENTRY_NODE_DOMAIN = "slot-chain-entry-node-v1";
    string internal constant TRANCHE_LEAF_DOMAIN = "slot-chain-tranche-leaf-v1";
    string internal constant TRANCHE_NODE_DOMAIN = "slot-chain-tranche-node-v1";
    string internal constant FORCE_USER_DOMAIN = "slot-chain-force-user-v2";
    string internal constant FORCE_USER_ADMISSION_DOMAIN = "slot-chain-force-user-admission-v2";
    string internal constant FORCED_QUEUE_CONFIG_DOMAIN = "slot-chain-forced-queue-config-v1";
    string internal constant FORCED_DESCRIPTOR_SCHEMA_DOMAIN =
        "slot-chain-force-descriptor-schema-v12";
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
    string internal constant BODY_DOMAIN = "slot-chain-body-v1";
    string internal constant BODY_CHUNK_DOMAIN = "slot-chain-body-chunk-v1";
    string internal constant SESSION_DOMAIN = "slot-chain-session-v1";
    string internal constant CORE_DOMAIN = "slot-chain-core-v3";
    string internal constant CANONICAL_DOMAIN = "slot-chain-canonical-v2";
    string internal constant CANDIDATE_DOMAIN = "slot-chain-candidate-v2";
    string internal constant WINNING_DATA_DOMAIN = "slot-chain-winning-data-v1";
    string internal constant SCHEDULE_LIST_DOMAIN = "slot-chain-schedule-list-v1";
    string internal constant SESSION_LIST_DOMAIN = "slot-chain-session-list-v1";
    string internal constant OUTPUTS_DOMAIN = "slot-chain-outputs-v3";
    string internal constant STATEMENT_DOMAIN = "slot-chain-statement-v3";
    string internal constant SETTLEMENT_VALIDITY_PUBLIC_INPUT_SCHEMA_DOMAIN =
        "slot-chain-settlement-validity-public-input-schema-v3";
    string internal constant REWARD_RECEIPT_DOMAIN = "slot-chain-reward-receipt-v1";
    string internal constant NORMAL_CONTEXT_DOMAIN = "slot-chain-normal-context-v1";
    string internal constant RECOVERY_DOMAIN = "slot-chain-recovery-v2";
}
