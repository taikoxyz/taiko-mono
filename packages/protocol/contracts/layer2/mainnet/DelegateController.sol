// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "src/shared/libs/LibNames.sol";
import "src/shared/libs/LibAddress.sol";
import "src/shared/libs/LibBytes.sol";
import "src/shared/goverance/Controller.sol";
import "src/shared/bridge/IBridge.sol";

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

    // __reserved0 and __reserved1 are here to make sure this contract's layout is compatible with
    // the DelegateOwner contract.

    // solhint-disable var-name-mixedcase
    uint256 private __reserved0;

    /// @notice The last processed execution ID.
    uint64 public lastExecutionId; // slot 2

    // solhint-disable var-name-mixedcase
    address private __reserved1; //
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
        require(executionId == 0 || executionId == ++lastExecutionId, InvalidTxId());

        _executeActions(actions);
    }
}

//  delegateControllerImpl 1: 0x5aB94081655555cC48653d7956D02C6402F32b99
//   delegateControllerImpl 2: 0x30AEf68b8A1784C5C553be9391b6c7cbd1f76ba3
//   > 'delegate_controller'
//          proxy   : 0x5C96Ff5B7F61b9E3436Ef04DA1377C8388dfC106
//          impl    : 0x5aB94081655555cC48653d7956D02C6402F32b99
//          owner   : 0x5C96Ff5B7F61b9E3436Ef04DA1377C8388dfC106
//          chain id: 167000
//   barUpgradeableImpl 1: 0x69E8296EE9feb2bf9cb46c266CdA4763451f51C0
//   barUpgradeableImpl 2: 0x6aC624FD2b3Bf8fbf1b121f7Aba0d1eC51f4c347
//   > 'bar_upgradeable'
//          proxy   : 0x43d5b77471D599D89340511d731BE80E8D54b327
//          impl    : 0x69E8296EE9feb2bf9cb46c266CdA4763451f51C0
//          owner   : 0x5C96Ff5B7F61b9E3436Ef04DA1377C8388dfC106
//          chain id: 167000
