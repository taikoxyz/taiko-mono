// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../libs/LibNames.sol";
import "./SignalBoost.sol";

interface IConsumer {
    function consume(
        ISignalBoost.SignalRequest calldata _request,
        ISignalBoost.SignalResponse calldata _response
    )
        external;
}

contract SignalBoostReceiver is SignalBoost {
    address public immutable senderAddress;
    uint64 public immutable l1ChainId;
    uint256[50] private __gap;

    constructor(
        uint64 _l1ChainId,
        ISignalService _signalService,
        address _senderAddress
    )
        SignalBoost(_signalService)
    {
        l1ChainId = _l1ChainId;
        senderAddress = _senderAddress;
    }

    function verifyToReceive(
        SignalRequest[] calldata _requests,
        SignalResponse[] calldata _responses,
        address[] calldata _consumers
    )
        external
        nonReentrant
        returns (uint256)
    {
        require(_requests.length == _responses.length, InvalidParamSizes());
        require(_requests.length == _consumers.length, InvalidParamSizes());

        bytes32 signal = hashRequestsAndResponses(_requests, _responses);

        // Using an empty proof so we only rely on same-slot signal received in anchor contract
        signalService.proveSignalReceived(l1ChainId, senderAddress, signal, bytes(""));

        for (uint256 i; i < _requests.length; ++i) {
            IConsumer(_consumers[i]).consume(_requests[i], _responses[i]);
        }
    }
}
