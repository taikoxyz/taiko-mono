// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "contracts/shared/signal-boost/IStateQuery.sol";
import "contracts/shared/signal-boost/LibStateQuery.sol";
import "contracts/shared/signal/ISignalService.sol";
import "contracts/shared/common/EssentialContract.sol";
import "./IStateVerifier.sol";
import "./IStateConsumer.sol";

/// @title StateVerifier
/// @notice Contract for verifying the state of multiple contracts.
/// @custom:security-contact security@taiko.xyz
contract StateVerifier is EssentialContract, IStateVerifier {
    error InvalidParamSizes();

    ISignalService public immutable signalService;
    uint64 public immutable l1ChainId;
    address public immutable l1StateQuerier;
    uint256[50] private __gap;

    constructor(
        ISignalService _signalService,
        uint64 _l1ChainId,
        address _l1StateQuerier
    )
        EssentialContract()
    {
        signalService = _signalService;
        l1ChainId = _l1ChainId;
        l1StateQuerier = _l1StateQuerier;
    }

    function init(address _owner) external initializer {
        __Essential_init(_owner);
    }

    /// @inheritdoc IStateVerifier
    function verifyState(
        IStateQuery.Query[] calldata _queries,
        IStateQuery.QueryResult[] calldata _results,
        address[] calldata _consumers
    )
        external
        nonReentrant
    {
        uint256 n = _queries.length;
        require(n == _results.length, InvalidParamSizes());
        require(n == _consumers.length, InvalidParamSizes());

        bytes32 signal =
            LibStateQuery.hashQueriesToSignal(l1ChainId, block.timestamp, _queries, _results);

        // Using an empty proof so we only rely on same-slot signal received in anchor contract
        signalService.proveSignalReceived(l1ChainId, l1StateQuerier, signal, bytes(""));

        for (uint256 i; i < n; ++i) {
            IStateConsumer(_consumers[i]).consume(_queries[i], _results[i]);
        }
    }
}
