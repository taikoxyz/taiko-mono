// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "contracts/shared/signal-boost/IStateQuery.sol";
import "contracts/shared/signal-boost/LibStateQuery.sol";
import "contracts/shared/signal/ISignalService.sol";
import "contracts/shared/common/EssentialContract.sol";
import "contracts/layer1/mainnet/libs/LibFasterReentryLock.sol";
import "./IStateQuerier.sol";

/// @title StateQuerier
/// @notice Contract for querying the state of multiple contracts.
/// @custom:security-contact security@taiko.xyz
contract StateQuerier is EssentialContract, IStateQuerier {
    ISignalService public immutable signalService;
    uint256[50] private __gap;

    constructor(ISignalService _signalService) EssentialContract() {
        signalService = _signalService;
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc IStateQuerier
    function queryState(IStateQuery.Query[] calldata _queries)
        external
        nonReentrant
        returns (IStateQuery.QueryResult[] memory results_, bytes32 signal_)
    {
        uint256 n = _queries.length;
        results_ = new IStateQuery.QueryResult[](n);

        for (uint256 i; i < n; ++i) {
            // Call the view function
            (results_[i].success, results_[i].output) =
                _queries[i].target.staticcall(_queries[i].payload);
        }

        signal_ = LibStateQuery.hashQueriesToSignal(
            uint64(block.chainid), block.timestamp, _queries, results_
        );

        signalService.sendSignal(signal_);
    }

    function _storeReentryLock(uint8 _reentry) internal override {
        LibFasterReentryLock.storeReentryLock(_reentry);
    }

    function _loadReentryLock() internal view override returns (uint8) {
        return LibFasterReentryLock.loadReentryLock();
    }
}
