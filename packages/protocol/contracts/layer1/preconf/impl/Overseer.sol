// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/preconf/iface/IOverseer.sol";
import "src/layer1/preconf/libs/LibPreconfConstants.sol";
import "openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "src/shared/common/EssentialContract.sol";
import "src/shared/governance/SimpleMultisig.sol";
import "@solady/src/utils/MerkleProofLib.sol";
import "@solady/src/utils/MerkleTreeLib.sol";

/// @title Overseer
/// @notice The Overseer is responsible for blacklisting validators of preconf operators based on
/// subjective faults.
/// For instance, non-adherence to fair exchange.
/// @dev Operators of blacklisted validators are not inserted in the lookahead. This is done to
/// prevent the lookahead from being polluted by invalid validators.
/// @custom:security-contact security@taiko.xyz
contract Overseer is IOverseer, SimpleMultisig, EssentialContract {
    /// @dev Maps the root of a merkle tree of validator keys to the timestamp at which they
    /// were blacklisted or unblacklisted.
    mapping(bytes32 validatorPubKeysRoot => BlacklistTimestamps blacklistTimestamps) public
        blacklist;

    uint256[49] private __gap;

    function init(uint64 _signingThreshold, address[] memory _signers) external initializer {
        __Essential_init(address(0));
        __SimpleMultisig_init(_signingThreshold, _signers);
    }

    // Blacklist functions
    // -----------------------------------------------------------------------------------

    /// @inheritdoc IOverseer
    function blacklistValidators(
        BLS.G1Point[] calldata _validatorPubKeys,
        bytes[] memory _signatures
    )
        external
    {
        // Merkleize the validators to a single validator's merkle root
        bytes32 validatorPubKeysRoot = MerkleTreeLib.root(_generateMerkleTree(_validatorPubKeys));

        BlacklistTimestamps memory blacklistTimestamps = blacklist[validatorPubKeysRoot];

        // The set of validators must not be already blacklisted
        require(
            blacklistTimestamps.blacklistedAt <= blacklistTimestamps.unBlacklistedAt,
            ValidatorsAlreadyBlacklisted()
        );

        // If the validators were unblacklisted, the overseer must wait for a delay before
        // blacklisting them again in order to not mess up the lookahead.
        require(
            block.timestamp > blacklistTimestamps.unBlacklistedAt + getConfig().blacklistDelay,
            BlacklistDelayNotMet()
        );

        // The signatures must be valid
        _verifySignatures(_getBlacklistDomainSeparator(), validatorPubKeysRoot, _signatures);

        blacklist[validatorPubKeysRoot].blacklistedAt = uint48(block.timestamp);

        emit Blacklisted(validatorPubKeysRoot, uint48(block.timestamp));
    }

    /// @inheritdoc IOverseer
    function unblacklistValidators(
        bytes32 _validatorPubKeysRoot,
        bytes[] memory _signatures
    )
        external
    {
        BlacklistTimestamps memory blacklistTimestamps = blacklist[_validatorPubKeysRoot];

        // The validators must be blacklisted
        require(
            blacklistTimestamps.blacklistedAt > blacklistTimestamps.unBlacklistedAt,
            ValidatorsNotBlacklisted()
        );

        // If the validators were blacklisted, the overseer must wait for a delay before
        // unblacklisting
        // them again in order to not mess up the lookahead.
        require(
            block.timestamp > blacklistTimestamps.blacklistedAt + getConfig().unblacklistDelay,
            UnblacklistDelayNotMet()
        );

        // The signatures must be valid
        _verifySignatures(_getUnblacklistDomainSeparator(), _validatorPubKeysRoot, _signatures);

        blacklist[_validatorPubKeysRoot].unBlacklistedAt = uint48(block.timestamp);

        emit Unblacklisted(_validatorPubKeysRoot, uint48(block.timestamp));
    }

    // Views
    // -----------------------------------------------------------------------------------

    /// @inheritdoc IOverseer
    function getConfig() public pure returns (Config memory) {
        return Config({ blacklistDelay: 1 days, unblacklistDelay: 1 days });
    }

    /// @inheritdoc IOverseer
    function getValidatorBlacklistInclusionProof(
        BLS.G1Point[] calldata _validatorPubKeys,
        uint256 _validatorPubKeyIndex
    )
        external
        pure
        returns (bytes32[] memory)
    {
        return
            MerkleTreeLib.leafProof(_generateMerkleTree(_validatorPubKeys), _validatorPubKeyIndex);
    }

    /// @inheritdoc IOverseer
    function isValidatorBlacklisted(
        BLS.G1Point memory _validatorPubKey,
        bytes32 _validatorPubKeysRoot,
        bytes32[] calldata _proof
    )
        external
        pure
        returns (bool)
    {
        bytes32 validatorPubKeyLeaf = keccak256(abi.encode(_validatorPubKey));
        return MerkleProofLib.verifyCalldata(_proof, _validatorPubKeysRoot, validatorPubKeyLeaf);
    }

    // Internal functions
    // -----------------------------------------------------------------------------------

    function _generateMerkleTree(BLS.G1Point[] calldata _validatorPubKeys)
        internal
        pure
        returns (bytes32[] memory)
    {
        return
            MerkleTreeLib.build(MerkleTreeLib.pad(_hashValidatorPubKeysToLeaves(_validatorPubKeys)));
    }

    /// @dev Saves gas by reusing a scratch space for encoding instead of repeatedly expanding
    /// the memory by using abi.encode(..)
    function _hashValidatorPubKeysToLeaves(BLS.G1Point[] calldata _validatorPubKeys)
        internal
        pure
        returns (bytes32[] memory)
    {
        bytes32[] memory leaves = new bytes32[](_validatorPubKeys.length);

        assembly {
            // Scratch space for encoding and hashing a validator's G1Point pub key
            let scratchSpace := mload(0x40)
            // Size of a G1Point (128 bytes)
            let scratchSpaceSize := 0x80
            // Set the pointer to skip the length
            let leavesPtr := add(leaves, 0x20)

            // Solidity: keccak256(abi.encode(_validatorPubKeys[i]))
            for { let i := 0 } lt(i, _validatorPubKeys.length) { i := add(i, 1) } {
                calldatacopy(
                    scratchSpace,
                    add(_validatorPubKeys.offset, mul(i, scratchSpaceSize)),
                    scratchSpaceSize
                )
                mstore(add(leavesPtr, mul(i, 0x20)), keccak256(scratchSpace, scratchSpaceSize))
            }
        }

        return leaves;
    }

    function _getBlacklistDomainSeparator() internal pure virtual returns (bytes32) {
        return keccak256("TAIKO_ALETHIA_BLACKLIST_OVERSEER");
    }

    function _getUnblacklistDomainSeparator() internal pure virtual returns (bytes32) {
        return keccak256("TAIKO_ALETHIA_UNBLACKLIST_OVERSEER");
    }

    // Overrides
    // -----------------------------------------------------------------------------------

    function _getAddSignerDomainSeparator() internal pure override returns (bytes32) {
        return keccak256("TAIKO_ALETHIA_ADD_OVERSEER_SIGNER");
    }

    function _getRemoveSignerDomainSeparator() internal pure override returns (bytes32) {
        return keccak256("TAIKO_ALETHIA_REMOVE_OVERSEER_SIGNER");
    }

    function _getUpdateSigningThresholdDomainSeparator() internal pure override returns (bytes32) {
        return keccak256("TAIKO_ALETHIA_UPDATE_OVERSEER_SIGNING_THRESHOLD");
    }
}
