// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../contracts/thirdparty/AddressManager.sol";
import "../contracts/L1/TaikoL1.sol";
import "../contracts/L1/TaikoData.sol";

contract TaikoL1Test is Test {
    TaikoL1 public L1;

    AddressManager public addressManager;
    bytes32 public genesisBlockHash;

    function propose(address proposer, uint256 txListSize) internal {
        bytes[] memory inputs = new bytes[](3);
        inputs[1] = bytes("txList");
        inputs[2] = bytes("txListProof");

        TaikoData.BlockMetadata memory meta = TaikoData.BlockMetadata({
            id: 0,
            l1Height: 0,
            l1Hash: 0,
            beneficiary: proposer,
            txListHash: keccak256(inputs[1]),
            txListProofHash: keccak256(inputs[2]),
            mixHash: 0,
            extraData: new bytes(10),
            gasLimit: 1000000,
            timestamp: 0
        });

        inputs[0] = abi.encode(meta);

        vm.prank(proposer, proposer);
        vm.deal(proposer, 1 ether);
        L1.proposeBlock(inputs);
    }

    function setUp() public {
        addressManager = new AddressManager();
        addressManager.init();

        uint256 feeBase = 1E18;
        L1 = new TaikoL1();
        L1.init(address(addressManager), genesisBlockHash, feeBase);
    }

    function testProposeSingleBlock() public {
        address alice = 0xc8885E210E59Dba0164Ba7CDa25f607e6d586B7A;
        propose(alice, 1024);
    }
}
