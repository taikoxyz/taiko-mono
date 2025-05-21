// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../shared/libs/LibNames.sol";
import "../shared/libs/LibAddress.sol";
import "../shared/libs/LibBytes.sol";
import "../shared/goverance/Controller.sol";
import "../shared/bridge/IBridge.sol";

/// @title DelegateController
/// @notice This contract will be the owner of all essential contracts deployed on the L2 chain.
/// @dev Notice that when sending the message on the owner chain, the gas limit of the message must
/// not be zero, so on this chain, some EOA can help execute this transaction.
/// @dev This contract is used by Alethia Mainnet.
/// @custom:security-contact security@taiko.xyz
contract DelegateController is Controller, IMessageInvocable {
    uint64 public immutable l1ChainId;
    address public immutable l2Bridge;
    address public immutable daoController;

    error SenderNotL2Bridge();
    error InvalidExecutionId();
    error SenderNotL1DaoController();

    // solhint-disable var-name-mixedcase
    uint64 private __deprecated_remoteChainId; // slot 1

    // solhint-disable var-name-mixedcase
    address private __deprecated_admin;

    /// @notice The last processed execution ID.
    uint64 public lastExecutionId; // slot 2

    // solhint-disable var-name-mixedcase
    address private __deprecated_remoteOwner;

    uint256[48] private __gap;

    constructor(uint64 _l1ChainId, address _l2Bridge, address _daoController) Controller() {
        l1ChainId = _l1ChainId;
        l2Bridge = _l2Bridge;
        daoController = _daoController;
    }

    function init() external initializer {
        __Essential_init(address(this));
    }

    /// @inheritdoc IMessageInvocable
    function onMessageInvocation(bytes calldata _data) external payable nonReentrant {
        require(msg.sender == l2Bridge, SenderNotL2Bridge());

        IBridge.Context memory ctx = IBridge(msg.sender).context();
        require(
            ctx.srcChainId == l1ChainId && ctx.from == daoController, SenderNotL1DaoController()
        );

        (uint64 executionId, Controller.Action[] memory actions) =
            abi.decode(_data, (uint64, Controller.Action[]));

        // Check txID
        require(executionId == 0 || executionId == ++lastExecutionId, InvalidExecutionId());

        _executeActions(actions);
    }
}
