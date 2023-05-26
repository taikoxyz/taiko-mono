pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {TaikoData} from "../contracts/L1/TaikoData.sol";


contract TestTaikoData is Test { 
	TaikoData.EthDeposit[] lst;
    // TaikoData.BlockMetadata meta;

    function setUp() public {
    }

	function return_1() public pure returns (TaikoData.BlockMetadata memory meta) {
        meta = TaikoData.BlockMetadata({
            id: 1,
            l1Height: 1,
            l1Hash: bytes32('abcd'),
            beneficiary: address(0x10020FCb72e27650651B05eD2CEcA493bC807Ba4),
            treasury: address(0x50081b12838240B1bA02b3177153Bca678a86078),
            txListHash: bytes32('abcd'),
            txListByteStart: 0,
            txListByteEnd: 1000,
            gasLimit: 1,
            mixHash: bytes32('abcd'),
            timestamp: 1,
            depositsProcessed: new TaikoData.EthDeposit[](0)
        });
    }

	function equality(TaikoData.BlockMetadata memory meta1, TaikoData.BlockMetadata memory meta2) public returns (bool) {
		require(meta1.id == meta2.id);
		require(meta1.l1Height == meta2.l1Height);
		require(meta1.l1Hash == meta2.l1Hash);
		require(meta1.beneficiary == meta2.beneficiary);
		require(meta1.treasury == meta2.treasury);
		require(meta1.txListHash == meta2.txListHash);
		require(meta1.txListByteStart == meta2.txListByteStart);
		require(meta1.txListByteEnd == meta2.txListByteEnd);
		require(meta1.gasLimit == meta2.gasLimit);
		require(meta1.mixHash == meta2.mixHash);
		require(meta1.timestamp == meta2.timestamp);
		for (uint256 i = 0; i < meta1.depositsProcessed.length; i++) {
            require(meta1.depositsProcessed[i].recipient == meta2.depositsProcessed[i].recipient);
			require(meta1.depositsProcessed[i].amount == meta2.depositsProcessed[i].amount);
		}
		return true;
	}

    function test_abiEncode() public {
		TaikoData.BlockMetadata memory meta = return_1();
		// console2.logBytes(abi.encode(meta));
		require(equality(abi.decode(abi.encode(meta), (TaikoData.BlockMetadata)), meta) == true);
    }

}