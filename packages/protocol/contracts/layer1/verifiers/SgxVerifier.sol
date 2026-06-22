// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IProofVerifier } from "./IProofVerifier.sol";
import { LibPublicInput } from "./LibPublicInput.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { IDcapAttestation } from "./IDcapAttestation.sol";

/// @title SgxVerifier
/// @notice This contract verifies SGX signature proofs onchain using attested SGX instances.
/// Each instance is registered via remote attestation and can verify proofs until expiry.
/// @dev Side-channel protection is achieved through mandatory instance expiry (INSTANCE_EXPIRY),
/// requiring periodic re-attestation with new keypairs.
/// @custom:security-contact security@taiko.xyz
contract SgxVerifier is IProofVerifier, Ownable2Step {
    /// @dev Each public-private key pair (Ethereum address) is generated within
    /// the SGX program when it boots up. The off-chain remote attestation
    /// ensures the validity of the program hash and has the capability of
    /// bootstrapping the network with trustworthy instances.
    struct Instance {
        address addr;
        uint64 validSince;
    }

    /// @notice The expiry time for the SGX instance.
    uint64 public constant INSTANCE_EXPIRY = 365 days;

    /// @notice A security feature, a delay until an instance is enabled when using onchain RA
    /// verification
    uint64 public constant INSTANCE_VALIDITY_DELAY = 0;

    /// @dev Offset of the quote body within the Automata DCAP `Output`: quoteVersion (2) +
    /// quoteBodyType (2) + tcbStatus (1) + fmspc (6) = 11 bytes.
    uint256 private constant OUTPUT_BODY_OFFSET = 11;
    /// @dev `quoteBodyType` value identifying an SGX Enclave Report body.
    uint8 private constant SGX_QUOTE_BODY_TYPE = 1;
    /// @dev Length of an Intel SGX quote header.
    uint256 private constant HEADER_LENGTH = 48;
    /// @dev Length of an SGX Enclave Report body.
    uint256 private constant ENCLAVE_REPORT_LENGTH = 384;
    /// @dev MRENCLAVE offset within the raw quote (header + enclave-report offset 64).
    uint256 private constant MRENCLAVE_OFFSET = HEADER_LENGTH + 64;
    /// @dev MRSIGNER offset within the raw quote (header + enclave-report offset 128).
    uint256 private constant MRSIGNER_OFFSET = HEADER_LENGTH + 128;
    /// @dev reportData offset within the raw quote (header + enclave-report offset 320).
    uint256 private constant REPORT_DATA_OFFSET = HEADER_LENGTH + 320;

    uint64 public immutable taikoChainId;
    address public immutable automataDcapAttestation;

    /// @dev For gas savings, we assign each SGX instance with an ID to minimize storage operations.
    /// Slot 1.
    uint256 public nextInstanceId;

    /// @dev One SGX instance is uniquely identified (on-chain) by its ECDSA public key
    /// (or rather ethereum address). The instance address remains valid for INSTANCE_EXPIRY
    /// duration (365 days) to protect against side-channel attacks through forced key expiry.
    /// After expiry, the instance must be re-attested and registered with a new address.
    /// Slot 2.
    mapping(uint256 instanceId => Instance instance) public instances;

    /// @dev One address shall be registered (during attestation) only once, otherwise it could
    /// bypass this contract's expiry check by always registering with the same attestation and
    /// getting multiple valid instanceIds.
    /// Slot 3.
    mapping(address instanceAddress => bool alreadyAttested) public addressRegistered;

    /// @dev Relocated from the replaced AutomataDcapV3Attestation contract. The new Automata DCAP
    /// entrypoint verifies quote authenticity and TCB status but does NOT allowlist the application
    /// enclave's identity, so the trusted MRENCLAVE/MRSIGNER policy is enforced here to preserve the
    /// pre-migration security model.
    /// Slot 4.
    bool public checkLocalEnclaveReport;
    /// Slot 5.
    mapping(bytes32 mrEnclave => bool trusted) public trustedUserMrEnclave;
    /// Slot 6.
    mapping(bytes32 mrSigner => bool trusted) public trustedUserMrSigner;

    uint256[44] private __gap;

    /// @notice Emitted when a new SGX instance is added to the registry.
    /// @param id The ID of the SGX instance.
    /// @param instance The address of the SGX instance.
    /// @param replaced Reserved for future use (always zero address).
    /// @param validSince The time since the instance is valid.
    event InstanceAdded(
        uint256 indexed id, address indexed instance, address indexed replaced, uint256 validSince
    );

    /// @notice Emitted when an SGX instance is deleted from the registry.
    /// @param id The ID of the SGX instance.
    /// @param instance The address of the SGX instance.
    event InstanceDeleted(uint256 indexed id, address indexed instance);

    /// @notice Emitted when a trusted MRENCLAVE value is updated.
    /// @param mrEnclave The MRENCLAVE value.
    /// @param trusted Whether the value is trusted.
    event MrEnclaveUpdated(bytes32 indexed mrEnclave, bool trusted);

    /// @notice Emitted when a trusted MRSIGNER value is updated.
    /// @param mrSigner The MRSIGNER value.
    /// @param trusted Whether the value is trusted.
    event MrSignerUpdated(bytes32 indexed mrSigner, bool trusted);

    /// @notice Emitted when enforcement of the local enclave identity allowlist is toggled.
    /// @param checkLocalEnclaveReport Whether the allowlist is enforced.
    event LocalReportCheckToggled(bool checkLocalEnclaveReport);

    error SGX_ALREADY_ATTESTED();
    error SGX_INVALID_ATTESTATION();
    error SGX_INVALID_INSTANCE();
    error SGX_INVALID_PROOF();
    error SGX_INVALID_CHAIN_ID();

    constructor(uint64 _taikoChainId, address _owner, address _automataDcapAttestation) {
        require(_taikoChainId != 0, SGX_INVALID_CHAIN_ID());
        taikoChainId = _taikoChainId;
        automataDcapAttestation = _automataDcapAttestation;

        _transferOwnership(_owner);
    }

    /// @notice Adds trusted SGX instances to the registry.
    /// @param _instances The address array of trusted SGX instances.
    /// @return The respective instanceId array per addresses.
    function addInstances(address[] calldata _instances)
        external
        onlyOwner
        returns (uint256[] memory)
    {
        return _addInstances(_instances, true);
    }

    /// @notice Deletes SGX instances from the registry.
    /// @param _ids The ids array of SGX instances.
    function deleteInstances(uint256[] calldata _ids) external onlyOwner {
        uint256 size = _ids.length;
        for (uint256 i; i < size; ++i) {
            uint256 idx = _ids[i];

            require(instances[idx].addr != address(0), SGX_INVALID_INSTANCE());

            emit InstanceDeleted(idx, instances[idx].addr);

            delete instances[idx];
        }
    }

    /// @notice Sets whether a given MRENCLAVE is trusted for instance registration.
    /// @param _mrEnclave The MRENCLAVE value.
    /// @param _trusted Whether the value is trusted.
    function setMrEnclave(bytes32 _mrEnclave, bool _trusted) external onlyOwner {
        trustedUserMrEnclave[_mrEnclave] = _trusted;
        emit MrEnclaveUpdated(_mrEnclave, _trusted);
    }

    /// @notice Sets whether a given MRSIGNER is trusted for instance registration.
    /// @param _mrSigner The MRSIGNER value.
    /// @param _trusted Whether the value is trusted.
    function setMrSigner(bytes32 _mrSigner, bool _trusted) external onlyOwner {
        trustedUserMrSigner[_mrSigner] = _trusted;
        emit MrSignerUpdated(_mrSigner, _trusted);
    }

    /// @notice Toggles enforcement of the trusted MRENCLAVE/MRSIGNER allowlist.
    function toggleLocalReportCheck() external onlyOwner {
        checkLocalEnclaveReport = !checkLocalEnclaveReport;
        emit LocalReportCheckToggled(checkLocalEnclaveReport);
    }

    /// @notice Adds an SGX instance after remote attestation is verified fully on-chain.
    /// @dev Migrated to the Automata DCAP attestation entrypoint
    /// (`IDcapAttestation.verifyAndAttestOnChain`), which consumes a raw quote and reads Intel
    /// collateral from on-chain PCCS. The trusted MRENCLAVE/MRSIGNER allowlist and the TCB-status
    /// acceptance policy are enforced here (previously in AutomataDcapV3Attestation).
    /// @param _rawQuote The raw Intel DCAP v3 (SGX) attestation quote.
    /// @return The respective instanceId.
    function registerInstance(bytes calldata _rawQuote) external returns (uint256) {
        (bool verified, bytes memory output) =
            IDcapAttestation(automataDcapAttestation).verifyAndAttestOnChain(_rawQuote);
        require(verified, SGX_INVALID_ATTESTATION());

        // `output` is the serialized Automata `Output`; require a full SGX enclave report body.
        require(
            output.length >= OUTPUT_BODY_OFFSET + ENCLAVE_REPORT_LENGTH, SGX_INVALID_ATTESTATION()
        );
        // quoteBodyType is a big-endian uint16 at output[2:4]; 1 == SGX Enclave Report.
        require(
            uint8(output[2]) == 0 && uint8(output[3]) == SGX_QUOTE_BODY_TYPE,
            SGX_INVALID_ATTESTATION()
        );
        // Preserve the pre-migration TCB-status acceptance policy (output[4] == tcbStatus).
        require(_isTcbStatusAccepted(uint8(output[4])), SGX_INVALID_ATTESTATION());

        // On success, the authenticated enclave report body is rawQuote[HEADER_LENGTH:+384].
        require(
            _rawQuote.length >= HEADER_LENGTH + ENCLAVE_REPORT_LENGTH, SGX_INVALID_ATTESTATION()
        );

        // NOTE: the SGX DEBUG attribute (bit 1 of the `attributes` field at body offset 48, i.e.
        // _rawQuote[HEADER_LENGTH + 48]) is intentionally NOT checked here. This preserves the exact
        // pre-migration behavior; closing this gap is tracked as a follow-up (see VENDORED.md).

        if (checkLocalEnclaveReport) {
            bytes32 mrEnclave = bytes32(_rawQuote[MRENCLAVE_OFFSET:MRENCLAVE_OFFSET + 32]);
            bytes32 mrSigner = bytes32(_rawQuote[MRSIGNER_OFFSET:MRSIGNER_OFFSET + 32]);
            require(
                trustedUserMrEnclave[mrEnclave] && trustedUserMrSigner[mrSigner],
                SGX_INVALID_ATTESTATION()
            );
        }

        address[] memory addresses = new address[](1);
        addresses[0] = address(bytes20(_rawQuote[REPORT_DATA_OFFSET:REPORT_DATA_OFFSET + 20]));

        return _addInstances(addresses, false)[0];
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
        require(_proof.length == 89, SGX_INVALID_PROOF());

        uint32 id = uint32(bytes4(_proof[:4]));
        address instance = address(bytes20(_proof[4:24]));
        require(_isInstanceValid(id, instance), SGX_INVALID_INSTANCE());

        bytes32 signatureHash = LibPublicInput.hashPublicInputs(
            _aggregatedProvingHash, address(this), instance, taikoChainId
        );

        // Verify the signature was created by the registered instance
        bytes memory signature = _proof[24:];
        require(instance == ECDSA.recover(signatureHash, signature), SGX_INVALID_PROOF());
    }

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
            require(!addressRegistered[_instances[i]], SGX_ALREADY_ATTESTED());

            addressRegistered[_instances[i]] = true;

            require(_instances[i] != address(0), SGX_INVALID_INSTANCE());

            instances[nextInstanceId] = Instance(_instances[i], validSince);
            ids[i] = nextInstanceId;

            emit InstanceAdded(nextInstanceId, _instances[i], address(0), validSince);

            ++nextInstanceId;
        }
    }

    function _isInstanceValid(uint256 id, address instance) private view returns (bool) {
        require(instance != address(0), SGX_INVALID_INSTANCE());
        require(instance == instances[id].addr, SGX_INVALID_INSTANCE());
        return instances[id].validSince <= block.timestamp
            && block.timestamp <= instances[id].validSince + INSTANCE_EXPIRY;
    }

    /// @dev Preserves the TCB-status acceptance policy of the replaced AutomataDcapV3Attestation
    /// (`_attestationTcbIsValid`): accept OK, SW-hardening-needed, configuration-and-SW-hardening-
    /// needed, out-of-date, and out-of-date-configuration-needed; reject configuration-needed,
    /// revoked, and unrecognized. Codes follow Automata's TCBStatus enumeration.
    /// @param _status The TCB status code from the attestation output.
    /// @return Whether the status is accepted.
    function _isTcbStatusAccepted(uint8 _status) private pure returns (bool) {
        return _status == 0 // OK
            || _status == 1 // TCB_SW_HARDENING_NEEDED
            || _status == 2 // TCB_CONFIGURATION_AND_SW_HARDENING_NEEDED
            || _status == 4 // TCB_OUT_OF_DATE
            || _status == 5; // TCB_OUT_OF_DATE_CONFIGURATION_NEEDED
    }
}
