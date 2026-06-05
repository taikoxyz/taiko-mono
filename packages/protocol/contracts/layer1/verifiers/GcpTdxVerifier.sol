// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IProofVerifier } from "./IProofVerifier.sol";
import { LibPublicInput } from "./LibPublicInput.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { BytesUtils } from "src/layer1/automata-attestation/utils/BytesUtils.sol";
import { EssentialContract } from "src/shared/common/EssentialContract.sol";

/// @title IAutomataDcapAttestation
/// @notice Interface for Automata DCAP attestation verification.
interface IAutomataDcapAttestation {
    function verifyAndAttestOnChain(bytes calldata rawQuote)
        external
        payable
        returns (bool, bytes memory);
}

/// @title GcpTdxVerifier
/// @notice Registry + proof verifier for **native** Intel TDX DCAP-attested provers
///         (GCP Confidential VMs and bare-metal TDX), as opposed to the Azure vTPM
///         flow handled by `AzureTdxVerifier`.
/// @dev Differences from `AzureTdxVerifier`:
///   - The prover submits a *raw* Intel TDX DCAP quote (read straight from
///     `/dev/tdx_guest` via configfs-tsm by `tdxs`), with no Azure vTPM envelope to
///     unwrap. So there is no `AzureTDX.verify` pre-step.
///   - Boot integrity is measured by the TDX quote's **RTMR0..3** (runtime
///     measurement registers) rather than Azure vTPM PCRs.
///   - The prover address is bound by the quote's 64-byte `reportData`:
///     `sha256(userData || nonce)` (matching `tdxs`/Constellation `MakeExtraData`),
///     where `userData` carries the prover address in its first 20 bytes.
///
/// The proof wire format is 85 bytes: `address(20) || signature(65)`. There is no
/// instance index — validity is looked up directly by address via `addressValidSince`,
/// which eliminates the need for provers to know their on-chain slot ID.
/// @custom:security-contact security@taiko.xyz
contract GcpTdxVerifier is IProofVerifier, EssentialContract {
    /// @dev Hardware measurements an attestation must match for `registerInstance` to
    /// admit a prover. `rtmrMask` selects which of RTMR0..3 are enforced (RTMR3 is
    /// often runtime-variable and may be excluded); `rtmrs` holds one 48-byte digest
    /// per set bit, in ascending index order.
    struct TrustedParams {
        bytes16 teeTcbSvn;
        uint8 rtmrMask;
        bytes mrSeam;
        bytes mrTd;
        bytes[] rtmrs;
    }

    /// @notice Expiry window for a registered TDX instance. After this, the instance must
    /// re-attest (which generates a fresh keypair).
    uint64 public constant INSTANCE_EXPIRY = 365 days;

    /// @notice Delay between registration and an instance becoming valid for proof
    /// submission. Set to 0; non-zero values let governance pause newly-attested keys.
    uint64 public constant INSTANCE_VALIDITY_DELAY = 0;

    /// @dev Byte offsets into the Automata DCAP V4 output (header 11 bytes:
    /// quoteVersion(2) || quoteBodyType(2) || tcbStatus(1) || fmspc(6), then the TD10
    /// report body). Same body layout `AzureTdxVerifier` relies on.
    uint256 private constant OFF_TEE_TCB_SVN = 11; // 16 bytes
    uint256 private constant OFF_MR_SEAM = 27; // 48 bytes
    uint256 private constant OFF_MR_TD = 147; // 48 bytes
    uint256 private constant OFF_RTMR0 = 339; // 48 bytes; RTMR_i = OFF_RTMR0 + 48*i
    uint256 private constant OFF_REPORT_DATA = 531; // 64 bytes
    uint256 private constant RTMR_LEN = 48;

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
    event InstanceAdded(address indexed instance, uint256 validSince);

    /// @notice Emitted when a TDX instance is deleted from the registry.
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
    /// @param _owner The owner of this contract. msg.sender will be used if this is zero.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    // ---------------------------------------------------------------
    // Owner only functions
    // ---------------------------------------------------------------

    /// @notice Adds trusted TDX instances to the registry without attestation.
    /// @dev Bypasses on-chain attestation; intended for genesis / governance recovery only.
    function addInstances(address[] calldata _instances) external onlyOwner {
        _addInstances(_instances, true);
    }

    /// @notice Deletes TDX instances from the registry by address.
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
    /// @dev `rtmrs` must contain exactly one 48-byte digest per set bit in `rtmrMask`.
    function setTrustedParams(uint256 _index, TrustedParams calldata _params) external onlyOwner {
        require(_params.rtmrMask < 16, TDX_INVALID_TRUSTED_PARAMS());
        require(_params.rtmrs.length == _popcount4(_params.rtmrMask), TDX_INVALID_TRUSTED_PARAMS());
        trustedParams[_index] = _params;
        emit TrustedParamsUpdated(_index, _params);
    }

    // ---------------------------------------------------------------
    // External permissionless functions
    // ---------------------------------------------------------------

    /// @notice Registers a TDX instance after verifying its native DCAP attestation.
    /// @dev Flow:
    ///   1. Submit the raw DCAP quote to Automata DCAP for on-chain verification.
    ///   2. Compare the parsed TD report body against `trustedParams[_trustedParamsIdx]`
    ///      (teeTcbSvn, mrSeam, mrTd, and the masked RTMRs).
    ///   3. Bind the prover identity: require quote `reportData == sha256(userData||nonce)`.
    ///   4. Mark the nonce used (prevents quote replay).
    ///   5. Extract the prover address from `userData[0:20]` and add it to the registry.
    /// @param _trustedParamsIdx The trusted-params index to validate against.
    /// @param _rawQuote The raw Intel TDX DCAP (V4) quote bytes.
    /// @param _userData The attested user data; first 20 bytes are the prover address.
    /// @param _nonce The attestation nonce bound into the quote's reportData.
    function registerInstance(
        uint256 _trustedParamsIdx,
        bytes calldata _rawQuote,
        bytes calldata _userData,
        bytes calldata _nonce
    )
        external
    {
        (bool verified, bytes memory output) =
            IAutomataDcapAttestation(automataDcapAttestation).verifyAndAttestOnChain(_rawQuote);
        require(verified, TDX_INVALID_ATTESTATION());

        TrustedParams memory params = trustedParams[_trustedParamsIdx];
        require(params.mrTd.length != 0, TDX_INVALID_TRUSTED_PARAMS());
        _validateAttestationOutput(output, params);

        // Bind the prover identity to the quote: the quote's 64-byte reportData carries
        // sha256(userData || nonce) in its leading 32 bytes (matches tdxs/Constellation
        // MakeExtraData, and the surge TdxVerifier reference impl).
        require(_userData.length >= 20, TDX_INVALID_REPORT_DATA());
        bytes memory reportData = BytesUtils.substring(output, OFF_REPORT_DATA, 64);
        bytes32 expected = sha256(bytes.concat(_userData, _nonce));
        require(bytes32(reportData) == expected, TDX_INVALID_REPORT_DATA());

        bytes32 nonceHash = keccak256(_nonce);
        require(!nonceUsed[nonceHash], TDX_INVALID_ATTESTATION());
        nonceUsed[nonceHash] = true;

        address[] memory addresses = new address[](1);
        addresses[0] = address(bytes20(_userData[0:20]));

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

        bytes32 signatureHash =
            LibPublicInput.hashPublicInputs(_commitmentHash, address(this), instance, taikoChainId);

        bytes memory signature = _proof[20:];
        require(instance == ECDSA.recover(signatureHash, signature), TDX_INVALID_PROOF());
    }

    /// @notice Checks if an address is a currently-registered (non-expired) TDX instance.
    function isInstanceRegistered(address _instance) external view returns (bool) {
        return _isInstanceValid(_instance);
    }

    // ---------------------------------------------------------------
    // Private functions
    // ---------------------------------------------------------------

    function _addInstances(
        address[] memory _instances,
        bool instantValid
    )
        private
    {
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

    function _popcount4(uint8 _bitmap) private pure returns (uint256 count) {
        for (uint256 i; i < 4; ++i) {
            if (_bitmap & (1 << i) != 0) ++count;
        }
    }

    function _validateAttestationOutput(
        bytes memory _attestationOutput,
        TrustedParams memory _params
    )
        private
        pure
    {
        // Automata DCAP V4 output: quoteVersion(2) || quoteBodyType(2) || tcbStatus(1)
        // || fmspc(6) || quoteBody. quoteVersion == 4, quoteBodyType == 2 (TD10 body).
        uint16 qVersion = uint16(bytes2(BytesUtils.substring(_attestationOutput, 0, 2)));
        uint16 qBodyType = uint16(bytes2(BytesUtils.substring(_attestationOutput, 2, 2)));
        require(qVersion == 4 && qBodyType == 2, TDX_INVALID_VERSION_TYPE());

        bytes16 teeTcbSvn = bytes16(BytesUtils.substring(_attestationOutput, OFF_TEE_TCB_SVN, 16));
        require(teeTcbSvn == _params.teeTcbSvn, TDX_INVALID_TCB_SVN());

        bytes memory mrSeam = BytesUtils.substring(_attestationOutput, OFF_MR_SEAM, 48);
        require(mrSeam.length == _params.mrSeam.length, TDX_INVALID_MR_SEAM());
        require(keccak256(mrSeam) == keccak256(_params.mrSeam), TDX_INVALID_MR_SEAM());

        bytes memory mrTd = BytesUtils.substring(_attestationOutput, OFF_MR_TD, 48);
        require(mrTd.length == _params.mrTd.length, TDX_INVALID_MR_TD());
        require(keccak256(mrTd) == keccak256(_params.mrTd), TDX_INVALID_MR_TD());

        // Enforce the RTMRs selected by rtmrMask (in ascending index order), each 48 bytes.
        uint256 rtmrIdx;
        for (uint256 i; i < 4; ++i) {
            if (_params.rtmrMask & (1 << i) != 0) {
                bytes memory rtmr =
                    BytesUtils.substring(_attestationOutput, OFF_RTMR0 + RTMR_LEN * i, RTMR_LEN);
                require(keccak256(rtmr) == keccak256(_params.rtmrs[rtmrIdx]), TDX_INVALID_RTMR());
                ++rtmrIdx;
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
    error TDX_INVALID_PROOF();
    error TDX_INVALID_REPORT_DATA();
    error TDX_INVALID_RTMR();
    error TDX_INVALID_TCB_SVN();
    error TDX_INVALID_TRUSTED_PARAMS();
    error TDX_INVALID_VERSION_TYPE();
}
