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
///   2. Proof verifier — implements `IProofVerifier`; recovers the signer of an 89-byte
///      `instance_id || address || signature` proof and checks it is a still-valid instance.
///
/// The proof wire format matches `SgxVerifier`, so a TDX prover can sit in any
/// `ComposeVerifier` slot that expects the SGX-style proof layout.
///
/// Side-channel protection: instances expire after `INSTANCE_EXPIRY`; re-attestation
/// produces a new keypair and a new `instance_id`.
/// @custom:security-contact security@taiko.xyz
contract AzureTdxVerifier is IProofVerifier, EssentialContract {
    /// @dev Each public-private key pair (Ethereum address) is generated inside the TDX VM
    /// at boot. The remote attestation flow binds that address to a verified image.
    struct Instance {
        address addr;
        uint64 validSince;
    }

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
    /// re-attest (which generates a fresh keypair and a new instance ID).
    uint64 public constant INSTANCE_EXPIRY = 365 days;

    /// @notice Delay between registration and an instance becoming valid for proof submission.
    /// Set to 0; non-zero values let governance pause newly-attested keys.
    uint64 public constant INSTANCE_VALIDITY_DELAY = 0;

    /// @notice L2 chain id bound to the proof's signature hash via `LibPublicInput`.
    uint64 public immutable taikoChainId;

    /// @notice The Automata DCAP attestation contract.
    address public immutable automataDcapAttestation;

    /// @dev Auto-incrementing instance ID counter. The proof's first 4 bytes reference an entry
    /// in `instances` by this ID for gas-efficient on-chain lookup.
    /// Slot 0.
    uint256 public nextInstanceId;

    /// @dev Registered TDX instances keyed by ID.
    /// Slot 1.
    mapping(uint256 instanceId => Instance instance) public instances;

    /// @dev Tracks every address that has ever been registered, so that a single attestation
    /// can't be replayed into multiple live instance IDs (which would bypass expiry).
    /// Slot 2.
    mapping(address instanceAddress => bool isAttested) public addressRegistered;

    /// @dev Used attestation nonces (prevent attestation replay).
    /// Slot 3.
    mapping(bytes32 nonceHash => bool isUsed) public nonceUsed;

    /// @dev Trusted measurement sets, keyed by index. Owner can register multiple sets to
    /// support multiple valid image versions in parallel.
    /// Slot 4.
    mapping(uint256 index => TrustedParams trustedParams) public trustedParams;

    uint256[45] private __gap;

    /// @notice Emitted when a new TDX instance is added to the registry.
    /// @param id The ID of the TDX instance.
    /// @param instance The address of the TDX instance.
    /// @param validSince The time since the instance is valid.
    event InstanceAdded(uint256 indexed id, address indexed instance, uint256 validSince);

    /// @notice Emitted when a TDX instance is deleted from the registry.
    /// @param id The ID of the TDX instance.
    /// @param instance The address of the TDX instance.
    event InstanceDeleted(uint256 indexed id, address indexed instance);

    /// @notice Emitted when trusted params are written or replaced at an index.
    event TrustedParamsUpdated(uint256 indexed index, TrustedParams params);

    constructor(uint64 _taikoChainId, address _automataDcapAttestation) {
        require(_taikoChainId != 0, TDX_INVALID_CHAIN_ID());
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
    /// @return ids The respective instanceId array for each address.
    function addInstances(address[] calldata _instances)
        external
        onlyOwner
        returns (uint256[] memory ids)
    {
        return _addInstances(_instances, true);
    }

    /// @notice Deletes TDX instances from the registry by ID.
    /// @param _ids The ids array of TDX instances.
    function deleteInstances(uint256[] calldata _ids) external onlyOwner {
        uint256 size = _ids.length;
        for (uint256 i; i < size; ++i) {
            uint256 idx = _ids[i];
            require(instances[idx].addr != address(0), TDX_INVALID_INSTANCE());

            emit InstanceDeleted(idx, instances[idx].addr);

            delete instances[idx];
        }
    }

    /// @notice Sets the trusted parameters for quote verification at a specific index.
    /// @dev Multiple indexes can hold different valid measurements at once (e.g. for staged
    /// image rollouts).
    /// @param _index The index of the trusted parameters
    /// @param _params The trusted parameters
    function setTrustedParams(uint256 _index, TrustedParams calldata _params) external onlyOwner {
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
    /// @return id The assigned instance ID.
    function registerInstance(
        uint256 _trustedParamsIdx,
        AzureTDX.VerifyParams memory _attestation
    )
        external
        returns (uint256 id)
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

        return _addInstances(addresses, false)[0];
    }

    /// @inheritdoc IProofVerifier
    /// @dev Proof layout (89 bytes): `instance_id` (4) || `instance` (20) || `signature` (65).
    /// Signature is over `LibPublicInput.hashPublicInputs(_commitmentHash, this, instance,
    /// taikoChainId)`; the recovered signer must equal `instance` and be a valid registered
    /// instance.
    function verifyProof(
        uint256, /* _proposalAge */
        bytes32 _commitmentHash,
        bytes calldata _proof
    )
        external
        view
    {
        require(_proof.length == 89, TDX_INVALID_PROOF());

        uint32 id = uint32(bytes4(_proof[:4]));
        address instance = address(bytes20(_proof[4:24]));
        require(_isInstanceValid(id, instance), TDX_INVALID_INSTANCE());

        bytes32 signatureHash = LibPublicInput.hashPublicInputs(
            _commitmentHash, address(this), instance, taikoChainId
        );

        bytes memory signature = _proof[24:];
        require(instance == ECDSA.recover(signatureHash, signature), TDX_INVALID_PROOF());
    }

    /// @notice Checks if an address is a currently-registered (non-expired) TDX instance.
    /// @param _instance The address to check
    /// @return True if the address has at least one live instance entry.
    function isInstanceRegistered(address _instance) external view returns (bool) {
        return addressRegistered[_instance];
    }

    // ---------------------------------------------------------------
    // Private functions
    // ---------------------------------------------------------------

    function _addInstances(
        address[] memory _instances,
        bool instantValid
    )
        private
        returns (uint256[] memory ids)
    {
        uint256 size = _instances.length;
        ids = new uint256[](size);

        uint64 validSince = uint64(block.timestamp);
        if (!instantValid) {
            validSince += INSTANCE_VALIDITY_DELAY;
        }

        for (uint256 i; i < size; ++i) {
            address addr = _instances[i];
            require(addr != address(0), TDX_INVALID_INSTANCE());
            require(!addressRegistered[addr], TDX_ALREADY_ATTESTED());

            addressRegistered[addr] = true;

            instances[nextInstanceId] = Instance(addr, validSince);
            ids[i] = nextInstanceId;

            emit InstanceAdded(nextInstanceId, addr, validSince);

            ++nextInstanceId;
        }
    }

    function _isInstanceValid(uint256 id, address instance) private view returns (bool) {
        if (instance == address(0)) return false;
        if (instance != instances[id].addr) return false;
        return instances[id].validSince <= block.timestamp
            && block.timestamp <= instances[id].validSince + INSTANCE_EXPIRY;
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
