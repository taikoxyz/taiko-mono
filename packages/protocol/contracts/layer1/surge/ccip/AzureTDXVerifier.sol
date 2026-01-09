// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

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

/// @title AzureTDXVerifier
/// @notice This contract is the implementation of verifying TDX signature proofs onchain.
/// @custom:security-contact security@nethermind.io
contract AzureTDXVerifier is EssentialContract {
    /// @dev Parameters for trusted TDX instances
    struct TrustedParams {
        bytes16 teeTcbSvn;
        uint24 pcrBitmap;
        bytes mrSeam;
        bytes mrTd;
        bytes32[] pcrs;
    }

    address public immutable automataDcapAttestation;

    /// @dev Mapping of registered TDX instance addresses.
    /// Slot 0.
    mapping(address instanceAddress => bool isRegistered) public instances;

    /// @dev Indicates whether a quote nonce hash has been used or not.
    /// Slot 1.
    mapping(bytes32 nonceHash => bool isUsed) public nonceUsed;

    /// @dev The trusted parameters for trusted TDX instances
    /// Slot 2.
    mapping(uint256 index => TrustedParams trustedParams) public trustedParams;

    uint256[47] private __gap;

    /// @notice Emitted when a new TDX instance is added to the registry.
    /// @param instance The address of the TDX instance.
    event InstanceAdded(address indexed instance);

    /// @notice Emitted when a TDX instance is deleted from the registry.
    /// @param instance The address of the TDX instance.
    event InstanceDeleted(address indexed instance);

    /// @notice Emitted when trusted params are updated
    /// @param index The index of the trusted params
    /// @param params The trusted params
    event TrustedParamsUpdated(uint256 indexed index, TrustedParams params);

    constructor(address _automataDcapAttestation) {
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

    /// @notice Adds trusted TDX instances to the registry.
    /// @param _instances The address array of trusted TDX instances.
    function addInstances(address[] calldata _instances) external onlyOwner {
        _addInstances(_instances);
    }

    /// @notice Deletes TDX instances from the registry.
    /// @param _instances The addresses of TDX instances to delete.
    function deleteInstances(address[] calldata _instances) external onlyOwner {
        uint256 size = _instances.length;
        for (uint256 i; i < size; ++i) {
            address instance = _instances[i];
            require(instances[instance], SurgeCCIP_TdxInvalidInstance());

            delete instances[instance];

            emit InstanceDeleted(instance);
        }
    }

    /// @notice Sets the trusted parameters for quote verification to a specific index
    /// @param _index The index of the trusted parameters
    /// @param _params The trusted parameters
    function setTrustedParams(
        uint256 _index,
        TrustedParams calldata _params
    )
        external
        onlyOwner
    {
        trustedParams[_index] = _params;
        emit TrustedParamsUpdated(_index, _params);
    }

    // ---------------------------------------------------------------
    // External permissionless functions
    // ---------------------------------------------------------------

    /// @notice Adds a TDX instance after the attestation is verified
    /// @param _trustedParamsIdx The index of the trusted parameters.
    /// @param _attestation The attestation verification parameters.
    function registerInstance(
        uint256 _trustedParamsIdx,
        AzureTDX.VerifyParams memory _attestation
    )
        external
    {
        (bool verified, bytes memory output) = IAutomataDcapAttestation(automataDcapAttestation)
            .verifyAndAttestOnChain(AzureTDX.verify(_attestation));
        require(verified, SurgeCCIP_TdxInvalidAttestation());

        TrustedParams memory params = trustedParams[_trustedParamsIdx];
        require(params.pcrBitmap != 0, SurgeCCIP_TdxInvalidTrustedParams());
        _validateAttestationOutput(output, _attestation, params);

        bytes32 nonceHash = keccak256(_attestation.nonce);
        require(!nonceUsed[nonceHash], SurgeCCIP_TdxInvalidAttestation());
        nonceUsed[nonceHash] = true;

        address[] memory addresses = new address[](1);
        addresses[0] = address(bytes20(_attestation.attestationDocument.userData));

        _addInstances(addresses);
    }

    /// @notice Checks if an address is a registered TDX instance
    /// @param _instance The address to check
    /// @return True if the address is a registered instance
    function isInstanceRegistered(address _instance) external view returns (bool) {
        return instances[_instance];
    }

    // ---------------------------------------------------------------
    // Private functions
    // ---------------------------------------------------------------

    function _addInstances(address[] memory _instances) private {
        uint256 size = _instances.length;

        for (uint256 i; i < size; ++i) {
            address instance = _instances[i];
            require(instance != address(0), SurgeCCIP_TdxInvalidInstance());
            require(!instances[instance], SurgeCCIP_TdxAlreadyAttested());

            instances[instance] = true;

            emit InstanceAdded(instance);
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
        bytes6 teeVersionType = bytes6(BytesUtils.substring(_attestationOutput, 0, 6));

        // TEE Version (0x04) || TEE Type (0x81000000)
        require(teeVersionType == 0x000481000000, SurgeCCIP_TdxInvalidVersionType());

        bytes16 teeTcbSvn = bytes16(BytesUtils.substring(_attestationOutput, 13, 16));

        require(teeTcbSvn == _params.teeTcbSvn, SurgeCCIP_TdxInvalidTcbSvn());

        bytes memory mrSeam = BytesUtils.substring(_attestationOutput, 29, 48);

        require(mrSeam.length == _params.mrSeam.length, SurgeCCIP_TdxInvalidMrSeam());
        require(keccak256(mrSeam) == keccak256(_params.mrSeam), SurgeCCIP_TdxInvalidMrSeam());

        bytes memory mrTd = BytesUtils.substring(_attestationOutput, 149, 48);
        require(mrTd.length == _params.mrTd.length, SurgeCCIP_TdxInvalidMrTd());
        require(keccak256(mrTd) == keccak256(_params.mrTd), SurgeCCIP_TdxInvalidMrTd());

        bytes32[] memory pcrs = new bytes32[](24);
        for (uint256 i; i < _attestation.pcrs.length; ++i) {
            pcrs[_attestation.pcrs[i].index] = _attestation.pcrs[i].digest;
        }

        uint256 pcrIdx;
        for (uint256 i; i < 24; ++i) {
            if (_params.pcrBitmap & (1 << i) != 0) {
                require(pcrs[i] == _params.pcrs[pcrIdx], SurgeCCIP_TdxInvalidPcr());
                ++pcrIdx;
            }
        }
    }

    // ---------------------------------------------------------------
    // Custom Errors
    // ---------------------------------------------------------------

    error SurgeCCIP_TdxAlreadyAttested();
    error SurgeCCIP_TdxInvalidAttestation();
    error SurgeCCIP_TdxInvalidInstance();
    error SurgeCCIP_TdxInvalidTrustedParams();
    error SurgeCCIP_TdxInvalidVersionType();
    error SurgeCCIP_TdxInvalidTcbSvn();
    error SurgeCCIP_TdxInvalidMrSeam();
    error SurgeCCIP_TdxInvalidMrTd();
    error SurgeCCIP_TdxInvalidPcr();
}
