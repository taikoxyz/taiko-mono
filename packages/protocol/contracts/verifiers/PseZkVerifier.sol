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

import "../4844/Lib4844.sol";
import "../common/EssentialContract.sol";
import "../thirdparty/optimism/Bytes.sol";
import "../L1/TaikoData.sol";
import "./IVerifier.sol";

/// @title PseZkVerifier
/// @notice See the documentation in {IVerifier}.
contract PseZkVerifier is EssentialContract, IVerifier {
    struct PointProof {
        bytes32 txListHash;
        uint256 pointValue;
        bytes1[48] pointCommitment;
        bytes1[48] pointProof;
    }

    struct ZkEvmProof {
        uint16 verifierId;
        bytes zkp;
        bytes pointProof;
    }

    uint256[50] private __gap;

    error L1_BLOB_NOT_USED();
    error L1_INVALID_PROOF();

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
        view
    {
        // Do not run proof verification to contest an existing proof
        if (ctx.isContesting) return;

        ZkEvmProof memory zkProof = abi.decode(proof.data, (ZkEvmProof));

        bytes32 txListHash;
        uint256 pointValue;
        if (ctx.blobUsed) {
            PointProof memory pf = abi.decode(zkProof.pointProof, (PointProof));

            txListHash = pf.txListHash;
            pointValue = pf.pointValue;

            Lib4844.evaluatePoint({
                blobHash: ctx.blobHash,
                x: calc4844PointEvalX(ctx.blobHash, pf.txListHash),
                y: pf.pointValue,
                commitment: pf.pointCommitment,
                pointProof: pf.pointProof
            });
        } else {
            if (zkProof.pointProof.length != 0) revert L1_BLOB_NOT_USED();

            txListHash = ctx.blobHash;
            pointValue = 0;
        }

        bytes32 instance = calcInstance({
            tran: tran,
            prover: ctx.prover,
            metaHash: ctx.metaHash,
            txListHash: txListHash,
            pointValue: pointValue
        });

        // Validate the instance using bytes utilities.
        bool verified = Bytes.equal(
            Bytes.slice(zkProof.zkp, 0, 32), bytes.concat(bytes16(0), bytes16(instance))
        );

        if (!verified) revert L1_INVALID_PROOF();

        verified = Bytes.equal(
            Bytes.slice(zkProof.zkp, 32, 32),
            bytes.concat(bytes16(0), bytes16(uint128(uint256(instance))))
        );
        if (!verified) revert L1_INVALID_PROOF();

        // Delegate to the ZKP verifier library to validate the proof.
        // Resolve the verifier's name and obtain its address.
        address verifierAddress = resolve(getVerifierName(zkProof.verifierId), false);

        // Call the verifier contract with the provided proof.
        bytes memory ret;
        (verified, ret) = verifierAddress.staticcall(bytes.concat(zkProof.zkp));

        // Check if the proof is valid.
        if (!verified) revert L1_INVALID_PROOF();
        if (ret.length != 32) revert L1_INVALID_PROOF();
        if (bytes32(ret) != keccak256("taiko")) revert L1_INVALID_PROOF();
    }

    function calc4844PointEvalX(
        bytes32 blobHash,
        bytes32 txListHash
    )
        public
        pure
        returns (uint256)
    {
        return uint256(keccak256(abi.encodePacked(blobHash, txListHash))) % Lib4844.BLS_MODULUS;
    }

    function calcInstance(
        TaikoData.Transition memory tran,
        address prover,
        bytes32 metaHash,
        bytes32 txListHash,
        uint256 pointValue
    )
        public
        pure
        returns (bytes32 instance)
    {
        return keccak256(
            abi.encode(
                tran.parentHash,
                tran.blockHash,
                tran.stateRoot,
                tran.graffiti,
                metaHash,
                prover,
                txListHash,
                pointValue
            )
        );
    }

    function getVerifierName(uint16 id) public pure returns (bytes32) {
        return bytes32(uint256(0x1000000) + id);
    }
}
