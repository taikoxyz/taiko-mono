// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../common/EssentialContract.sol";
import "../signal/ISignalService.sol";

abstract contract ISignalBoost {
    struct SignalRequest {
        // L1 contract to query
        address target;
        // Function selector and parameters of the view function
        bytes payload;
    }

    struct SignalResponse {
        bool success;
        bytes output;
    }
}

abstract contract SignalBoost is EssentialContract, ISignalBoost {
    error InvalidParamSizes();

    ISignalService public immutable signalService;

    // solhint-disable var-name-mixedcase
    uint256[50] private __gap;

    constructor(ISignalService _signalService) EssentialContract() {
        signalService = _signalService;
    }

    /// @notice Initializes the contract.
    /// @param _owner The owner of this contract. msg.sender will be used if this value is zero.
    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    function hashRequestsAndResponses(
        SignalRequest[] calldata _requests,
        SignalResponse[] memory _responses
    )
        internal
        view
        returns (bytes32)
    {
        require(_requests.length == _responses.length, InvalidParamSizes());
        uint256 n = _requests.length;
        bytes32[] memory leaves = new bytes32[](n);
        for (uint256 i; i < n; ++i) {
            leaves[i] = keccak256(abi.encode(_requests[i], _responses[i]));
        }
        return keccak256(abi.encode(block.timestamp, leaves[0]));
    }
}
