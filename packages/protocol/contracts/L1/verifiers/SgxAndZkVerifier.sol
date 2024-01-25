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

pragma solidity 0.8.20;

import "../../common/EssentialContract.sol";
import "../../thirdparty/LibBytesUtils.sol";
import "../TaikoData.sol";
import "./IVerifier.sol";

/// @title SgxAndZkVerifier
/// @notice See the documentation in {IVerifier}.
contract SgxAndZkVerifier is EssentialContract, IVerifier {
    uint8 public constant SGX_DEFAULT_PROOF_SIZE = 89;
    uint256[50] private __gap;

    /// @notice Initializes the contract with the provided address manager.
    /// @param _addressManager The address of the address manager contract.
    function init(address _addressManager) external initializer {
        __Essential_init(_addressManager);
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
        _proof.tier = proof.tier;

        address automataDcapAttestation = (resolve("automata_dcap_attestation", true));
        uint16 sgxProofLength = SGX_DEFAULT_PROOF_SIZE;

        if (automataDcapAttestation != address(0) ) {
            uint16 length =  uint16(bytes2(LibBytesUtils.slice(proof.data, 89, 2)));
            sgxProofLength += (2+length); // 2 for the uin16 length and the rest is the attestation quote, which maximum can be 1200 bytes
        }

        // Verify the SGX part
        _proof.data = LibBytesUtils.slice(proof.data, 0, sgxProofLength);
        IVerifier(resolve("tier_sgx", false)).verifyProof(ctx, tran, _proof);

        // Verify the ZK part
        _proof.data =
            LibBytesUtils.slice(proof.data, sgxProofLength, (proof.data.length - sgxProofLength));
        IVerifier(resolve("tier_pse_zkevm", false)).verifyProof(ctx, tran, _proof);
    }
}
