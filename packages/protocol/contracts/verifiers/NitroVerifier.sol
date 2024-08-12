// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "oyster-contracts/AttestationVerifier.sol";
import "../L1/ITaikoL1.sol";
import "./IVerifier.sol";

contract NitroVerifier is AttestationVerifier, IVerifier {
    /// @dev Each public-private key pair (Ethereum address) is generated within
    /// the program when it boots up. The off-chain remote attestation
    /// ensures the validity of the program hash and has the capability of
    /// bootstrapping the network with trustworthy instances.
    struct Instance {
        address addr;
        uint64 validSince;
    }

    /// @notice The expiry time for the Nitro instance.
    uint64 public constant INSTANCE_EXPIRY = 365 days;

    /// @notice A security feature, a delay until an instance is enabled when using onchain RA
    /// verification
    uint64 public constant INSTANCE_VALIDITY_DELAY = 0;

    /// @dev One Nitro instance is uniquely identified (on-chain) by it's ECDSA public key
    /// (or rather ethereum address). Once that address is used (by proof verification) it has to be
    /// overwritten by a new one (representing the same instance). This is due to side-channel
    /// protection. Also this public key shall expire after some time
    /// TODO: Verify -> (for now it is a long enough 6 months setting).
    /// Slot 1.
    mapping(uint256 instanceId => Instance instance) public instances;

    /// @dev One address shall be registered (during attestation) only once, otherwise it could
    /// bypass this contract's expiry check by always registering with the same attestation and
    /// getting multiple valid instanceIds. While during proving, it is technically possible to
    /// register the old addresses, it is less of a problem, because the instanceId would be the
    /// same for those addresses and if deleted - the attestation cannot be reused anyways.
    /// Slot 2.
    mapping(address instanceAddress => bool alreadyAttested) public addressRegistered;

    uint256[47] private __gap;

    /// @notice Emitted when a new Nitro instance is added to the registry, or replaced.
    /// @param id The ID of the Nitro instance.
    /// @param instance The address of the Ntiro instance.
    /// @param replaced The address of the Ntiro instance that was replaced. If it is the first
    /// instance, this value is zero address.
    /// @param validSince The time since the instance is valid.
    event InstanceAdded(
        uint256 indexed id, address indexed instance, address indexed replaced, uint256 validSince
    );

    /// @notice Emitted when an Nitro instance is deleted from the registry.
    /// @param id The ID of the Nitro instance.
    /// @param instance The address of the Ntiro instance.
    event InstanceDeleted(uint256 indexed id, address indexed instance);

    error NITRO_ALREADY_ATTESTED();
    error NITRO_INVALID_ATTESTATION();
    error NITRO_INVALID_INSTANCE();
    error NITRO_INVALID_PROOF();

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    /// @param _rollupAddressManager The address of the {AddressManager} contract.
    function init(address _owner, address _rollupAddressManager) external initializer {
        __Essential_init(_owner, _rollupAddressManager);
    }

    /// @notice Deletes Nitro instances from the registry.
    /// @param _ids The ids array of Nitro instances.
    function deleteInstances(uint256[] calldata _ids) external {
        for (uint256 i; i < _ids.length; ++i) {
            uint256 idx = _ids[i];

            if (instances[idx].addr == address(0)) {
                revert NITRO_INVALID_INSTANCE();
            }

            emit InstanceDeleted(idx, instances[idx].addr);

            delete instances[idx];
        }
    }

    /// @notice Adds an Nitro instance after the attestation is verified
    /// @param signature The Oyster enclave signature of the attestation quote.
    /// @param attestation The parsed attestation quote.
    /// @return The respective instanceId
    function registerInstance(
        bytes calldata signature,
        Attestation calldata attestation
    )
        external
        returns (uint256)
    {
        (bool verified,) = IAttestation(automataDcapAttestation).verifyParsedQuote(_attestation);

        if (!verified) revert SGX_INVALID_ATTESTATION();

        address[] memory _address = new address[](1);
        _address[0] = address(bytes20(_attestation.localEnclaveReport.reportData));

        return _addInstances(_address, false)[0];
    }

    /// @inheritdoc IVerifier
    function verifyProof(
        Context calldata _ctx,
        TaikoData.Transition calldata _tran,
        TaikoData.TierProof calldata _proof
    )
        external
    {
        // Do not run proof verification to contest an existing proof
        if (_ctx.isContesting) return;

        // Size is: 89 bytes
        // 4 bytes + 20 bytes + 65 bytes (signature) = 89
        if (_proof.data.length != 89) revert NITRO_INVALID_PROOF();

        uint32 id = uint32(bytes4(_proof.data[:4]));
        address newInstance = address(bytes20(_proof.data[4:24]));

        address oldInstance = ECDSA.recover(
            LibPublicInput.hashPublicInputs(
                _tran, address(this), newInstance, _ctx.prover, _ctx.metaHash, taikoChainId()
            ),
            _proof.data[24:]
        );

        if (!_isInstanceValid(id, oldInstance)) revert NITRO_INVALID_INSTANCE();

        if (oldInstance != newInstance) {
            _replaceInstance(id, oldInstance, newInstance);
        }
    }

    function taikoChainId() internal view virtual returns (uint64) {
        return ITaikoL1(resolve(LibStrings.B_TAIKO, false)).getConfig().chainId;
    }

    function _addInstances(
        address[] memory _instances,
        bool instantValid
    )
        private
        returns (uint256[] memory ids)
    {
        ids = new uint256[](_instances.length);

        uint64 validSince = uint64(block.timestamp);

        if (!instantValid) {
            validSince += INSTANCE_VALIDITY_DELAY;
        }

        for (uint256 i; i < _instances.length; ++i) {
            if (addressRegistered[_instances[i]]) {
                revert NITRO_ALREADY_ATTESTED();
            }

            addressRegistered[_instances[i]] = true;

            if (_instances[i] == address(0)) revert NITRO_INVALID_INSTANCE();

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
        if (instance == address(0)) return false;
        if (instance != instances[id].addr) return false;
        return instances[id].validSince <= block.timestamp
            && block.timestamp <= instances[id].validSince + INSTANCE_EXPIRY;
    }
}
