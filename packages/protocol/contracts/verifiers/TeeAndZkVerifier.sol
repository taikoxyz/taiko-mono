// SPDX-License-Identifier: MIT
//  _____     _ _         _         _
// |_   _|_ _(_) |_____  | |   __ _| |__ ___
//   | |/ _` | | / / _ \ | |__/ _` | '_ (_-<
//   |_|\__,_|_|_\_\___/ |____\__,_|_.__/__/
//
//   Email: security@taiko.xyz
//   Website: https://taiko.xyz
//   GitHub: https://github.com/taikoxyz
//   Discord: https://discord.gg/taikoxyz
//   Twitter: https://twitter.com/taikoxyz
//   Blog: https://mirror.xyz/labs.taiko.eth
//   Youtube: https://www.youtube.com/@taikoxyz

pragma solidity 0.8.24;

import "../common/EssentialContract.sol";
import "../L1/TaikoData.sol";
import "../L1/tiers/ITierProvider.sol";
import "./IVerifier.sol";
import "@optimism/packages/contracts-bedrock/src/libraries/Bytes.sol";

/// @title TeeAndZkVerifier
/// @notice See the documentation in {IVerifier}.
contract TeeAndZkVerifier is EssentialContract, IVerifier {
    // Some public constants related to specific verifier constraints (e.g.: due to slicing)
    uint8 public constant SGX_PROOF_SIZE = 89;

    uint256[50] private __gap;

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _rollupAddressManager The address of the {AddressManager} contract.
    function init(address _owner, address _rollupAddressManager) external initializer {
        __Essential_init(_owner, _rollupAddressManager);
    }

    /// @inheritdoc IVerifier
    function verifyProof(
        Context calldata ctx,
        TaikoData.Transition calldata tran,
        TaikoData.TierProof calldata proof
    )
        external
        onlyFromNamed("taiko")
    {
        TaikoData.TierProof memory _proof;

        // Based on the tier id - we shall conduct the rooting!
        // For example in LibTiers, we will have something like this:
        // SGX + risc0 ZKVM tier ID. -> uint16 public constant TIER_SGX_RISC0 = 301;
        if (_proof.tier == LibTiers.TIER_SGX_RISC0) {
            // Verify the SGX part
            _proof.data = Bytes.slice(proof.data, 0, SGX_PROOF_SIZE);
            IVerifier(resolve("tier_sgx", false)).verifyProof(ctx, tran, _proof);

            // Verify the risc_zero ZK part
            _proof.data =
                Bytes.slice(proof.data, SGX_PROOF_SIZE, (proof.data.length - SGX_PROOF_SIZE));
            IVerifier(resolve("tier_risc_zero", false)).verifyProof(ctx, tran, _proof);
        } else if (_proof.tier == LibTiers.TIER_SGX_SP1) {
            // Verify the SGX part
            _proof.data = Bytes.slice(proof.data, 0, SGX_PROOF_SIZE);
            IVerifier(resolve("tier_sgx", false)).verifyProof(ctx, tran, _proof);

            // Verify the sp1 ZK part
            _proof.data =
                Bytes.slice(proof.data, SGX_PROOF_SIZE, (proof.data.length - SGX_PROOF_SIZE));
            IVerifier(resolve("tier_sp1", false)).verifyProof(ctx, tran, _proof);
        }
    }
}
