// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./SgxVerifierBase.sol";
import "./IVerifier.sol";

/// @title SgxVerifier
/// @notice This contract is the implementation of verifying SGX signature proofs
/// onchain.
/// @dev Please see references below:
/// - Reference #1: https://ethresear.ch/t/2fa-zk-rollups-using-sgx/14462
/// - Reference #2: https://github.com/gramineproject/gramine/discussions/1579
/// @custom:security-contact security@taiko.xyz
contract SgxVerifier is SgxVerifierBase, IVerifier {
    uint256[50] private __gap;

    error SGX_INVALID_PROOF();

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _rollupAddressManager The address of the {AddressManager} contract.
    function init(address _owner, address _rollupAddressManager) external initializer {
        __Essential_init(_owner, _rollupAddressManager);
    }

    /// @inheritdoc IVerifier
    function verifyProof(
        Context calldata _ctx,
        TaikoData.Transition calldata _tran,
        TaikoData.TierProof calldata _proof
    )
        external
        onlyFromNamedEither(LibStrings.B_TAIKO, LibStrings.B_TIER_TEE_ANY)
    {
        // Do not run proof verification to contest an existing proof
        if (_ctx.isContesting) return;

        // Size is: 89 bytes
        // 4 bytes + 20 bytes + 65 bytes (signature) = 89
        if (_proof.data.length != 89) revert SGX_INVALID_PROOF();

        uint32 id = uint32(bytes4(_proof.data[:4]));
        address newInstance = address(bytes20(_proof.data[4:24]));

        address oldInstance = ECDSA.recover(
            LibPublicInput.hashPublicInputs(
                _tran, address(this), newInstance, _ctx.prover, _ctx.metaHash, taikoChainId()
            ),
            _proof.data[24:]
        );

        if (!_isInstanceValid(id, oldInstance)) revert SGX_INVALID_INSTANCE();

        if (newInstance != oldInstance && newInstance != address(0)) {
            _replaceInstance(id, oldInstance, newInstance);
        }
    }

    /// @inheritdoc IVerifier
    function verifyBatchProof(
        ContextV2[] calldata _ctxs,
        TaikoData.TierProof calldata _proof
    )
        external
        onlyFromNamedEither(LibStrings.B_TAIKO, LibStrings.B_TIER_TEE_ANY)
    {
        // Size is: 109 bytes
        // 4 bytes + 20 bytes + 20 bytes + 65 bytes (signature) = 109
        if (_proof.data.length != 109) revert SGX_INVALID_PROOF();

        uint32 id = uint32(bytes4(_proof.data[:4]));
        address oldInstance = address(bytes20(_proof.data[4:24]));
        address newInstance = address(bytes20(_proof.data[24:44]));

        // Collect public inputs
        bytes32[] memory publicInputs = new bytes32[](_ctxs.length + 2);
        // First public input is the current instance public key
        publicInputs[0] = bytes32(uint256(uint160(oldInstance)));
        publicInputs[1] = bytes32(uint256(uint160(newInstance)));
        // All other inputs are the block program public inputs (a single 32 byte value)
        uint64 chainId = taikoChainId();
        for (uint256 i; i < _ctxs.length; ++i) {
            // TODO: For now this assumes the new instance public key to remain the same
            publicInputs[i + 2] = LibPublicInput.hashPublicInputs(
                _ctxs[i].tran,
                address(this),
                newInstance,
                _ctxs[i].prover,
                _ctxs[i].metaHash,
                chainId
            );
        }

        bytes32 signatureHash = keccak256(abi.encodePacked(publicInputs));
        // Verify the blocks
        if (oldInstance != ECDSA.recover(signatureHash, _proof.data[44:])) {
            revert SGX_INVALID_PROOF();
        }

        if (!_isInstanceValid(id, oldInstance)) revert SGX_INVALID_INSTANCE();

        if (newInstance != oldInstance && newInstance != address(0)) {
            _replaceInstance(id, oldInstance, newInstance);
        }
    }

    function taikoChainId() internal view virtual returns (uint64) {
        return ITaikoL1(resolve(LibStrings.B_TAIKO, false)).getConfig().chainId;
    }
}
