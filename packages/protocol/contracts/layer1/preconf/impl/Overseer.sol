// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/layer1/preconf/iface/IOverseer.sol";
import "src/layer1/preconf/libs/LibPreconfConstants.sol";
import "openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "src/shared/common/EssentialContract.sol";
import "@solady/src/utils/MerkleProofLib.sol";
import "@solady/src/utils/MerkleTreeLib.sol";

/// @title Overseer
/// @notice The Overseer is responsible for blacklisting validators of preconf operators based on
/// subjective faults.
/// For instance, non-adherence to fair exchange.
/// @dev Operators of blacklisted validators are not inserted in the lookahead. This is done to
/// prevent the lookahead from being polluted by invalidators.
/// @custom:security-contact security@taiko.xyz
contract Overseer is IOverseer, EssentialContract {
    uint64 public signingThreshold;
    uint64 public numSigners;
    uint64 public nonce;

    mapping(address signerAddress => bool isSigner) public signers;

    /// @dev Maps the root of a merkle tree of validator keys to the timestamp at which they
    /// were blacklisted or unblacklisted.
    mapping(bytes32 validatorsRoot => BlacklistTimestamps blacklistTimestamps) public blacklist;

    uint256[47] private __gap;

    function init(uint64 _signingThreshold, address[] memory _signers) external initializer {
        __Essential_init(address(0));
        __OverseerInit(_signingThreshold, _signers);
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
        bytes32 validatorsRoot = MerkleTreeLib.root(_generateMerkleTree(_validatorPubKeys));

        BlacklistTimestamps memory blacklistTimestamps = blacklist[validatorsRoot];

        // The set of validators must not be already blacklisted
        require(
            blacklistTimestamps.blacklistedAt <= blacklistTimestamps.unBlacklistedAt,
            ValidatorsAlreadyBlacklisted()
        );

        // If the validators were unblacklisted, the overseer must wait for a delay before
        // blacklisting
        // them again in order to not mess up the lookahead.
        require(
            block.timestamp > blacklistTimestamps.unBlacklistedAt + getConfig().blacklistDelay,
            BlacklistDelayNotMet()
        );

        // The signatures must be valid
        unchecked {
            bytes32 digest = keccak256(
                abi.encode(
                    LibPreconfConstants.BLACKLIST_OVERSEER_DOMAIN_SEPARATOR, nonce++, validatorsRoot
                )
            );
            _verifySignatures(digest, _signatures);
        }

        blacklist[validatorsRoot].blacklistedAt = uint128(block.timestamp);

        emit Blacklisted(validatorsRoot, block.timestamp);
    }

    /// @inheritdoc IOverseer
    function unblacklistValidators(bytes32 _validatorsRoot, bytes[] memory _signatures) external {
        BlacklistTimestamps memory blacklistTimestamps = blacklist[_validatorsRoot];

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
        unchecked {
            bytes32 digest = keccak256(
                abi.encode(
                    LibPreconfConstants.UNBLACKLIST_OVERSEER_DOMAIN_SEPARATOR,
                    nonce++,
                    _validatorsRoot
                )
            );
            _verifySignatures(digest, _signatures);
        }

        blacklist[_validatorsRoot].unBlacklistedAt = uint128(block.timestamp);

        emit Unblacklisted(_validatorsRoot, block.timestamp);
    }

    // Signers management functions
    // -----------------------------------------------------------------------------------

    /// @inheritdoc IOverseer
    function addSigner(address _signer, bytes[] memory _signatures) external {
        require(!signers[_signer], SignerAlreadyExists());

        unchecked {
            bytes32 digest = keccak256(
                abi.encode(
                    LibPreconfConstants.ADD_OVERSEER_SIGNER_DOMAIN_SEPARATOR, nonce++, _signer
                )
            );
            _verifySignatures(digest, _signatures);

            signers[_signer] = true;
            ++numSigners;
        }

        emit SignerAdded(_signer);
    }

    /// @inheritdoc IOverseer
    function removeSigner(address _signer, bytes[] memory _signatures) external {
        require(signers[_signer], SignerDoesNotExist());

        // The number of signers must not fall below the signing threshold
        require(numSigners > signingThreshold, CannotRemoveSignerWhenThresholdIsReached());

        unchecked {
            bytes32 digest = keccak256(
                abi.encode(
                    LibPreconfConstants.REMOVE_OVERSEER_SIGNER_DOMAIN_SEPARATOR, nonce++, _signer
                )
            );
            _verifySignatures(digest, _signatures);

            delete signers[_signer];
            --numSigners;
        }

        emit SignerRemoved(_signer);
    }

    /// @inheritdoc IOverseer
    function updateSigningThreshold(
        uint64 _signingThreshold,
        bytes[] memory _signatures
    )
        external
    {
        // The new threshold must not exceed the number of signers
        require(_signingThreshold <= numSigners, InvalidSigningThreshold());

        unchecked {
            bytes32 digest = keccak256(
                abi.encode(
                    LibPreconfConstants.UPDATE_OVERSEER_SIGNING_THRESHOLD_DOMAIN_SEPARATOR,
                    nonce++,
                    _signingThreshold
                )
            );
            _verifySignatures(digest, _signatures);
        }

        signingThreshold = _signingThreshold;

        emit SigningThresholdUpdated(_signingThreshold);
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
        uint256 _validatorIndex
    )
        external
        pure
        returns (bytes32[] memory)
    {
        return MerkleTreeLib.leafProof(_generateMerkleTree(_validatorPubKeys), _validatorIndex);
    }

    /// @inheritdoc IOverseer
    function isValidatorBlacklisted(
        BLS.G1Point memory _validatorPubKey,
        bytes32 _validatorsRoot,
        bytes32[] calldata _proof
    )
        external
        pure
        returns (bool)
    {
        bytes32 validatorLeaf = keccak256(abi.encode(_validatorPubKey));
        return MerkleProofLib.verifyCalldata(_proof, _validatorsRoot, validatorLeaf);
    }

    // Internal functions
    // -----------------------------------------------------------------------------------

    function __OverseerInit(uint64 _signingThreshold, address[] memory _signers) internal {
        require(_signingThreshold <= _signers.length, InvalidSigningThreshold());

        for (uint256 i; i < _signers.length; ++i) {
            signers[_signers[i]] = true;
        }

        numSigners = uint64(_signers.length);
        signingThreshold = _signingThreshold;
    }

    function _generateMerkleTree(BLS.G1Point[] calldata _validatorPubKeys)
        internal
        pure
        returns (bytes32[] memory)
    {
        return MerkleTreeLib.build(MerkleTreeLib.pad(_hashValidatorsToLeaves(_validatorPubKeys)));
    }

    /// @dev Saves gas by reusing a scratch space for encoding instead of repeatedly expanding
    /// the memory by using abi.encode(..)
    function _hashValidatorsToLeaves(BLS.G1Point[] calldata _validatorPubKeys)
        internal
        pure
        returns (bytes32[] memory)
    {
        bytes32[] memory leaves = new bytes32[](_validatorPubKeys.length);

        assembly {
            // Scratch space for encoding and hashing a validator's G1Point pub key
            let scratchSpace := mload(0x40)
            // Size of a G1Point (128 bytes)
            let scratchSpaceSize := 0x40
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

    function _verifySignatures(bytes32 _digest, bytes[] memory _signatures) internal view {
        require(_signatures.length >= signingThreshold, InsufficientSignatures());

        address lastSigner;
        address currentSigner;

        for (uint256 i; i < _signatures.length; ++i) {
            // Recover the signer from the signature
            currentSigner = ECDSA.recover(_digest, _signatures[i]);
            require(signers[currentSigner], NotAnExistingSigner());

            // To prevent reuse of same signer
            require(lastSigner < currentSigner, SignersMustBeSortedInAscendingOrder());

            lastSigner = currentSigner;
        }
    }
}
