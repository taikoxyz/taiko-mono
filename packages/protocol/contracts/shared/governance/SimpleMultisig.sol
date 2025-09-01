// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/common/EssentialContract.sol";
import "openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @title SimpleMultisig
/// @notice A simple multisig contract that allows for signer management and signature verification.
/// @dev This contract provides basic multisig functionality with signer management and signature
/// verification.
/// It can be inherited by other contracts that need multisig capabilities.
/// @custom:security-contact security@taiko.xyz
abstract contract SimpleMultisig {
    // Events and errors
    // -----------------

    event SignerAdded(address indexed signer);
    event SignerRemoved(address indexed signer);
    event SigningThresholdUpdated(uint64 newSigningThreshold);

    error AtleastOneSignerIsRequired();
    error CannotRemoveSignerWhenThresholdIsReached();
    error InsufficientSignatures();
    error InvalidSigningThreshold();
    error NotAnExistingSigner();
    error SignerAlreadyExists();
    error SignerDoesNotExist();
    error SignersMustBeSortedInAscendingOrder();

    // Storage
    // -------

    uint64 public signingThreshold;
    uint64 public numSigners;
    uint64 public nonce;

    mapping(address signerAddress => bool isSigner) public signers;

    uint256[48] private __gap;

    // Initializer
    // -----------------------------------------------------------------------------------

    function __SimpleMultisig_init(uint64 _signingThreshold, address[] memory _signers) internal {
        require(_signers.length > 0, AtleastOneSignerIsRequired());
        require(
            _signingThreshold != 0 && _signingThreshold <= _signers.length,
            InvalidSigningThreshold()
        );

        for (uint256 i; i < _signers.length; ++i) {
            signers[_signers[i]] = true;
        }

        numSigners = uint64(_signers.length);
        signingThreshold = _signingThreshold;
    }

    // Signers management functions
    // -----------------------------------------------------------------------------------

    /// @notice Adds a new signer to the multisig
    /// @param _signer The address of the signer to add
    /// @param _signatures Array of signatures from existing signers
    function addSigner(address _signer, bytes[] memory _signatures) external {
        require(!signers[_signer], SignerAlreadyExists());

        _verifySignatures(
            _getAddSignerDomainSeparator(), bytes32(uint256(uint160(_signer))), _signatures
        );
        signers[_signer] = true;

        unchecked {
            ++numSigners;
        }

        emit SignerAdded(_signer);
    }

    /// @notice Removes a signer from the multisig
    /// @param _signer The address of the signer to remove
    /// @param _signatures Array of signatures from existing signers
    function removeSigner(address _signer, bytes[] memory _signatures) external {
        require(signers[_signer], SignerDoesNotExist());

        // The number of signers must not fall below the signing threshold
        require(numSigners > signingThreshold, CannotRemoveSignerWhenThresholdIsReached());

        unchecked {
            _verifySignatures(
                _getRemoveSignerDomainSeparator(), bytes32(uint256(uint160(_signer))), _signatures
            );

            delete signers[_signer];
            --numSigners;
        }

        emit SignerRemoved(_signer);
    }

    /// @notice Updates the signing threshold
    /// @param _signingThreshold The new signing threshold value
    /// @param _signatures Array of signatures from existing signers
    function updateSigningThreshold(
        uint64 _signingThreshold,
        bytes[] memory _signatures
    )
        external
    {
        // The new threshold must not exceed the number of signers
        require(_signingThreshold <= numSigners, InvalidSigningThreshold());

        unchecked {
            _verifySignatures(
                _getUpdateSigningThresholdDomainSeparator(),
                bytes32(uint256(_signingThreshold)),
                _signatures
            );
        }

        signingThreshold = _signingThreshold;

        emit SigningThresholdUpdated(_signingThreshold);
    }

    // Internal functions
    // -----------------------------------------------------------------------------------

    /// @param _ds The domain separator
    /// @param _data The data to be hashed and signed
    /// @param _signatures The signatures to be verified
    function _verifySignatures(bytes32 _ds, bytes32 _data, bytes[] memory _signatures) internal {
        require(_signatures.length >= signingThreshold, InsufficientSignatures());

        bytes32 digest;
        unchecked {
            digest = keccak256(abi.encode(_ds, ++nonce, _data));
        }

        address lastSigner;
        address currentSigner;

        for (uint256 i; i < _signatures.length; ++i) {
            // Recover the signer from the signature
            currentSigner = ECDSA.recover(digest, _signatures[i]);
            require(signers[currentSigner], NotAnExistingSigner());

            // To prevent reuse of same signer
            require(lastSigner < currentSigner, SignersMustBeSortedInAscendingOrder());

            lastSigner = currentSigner;
        }
    }

    // Virtual functions
    // -----------------------------------------------------------------------------------

    function _getAddSignerDomainSeparator() internal pure virtual returns (bytes32) {
        return keccak256("TAIKO_SIMPLE_MULTISIG_ADD_SIGNER");
    }

    function _getRemoveSignerDomainSeparator() internal pure virtual returns (bytes32) {
        return keccak256("TAIKO_SIMPLE_MULTISIG_REMOVE_SIGNER");
    }

    function _getUpdateSigningThresholdDomainSeparator() internal pure virtual returns (bytes32) {
        return keccak256("TAIKO_SIMPLE_MULTISIG_UPDATE_SIGNING_THRESHOLD");
    }
}
