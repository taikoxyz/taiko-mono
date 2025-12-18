// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/bridge/IBridge.sol";
import "src/shared/governance/Controller.sol";
import "src/shared/libs/LibAddress.sol";
import "src/shared/libs/LibBytes.sol";
import "src/shared/libs/LibNames.sol";

import "./DelegateController_Layout.sol"; // DO NOT DELETE

/// @title DelegateController
/// @notice This contract will be the owner of all essential contracts deployed on the L2 chain.
/// @dev Notice that when sending the message on the owner chain, the gas limit of the message must
/// not be zero, so on this chain, some EOA can help execute this transaction.
/// @dev This contract is used by Alethia Mainnet.
/// @custom:security-contact security@taiko.xyz
contract DelegateController is Controller, IMessageInvocable {
    address public immutable l2Bridge;
    address public immutable daoController;
    uint64 public immutable l1ChainId;

    error SenderNotL2Bridge();
    error InvalidTxId();
    error SenderNotL1DaoController();

    uint256[50] private __gap;

    constructor(uint64 _l1ChainId, address _l2Bridge, address _daoController) {
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

        uint64 executionId = uint64(bytes8(_data[:8]));
        require(executionId == 0 || executionId == ++lastExecutionId, InvalidTxId());

        _executeActions(_data[8:]);
    }
}
