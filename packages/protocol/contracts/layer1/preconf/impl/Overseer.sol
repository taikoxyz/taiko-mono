// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "src/layer1/preconf/iface/IOverseer.sol";
import "src/layer1/preconf/libs/LibPreconfConstants.sol";
import "openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "src/shared/common/EssentialContract.sol";

/// @title Overseer
/// @notice The Overseer is responsible for the following:
/// - Slashing malicious commitments via the URC when assigned as the slasher
///   (currently only for lookahead commitments until EIP-7917 is live)
/// - Blacklisting preconf operators based on subjective faults. For instance, non-adherence to
///   fair exchange.
///   (blacklisted operators are not inserted in the lookahead)
/// @custom:security-contact security@taiko.xyz
contract Overseer is IOverseer, EssentialContract {
    address public immutable urc;

    uint64 public signingThreshold;
    uint64 public numSigners;
    uint64 public nonce;

    mapping(address signerAddress => bool isSigner) public signers;

    mapping(bytes32 operatorRegistrationRoot => BlacklistedOperator blacklistedOperator) public
        blacklistedOperators;

    uint256[47] private __gap;

    constructor(address _urc) {
        urc = _urc;
    }

    function init(uint64 _signingThreshold, address[] memory _signers) external initializer {
        __Essential_init(address(0));
        __OverseerInit(_signingThreshold, _signers);
    }

    /// @dev Based on URC's ISlasher interface
    function slash(
        Delegation calldata, /*_delegation*/
        Commitment calldata, /*_commitment*/
        address _committer,
        bytes calldata _evidence,
        address /*_challenger*/
    )
        external
        nonReentrant
        onlyFrom(urc)
        returns (uint256)
    {
        // `_evidence` is expected to be a list of signatures advocating for the slashing of the
        // committer
        unchecked {
            bytes32 digest = keccak256(
                abi.encode(LibPreconfConstants.OVERSEER_SLASH_DOMAIN_SEPARATOR, nonce++, _committer)
            );
            _verifySignatures(digest, abi.decode(_evidence, (bytes[])));
        }

        uint256 slashedAmount = getConfig().slashingAmount;

        emit Slashed(_committer, slashedAmount);

        return slashedAmount;
    }

    // Blacklist functions
    // -----------------------------------------------------------------------------------

    /// @inheritdoc IOverseer
    function blacklistOperator(
        bytes32 _operatorRegistrationRoot,
        bytes[] memory _signatures
    )
        external
    {
        BlacklistedOperator memory blacklistedOperator =
            blacklistedOperators[_operatorRegistrationRoot];

        // The operator must not be already blacklisted
        require(
            blacklistedOperator.blacklistedAt <= blacklistedOperator.unBlacklistedAt,
            OperatorAlreadyBlacklisted()
        );

        // If the operator was unblacklisted, the overseer must wait for a delay before blacklisting
        // them again in order to not mess up the lookahead.
        require(
            block.timestamp > blacklistedOperator.unBlacklistedAt + getConfig().blacklistDelay,
            BlacklistDelayNotMet()
        );

        // The signatures must be valid
        unchecked {
            bytes32 digest = keccak256(
                abi.encode(
                    LibPreconfConstants.BLACKLIST_OVERSEER_DOMAIN_SEPARATOR,
                    nonce++,
                    _operatorRegistrationRoot
                )
            );
            _verifySignatures(digest, _signatures);
        }

        blacklistedOperators[_operatorRegistrationRoot].blacklistedAt = uint128(block.timestamp);

        emit Blacklisted(_operatorRegistrationRoot, block.timestamp);
    }

    /// @inheritdoc IOverseer
    function unblacklistOperator(
        bytes32 _operatorRegistrationRoot,
        bytes[] memory _signatures
    )
        external
    {
        BlacklistedOperator memory blacklistedOperator =
            blacklistedOperators[_operatorRegistrationRoot];

        // The operator must be blacklisted
        require(
            blacklistedOperator.blacklistedAt > blacklistedOperator.unBlacklistedAt,
            OperatorNotBlacklisted()
        );

        // If the operator was blacklisted, the overseer must wait for a delay before unblacklisting
        // them again in order to not mess up the lookahead.
        require(
            block.timestamp > blacklistedOperator.blacklistedAt + getConfig().unblacklistDelay,
            UnblacklistDelayNotMet()
        );

        // The signatures must be valid
        unchecked {
            bytes32 digest = keccak256(
                abi.encode(
                    LibPreconfConstants.UNBLACKLIST_OVERSEER_DOMAIN_SEPARATOR,
                    nonce++,
                    _operatorRegistrationRoot
                )
            );
            _verifySignatures(digest, _signatures);
        }

        blacklistedOperators[_operatorRegistrationRoot].unBlacklistedAt = uint128(block.timestamp);

        emit Unblacklisted(_operatorRegistrationRoot, block.timestamp);
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
        return Config({ blacklistDelay: 1 days, unblacklistDelay: 1 days, slashingAmount: 1 ether });
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
