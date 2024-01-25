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

import "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "../../common/EssentialContract.sol";
import "../../thirdparty/LibBytesUtils.sol";
import "../ITaikoL1.sol";
import "./IVerifier.sol";
import { IAttestation } from "../../thirdparty/onchainRA/interfaces/IAttestation.sol";

import "forge-std/console2.sol";
/// @title SgxVerifier
/// @notice This contract is the implementation of verifying SGX signature
/// proofs on-chain. Please see references below!
/// Reference #1: https://ethresear.ch/t/2fa-zk-rollups-using-sgx/14462
/// Reference #2: https://github.com/gramineproject/gramine/discussions/1579
contract SgxVerifier is EssentialContract, IVerifier {
    /// @dev Each public-private key pair (Ethereum address) is generated within
    /// the SGX program when it boots up. The off-chain remote attestation
    /// ensures the validity of the program hash and has the capability of
    /// bootstrapping the network with trustworthy instances.
    struct Instance {
        address addr;
        uint64 addedAt; // We can calculate if expired
    }

    uint256 public constant INSTANCE_EXPIRY = 180 days;

    /// @dev For gas savings, we shall assign each SGX instance with an id
    /// so that when we need to set a new pub key, just write storage once.
    uint256 public nextInstanceId; // slot 1

    /// @dev One SGX instance is uniquely identified (on-chain) by it's ECDSA
    /// public key (or rather ethereum address). Once that address is used (by
    /// proof verification) it has to be overwritten by a new one (representing
    /// the same instance). This is due to side-channel protection. Also this
    /// public key shall expire after some time. (For now it is a long enough 6
    /// months setting.)
    mapping(uint256 instanceId => Instance) public instances; // slot 2

    uint256[48] private __gap;

    event InstanceAdded(
        uint256 indexed id, address indexed instance, address replaced, uint256 timstamp
    );

    error SGX_INVALID_ATTESTATION();
    error SGX_INVALID_INSTANCE();
    error SGX_INVALID_INSTANCES();
    error SGX_INVALID_PROOF();
    error SGX_MISSING_ATTESTATION();

    /// @notice Initializes the contract with the provided address manager.
    /// @param _addressManager The address of the address manager contract.
    function init(address _addressManager) external initializer {
        __Essential_init(_addressManager);
    }

    /// @notice Adds trusted SGX instances to the registry.
    /// @param _instances The address array of trusted SGX instances.
    /// @return ids The respective instanceId array per addresses.
    function addInstances(address[] calldata _instances)
        external
        onlyOwner
        returns (uint256[] memory ids)
    {
        if (_instances.length == 0) revert SGX_INVALID_INSTANCES();
        ids = _addInstances(_instances);
    }

    /// @notice Adds SGX instances to the registry by another SGX instance.
    /// @param id The id of the SGX instance who is adding new members.
    /// @param newInstance The new address of this instance.
    /// @param extraInstances The address array of SGX instances.
    /// @param signature The signature proving authenticity.
    /// @return ids The respective instanceId array per addresses.
    function addInstances(
        uint256 id,
        address newInstance,
        address[] calldata extraInstances,
        bytes calldata signature
    )
        external
        returns (uint256[] memory ids)
    {
        address taikoL1 = resolve("taiko", false);
        bytes32 signedHash = keccak256(
            abi.encode(
                "ADD_INSTANCES",
                ITaikoL1(taikoL1).getConfig().chainId,
                address(this),
                newInstance,
                extraInstances
            )
        );
        address oldInstance = ECDSA.recover(signedHash, signature);
        if (!_isInstanceValid(id, oldInstance)) revert SGX_INVALID_INSTANCE();

        _replaceInstance(id, oldInstance, newInstance);

        ids = _addInstances(extraInstances);
    }

    /// @inheritdoc IVerifier
    function verifyProof(
        Context calldata ctx,
        TaikoData.Transition calldata tran,
        TaikoData.TierProof calldata proof
    )
        external
        onlyFromNamed2("taiko", "tier_sgx_and_pse_zkevm")
    {
        // Do not run proof verification to contest an existing proof
        if (ctx.isContesting) return;

        address automataDcapAttestation = (resolve("automata_dcap_attestation", true));

        // Size is: 89 bytes at least - if attestation is on, than it shall be more
        // 4 bytes + 20 bytes + 65 bytes (signature) = 89
        // If on-chain attestation is suported, the proof shall be extra +2 bytes (marking the lengnth of attestation) + attestation length
        if (proof.data.length < 89) revert SGX_INVALID_PROOF();

        uint32 id = uint32(bytes4(LibBytesUtils.slice(proof.data, 0, 4)));
        address newInstance = address(bytes20(LibBytesUtils.slice(proof.data, 4, 20)));
        bytes memory signature = LibBytesUtils.slice(proof.data, 24, 65);

        if (automataDcapAttestation != address(0) ) {
            if (proof.data.length < 91) {
                revert SGX_MISSING_ATTESTATION();
            }
            uint16 length =  uint16(bytes2(LibBytesUtils.slice(proof.data, 89, 2)));
            bytes memory quote = LibBytesUtils.slice(proof.data, 91, length);
            if(!IAttestation(automataDcapAttestation).verifyAttestation(quote)) {
                revert SGX_INVALID_ATTESTATION();
            }
        }

        address oldInstance =
            ECDSA.recover(getSignedHash(tran, newInstance, ctx.prover, ctx.metaHash), signature);

        if (!_isInstanceValid(id, oldInstance)) revert SGX_INVALID_INSTANCE();
        _replaceInstance(id, oldInstance, newInstance);
    }

    function getSignedHash(
        TaikoData.Transition memory tran,
        address newInstance,
        address prover,
        bytes32 metaHash
    )
        public
        view
        returns (bytes32 signedHash)
    {
        address taikoL1 = resolve("taiko", false);
        return keccak256(
            abi.encode(
                "VERIFY_PROOF",
                ITaikoL1(taikoL1).getConfig().chainId,
                address(this),
                tran,
                newInstance,
                prover,
                metaHash
            )
        );
    }

    function _addInstances(address[] calldata _instances) private returns (uint256[] memory ids) {
        ids = new uint256[](_instances.length);

        for (uint256 i; i < _instances.length; ++i) {
            if (_instances[i] == address(0)) revert SGX_INVALID_INSTANCE();

            instances[nextInstanceId] = Instance(_instances[i], uint64(block.timestamp));
            ids[i] = nextInstanceId;

            emit InstanceAdded(nextInstanceId, _instances[i], address(0), block.timestamp);

            nextInstanceId++;
        }
    }

    function _replaceInstance(uint256 id, address oldInstance, address newInstance) private {
        instances[id] = Instance(newInstance, uint64(block.timestamp));
        emit InstanceAdded(id, newInstance, oldInstance, block.timestamp);
    }

    function _isInstanceValid(uint256 id, address instance) private view returns (bool) {
        if (instance == address(0)) return false;
        if (instance != instances[id].addr) return false;
        return instances[id].addedAt + getExpiry() > block.timestamp;
    }

    /// @notice Tells if we need to set expiry to 'infinity' (for attestation tests).
    /// @return Override in test contract
    function getExpiry() public pure virtual returns (uint256) {
        return INSTANCE_EXPIRY;
    }
}
