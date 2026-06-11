// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IProofVerifier } from "./IProofVerifier.sol";
import { LibPublicInput } from "./LibPublicInput.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { AzureTDX } from "azure-tdx-verifier/AzureTDX.sol";
import { BytesUtils } from "src/layer1/automata-attestation/utils/BytesUtils.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";

/// @title IAutomataDcapAttestation
/// @notice Interface for Automata DCAP attestation verification
interface IAutomataDcapAttestation {
    function verifyAndAttestOnChain(bytes calldata rawQuote)
        external
        payable
        returns (bool, bytes memory);
}

/// @title AzureTdxVerifier
/// @notice Registry + proof verifier for Azure TDX-attested provers.
/// @dev Combines two responsibilities:
///   1. Registry — admits TDX instances after on-chain attestation (Azure vTPM + Automata DCAP)
///      with measurement checks against `trustedParams`.
///   2. Proof verifier — implements `IProofVerifier`; recovers the signer of an 85-byte
///      `address || signature` proof and checks it is a still-valid instance.
///
/// The proof wire format is 85 bytes: `address(20) || signature(65)`. There is no
/// instance index — validity is looked up directly by address via `addressValidSince`.
/// @custom:security-contact security@taiko.xyz
contract AzureTdxVerifier is IProofVerifier, EssentialContract {
    /// @dev Parameters describing a "trusted" TDX image — the hardware measurements an
    /// attestation must match for `registerInstance` to admit the prover.
    struct TrustedParams {
        bytes16 teeTcbSvn;
        uint24 pcrBitmap;
        bytes mrSeam;
        bytes mrTd;
        bytes32[] pcrs;
    }

    /// @notice Expiry window for a registered TDX instance. After this, the instance must
    /// re-attest (which generates a fresh keypair).
    uint64 public constant INSTANCE_EXPIRY = 365 days;

    /// @notice Delay between registration and an instance becoming valid for proof submission.
    /// Set to 0; non-zero values let governance pause newly-attested keys.
    uint64 public constant INSTANCE_VALIDITY_DELAY = 0;

    /// @notice L2 chain id bound to the proof's signature hash via `LibPublicInput`.
    uint64 public immutable taikoChainId;

    /// @notice The Automata DCAP attestation contract.
    address public immutable automataDcapAttestation;

    /// @dev Timestamp from which a registered address is valid. A zero value means the
    /// address is not registered. Slot 0.
    mapping(address instanceAddress => uint64 validSince) public addressValidSince;

    /// @dev Used attestation nonces (prevent attestation replay). Slot 1.
    mapping(bytes32 nonceHash => bool isUsed) public nonceUsed;

    /// @dev Trusted measurement sets, keyed by index. Owner can register multiple sets to
    /// support multiple valid image versions in parallel. Slot 2.
    mapping(uint256 index => TrustedParams trustedParams) public trustedParams;

    uint256[47] private __gap;

    /// @notice Emitted when a new TDX instance is added to the registry.
    /// @param instance The address of the TDX instance.
    /// @param validSince The time since the instance is valid.
    event InstanceAdded(address indexed instance, uint256 validSince);

    /// @notice Emitted when a TDX instance is deleted from the registry.
    /// @param instance The address of the TDX instance.
    event InstanceDeleted(address indexed instance);

    /// @notice Emitted when trusted params are written or replaced at an index.
    event TrustedParamsUpdated(uint256 indexed index, TrustedParams params);

    constructor(uint64 _taikoChainId, address _automataDcapAttestation) {
        require(_taikoChainId != 0, TDX_INVALID_CHAIN_ID());
        require(_automataDcapAttestation != address(0), TDX_INVALID_AUTOMATA_DCAP());
        taikoChainId = _taikoChainId;
        automataDcapAttestation = _automataDcapAttestation;
    }

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    // ---------------------------------------------------------------
    // Owner only functions
    // ---------------------------------------------------------------

    /// @notice Adds trusted TDX instances to the registry without attestation.
    /// @dev Bypasses on-chain attestation; intended for genesis / governance recovery only.
    /// Use `registerInstance` for normal flow.
    /// @param _instances The address array of trusted TDX instances.
    function addInstances(address[] calldata _instances) external onlyOwner {
        _addInstances(_instances, true);
    }

    /// @notice Deletes TDX instances from the registry by address.
    /// @param _instances The address array of TDX instances to delete.
    function deleteInstances(address[] calldata _instances) external onlyOwner {
        uint256 size = _instances.length;
        for (uint256 i; i < size; ++i) {
            address addr = _instances[i];
            require(addressValidSince[addr] != 0, TDX_INVALID_INSTANCE());
            emit InstanceDeleted(addr);
            delete addressValidSince[addr];
        }
    }

    /// @notice Sets the trusted parameters for quote verification at a specific index.
    /// @dev Multiple indexes can hold different valid measurements at once (e.g. for staged
    /// image rollouts).
    /// @param _index The index of the trusted parameters
    /// @param _params The trusted parameters
    function setTrustedParams(
        uint256 _index,
        TrustedParams calldata _params
    )
        external
        onlyOwner
    {
        // pcrs must contain exactly one digest per set bit in pcrBitmap; otherwise
        // _validateAttestationOutput would revert with an out-of-bounds access at registration.
        require(_params.pcrs.length == _popcount24(_params.pcrBitmap), TDX_INVALID_TRUSTED_PARAMS());
        trustedParams[_index] = _params;
        emit TrustedParamsUpdated(_index, _params);
    }

    // ---------------------------------------------------------------
    // External permissionless functions
    // ---------------------------------------------------------------

    /// @notice Registers a TDX instance after verifying its attestation.
    /// @dev Flow:
    ///   1. Pass the Azure attestation through `AzureTDX.verify` (vTPM checks) to produce the
    ///      raw DCAP quote bytes.
    ///   2. Submit the quote to Automata DCAP for on-chain verification.
    ///   3. Compare the parsed quote body against `trustedParams[_trustedParamsIdx]`.
    ///   4. Mark the nonce as used (prevents quote replay).
    ///   5. Extract the prover's Ethereum address from `userData` and add it to the registry.
    /// @param _trustedParamsIdx The index of the trusted parameters set to validate against.
    /// @param _attestation The Azure TDX attestation verification parameters.
    function registerInstance(
        uint256 _trustedParamsIdx,
        AzureTDX.VerifyParams memory _attestation
    )
        external
    {
        (bool verified, bytes memory output) = IAutomataDcapAttestation(automataDcapAttestation)
            .verifyAndAttestOnChain(AzureTDX.verify(_attestation));
        require(verified, TDX_INVALID_ATTESTATION());

        TrustedParams memory params = trustedParams[_trustedParamsIdx];
        require(params.pcrBitmap != 0, TDX_INVALID_TRUSTED_PARAMS());
        _validateAttestationOutput(output, _attestation, params);

        bytes32 nonceHash = keccak256(_attestation.nonce);
        require(!nonceUsed[nonceHash], TDX_INVALID_ATTESTATION());
        nonceUsed[nonceHash] = true;

        address[] memory addresses = new address[](1);
        addresses[0] = address(bytes20(_attestation.attestationDocument.userData));

        _addInstances(addresses, false);
    }

    /// @inheritdoc IProofVerifier
    /// @dev Proof layout (85 bytes): `instance` (20) || `signature` (65).
    function verifyProof(
        uint256, /* _proposalAge */
        bytes32 _commitmentHash,
        bytes calldata _proof
    )
        external
        view
    {
        require(_proof.length == 85, TDX_INVALID_PROOF());

        address instance = address(bytes20(_proof[:20]));
        require(_isInstanceValid(instance), TDX_INVALID_INSTANCE());

        bytes32 signatureHash = LibPublicInput.hashPublicInputs(
            _commitmentHash, address(this), instance, taikoChainId
        );

        bytes memory signature = _proof[20:];
        require(instance == ECDSA.recover(signatureHash, signature), TDX_INVALID_PROOF());
    }

    /// @notice Checks if an address is a currently-registered (non-expired) TDX instance.
    /// @param _instance The address to check
    /// @return True if the address has a live (registered, non-expired, not deleted) instance.
    function isInstanceRegistered(address _instance) external view returns (bool) {
        return _isInstanceValid(_instance);
    }

    // ---------------------------------------------------------------
    // Private functions
    // ---------------------------------------------------------------

    function _addInstances(address[] memory _instances, bool instantValid) private {
        uint256 size = _instances.length;

        uint64 validSince = uint64(block.timestamp);
        if (!instantValid) {
            validSince += INSTANCE_VALIDITY_DELAY;
        }

        for (uint256 i; i < size; ++i) {
            address addr = _instances[i];
            require(addr != address(0), TDX_INVALID_INSTANCE());
            require(addressValidSince[addr] == 0, TDX_ALREADY_ATTESTED());

            addressValidSince[addr] = validSince;

            emit InstanceAdded(addr, validSince);
        }
    }

    function _isInstanceValid(address instance) private view returns (bool) {
        if (instance == address(0)) return false;
        uint64 vs = addressValidSince[instance];
        if (vs == 0) return false;
        return vs <= block.timestamp && block.timestamp <= vs + INSTANCE_EXPIRY;
    }

    function _popcount24(uint24 _bitmap) private pure returns (uint256 count) {
        for (uint256 i; i < 24; ++i) {
            if (_bitmap & (1 << i) != 0) ++count;
        }
    }

    function _validateAttestationOutput(
        bytes memory _attestationOutput,
        AzureTDX.VerifyParams memory _attestation,
        TrustedParams memory _params
    )
        private
        pure
    {
        // Automata DCAP V4 output format: quoteVersion(2) || quoteBodyType(2) || tcbStatus(1) || fmspc(6) || quoteBody
        // quoteVersion == 4 (TDX V4 quote), quoteBodyType == 2 (TD10 Report Body)
        uint16 qVersion = uint16(bytes2(BytesUtils.substring(_attestationOutput, 0, 2)));
        uint16 qBodyType = uint16(bytes2(BytesUtils.substring(_attestationOutput, 2, 2)));
        require(qVersion == 4 && qBodyType == 2, TDX_INVALID_VERSION_TYPE());

        bytes16 teeTcbSvn = bytes16(BytesUtils.substring(_attestationOutput, 11, 16));
        require(teeTcbSvn == _params.teeTcbSvn, TDX_INVALID_TCB_SVN());

        bytes memory mrSeam = BytesUtils.substring(_attestationOutput, 27, 48);
        require(mrSeam.length == _params.mrSeam.length, TDX_INVALID_MR_SEAM());
        require(keccak256(mrSeam) == keccak256(_params.mrSeam), TDX_INVALID_MR_SEAM());

        bytes memory mrTd = BytesUtils.substring(_attestationOutput, 147, 48);
        require(mrTd.length == _params.mrTd.length, TDX_INVALID_MR_TD());
        require(keccak256(mrTd) == keccak256(_params.mrTd), TDX_INVALID_MR_TD());

        bytes32[] memory pcrs = new bytes32[](24);
        for (uint256 i; i < _attestation.pcrs.length; ++i) {
            pcrs[_attestation.pcrs[i].index] = _attestation.pcrs[i].digest;
        }

        uint256 pcrIdx;
        for (uint256 i; i < 24; ++i) {
            if (_params.pcrBitmap & (1 << i) != 0) {
                require(pcrs[i] == _params.pcrs[pcrIdx], TDX_INVALID_PCR());
                ++pcrIdx;
            }
        }
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error TDX_ALREADY_ATTESTED();
    error TDX_INVALID_ATTESTATION();
    error TDX_INVALID_AUTOMATA_DCAP();
    error TDX_INVALID_CHAIN_ID();
    error TDX_INVALID_INSTANCE();
    error TDX_INVALID_MR_SEAM();
    error TDX_INVALID_MR_TD();
    error TDX_INVALID_PCR();
    error TDX_INVALID_PROOF();
    error TDX_INVALID_TCB_SVN();
    error TDX_INVALID_TRUSTED_PARAMS();
    error TDX_INVALID_VERSION_TYPE();
}
