// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../Layer1Test.sol";
import "./TestTierRouter.sol";
import "./TestVerifier.sol";

abstract contract TaikoL1TestBase is Layer1Test {
    bytes32 internal GENESIS_BLOCK_HASH = keccak256("GENESIS_BLOCK_HASH");

    TaikoToken internal eBondToken;
    SignalService internal eSignalService;
    Bridge internal eBridge;
    ITierRouter internal eTierRouter;
    TestVerifier internal eTier1Verifier;
    TestVerifier internal eTier2Verifier;
    TestVerifier internal eTier3Verifier;
    TaikoL1 internal taikoL1;

    address internal tSignalService = randAddress();
    address internal taikoL2 = randAddress();

    function setUpOnEthereum() internal override {
        eBondToken = deployBondToken();
        eSignalService = deploySignalService(address(new SignalService()));
        eBridge = deployBridge(address(new Bridge()));
        eTierRouter = deployTierRouter();
        eTier1Verifier = deployVerifier("");
        eTier2Verifier = deployVerifier("tier_2");
        eTier3Verifier = deployVerifier("tier_3");
        taikoL1 = deployTaikoL1(getConfig());

        eSignalService.authorize(address(taikoL1), true);
    }

    function setUpOnTaiko() internal override {
        register("taiko", taikoL2);
        register("signal_service", tSignalService);
    }

    // TODO: order and name mismatch
    function giveEthAndTko(address to, uint256 amountTko, uint256 amountEth) internal {
        vm.deal(to, amountEth);
        eBondToken.transfer(to, amountTko);

        vm.prank(to);
        eBondToken.approve(address(taikoL1), amountTko);

        console2.log("Bond balance :", to, eBondToken.balanceOf(to));
        console2.log("Ether balance:", to, to.balance);
    }

    function getConfig() public pure virtual returns (TaikoData.Config memory);

    function deployTierRouter() internal returns (ITierRouter) {
        return ITierRouter(
            deploy({ name: "tier_router", impl: address(new TestTierRouter()), data: "" })
        );
    }

    function deployTaikoL1(TaikoData.Config memory config) internal returns (TaikoL1 ) {
        return  TaikoL1(
            deploy({
                name: "taiko",
                impl: address(new TaikoL1WithConfig()),
                data: abi.encodeCall(
                    TaikoL1WithConfig.initWithConfig,
                    (address(0), address(resolver), GENESIS_BLOCK_HASH, false, config)
                )
            })
        );
    }

    function deployVerifier(bytes32 name) internal returns (TestVerifier) {
        return TestVerifier(deploy({ name: name, impl: address(new TestVerifier()), data: "" }));
    }
}
