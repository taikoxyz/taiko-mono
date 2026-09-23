// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../CommonTest.sol";
import "test/shared/bridge/helpers/MessageReceiver_SendingHalfEtherBalance.sol";

contract TestBridge2Base is CommonTest {
    bytes internal constant FAKE_PROOF = "";

    // Contracts on Ethereum
    SignalService internal eSignalService;
    Bridge internal eBridge;

    // Contracts on Taiko
    address internal tBridge = randAddress();

    modifier assertSameTotalBalance() {
        uint256 totalBalance = getBalanceForAccounts();
        _;
        uint256 totalBalance2 = getBalanceForAccounts();
        assertEq(totalBalance2, totalBalance);
        assertEq(address(eSignalService).balance, 0);
    }

    modifier dealEther(address addr) {
        vm.deal(addr, 100 ether);
        _;
    }

    function setUpOnEthereum() internal virtual override {
        eSignalService = _deployMockSignalService();
        eBridge = deployBridge(
            address(
                new Bridge(
                    address(resolver),
                    address(eSignalService),
                    getQuotaManager(),
                    getPauser(),
                    getRecallEnabled()
                )
            )
        );
        vm.deal(address(eBridge), 10_000 ether);
    }

    function getQuotaManager() internal virtual returns (address) {
        return address(0);
    }

    function getPauser() internal virtual returns (address) {
        return address(0);
    }

    /// @dev Enabled by default; tests of the disabled path override this.
    function getRecallEnabled() internal virtual returns (bool) {
        return true;
    }

    function setUpOnTaiko() internal virtual override {
        register("bridge", tBridge);
    }

    function getBalanceForAccounts() public view returns (uint256) {
        return Alice.balance + Bob.balance + Carol.balance + David.balance
            + address(eBridge).balance + deployer.balance;
    }

    function _deployMockSignalService() private returns (SignalService) {
        return deploySignalServiceWithoutProof(
            address(this), address(uint160(uint256(keccak256("REMOTE_SIGNAL_SERVICE_E")))), deployer
        );
    }

    /// @dev A minimal L1 -> L2 Ether message owned by `_owner`, as sent (and possibly recalled)
    /// on Ethereum. It carries no fee and no gas limit, so only the owner can process it on Taiko.
    function _l1ToL2Message(
        address _owner,
        uint256 _value
    )
        internal
        view
        returns (IBridge.Message memory message_)
    {
        message_.srcOwner = _owner;
        message_.destOwner = _owner;
        message_.srcChainId = ethereumChainId;
        message_.destChainId = taikoChainId;
        message_.value = _value;
        message_.to = Zachary;
    }

    /// @dev A minimal L2 -> L1 Ether delivery to `_destOwner`, as processed on Ethereum. The
    /// bridge itself is the target, so the invocation is prohibited and the whole value is refunded
    /// to `_destOwner` once the message is DONE.
    function _l2ToL1Message(
        address _destOwner,
        uint256 _value
    )
        internal
        view
        returns (IBridge.Message memory message_)
    {
        message_.srcChainId = taikoChainId;
        message_.destChainId = ethereumChainId;
        message_.gasLimit = 1_000_000;
        message_.destOwner = _destOwner;
        message_.value = _value;
        message_.to = address(eBridge);
    }
}
