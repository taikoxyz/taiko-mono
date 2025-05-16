// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../common/EssentialContract.sol";
import "../signal/ISignalService.sol";

interface ISignalBoost {
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

contract SignalBoost is EssentialContract, ISignalBoost {
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

    function writeSignals(SignalRequest[] calldata _requests)
        external
        nonReentrant
        returns (SignalResponse[] memory responses_)
    {
        uint256 len = _requests.length;
        responses_ = new SignalResponse[](len);
        bytes32[] memory leaves = new bytes32[](len);

        for (uint256 i; i < len; ++i) {
            // Call the view function
            (responses_[i].success, responses_[i].output) =
                _requests[i].target.staticcall(_requests[i].payload);

            leaves[i] = keccak256(abi.encode(_requests[i], responses_[i]));
        }

        // Compute Merkle root
        bytes32 signalRequestsRoot; // = merklize(leaves);

        // Write to the SignalService contract
        signalService.sendSignal(signalRequestsRoot);
    }
}

contract SignalBoostL2 is EssentialContract, ISignalBoost {
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

    function validateSignalRequestResponse(
        bytes32 _signalRequestsRoot,
        SignalRequest calldata _request,
        SignalResponse calldata _response,
        bytes[] calldata _proof
    )
        external
        view
        returns (uint256)
    {
        // Verify the signal was written to the L2 SignalService
        require(signalService.verifySignal(_signalRequestsRoot), "Signal not found");

        // Reconstruct the Merkle leaf
        bytes32 leaf = keccak256(abi.encode(_request, _response));

        // Verify the Merkle proof
        // require(verifyProof(_signalRequestsRoot, leaf, _proof), "Invalid Merkle proof");
    }
}
