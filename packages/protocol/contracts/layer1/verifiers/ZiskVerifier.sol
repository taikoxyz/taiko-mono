// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IProofVerifier } from "./IProofVerifier.sol";
import { LibPublicInput } from "./LibPublicInput.sol";
import { IZiskVerifier } from "./zisk-vendor/IZiskVerifier.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @title ZiskVerifier
/// @custom:security-contact security@taiko.xyz
contract ZiskVerifier is IProofVerifier, Ownable2Step {
    uint64 public immutable taikoChainId;
    address public immutable ziskRemoteVerifier;

    /// @notice Zisk protocol root constant (version-specific, e.g. Zisk v0.16.0).
    /// @dev Must be updated when the Zisk proving system version changes.
    uint64[4] public rootCVadcopFinal;

    /// @notice The verification keys mappings for the proving programs.
    mapping(bytes32 programVKey => bool trusted) public isProgramTrusted;

    /// @dev Emitted when a trusted program is set / unset.
    /// @param programVKey The verification key of the program.
    /// @param trusted Whether the program is trusted.
    event ProgramTrusted(bytes32 programVKey, bool trusted);

    error ZISK_INVALID_PROGRAM_VKEY();
    error ZISK_INVALID_CHAIN_ID();
    error ZISK_INVALID_REMOTE_VERIFIER();
    error ZISK_INVALID_PARAMS();
    error ZISK_INVALID_PROOF();

    error ZISK_INVALID_ROOT_CV();

    constructor(
        uint64 _taikoChainId,
        address _ziskRemoteVerifier,
        uint64[4] memory _rootCVadcopFinal,
        address _owner
    ) {
        require(_taikoChainId > 1, ZISK_INVALID_CHAIN_ID());
        require(_ziskRemoteVerifier != address(0), ZISK_INVALID_REMOTE_VERIFIER());
        require(
            _rootCVadcopFinal[0] | _rootCVadcopFinal[1] | _rootCVadcopFinal[2]
                | _rootCVadcopFinal[3] != 0,
            ZISK_INVALID_ROOT_CV()
        );
        taikoChainId = _taikoChainId;
        ziskRemoteVerifier = _ziskRemoteVerifier;
        rootCVadcopFinal = _rootCVadcopFinal;

        _transferOwnership(_owner);
    }

    /// @notice Sets/unsets a program's verification key as trusted entity
    /// @param _programVKey The verification key of the program.
    /// @param _trusted True if trusted, false otherwise.
    function setProgramTrusted(bytes32 _programVKey, bool _trusted) external onlyOwner {
        isProgramTrusted[_programVKey] = _trusted;
        emit ProgramTrusted(_programVKey, _trusted);
    }

    /// @inheritdoc IProofVerifier
    function verifyProof(
        uint256, /* _proposalAge */
        bytes32 _aggregatedProvingHash,
        bytes calldata _proof
    )
        external
        view
    {
        // Minimum: 32 bytes (programVKey) + at least 1 byte of proof data.
        // The remote verifier performs full proof validation; this is a basic sanity check.
        require(_proof.length > 32, ZISK_INVALID_PARAMS());

        // Extract the program VKey
        bytes32 programVKey = bytes32(_proof[0:32]);

        // Check if the program is trusted
        require(isProgramTrusted[programVKey], ZISK_INVALID_PROGRAM_VKEY());

        bytes32 publicInput = LibPublicInput.hashPublicInputs(
            _aggregatedProvingHash, address(this), address(0), taikoChainId
        );

        // Unpack program VKey from bytes32 to uint64[4]
        uint64[4] memory programVK = _unpackVKey(programVKey);

        bytes32[] memory padding = new bytes32[](7);

        // _proof[32:] is the Zisk PLONK proof
        (bool success,) = ziskRemoteVerifier.staticcall(
            abi.encodeCall(
                IZiskVerifier.verifySnarkProof,
                (
                    programVK,
                    rootCVadcopFinal,
                    // ZISK expects right padding upto 256 bytes
                    abi.encodePacked(publicInput, padding),
                    _proof[32:]
                )
            )
        );

        require(success, ZISK_INVALID_PROOF());
    }

    /// @dev Unpacks a bytes32 into uint64[4] (big-endian packed)
    function _unpackVKey(bytes32 _packed) internal pure returns (uint64[4] memory vkey_) {
        vkey_[0] = uint64(bytes8(_packed));
        vkey_[1] = uint64(bytes8(_packed << 64));
        vkey_[2] = uint64(bytes8(_packed << 128));
        vkey_[3] = uint64(bytes8(_packed << 192));
    }
}
