// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoTest.sol";
import "../../contracts/L1/TaikoData.sol";

contract TestTaikoL2AdjustExcess is TaikoTest {
    using SafeCast for uint256;

    // Initial salt for semi-random generation
    uint256 salt = 2_195_684_615_435_261_315_311;
    // same as `block_gas_limit` in foundry.toml
    uint32 public constant BLOCK_GAS_LIMIT = 30_000_000;

    address public addressManager;
    TaikoL2EIP1559Configurable public L2;

    function setUp() public {
        addressManager = deployProxy({
            name: "address_manager",
            impl: address(new AddressManager()),
            data: abi.encodeCall(AddressManager.init, (address(0)))
        });

        SignalService ss = SignalService(
            deployProxy({
                name: "signal_service",
                impl: address(new SignalService()),
                data: abi.encodeCall(SignalService.init, (address(0), addressManager)),
                registerTo: addressManager
            })
        );

        uint64 gasExcess = 20_000_000_000;
        uint8 quotient = 8;
        uint32 gasTarget = 0;
        uint64 l1ChainId = 12_345;

        L2 = TaikoL2EIP1559Configurable(
            payable(
                deployProxy({
                    name: "taiko",
                    impl: address(new TaikoL2EIP1559Configurable()),
                    data: abi.encodeCall(
                        TaikoL2.init, (address(0), addressManager, l1ChainId, gasExcess)
                    ),
                    registerTo: addressManager
                })
            )
        );

        //        L2.setConfigAndExcess(LibL2Config.Config(gasTarget, quotient), gasExcess);

        ss.authorize(address(L2), true);

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 30);
    }

    function test_L2_AdjustExcess() external {
        uint64 currGasExcess = 20_000_000_000;
        uint64 currGasTarget = 0;
        uint64 newGasTarget = 5_000_000 * 8;
        //        uint64 newGasExcess = L2.adjustExcess(currGasExcess, currGasTarget, newGasTarget);
        //        console2.log("After adjustExcess, newGasExcess is", newGasExcess);
        TaikoData.BaseFeeConfig memory config = TaikoData.BaseFeeConfig({
            adjustmentQuotient: 8,
            sharingPctg: 0,
            gasIssuancePerSecond: 5_000_000,
            minGasExcess: 1_340_000_000,
            maxGasIssuancePerBlock: 600_000_000
        });
        (uint256 basefee, uint64 parentGasExcess) =
            L2.calculateBaseFee(config, 36, currGasExcess, 0);
        console2.log("basefee is", basefee);
        console2.log("parentGasExcess is", parentGasExcess);
        uint64 newGasExcess2 = L2.adjustExcess(parentGasExcess, newGasTarget, newGasTarget);
        console2.log("After adjustExcess, newGasExcess2 is", newGasExcess2);
        (uint256 basefee2, uint64 parentGasExcess2) =
            L2.calculateBaseFee(config, 36, newGasExcess2, 151_461);
        console2.log("basefee2 is", basefee2);
        console2.log("parentGasExcess2 is", parentGasExcess2);
    }
}
