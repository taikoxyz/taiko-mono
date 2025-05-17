// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./SignalBoost.sol";

contract SignalBoostSender is SignalBoost {
    uint256[50] private __gap;

    constructor(ISignalService _signalService) SignalBoost(_signalService) { }

    function queryToSend(SignalRequest[] calldata _requests)
        external
        nonReentrant
        returns (SignalResponse[] memory responses_)
    {
        uint256 n = _requests.length;
        responses_ = new SignalResponse[](n);

        for (uint256 i; i < n; ++i) {
            // Call the view function
            (responses_[i].success, responses_[i].output) =
                _requests[i].target.staticcall(_requests[i].payload);
        }

        signalService.sendSignal(hashRequestsAndResponses(_requests, responses_));
    }
}
