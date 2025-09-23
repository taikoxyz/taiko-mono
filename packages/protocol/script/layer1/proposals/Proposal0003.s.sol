// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./BuildProposal.sol";

interface IBarContract {
    function withdraw(address _token, address _to, uint256 _amount) external;
}

interface IReverseRegistrar {
    function setName(string memory name) external returns (bytes32);
}

// To print the proposal action data: `P=0003 pnpm proposal`
// To dryrun the proposal on L1: `P=0003 pnpm proposal:dryrun:l1`
// To dryrun the proposal on L2: `P=0003 pnpm proposal:dryrun:l2`
contract Proposal0003 is BuildProposal {
    // L2 contracts
    address public constant L2_BAR_CONTRACT = 0x0e577Bb67d38c18E4B9508984DA36d6D316ade58;
    address public constant L2_BAR_CONTRACT_NEW_IMPL = 0x7fBd8DbA7678eDb9eaDf83e204372d8a39F75398;
    address public constant L2_DANIEL_WANG_ADDRESS = 0xf0A0d6Bd4aA94F53F3FB2c88488202a9E9eD2c55;

    function buildL1Actions() internal pure override returns (Controller.Action[] memory actions) { }

    function buildL2Actions()
        internal
        pure
        override
        returns (uint64 l2ExecutionId, uint32 l2GasLimit, Controller.Action[] memory actions)
    {
        l2ExecutionId = 1;
        l2GasLimit = 25_000_000;
        actions = new Controller.Action[](6);

        // Transfer 0.0001 Ether from DelegateController to Daniel Wang
        actions[0] =
            Controller.Action({ target: L2_DANIEL_WANG_ADDRESS, value: 0.0001 ether, data: "" });

        // Transfer 1 TAIKO from DelegateController to Daniel Wang
        actions[1] = Controller.Action({
            target: L2.TAIKO_TOKEN,
            value: 0,
            data: abi.encodeCall(IERC20.transfer, (L2_DANIEL_WANG_ADDRESS, 1 ether))
        });

        // Upgrade BarUpgradeable to use a new (but identical)implementation
        actions[2] = buildUpgradeAction(L2_BAR_CONTRACT, L2_BAR_CONTRACT_NEW_IMPL);

        // Transfer BarUpgradeable's ownership to Daniel Wang
        actions[3] = Controller.Action({
            target: L2_BAR_CONTRACT,
            value: 0,
            data: abi.encodeCall(Ownable.transferOwnership, (L2_DANIEL_WANG_ADDRESS))
        });

        // Transfer 0.0001 Ether from BarUpgradeable to Daniel Wang
        actions[4] = Controller.Action({
            target: L2_BAR_CONTRACT,
            value: 0,
            data: abi.encodeCall(
                IBarContract.withdraw, (address(0), L2_DANIEL_WANG_ADDRESS, 0.0001 ether)
            )
        });

        // Transfer 1 TAIKO from BarUpgradeable to Daniel Wang
        actions[5] = Controller.Action({
            target: L2_BAR_CONTRACT,
            value: 0,
            data: abi.encodeCall(
                IBarContract.withdraw, (L2.TAIKO_TOKEN, L2_DANIEL_WANG_ADDRESS, 1 ether)
            )
        });
    }
}
