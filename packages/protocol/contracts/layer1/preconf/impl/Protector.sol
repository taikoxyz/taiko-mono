// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "src/layer1/preconf/iface/IProtector.sol";
import "src/layer1/preconf/libs/LibPreconfConstants.sol";
import "openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "src/shared/common/EssentialContract.sol";

/// @title Protector
/// @custom:security-contact security@taiko.xyz
contract Protector is IProtector, EssentialContract {
    address public immutable urc;

    uint64 public signingThreshold;
    uint64 public numSigners;
    uint64 public nonce;

    mapping(address signerAddress => bool isSigner) public signers;

    uint256[48] private __gap;

    constructor(address _urc) {
        urc = _urc;
    }

    function init(uint64 _signingThreshold, address[] memory _signers) external initializer {
        __Essential_init(address(0));
        __Protector_init(_signingThreshold, _signers);
    }

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
                abi.encode(
                    LibPreconfConstants.PROTECTOR_SLASH_DOMAIN_SEPARATOR, nonce++, _committer
                )
            );
            _verifySignatures(digest, abi.decode(_evidence, (bytes[])));
        }

        emit Slashed(_committer, 1 ether);

        // TODO: Make this confiugurable
        return 1 ether;
    }

    // Signers management functions
    // -----------------------------------------------------------------------------------

    /// @inheritdoc IProtector
    function addSigner(address _signer, bytes[] memory _signatures) external {
        require(!signers[_signer], SignerAlreadyExists());

        unchecked {
            bytes32 digest = keccak256(
                abi.encode(
                    LibPreconfConstants.ADD_PROTECTOR_SIGNER_DOMAIN_SEPARATOR, nonce++, _signer
                )
            );
            _verifySignatures(digest, _signatures);

            signers[_signer] = true;
            ++numSigners;
        }

        emit SignerAdded(_signer);
    }

    /// @inheritdoc IProtector
    function removeSigner(address _signer, bytes[] memory _signatures) external {
        require(signers[_signer], SignerDoesNotExist());
        require(numSigners > signingThreshold, CannotRemoveSignerWhenThresholdIsReached());

        unchecked {
            bytes32 digest = keccak256(
                abi.encode(
                    LibPreconfConstants.REMOVE_PROTECTOR_SIGNER_DOMAIN_SEPARATOR, nonce++, _signer
                )
            );
            _verifySignatures(digest, _signatures);

            delete signers[_signer];
            --numSigners;
        }

        emit SignerRemoved(_signer);
    }

    /// @inheritdoc IProtector
    function updateSigningThreshold(
        uint64 _signingThreshold,
        bytes[] memory _signatures
    )
        external
    {
        require(_signingThreshold <= numSigners, InvalidSigningThreshold());

        unchecked {
            bytes32 digest = keccak256(
                abi.encode(
                    LibPreconfConstants.UPDATE_PROTECTOR_SIGNING_THRESHOLD_DOMAIN_SEPARATOR,
                    nonce++,
                    _signingThreshold
                )
            );
            _verifySignatures(digest, _signatures);
        }

        signingThreshold = _signingThreshold;

        emit SigningThresholdUpdated(_signingThreshold);
    }

    // Internal functions
    // -----------------------------------------------------------------------------------

    function __Protector_init(uint64 _signingThreshold, address[] memory _signers) internal {
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

            // To prevent replay of signatures
            require(lastSigner < currentSigner, SignersMustBeSortedInAscendingOrder());

            lastSigner = currentSigner;
        }
    }
}
