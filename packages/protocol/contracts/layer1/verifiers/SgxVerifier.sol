// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "src/shared/common/EssentialContract.sol";
import "src/shared/libs/LibStrings.sol";
import "../automata-attestation/interfaces/IAttestation.sol";
import "../automata-attestation/lib/QuoteV3Auth/V3Struct.sol";
import "../based/ITaikoInbox.sol";
import "./LibPublicInput.sol";
import "./IVerifier.sol";

/// @title SgxVerifier
/// @notice This contract is the implementation of verifying SGX signature proofs
/// onchain.
/// @dev Please see references below:
/// - Reference #1: https://ethresear.ch/t/2fa-zk-rollups-using-sgx/14462
/// - Reference #2: https://github.com/gramineproject/gramine/discussions/1579
/// @custom:security-contact security@taiko.xyz
contract SgxVerifier is EssentialContract, IVerifier {
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

    uint64 public immutable taikoChainId;
    address public immutable taikoInbox;
    address public immutable taikoProofVerifier;
    address public immutable automataDcapAttestation;

    /// @dev For gas savings, we shall assign each SGX instance with an id that when we need to
    /// set a new pub key, just write storage once.
    /// Slot 1.
    uint256 public nextInstanceId;

    /// @dev One SGX instance is uniquely identified (on-chain) by it's ECDSA public key
    /// (or rather ethereum address). Once that address is used (by proof verification) it has to be
    /// overwritten by a new one (representing the same instance). This is due to side-channel
    /// protection. Also this public key shall expire after some time
    /// (for now it is a long enough 6 months setting).
    /// Slot 2.
    mapping(uint256 instanceId => Instance instance) public instances;

    /// @dev One address shall be registered (during attestation) only once, otherwise it could
    /// bypass this contract's expiry check by always registering with the same attestation and
    /// getting multiple valid instanceIds. While during proving, it is technically possible to
    /// register the old addresses, it is less of a problem, because the instanceId would be the
    /// same for those addresses and if deleted - the attestation cannot be reused anyways.
    /// Slot 3.
    mapping(address instanceAddress => bool alreadyAttested) public addressRegistered;

    uint256[47] private __gap;

    /// @notice Emitted when a new SGX instance is added to the registry, or replaced.
    /// @param id The ID of the SGX instance.
    /// @param instance The address of the SGX instance.
    /// @param replaced The address of the SGX instance that was replaced. If it is the first
    /// instance, this value is zero address.
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

    constructor(
        uint64 _taikoChainId,
        address _taikoInbox,
        address _taikoProofVerifier,
        address _automataDcapAttestation
    )
        EssentialContract(address(0))
    {
        taikoChainId = _taikoChainId;
        taikoInbox = _taikoInbox;
        taikoProofVerifier = _taikoProofVerifier;
        automataDcapAttestation = _automataDcapAttestation;
    }

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
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
    function deleteInstances(uint256[] calldata _ids)
        external
        onlyFromOwnerOrNamed(LibStrings.B_SGX_WATCHDOG)
    {
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
        (bool verified,) = IAttestation(automataDcapAttestation).verifyParsedQuote(_attestation);
        require(verified, SGX_INVALID_ATTESTATION());

        address[] memory addresses = new address[](1);
        addresses[0] = address(bytes20(_attestation.localEnclaveReport.reportData));

        return _addInstances(addresses, false)[0];
    }

    /// @inheritdoc IVerifier
    function verifyProof(
        Context[] calldata _ctxs,
        bytes calldata _proof
    )
        external
        onlyFromEither(taikoInbox, taikoProofVerifier)
    {
        // Size is: 109 bytes
        // 4 bytes + 20 bytes + 20 bytes + 65 bytes (signature) = 109
        require(_proof.length == 109, SGX_INVALID_PROOF());

        address oldInstance = address(bytes20(_proof[4:24]));
        address newInstance = address(bytes20(_proof[24:44]));

        // Collect public inputs
        uint256 size = _ctxs.length;
        bytes32[] memory publicInputs = new bytes32[](size + 2);
        // First public input is the current instance public key
        publicInputs[0] = bytes32(uint256(uint160(oldInstance)));
        publicInputs[1] = bytes32(uint256(uint160(newInstance)));

        // All other inputs are the block program public inputs (a single 32 byte value)
        for (uint256 i; i < size; ++i) {
            // TODO(Yue): For now this assumes the new instance public key to remain the same
            publicInputs[i + 2] = LibPublicInput.hashPublicInputs(
                _ctxs[i].transition, address(this), newInstance, _ctxs[i].metaHash, taikoChainId
            );
        }

        bytes32 signatureHash = keccak256(abi.encodePacked(publicInputs));
        // Verify the blocks
        bytes memory signature = _proof[44:];
        require(oldInstance == ECDSA.recover(signatureHash, signature), SGX_INVALID_PROOF());

        uint32 id = uint32(bytes4(_proof[:4]));
        require(_isInstanceValid(id, oldInstance), SGX_INVALID_INSTANCE());

        if (newInstance != oldInstance && newInstance != address(0)) {
            _replaceInstance(id, oldInstance, newInstance);
        }
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

    function _replaceInstance(uint256 id, address oldInstance, address newInstance) private {
        // Replacing an instance means, it went through a cooldown (if added by on-chain RA) so no
        // need to have a cooldown
        instances[id] = Instance(newInstance, uint64(block.timestamp));
        emit InstanceAdded(id, newInstance, oldInstance, block.timestamp);
    }

    function _isInstanceValid(uint256 id, address instance) private view returns (bool) {
        require(instance != address(0), SGX_INVALID_INSTANCE());
        require(instance == instances[id].addr, SGX_INVALID_INSTANCE());
        return instances[id].validSince <= block.timestamp
            && block.timestamp <= instances[id].validSince + INSTANCE_EXPIRY;
    }
}
