// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IProofVerifier } from "./IProofVerifier.sol";
import { LibPublicInput } from "./LibPublicInput.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { IAttestation } from "src/layer1/automata-attestation/interfaces/IAttestation.sol";
import { V3Struct } from "src/layer1/automata-attestation/lib/QuoteV3Auth/V3Struct.sol";

/// @title SgxVerifier
/// @notice Abstract base that verifies SGX signature proofs onchain using attested SGX instances.
/// Each instance is registered via remote attestation and can verify proofs until expiry. The
/// TCB-status acceptance policy is left abstract so that per-network subclasses define it (the
/// strict mainnet policy must remain the secure default).
/// @dev Side-channel protection is achieved through mandatory instance expiry (INSTANCE_EXPIRY),
/// requiring periodic re-attestation with new keypairs.
/// @custom:security-contact security@taiko.xyz
abstract contract SgxVerifier is IProofVerifier, Ownable2Step {
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

    /// @dev SGX ATTRIBUTES.FLAGS bits that a production application enclave must never set. In DCAP
    /// quote bytes the 16-byte ATTRIBUTES field is FLAGS (low 8 bytes, little-endian) followed by
    /// XFRM, so these FLAGS bits live in the first byte. Enforced uniformly on every network (it is
    /// NOT part of the per-network policy): such an enclave must never be trusted on-chain.
    /// DEBUG(0x02): the host can read/write enclave memory, so the in-enclave signing key is
    /// extractable.
    /// PROVISION_KEY(0x10): the enclave can derive platform-identifying provisioning keys.
    /// EINITTOKEN_KEY(0x20): the enclave can derive the launch-token key, a launch-enclave-only
    /// privilege an application enclave must never hold.
    /// Subclasses may pin the remaining bits per-MRENCLAVE via `_validateEnclaveAttributes`.
    bytes16 internal constant SGX_FORBIDDEN_ATTRIBUTE_MASK =
        bytes16(0x32000000000000000000000000000000);

    uint64 public immutable taikoChainId;
    address public immutable automataDcapAttestation;

    /// @notice The address authorized to register SGX instances via `registerInstance`.
    /// @dev If set to a non-zero address, only this address may call `registerInstance`.
    /// If set to `address(0)`, `registerInstance` is permissionless and callable by anyone.
    address public immutable registrar;

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

    uint256[47] private __gap;

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

    error SGX_ALREADY_ATTESTED();
    error SGX_INVALID_ATTESTATION();
    error SGX_INVALID_INSTANCE();
    error SGX_INVALID_PROOF();
    error SGX_INVALID_CHAIN_ID();
    error SGX_FORBIDDEN_ATTRIBUTES();
    error SGX_INVALID_TCB_STATUS();
    error SGX_NOT_REGISTRAR();

    constructor(
        uint64 _taikoChainId,
        address _owner,
        address _automataDcapAttestation,
        address _registrar
    ) {
        require(_taikoChainId != 0, SGX_INVALID_CHAIN_ID());
        taikoChainId = _taikoChainId;
        automataDcapAttestation = _automataDcapAttestation;
        registrar = _registrar;

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

    /// @notice Adds an SGX instance after the attestation is verified
    /// @param _attestation The parsed attestation quote.
    /// @return The respective instanceId
    function registerInstance(V3Struct.ParsedV3QuoteStruct calldata _attestation)
        external
        returns (uint256)
    {
        require(registrar == address(0) || msg.sender == registrar, SGX_NOT_REGISTRAR());

        (bool verified, bytes memory retData) =
            IAttestation(automataDcapAttestation).verifyParsedQuote(_attestation);
        require(verified, SGX_INVALID_ATTESTATION());

        // On a successful verification the attestation returns
        // retData = abi.encodePacked(sha256(quote), uint8 tcbStatus), so the platform TCB status is
        // the 33rd byte (offset 32). Enforce the per-network TCB-status policy on top of the
        // attestation's own acceptance check.
        require(retData.length >= 33, SGX_INVALID_ATTESTATION());
        require(isTcbStatusAccepted(uint8(retData[32])), SGX_INVALID_TCB_STATUS());

        require(
            _attestation.localEnclaveReport.attributes & SGX_FORBIDDEN_ATTRIBUTE_MASK == bytes16(0),
            SGX_FORBIDDEN_ATTRIBUTES()
        );

        // Per-network enclave-identity policy on top of the universal floor above. The strict
        // mainnet subclass pins the full ATTRIBUTES profile per allowlisted MRENCLAVE.
        _validateEnclaveAttributes(
            _attestation.localEnclaveReport.mrEnclave, _attestation.localEnclaveReport.attributes
        );

        address[] memory addresses = new address[](1);
        addresses[0] = address(bytes20(_attestation.localEnclaveReport.reportData));

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

    /// @notice Returns whether a platform TCB status is accepted by this verifier's network policy.
    /// @dev Defined by per-network subclasses. The platform TCB status is read from the attestation
    /// output and expressed against the attestation's `TCBInfoStruct.TCBStatus` enum, so the on-chain
    /// policy and the attestation cannot diverge and an enum reorder is caught at compile time. The
    /// strict mainnet policy must remain the secure default.
    /// @param _status The TCB status code from the attestation output.
    /// @return Whether the status is accepted.
    function isTcbStatusAccepted(uint8 _status) public pure virtual returns (bool);

    /// @dev Hook for an additional, per-network enclave-identity policy enforced during
    /// `registerInstance`, run after the universal forbidden-attribute floor. The base
    /// implementation is a no-op (the floor is the only attribute check) and is intended only for
    /// non-production (devnet) verifiers; production subclasses MUST override this to pin the full
    /// ATTRIBUTES profile per allowlisted MRENCLAVE. An override MUST revert to reject a
    /// registration. Parameters are the attested application-enclave measurement and its 16-byte
    /// ATTRIBUTES (FLAGS || XFRM) field, both authenticated by the attestation.
    function _validateEnclaveAttributes(bytes32, bytes16) internal view virtual { }

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
}
