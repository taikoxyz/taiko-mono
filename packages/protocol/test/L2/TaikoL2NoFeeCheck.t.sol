// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../TaikoTest.sol";

contract SkipBasefeeCheckL2 is TaikoL2EIP1559Configurable {
    function skipFeeCheck() public pure override returns (bool) {
        return true;
    }
}

contract TestTaikoL2NoFeeCheck is TaikoTest {
    using SafeCast for uint256;

    // Initial salt for semi-random generation
    uint256 salt = 2_195_684_615_435_261_315_311;
    // same as `block_gas_limit` in foundry.toml
    uint32 public constant BLOCK_GAS_LIMIT = 30_000_000;

    address public addressManager;
    SkipBasefeeCheckL2 public L2;

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

        uint64 gasExcess = 0;
        uint8 quotient = 8;
        uint32 gasTarget = 60_000_000;
        uint64 l1ChainId = 12_345;

        gasExcess = 195_420_300_100;
        L2 = SkipBasefeeCheckL2(
            payable(
                deployProxy({
                    name: "taiko",
                    impl: address(new SkipBasefeeCheckL2()),
                    data: abi.encodeCall(
                        TaikoL2.init, (address(0), addressManager, l1ChainId, gasExcess)
                        ),
                    registerTo: addressManager
                })
            )
        );

        L2.setConfigAndExcess(
            LibL2Config.Config(gasTarget, quotient, uint64(gasTarget) * 300), gasExcess
        );

        ss.authorize(address(L2), true);

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 30);
    }

    function test_L2_NoFeeCheck_simulation_lower_traffic() external {
        console2.log("LOW TRAFFIC STARTS"); // For parser
        _simulation(100_000, 10_000_000, 1, 8);
        console2.log("LOW TRAFFIC ENDS");
    }

    function test_L2_NoFeeCheck_simulation_higher_traffic() external {
        console2.log("HIGH TRAFFIC STARTS"); // For parser
        _simulation(100_000, 120_000_000, 1, 8);
        console2.log("HIGH TRAFFIC ENDS");
    }

    function test_L2_NoFeeCheck_simulation_target_traffic() external {
        console2.log("TARGET TRAFFIC STARTS"); // For parser
        _simulation(60_000_000, 0, 12, 0);
        console2.log("TARGET TRAFFIC ENDS");
    }

    function _simulation(
        uint256 minGas,
        uint256 maxDiffToMinGas,
        uint8 quickest,
        uint8 maxDiffToQuickest
    )
        internal
    {
        // We need to randomize the:
        // - parent gas used (We should sometimes exceed 150.000.000 gas / 12
        // seconds (to simulate congestion a bit) !!)
        // - the time we fire away an L2 block (anchor transaction).
        // The rest is baked in.
        // initial gas excess issued: 49954623777 (from eip1559_util.py) if we
        // want to stick to the params of 10x Ethereum gas, etc.

        // This variables counts if we reached the 12seconds (L1) height, if so
        // then resets the accumulated parent gas used and increments the L1
        // height number
        uint8 accumulated_seconds = 0;
        uint256 accumulated_parent_gas_per_l1_block = 0;
        uint64 l1Height = uint64(block.number);
        uint64 l1BlockCounter = 0;
        uint64 maxL2BlockCount = 180;
        uint256 allBaseFee = 0;
        uint256 allGasUsed = 0;
        uint256 newRandomWithoutSalt;
        // Simulate 200 L2 blocks
        for (uint256 i; i < maxL2BlockCount; ++i) {
            newRandomWithoutSalt = uint256(
                keccak256(
                    abi.encodePacked(
                        block.prevrandao, msg.sender, block.timestamp, i, newRandomWithoutSalt, salt
                    )
                )
            );

            uint32 currentGasUsed;
            if (maxDiffToMinGas == 0) {
                currentGasUsed = uint32(minGas);
            } else {
                currentGasUsed =
                    uint32(pickRandomNumber(newRandomWithoutSalt, minGas, maxDiffToMinGas));
            }
            salt = uint256(keccak256(abi.encodePacked(currentGasUsed, salt)));
            accumulated_parent_gas_per_l1_block += currentGasUsed;
            allGasUsed += currentGasUsed;

            uint8 currentTimeAhead;
            if (maxDiffToQuickest == 0) {
                currentTimeAhead = uint8(quickest);
            } else {
                currentTimeAhead =
                    uint8(pickRandomNumber(newRandomWithoutSalt, quickest, maxDiffToQuickest));
            }
            accumulated_seconds += currentTimeAhead;

            if (accumulated_seconds >= 12) {
                console2.log(
                    "Gas used per L1 block:", l1Height, ":", accumulated_parent_gas_per_l1_block
                );
                l1Height++;
                l1BlockCounter++;
                accumulated_parent_gas_per_l1_block = 0;
                accumulated_seconds = 0;
            }

            vm.prank(L2.GOLDEN_TOUCH_ADDRESS());
            _anchorSimulation(currentGasUsed, l1Height);
            (uint256 currentBaseFee,) = L2.getBasefee(l1Height, currentGasUsed);
            allBaseFee += currentBaseFee;
            console2.log("Actual gas in L2 block is:", currentGasUsed);
            console2.log("L2block to baseFee is:", i, ":", currentBaseFee);
            vm.roll(block.number + 1);

            vm.warp(block.timestamp + currentTimeAhead);
        }

        console2.log("Average wei gas price per L2 block is:", (allBaseFee / maxL2BlockCount));
        console2.log("Average gasUsed per L1 block:", (allGasUsed / l1BlockCounter));
    }

    function test_L2_NoFeeCheck_L2_AnchorTx_signing(bytes32 digest) external {
        (uint8 v, uint256 r, uint256 s) = LibL2Signer.signAnchor(digest, uint8(1));
        address signer = ecrecover(digest, v + 27, bytes32(r), bytes32(s));
        assertEq(signer, L2.GOLDEN_TOUCH_ADDRESS());

        (v, r, s) = LibL2Signer.signAnchor(digest, uint8(2));
        signer = ecrecover(digest, v + 27, bytes32(r), bytes32(s));
        assertEq(signer, L2.GOLDEN_TOUCH_ADDRESS());

        vm.expectRevert();
        LibL2Signer.signAnchor(digest, uint8(0));

        vm.expectRevert();
        LibL2Signer.signAnchor(digest, uint8(3));
    }

    // Semi-random number generator
    function pickRandomNumber(
        uint256 randomNum,
        uint256 lowerLimit,
        uint256 diffBtwLowerAndUpperLimit
    )
        internal
        view
        returns (uint256)
    {
        randomNum = uint256(keccak256(abi.encodePacked(randomNum, salt)));
        return (lowerLimit + (randomNum % diffBtwLowerAndUpperLimit));
    }

    function _anchorSimulation(uint32 parentGasLimit, uint64 l1Height) private {
        bytes32 l1Hash = randBytes32();
        bytes32 l1StateRoot = randBytes32();
        L2.anchor(l1Hash, l1StateRoot, l1Height, parentGasLimit);
    }
}
