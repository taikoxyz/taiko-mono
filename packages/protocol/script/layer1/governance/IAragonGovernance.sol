// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal typed mirrors of the deployed Aragon governance-stack contracts,
/// covering only what the proposal scripts touch. Declarations copy the upstream types
/// and names verbatim so they can be diffed against the sources; contract-typed fields
/// (e.g. `SignerList signerList`) are declared `address`, which is ABI-identical.
///
/// Fidelity anchors — the deployed implementations, not upstream HEAD, are what these
/// mirrors must match:
/// - Upstream source: github.com/taikoxyz/dao-contracts, tag `dao-contracts-v1.0.0`
///   (commit 76aae6e), verified identical to the deployed implementations below.
/// - Deployed proxies: `LibL1Addrs` (DAO_SIGNER_LIST, DAO_STANDARD_MULTISIG,
///   DAO_EMERGENCY_MULTISIG, DAO_ENCRYPTION_REGISTRY). Every selector below has been
///   checked against the implementation bytecode behind them:
///   SignerList 0x584FE70fE82F728F0fE26488857D623f3b59e070,
///   Standard Multisig 0x8510D389236D7213Ee9b9C38CaaBC0Ad24853C25,
///   Emergency Multisig 0x437E450452E8bC142Bd5317199296EcB187c514B,
///   EncryptionRegistry 0x2eFDb93a3B87b930E553d504db67Ee41c69C42d1 (not proxied).
/// - `BuildDirectProposal`'s l1dryrun mode exercises the declarations on a mainnet fork
///   (`appointAgent` only until the Taiko Labs agent rotation lands on-chain), so drift
///   from the deployed ABI fails there instead of silently corrupting a proposal.

/// @dev Mirrors Aragon OSx `IDAO.Action`.
struct Action {
    address to;
    uint256 value;
    bytes data;
}

/// @notice SignerList: the Security Council membership census (an OSx `Addresslist`).
/// @custom:security-contact security@taiko.xyz
interface ISignerList {
    struct Settings {
        address encryptionRegistry;
        uint16 minSignerListLength;
    }

    /// @notice Adds members to the census. Reverts if the list would exceed uint16.
    function addSigners(address[] calldata _signers) external;
    /// @notice Removes members. Reverts if the list would drop below
    /// `settings.minSignerListLength`.
    function removeSigners(address[] calldata _signers) external;
    /// @notice Replaces the full settings struct.
    function updateSettings(Settings calldata _newSettings) external;
    /// @notice The `Settings` auto-getter, flattened.
    function settings()
        external
        view
        returns (address encryptionRegistry, uint16 minSignerListLength);
    /// @notice Whether `_account` currently holds a council seat.
    function isListed(address _account) external view returns (bool);
    /// @notice Current number of seats.
    function addresslistLength() external view returns (uint256);
}

/// @notice The Standard Multisig (upstream `Multisig.sol`): council-created proposals
/// that pass through the optimistic (veto) stage before DAO execution.
/// @custom:security-contact security@taiko.xyz
interface IMultisig {
    struct MultisigSettings {
        bool onlyListed;
        uint16 minApprovals;
        uint32 destinationProposalDuration;
        address signerList;
        uint32 proposalExpirationPeriod;
    }

    struct ProposalParameters {
        uint16 minApprovals;
        uint64 snapshotBlock;
        uint64 expirationDate;
    }

    /// @notice Creates a proposal; sender must be listed or appointed by a listed seat
    /// (when `onlyListed`). `_approveProposal` additionally records the sender's approval.
    function createProposal(
        bytes calldata _metadataURI,
        Action[] calldata _destinationActions,
        address _destinationPlugin,
        bool _approveProposal
    )
        external
        returns (uint256 proposalId);
    /// @notice Replaces the full settings struct.
    function updateMultisigSettings(MultisigSettings calldata _multisigSettings) external;
    /// @notice The `MultisigSettings` auto-getter, flattened.
    function multisigSettings()
        external
        view
        returns (
            bool onlyListed,
            uint16 minApprovals,
            uint32 destinationProposalDuration,
            address signerList,
            uint32 proposalExpirationPeriod
        );
    /// @notice The stored proposal: status, approvals, parameters, metadata, and the
    /// actions the DAO will execute (what approvers compare against the repo).
    function getProposal(uint256 _proposalId)
        external
        view
        returns (
            bool executed,
            uint16 approvals,
            ProposalParameters memory parameters,
            bytes memory metadataURI,
            Action[] memory destinationActions,
            address destinationPlugin
        );
}

/// @notice The Emergency Multisig (upstream `EmergencyMultisig.sol`): encrypted
/// proposals executed by the DAO directly, without a veto stage.
/// @custom:security-contact security@taiko.xyz
interface IEmergencyMultisig {
    struct MultisigSettings {
        bool onlyListed;
        uint16 minApprovals;
        address signerList;
        uint32 proposalExpirationPeriod;
    }

    /// @notice Replaces the full settings struct.
    function updateMultisigSettings(MultisigSettings calldata _multisigSettings) external;
    /// @notice The `MultisigSettings` auto-getter, flattened.
    function multisigSettings()
        external
        view
        returns (
            bool onlyListed,
            uint16 minApprovals,
            address signerList,
            uint32 proposalExpirationPeriod
        );
}

/// @notice EncryptionRegistry: per-seat encryption agents and public keys.
/// @custom:security-contact security@taiko.xyz
interface IEncryptionRegistry {
    /// @notice Appoints `_newAgent` for the calling seat; appointing oneself
    /// un-appoints (clears the agent), and either path wipes the stored public key.
    function appointAgent(address _newAgent) external;
    /// @notice Prunes accounts that are no longer listed on the SignerList from the
    /// registry's enumeration (their `appointerOf`/agent mappings persist).
    function removeUnused() external;
    /// @notice The seat that appointed `_agent`, or address(0).
    function appointerOf(address _agent) external view returns (address);
    /// @notice All enumerated accounts (listed seats that registered or appointed).
    function getRegisteredAccounts() external view returns (address[] memory);
}
