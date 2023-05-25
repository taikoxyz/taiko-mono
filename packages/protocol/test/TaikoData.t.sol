pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {TaikoData} from "../contracts/L1/TaikoData.sol";


contract TestTaikoData is Test { 
	TaikoData.EthDeposit[] lst;
    TaikoData.BlockMetadata meta;

    function setUp() public {
		// lst = new TaikoData.EthDeposit[](0);
		// meta = TaikoData.BlockMetadata({
		// 	id: uint64(1),
		// 	timestamp: uint64(1),
		// 	l1Height: uint64(1),
		// 	l1Hash: bytes32("abcd"),
		// 	mixHash: bytes32("abcd"),
		// 	txListHash: bytes32("abcd"),
		// 	txListByteStart: uint24(1),
		// 	txListByteEnd: uint24(100),
		// 	gasLimit: uint32(10000),
		// 	beneficiary: address(0x10020FCb72e27650651B05eD2CEcA493bC807Ba4),
		// 	treasury: address(0x50081b12838240B1bA02b3177153Bca678a86078),
		// 	depositsProcessed: lst
		// 	TaikoData.EthDeposit({recipient: address(0x10020FCb72e27650651B05eD2CEcA493bC807Ba4), amount: uint96(2)})
		// });
    }

    function test_abiEncode() public {

    }

}